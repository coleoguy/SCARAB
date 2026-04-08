#!/usr/bin/env python3
"""
Step 2: Select best RNA-seq runs per species and construct ENA download URLs.

Three categories:
  - both_sex: species with male + female RNA-seq (matched tissue, up to 3+3)
  - male_only / female_only: species with one sex (autosomal baseline, up to 3)

Usage:
    python3 scripts/phase3/select_rnaseq_runs.py

Input:  results/sra_rnaseq_runs_detailed.csv   (both-sex species)
        results/sra_rnaseq_runs_singlesex.csv   (single-sex species)
Output: results/selected_rnaseq_runs.csv
        results/rnaseq_selection_summary.txt
        results/rnaseq_download_manifest.txt
"""

import csv
import os
import re
from collections import defaultdict

DETAILED_CSV = "results/sra_rnaseq_runs_detailed.csv"
SINGLESEX_CSV = "results/sra_rnaseq_runs_singlesex.csv"
OUT_SELECTED = "results/selected_rnaseq_runs.csv"
OUT_SUMMARY = "results/rnaseq_selection_summary.txt"
OUT_MANIFEST = "results/rnaseq_download_manifest.txt"

MIN_SPOTS = 5_000_000
MIN_SPOTS_RECOVERY = 2_000_000  # relaxed threshold for both-sex recovery
MAX_PER_SEX = 3
MIN_SINGLE_SEX_RUNS = 2  # require >=2 runs for single-sex species


def normalize_tissue(raw):
    t = raw.lower().strip().rstrip(".")
    if not t or t in ("not applicable", "not collected", "not determined",
                       "n/a", "unknown"):
        return "unspecified"

    # Luciola-style encoded tissue: "69-SwLa-LuIta-3-m-H_head" -> head
    # Pattern: digits-lab-species-digits-sex-tissue
    m = re.search(r'[_-]([hH]_?head|[bB]_?abdomen|[tT]_?thorax|[lL]_?leg)', t)
    if m:
        part = m.group(1).lower()
        if "head" in part:
            return "head"
        if "abdomen" in part:
            return "abdomen"
        if "thorax" in part:
            return "thorax"
        if "leg" in part:
            return "leg"

    # Whole body variants
    whole_terms = {
        "whole body", "whole organism", "whole insect", "whole beetle",
        "complete insect", "entire body", "full body", "body", "whole bodies",
        "whole individual", "whole adults", "whole adult", "adult",
        "adults", "whole worm", "the whole worm", "whole",
        "missing", "adult body",
    }
    if t in whole_terms or "whole body" in t or "whole organism" in t or "whole insect" in t:
        return "whole_body"

    # Typos
    if t in ("whole bady",):
        return "whole_body"

    if t in ("antenna", "antennae", "male antenna", "female antenna",
             "male antennae", "female antennae") or "antenna" in t:
        return "antenna"
    if t in ("head",) or t.startswith("head"):
        return "head"
    if t in ("abdomen",) or t.startswith("abdomen"):
        return "abdomen"
    if t in ("thorax",):
        return "thorax"
    if "gut" in t or "midgut" in t or "hindgut" in t:
        return "gut"
    if "fat body" in t or "fatbody" in t or "fat-body" in t:
        return "fat_body"
    if t in ("ovary", "ovaries", "testes", "testis", "gonad", "gonads",
             "reproductive") or "ovar" in t or "testi" in t:
        return "gonad"
    if "reproductive" in t or "residual" in t:
        return "gonad"
    if t in ("leg", "legs", "foreleg", "forelegs", "hindleg") or "leg" in t:
        return "leg"
    if "hemocyte" in t:
        return "hemocyte"
    if "larva" in t or "pupae" in t or "pupal" in t or "prepupal" in t:
        return "immature"

    return t


def ena_url(srr, read_num=None):
    prefix = srr[:6]
    if len(srr) == 9:
        suffix_dir = ""
    elif len(srr) == 10:
        suffix_dir = "/00" + srr[-1]
    elif len(srr) == 11:
        suffix_dir = "/0" + srr[-2:]
    elif len(srr) == 12:
        suffix_dir = "/" + srr[-3:]
    else:
        suffix_dir = ""

    base = "https://ftp.sra.ebi.ac.uk/vol1/fastq"
    if read_num is not None:
        filename = "{}_{}.fastq.gz".format(srr, read_num)
    else:
        filename = "{}.fastq.gz".format(srr)

    return "{}/{}{}/{}/{}".format(base, prefix, suffix_dir, srr, filename)


def estimate_gb(spots, layout):
    read_len = 150
    compress_ratio = 0.28
    n_files = 2 if layout == "PAIRED" else 1
    return (spots * read_len * compress_ratio * n_files) / 1e9


def sort_key(r):
    return (0 if r["layout"] == "PAIRED" else 1, -int(r["spots"]))


def select_bothsex(runs):
    """Select best runs for a both-sex species."""
    # Try standard threshold first, then recovery threshold
    for min_spots in [MIN_SPOTS, MIN_SPOTS_RECOVERY]:
        eligible = [r for r in runs
                    if r["platform"] == "ILLUMINA"
                    and r["sex"] in ("male", "female")
                    and int(r["spots"]) >= min_spots]
        if not eligible:
            continue

        for r in eligible:
            r["tissue_norm"] = normalize_tissue(r["tissue"])

        by_tissue = defaultdict(list)
        for r in eligible:
            by_tissue[r["tissue_norm"]].append(r)

        # Try tissue tiers
        for tier_name, tier_test in [
            ("tier 1: whole_body", lambda m, f: "whole_body" in by_tissue and
                len([r for r in by_tissue["whole_body"] if r["sex"] == "male"]) >= 1 and
                len([r for r in by_tissue["whole_body"] if r["sex"] == "female"]) >= 1),
        ]:
            pass  # handled below explicitly

        best_tissue = None
        best_note = ""

        # Tier 1: whole_body
        if "whole_body" in by_tissue:
            t = by_tissue["whole_body"]
            if ([r for r in t if r["sex"] == "male"] and
                [r for r in t if r["sex"] == "female"]):
                best_tissue = "whole_body"
                best_note = "whole_body (tier 1)"

        # Tier 2: any tissue with >=2 per sex
        if best_tissue is None:
            for tissue in sorted(by_tissue.keys()):
                if tissue in ("unspecified", "immature"):
                    continue
                t = by_tissue[tissue]
                males = [r for r in t if r["sex"] == "male"]
                females = [r for r in t if r["sex"] == "female"]
                if len(males) >= 2 and len(females) >= 2:
                    best_tissue = tissue
                    best_note = "{} (tier 2: >=2 per sex)".format(tissue)
                    break

        # Tier 3: any tissue with >=1 per sex
        if best_tissue is None:
            for tissue in sorted(by_tissue.keys()):
                if tissue in ("unspecified", "immature"):
                    continue
                t = by_tissue[tissue]
                males = [r for r in t if r["sex"] == "male"]
                females = [r for r in t if r["sex"] == "female"]
                if len(males) >= 1 and len(females) >= 1:
                    best_tissue = tissue
                    best_note = "{} (tier 3: >=1 per sex)".format(tissue)
                    break

        # Tier 4: unspecified
        if best_tissue is None and "unspecified" in by_tissue:
            t = by_tissue["unspecified"]
            males = [r for r in t if r["sex"] == "male"]
            females = [r for r in t if r["sex"] == "female"]
            if males and females:
                best_tissue = "unspecified"
                best_note = "unspecified (tier 4)"

        if best_tissue is not None:
            t = by_tissue[best_tissue]
            males = sorted([r for r in t if r["sex"] == "male"], key=sort_key)
            females = sorted([r for r in t if r["sex"] == "female"], key=sort_key)
            selected = males[:MAX_PER_SEX] + females[:MAX_PER_SEX]
            if min_spots < MIN_SPOTS:
                best_note += " [recovered at {}M threshold]".format(min_spots // 1_000_000)
            note = "{}: {}M + {}F".format(best_note,
                                           min(len(males), MAX_PER_SEX),
                                           min(len(females), MAX_PER_SEX))
            return selected, note, "both_sex"

    tissues_found = set()
    for r in runs:
        if r["platform"] == "ILLUMINA" and r["sex"] in ("male", "female"):
            tissues_found.add(normalize_tissue(r["tissue"]))
    return [], "dropped: no matched tissue (tissues: {})".format(
        ", ".join(sorted(tissues_found))), "both_sex"


def select_singlesex(runs):
    """Select runs for a single-sex species."""
    eligible = [r for r in runs
                if r["platform"] == "ILLUMINA"
                and r["sex"] in ("male", "female")
                and int(r["spots"]) >= MIN_SPOTS]

    if not eligible:
        return [], "dropped: no Illumina runs with known sex and >=5M spots", ""

    # Determine which sex
    males = [r for r in eligible if r["sex"] == "male"]
    females = [r for r in eligible if r["sex"] == "female"]

    if males and not females:
        sex_label = "male_only"
        pool = males
    elif females and not males:
        sex_label = "female_only"
        pool = females
    else:
        # Shouldn't happen for single-sex species, but handle it
        sex_label = "both_sex"
        pool = eligible

    if len(pool) < MIN_SINGLE_SEX_RUNS:
        return [], "dropped: only {} {} run(s), need >={}".format(
            len(pool), sex_label, MIN_SINGLE_SEX_RUNS), sex_label

    # Normalize tissues
    for r in pool:
        r["tissue_norm"] = normalize_tissue(r["tissue"])

    # Prefer whole_body, then any adult tissue
    by_tissue = defaultdict(list)
    for r in pool:
        by_tissue[r["tissue_norm"]].append(r)

    best_tissue = None
    if "whole_body" in by_tissue and len(by_tissue["whole_body"]) >= MIN_SINGLE_SEX_RUNS:
        best_tissue = "whole_body"
    else:
        # Pick tissue with most runs (excluding immature)
        for tissue in sorted(by_tissue.keys(), key=lambda t: -len(by_tissue[t])):
            if tissue in ("immature",):
                continue
            if len(by_tissue[tissue]) >= MIN_SINGLE_SEX_RUNS:
                best_tissue = tissue
                break

    if best_tissue is None:
        # Pool all adult tissues
        adult_pool = [r for r in pool if r["tissue_norm"] != "immature"]
        if len(adult_pool) >= MIN_SINGLE_SEX_RUNS:
            adult_pool.sort(key=sort_key)
            selected = adult_pool[:MAX_PER_SEX]
            note = "{}: {} runs (mixed tissue)".format(sex_label, len(selected))
            return selected, note, sex_label
        return [], "dropped: <{} adult runs".format(MIN_SINGLE_SEX_RUNS), sex_label

    t_runs = sorted(by_tissue[best_tissue], key=sort_key)
    selected = t_runs[:MAX_PER_SEX]
    note = "{}: {} runs ({})".format(sex_label, len(selected), best_tissue)
    return selected, note, sex_label


def main():
    # Load both-sex detailed runs
    all_runs = defaultdict(list)
    with open(DETAILED_CSV) as f:
        for row in csv.DictReader(f):
            all_runs[row["species_name"]].append(row)
    print("Both-sex: {} runs across {} species".format(
        sum(len(v) for v in all_runs.values()), len(all_runs)))

    # Load single-sex runs
    singlesex_runs = defaultdict(list)
    if os.path.exists(SINGLESEX_CSV):
        with open(SINGLESEX_CSV) as f:
            for row in csv.DictReader(f):
                singlesex_runs[row["species_name"]].append(row)
        print("Single-sex: {} runs across {} species".format(
            sum(len(v) for v in singlesex_runs.values()), len(singlesex_runs)))

    os.makedirs("results", exist_ok=True)

    selected_rows = []
    summary_lines = []
    manifest_urls = []
    counts = {"both_sex": 0, "male_only": 0, "female_only": 0, "dropped": 0}

    # Process both-sex species
    for species in sorted(all_runs.keys()):
        runs = all_runs[species]
        selected, note, cat = select_bothsex(runs)

        if not selected:
            summary_lines.append("  DROPPED  {:<40s} {}".format(species, note))
            counts["dropped"] += 1
            continue

        counts["both_sex"] += 1
        total_gb = _add_selected(selected, selected_rows, manifest_urls)
        summary_lines.append("  BOTH     {:<40s} {} — est {:.1f} GB".format(
            species, note, total_gb))

    # Process single-sex species
    for species in sorted(singlesex_runs.keys()):
        if species in all_runs:
            continue  # already handled
        runs = singlesex_runs[species]
        selected, note, cat = select_singlesex(runs)

        if not selected:
            summary_lines.append("  DROPPED  {:<40s} {}".format(species, note))
            counts["dropped"] += 1
            continue

        counts[cat] += 1
        total_gb = _add_selected(selected, selected_rows, manifest_urls)
        summary_lines.append("  {:7s}  {:<40s} {} — est {:.1f} GB".format(
            cat.upper(), species, note, total_gb))

    # Write outputs
    sel_fields = ["species_name", "tip_label", "family", "clade",
                  "srr_accession", "sex", "tissue", "tissue_norm",
                  "spots", "layout", "ena_url_r1", "ena_url_r2",
                  "species_dir", "est_gb", "category"]
    with open(OUT_SELECTED, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sel_fields)
        w.writeheader()
        for row in selected_rows:
            w.writerow(row)

    with open(OUT_MANIFEST, "w") as f:
        for url in manifest_urls:
            f.write(url + "\n")

    total_est_gb = sum(float(r["est_gb"]) for r in selected_rows)
    n_species = len(set(r["species_name"] for r in selected_rows))

    header = [
        "RNA-seq Run Selection Summary",
        "=" * 50,
        "Both-sex species selected: {}".format(counts["both_sex"]),
        "Male-only species selected: {}".format(counts["male_only"]),
        "Female-only species selected: {}".format(counts["female_only"]),
        "Total species selected: {}".format(n_species),
        "Species dropped: {}".format(counts["dropped"]),
        "",
        "Total runs selected: {}".format(len(selected_rows)),
        "Total FASTQ files: {}".format(len(manifest_urls)),
        "Estimated download size: {:.0f} GB".format(total_est_gb),
        "",
        "Per-species details:",
    ]

    summary_text = "\n".join(header + sorted(summary_lines))
    with open(OUT_SUMMARY, "w") as f:
        f.write(summary_text + "\n")

    print(summary_text)
    print("\nOutputs:")
    print("  {}  ({} runs, {} species)".format(OUT_SELECTED, len(selected_rows), n_species))
    print("  {}  ({} URLs)".format(OUT_MANIFEST, len(manifest_urls)))


def _add_selected(selected, selected_rows, manifest_urls):
    """Add selected runs to output lists. Returns total estimated GB."""
    total_gb = 0
    for r in selected:
        layout = r["layout"]
        gb = estimate_gb(int(r["spots"]), layout)
        total_gb += gb

        if layout == "PAIRED":
            url_r1 = ena_url(r["srr_accession"], 1)
            url_r2 = ena_url(r["srr_accession"], 2)
            manifest_urls.append(url_r1)
            manifest_urls.append(url_r2)
        else:
            url_r1 = ena_url(r["srr_accession"])
            url_r2 = ""
            manifest_urls.append(url_r1)

        species_dir = r["tip_label"] if r["tip_label"] else r["species_name"].replace(" ", "_")

        # Determine category
        males_in_sel = any(s["sex"] == "male" for s in selected)
        females_in_sel = any(s["sex"] == "female" for s in selected)
        if males_in_sel and females_in_sel:
            cat = "both_sex"
        elif males_in_sel:
            cat = "male_only"
        else:
            cat = "female_only"

        selected_rows.append({
            "species_name": r["species_name"],
            "tip_label": r["tip_label"],
            "family": r["family"],
            "clade": r["clade"],
            "srr_accession": r["srr_accession"],
            "sex": r["sex"],
            "tissue": r["tissue"],
            "tissue_norm": r.get("tissue_norm", normalize_tissue(r["tissue"])),
            "spots": r["spots"],
            "layout": layout,
            "ena_url_r1": url_r1,
            "ena_url_r2": url_r2,
            "species_dir": species_dir,
            "est_gb": round(gb, 1),
            "category": cat,
        })
    return total_gb


if __name__ == "__main__":
    main()
