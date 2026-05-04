#!/usr/bin/env python
"""
01_calibs_to_treepl_config.py
=============================
Read cai2022_calibrations.csv and mrca_mapping.csv; produce a treePL config
file for cross-validation AND a separate one for the final dated run.

Usage (Grace login node, Python 3.6):
    python 01_calibs_to_treepl_config.py

Inputs (edit PATHS below if needed):
    CALIB_CSV     -- cai2022_calibrations.csv (from repo)
    MRCA_CSV      -- mrca_mapping.csv (Heath must supply; columns: node_num,tip1,tip2)
    TREE_FILE     -- rooted backbone tree from Phase 1 IQ-TREE (Newick)

Outputs:
    CV_CONFIG     -- treePL config for cross-validation (cv mode)
    DATED_CONFIG  -- treePL config template for final run (smoothing = PLACEHOLDER)

treePL config format reference:
    treefile = /path/to/tree.nwk
    smooth = 100
    mrca = CROWN_COLEOPTERA tip1 tip2
    min = CROWN_COLEOPTERA 251.878
    max = CROWN_COLEOPTERA 307.1
    outfile = /path/to/output.tre
    cv
    cvstart = 0.0001
    cvstop = 10000
    cvmultstep = 10
    moredetail
    thorough
    numthreads = 1

Notes:
- Calibrations with applies_at_TOB_scope_yes_no == 'N' are skipped.
- Node labels in treePL must be valid identifiers (no spaces, no parentheses).
  We sanitize by replacing spaces and special chars with underscores.
- treePL requires min <= age <= max; we use age_min_Ma as min and age_max_Ma as max.
- Root calibration (node 2, crown Coleoptera) gets both min and max.
  Interior nodes get min only unless you have a soft max fossil — we use
  the CSV max when present.
- The CV config includes the 'cv' keyword and cv* parameters.
  The dated config replaces 'cv' block with 'smooth = SMOOTHING_PLACEHOLDER'.
"""

from __future__ import print_function
import csv
import os
import re
import sys

# ============================================================================
# PATHS — edit if your layout differs
# ============================================================================

SCRATCH = os.environ.get("SCRATCH", "/scratch/user/blackmon")
TOB = os.path.join(SCRATCH, "tob")
DATING = os.path.join(TOB, "dating")

CALIB_CSV = os.path.join(DATING, "cai2022_calibrations.csv")
MRCA_CSV = os.path.join(DATING, "mrca_mapping.csv")
TREE_FILE = os.path.join(TOB, "phylogenomics", "concat", "tob_concat.treefile")

CV_CONFIG = os.path.join(DATING, "treepl_cv.config")
DATED_CONFIG = os.path.join(DATING, "treepl_dated.config")
OUTFILE_CV = os.path.join(DATING, "cv", "tob_cv_dated.tre")
OUTFILE_DATED = os.path.join(DATING, "tob_dated.tre")

# Cross-validation smoothing grid: log-spaced from 0.0001 to 10000, step *10
CV_START = 0.0001
CV_STOP = 10000
CV_MULT_STEP = 10

# ============================================================================
# HELPERS
# ============================================================================

def sanitize_label(text):
    """Make a treePL-safe node name: alphanum + underscores only."""
    label = re.sub(r"[^A-Za-z0-9]+", "_", text.strip())
    label = label.strip("_")
    return label


def read_calibrations(calib_csv):
    """Return list of dicts for calibrations with applies_at_TOB_scope == 'Y'."""
    calibs = []
    with open(calib_csv, "r") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            scope = row.get("applies_at_TOB_scope_yes_no", "").strip().upper()
            if scope != "Y":
                continue
            calibs.append({
                "node_num": row["node_num"].strip(),
                "node_label": row["node_label"].strip(),
                "age_min_Ma": row["age_min_Ma"].strip(),
                "age_max_Ma": row["age_max_Ma"].strip(),
                "burmese_amber": row.get("burmese_amber_flag", "N").strip().upper(),
            })
    return calibs


def read_mrca_mapping(mrca_csv):
    """Return dict: node_num (str) -> (tip1, tip2)."""
    mapping = {}
    with open(mrca_csv, "r") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            num = row["node_num"].strip()
            mapping[num] = (row["tip1"].strip(), row["tip2"].strip())
    return mapping


def build_config_lines(calibs, mrca_map, tree_file, outfile, smoothing_block):
    """
    Return a list of text lines for one treePL config.

    smoothing_block: list of strings inserted after 'treefile' + 'outfile' lines.
    Examples:
      CV block:    ['cv', 'cvstart = 0.0001', 'cvstop = 10000', 'cvmultstep = 10']
      Dated block: ['smooth = SMOOTHING_PLACEHOLDER']
    """
    lines = []
    lines.append("treefile = {0}".format(tree_file))
    lines.append("outfile = {0}".format(outfile))
    lines.append("")
    lines.extend(smoothing_block)
    lines.append("")
    lines.append("moredetail")
    lines.append("thorough")
    lines.append("numthreads = 1")
    lines.append("")
    lines.append("# --------------------------------------------------------")
    lines.append("# Calibration nodes (Cai et al. 2022)")
    lines.append("# Burmese amber nodes are flagged; include in default run.")
    lines.append("# --------------------------------------------------------")
    lines.append("")

    missing_mrca = []
    written = 0

    for calib in calibs:
        num = calib["node_num"]
        label_raw = calib["node_label"]
        label = sanitize_label(label_raw)
        # Prefix with node number to guarantee uniqueness
        label = "node{0}_{1}".format(num, label)

        if num not in mrca_map:
            missing_mrca.append(num)
            lines.append("# MRCA MISSING for node {0}: {1}".format(num, label_raw))
            continue

        tip1, tip2 = mrca_map[num]
        amber_flag = " # BURMESE_AMBER" if calib["burmese_amber"] == "Y" else ""

        lines.append("mrca = {0} {1} {2}{3}".format(label, tip1, tip2, amber_flag))
        lines.append("min = {0} {1}".format(label, calib["age_min_Ma"]))
        lines.append("max = {0} {1}".format(label, calib["age_max_Ma"]))
        lines.append("")
        written += 1

    return lines, missing_mrca, written


def write_config(path, lines):
    out_dir = os.path.dirname(path)
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")


# ============================================================================
# MAIN
# ============================================================================

def main():
    # Validate inputs
    for path, label in [(CALIB_CSV, "CALIB_CSV"), (MRCA_CSV, "MRCA_CSV"), (TREE_FILE, "TREE_FILE")]:
        if not os.path.isfile(path):
            print("ERROR: {0} not found: {1}".format(label, path))
            sys.exit(1)

    calibs = read_calibrations(CALIB_CSV)
    print("Calibrations with TOB scope: {0}".format(len(calibs)))

    mrca_map = read_mrca_mapping(MRCA_CSV)
    print("MRCA mappings loaded: {0}".format(len(mrca_map)))

    # Create output dirs
    for d in [DATING, os.path.join(DATING, "cv")]:
        if not os.path.isdir(d):
            os.makedirs(d)

    # ---- CV config ----
    cv_block = [
        "cv",
        "cvstart = {0}".format(CV_START),
        "cvstop = {0}".format(CV_STOP),
        "cvmultstep = {0}".format(CV_MULT_STEP),
    ]
    cv_lines, missing_cv, written_cv = build_config_lines(
        calibs, mrca_map, TREE_FILE, OUTFILE_CV, cv_block
    )
    write_config(CV_CONFIG, cv_lines)
    print("Written CV config: {0}  ({1} calibrations written)".format(CV_CONFIG, written_cv))

    # ---- Dated config ----
    dated_block = [
        "# Replace SMOOTHING_PLACEHOLDER with value chosen from CV results",
        "smooth = SMOOTHING_PLACEHOLDER",
    ]
    dated_lines, missing_dated, written_dated = build_config_lines(
        calibs, mrca_map, TREE_FILE, OUTFILE_DATED, dated_block
    )
    write_config(DATED_CONFIG, dated_lines)
    print("Written dated config: {0}".format(DATED_CONFIG))

    if missing_cv:
        print("")
        print("WARNING: {0} calibration nodes have no MRCA mapping and were skipped:".format(len(missing_cv)))
        for n in missing_cv:
            print("  node_num = {0}".format(n))
        print("Add these to {0} before running treePL.".format(MRCA_CSV))

    print("")
    print("Next steps:")
    print("  1. If missing MRCA entries above, fill in {0} and re-run.".format(MRCA_CSV))
    print("  2. sbatch 02_treepl_cv.slurm")
    print("  3. Inspect {0}/cv/cv_results.txt, pick optimal smoothing.".format(DATING))
    print("  4. Edit smooth = line in {0}".format(DATED_CONFIG))
    print("  5. sbatch 03_treepl_dating.slurm")


if __name__ == "__main__":
    main()
