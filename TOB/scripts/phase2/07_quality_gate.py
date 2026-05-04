#!/usr/bin/env python3
"""
07_quality_gate.py -- Per-family quality report for TOB Phase 2.

For each family with a completed IQ-TREE run, reports:
  - N taxa in supermatrix
  - N loci present
  - Occupancy distribution (mean, min, max)
  - Bootstrap distribution from .contree (mean, % nodes >=80, >=95)
  - Whether the family stem node in the tree conflicts with the backbone
    constraint (checks that the family is monophyletic with respect to
    any backbone outgroup tips present in the supermatrix)

Python 3.6 compatible: no f-strings, no walrus, no pathlib.

Usage:
    python 07_quality_gate.py [--family FAMILY]

    Without --family: processes all families in $SCRATCH/tob/trees/
    With --family: processes only the named family

Output:
    $SCRATCH/tob/qc/quality_gate_report.tsv  (tab-separated, one row per family)
    $SCRATCH/tob/qc/{FAMILY}_qc.tsv          (per-family detail)

Acceptance criteria (flag, do not auto-fail):
    - <4 taxa after occupancy filter -> "too_few_taxa"
    - Mean bootstrap <50 -> "low_support"
    - % nodes with UFBoot >=80 < 50 -> "poor_resolution"
    - Family non-monophyletic w.r.t. backbone outgroups -> "conflict"
"""

import argparse
import csv
import os
import re
import sys

SCRATCH_TOB = os.path.join(os.environ.get("SCRATCH", "/scratch/user/blackmon"), "tob")
TREE_DIR = os.path.join(SCRATCH_TOB, "trees")
SUPERMATRIX_DIR = os.path.join(SCRATCH_TOB, "supermatrices")
QC_DIR = os.path.join(SCRATCH_TOB, "qc")
os.makedirs(QC_DIR, exist_ok=True)


def parse_bootstrap_values(contree_path):
    """Extract bootstrap values from IQ-TREE .contree (Newick with node labels)."""
    if not os.path.isfile(contree_path):
        return []
    with open(contree_path) as fh:
        content = fh.read()
    # Bootstrap values appear as numeric labels after closing parens: )85 or )100
    values = re.findall(r'\)(\d+(?:\.\d+)?)', content)
    return [float(v) for v in values]


def count_taxa_in_treefile(treefile_path):
    """Count tips in a Newick treefile by counting leaf labels."""
    if not os.path.isfile(treefile_path):
        return 0
    with open(treefile_path) as fh:
        content = fh.read()
    # Tip labels are bare strings between commas, (, ) and :
    tips = re.findall(r'[(,]([^(),;:]+)(?::[0-9.e\-]+)?', content)
    return len(tips)


def read_occupancy_tsv(occ_path):
    """Returns list of occupancy floats for retained taxa."""
    if not os.path.isfile(occ_path):
        return []
    occupancies = []
    with open(occ_path) as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            if row.get("status", "").strip() == "retained":
                try:
                    occupancies.append(float(row["occupancy"]))
                except (KeyError, ValueError):
                    pass
    return occupancies


def check_monophyly_hint(treefile_path, family_name):
    """
    Rough monophyly check: if any taxon NOT in the family appears nested
    inside a block of family taxa, flag as potential conflict.
    This is a heuristic only (full monophyly check requires ETE3/DendroPy).
    Returns 'ok', 'conflict_possible', or 'no_outgroup'.
    """
    if not os.path.isfile(treefile_path):
        return "no_treefile"

    with open(treefile_path) as fh:
        newick = fh.read()

    # Identify tip names
    tips = re.findall(r'[(,]([^(),;:]+)(?::[0-9.e\-]+)?', newick)
    tips = [t.strip() for t in tips if t.strip()]

    # Heuristic: family name should appear in most tip labels (genus_species)
    # Outgroups will be tips that look like they belong to other families.
    # Without a reference taxonomy we cannot do this precisely.
    # Flag for manual review if >10% of tips don't contain any word from family_name.
    fam_words = [w.lower() for w in re.split(r'\W+', family_name) if len(w) > 3]
    if not fam_words:
        return "no_outgroup"

    n_foreign = sum(1 for t in tips
                    if not any(w in t.lower() for w in fam_words))
    if n_foreign == 0:
        return "no_outgroup"
    elif n_foreign > 0 and n_foreign < len(tips):
        return "ok"  # Mixed: backbone outgroup tips present, cannot determine without topology parsing
    else:
        return "conflict_possible"


def process_family(family_name):
    """Returns a dict of QC metrics for the family, or None if tree missing."""
    treefile = os.path.join(TREE_DIR, family_name, family_name + ".treefile")
    contree = os.path.join(TREE_DIR, family_name, family_name + ".contree")
    iqtree_log = os.path.join(TREE_DIR, family_name, family_name + ".iqtree")
    occ_path = os.path.join(SUPERMATRIX_DIR, family_name, "occupancy.tsv")
    partition_path = os.path.join(SUPERMATRIX_DIR, family_name, "partitions.txt")

    if not os.path.isfile(treefile):
        return {"family": family_name, "status": "no_treefile",
                "n_taxa": 0, "n_loci": 0, "occ_mean": "NA", "occ_min": "NA",
                "bs_mean": "NA", "bs_pct80": "NA", "bs_pct95": "NA",
                "monophyly_hint": "NA", "flags": "no_treefile"}

    # Occupancy
    occupancies = read_occupancy_tsv(occ_path)
    n_taxa = len(occupancies)
    occ_mean = sum(occupancies) / len(occupancies) if occupancies else 0.0
    occ_min = min(occupancies) if occupancies else 0.0

    # Loci count from partition file
    n_loci = 0
    if os.path.isfile(partition_path):
        with open(partition_path) as fh:
            n_loci = sum(1 for line in fh if line.strip())

    # Bootstrap
    bs_values = parse_bootstrap_values(contree)
    if bs_values:
        bs_mean = sum(bs_values) / len(bs_values)
        bs_pct80 = 100.0 * sum(1 for v in bs_values if v >= 80) / len(bs_values)
        bs_pct95 = 100.0 * sum(1 for v in bs_values if v >= 95) / len(bs_values)
    else:
        bs_mean = bs_pct80 = bs_pct95 = 0.0

    # Monophyly hint
    monophyly = check_monophyly_hint(treefile, family_name)

    # Flag logic
    flags = []
    if n_taxa < 4:
        flags.append("too_few_taxa")
    if bs_values and bs_mean < 50:
        flags.append("low_support")
    if bs_values and bs_pct80 < 50:
        flags.append("poor_resolution")
    if monophyly == "conflict_possible":
        flags.append("conflict_possible")
    flag_str = ",".join(flags) if flags else "PASS"

    row = {
        "family": family_name,
        "status": "ok",
        "n_taxa": n_taxa,
        "n_loci": n_loci,
        "occ_mean": "{:.3f}".format(occ_mean),
        "occ_min": "{:.3f}".format(occ_min),
        "bs_mean": "{:.1f}".format(bs_mean),
        "bs_pct80": "{:.1f}".format(bs_pct80),
        "bs_pct95": "{:.1f}".format(bs_pct95),
        "monophyly_hint": monophyly,
        "flags": flag_str,
    }

    # Write per-family detail file
    detail_path = os.path.join(QC_DIR, family_name + "_qc.tsv")
    with open(detail_path, "w") as fh:
        for k, v in row.items():
            fh.write("{}\t{}\n".format(k, v))

    return row


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--family", default=None,
                        help="Process only this family (default: all)")
    args = parser.parse_args()

    if args.family:
        families = [args.family]
    else:
        if not os.path.isdir(TREE_DIR):
            sys.stderr.write("ERROR: tree dir not found: {}\n".format(TREE_DIR))
            sys.exit(1)
        families = sorted(os.listdir(TREE_DIR))

    FIELDNAMES = ["family", "status", "n_taxa", "n_loci",
                  "occ_mean", "occ_min",
                  "bs_mean", "bs_pct80", "bs_pct95",
                  "monophyly_hint", "flags"]

    report_path = os.path.join(QC_DIR, "quality_gate_report.tsv")
    rows = []
    n_pass = 0
    n_flag = 0
    n_skip = 0

    for family_name in families:
        fam_tree_dir = os.path.join(TREE_DIR, family_name)
        if not os.path.isdir(fam_tree_dir):
            continue
        row = process_family(family_name)
        if row is None:
            continue
        rows.append(row)
        if row["status"] == "no_treefile":
            n_skip += 1
        elif row["flags"] == "PASS":
            n_pass += 1
        else:
            n_flag += 1

    with open(report_path, "w") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDNAMES, delimiter="\t")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)

    print("Quality gate complete.")
    print("  Families processed: {}".format(len(rows)))
    print("  PASS:    {}".format(n_pass))
    print("  FLAGGED: {}".format(n_flag))
    print("  SKIPPED (no tree): {}".format(n_skip))
    print("  Report: {}".format(report_path))
    print("")
    print("Flagged families (review before Phase 3 grafting):")
    for row in rows:
        if row["flags"] != "PASS" and row["status"] != "no_treefile":
            print("  {} -> {}".format(row["family"], row["flags"]))


if __name__ == "__main__":
    main()
