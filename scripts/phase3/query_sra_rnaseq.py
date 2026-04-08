#!/usr/bin/env python3
"""
Query NCBI SRA for male/female RNA-seq runs across all SCARAB species.

Uses Entrez E-utilities (no API key = 3 requests/sec).
Set NCBI_API_KEY env var for 10 requests/sec.

Usage:
    python3 scripts/phase3/query_sra_rnaseq.py [--api-key YOUR_KEY]

Output: results/sra_rnaseq_survey.csv
"""

import csv
import os
import sys
import time
import re
import argparse
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
from collections import defaultdict

# --- Config ---
TIP_MAP = "data/genomes/tree_tip_mapping.csv"
OUT_CSV = "results/sra_rnaseq_survey.csv"
OUT_SUMMARY = "results/sra_rnaseq_summary.txt"
ESEARCH = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
EFETCH = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default=os.environ.get("NCBI_API_KEY", ""))
    p.add_argument("--resume", action="store_true",
                   help="Skip species already in output CSV")
    return p.parse_args()


def eutil_get(url, params, api_key, max_retries=3):
    """GET request to NCBI E-utility with retry logic."""
    if api_key:
        params["api_key"] = api_key
    query = urllib.parse.urlencode(params)
    full_url = "{}?{}".format(url, query)

    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(full_url)
            req.add_header("User-Agent", "SCARAB-SRA-survey/1.0")
            resp = urllib.request.urlopen(req, timeout=30)
            return resp.read().decode("utf-8")
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(2 * (attempt + 1))
            else:
                raise


def search_sra(species, api_key):
    """Search SRA for RNA-seq runs for a species. Returns list of SRA UIDs."""
    # Query: species name + RNA-Seq + Illumina (most useful for expression)
    query = '"{}"[Organism] AND "RNA-Seq"[Strategy]'.format(species)
    params = {
        "db": "sra",
        "term": query,
        "retmax": "500",
        "usehistory": "n",
    }
    xml_text = eutil_get(ESEARCH, params, api_key)
    root = ET.fromstring(xml_text)

    count_el = root.find("Count")
    count = int(count_el.text) if count_el is not None else 0

    uids = []
    id_list = root.find("IdList")
    if id_list is not None:
        for uid_el in id_list.findall("Id"):
            uids.append(uid_el.text)

    return count, uids


def fetch_run_info(uids, api_key):
    """Fetch SRA experiment XML for given UIDs. Returns parsed run records."""
    if not uids:
        return []

    # Fetch in batches of 50
    records = []
    for i in range(0, len(uids), 50):
        batch = uids[i:i+50]
        params = {
            "db": "sra",
            "id": ",".join(batch),
            "rettype": "xml",
            "retmode": "xml",
        }
        xml_text = eutil_get(EFETCH, params, api_key)

        # Parse experiment packages
        # Wrap in root if needed
        if not xml_text.strip().startswith("<?xml"):
            xml_text = '<?xml version="1.0"?><ROOT>' + xml_text + '</ROOT>'
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError:
            # Try wrapping
            xml_text = "<ROOT>" + xml_text + "</ROOT>"
            root = ET.fromstring(xml_text)

        for pkg in root.iter("EXPERIMENT_PACKAGE"):
            rec = parse_experiment_package(pkg)
            if rec:
                records.append(rec)

        if i + 50 < len(uids):
            time.sleep(0.35)

    return records


def parse_experiment_package(pkg):
    """Extract key fields from an SRA EXPERIMENT_PACKAGE XML element."""
    rec = {
        "accession": "",
        "title": "",
        "organism": "",
        "sex": "",
        "tissue": "",
        "dev_stage": "",
        "sample_attrs": "",
        "spots": 0,
        "bases": 0,
        "platform": "",
        "layout": "",
    }

    # Experiment accession
    exp = pkg.find(".//EXPERIMENT")
    if exp is not None:
        rec["accession"] = exp.get("accession", "")
        title_el = exp.find(".//TITLE")
        if title_el is not None and title_el.text:
            rec["title"] = title_el.text.strip()

    # Platform
    platform = pkg.find(".//PLATFORM")
    if platform is not None and len(platform) > 0:
        rec["platform"] = platform[0].tag  # e.g., ILLUMINA

    # Layout
    layout = pkg.find(".//LIBRARY_LAYOUT")
    if layout is not None and len(layout) > 0:
        rec["layout"] = layout[0].tag  # SINGLE or PAIRED

    # Sample attributes - this is where sex/tissue info lives
    sample = pkg.find(".//SAMPLE")
    if sample is not None:
        org = sample.find(".//SCIENTIFIC_NAME")
        if org is not None and org.text:
            rec["organism"] = org.text.strip()

        attrs = {}
        for sa in sample.findall(".//SAMPLE_ATTRIBUTE"):
            tag_el = sa.find("TAG")
            val_el = sa.find("VALUE")
            if tag_el is not None and val_el is not None:
                tag = tag_el.text.strip().lower() if tag_el.text else ""
                val = val_el.text.strip() if val_el.text else ""
                attrs[tag] = val

        rec["sample_attrs"] = "; ".join(
            "{}={}".format(k, v) for k, v in sorted(attrs.items())
        )

        # Extract sex
        for key in ["sex", "gender", "Sex", "Gender"]:
            if key.lower() in attrs:
                rec["sex"] = attrs[key.lower()]
                break

        # Check title/attributes for sex keywords if not found
        if not rec["sex"]:
            all_text = " ".join(attrs.values()) + " " + rec["title"]
            all_lower = all_text.lower()
            if re.search(r'\bmale\b', all_lower) and not re.search(r'\bfemale\b', all_lower):
                rec["sex"] = "male (inferred)"
            elif re.search(r'\bfemale\b', all_lower):
                rec["sex"] = "female (inferred)"

        # Extract tissue
        for key in ["tissue", "tissue_type", "organ", "body part",
                     "cell_type", "isolation source", "sample type"]:
            if key in attrs:
                rec["tissue"] = attrs[key]
                break

        # Dev stage
        for key in ["dev_stage", "developmental stage", "development stage",
                     "life stage", "age"]:
            if key in attrs:
                rec["dev_stage"] = attrs[key]
                break

    # Run stats
    run = pkg.find(".//RUN")
    if run is not None:
        spots = run.get("total_spots", "0")
        bases = run.get("total_bases", "0")
        rec["spots"] = int(spots) if spots else 0
        rec["bases"] = int(bases) if bases else 0

    return rec


def classify_sex(sex_str):
    """Normalize sex string to male/female/unknown."""
    s = sex_str.lower().strip()
    if not s or s in ("not applicable", "not collected", "not determined",
                      "missing", "n/a", "unknown", "pooled", "mixed"):
        return "unknown"
    if "female" in s:
        return "female"
    if "male" in s:
        return "male"
    return "unknown"


def main():
    args = parse_args()
    api_key = args.api_key
    delay = 0.11 if api_key else 0.35  # 10/sec vs 3/sec

    # Read species list
    species_list = []
    with open(TIP_MAP) as f:
        reader = csv.DictReader(f)
        for row in reader:
            species_list.append({
                "tip_label": row["tip_label"],
                "species_name": row["species_name"],
                "family": row["family"],
                "clade": row["clade"],
            })

    print("Surveying {} species for RNA-seq in SRA...".format(len(species_list)))
    print("Rate: {} req/sec".format("10" if api_key else "3 (set NCBI_API_KEY for 10)"))

    # Resume support
    done_species = set()
    all_rows = []
    if args.resume and os.path.exists(OUT_CSV):
        with open(OUT_CSV) as f:
            reader = csv.DictReader(f)
            for row in reader:
                done_species.add(row["species_name"])
                all_rows.append(row)
        print("Resuming: {} species already done".format(len(done_species)))

    os.makedirs("results", exist_ok=True)

    fieldnames = [
        "species_name", "tip_label", "family", "clade",
        "total_rnaseq_runs", "male_runs", "female_runs", "unknown_sex_runs",
        "has_male", "has_female", "has_both_sexes",
        "tissues", "platforms", "example_accessions",
    ]

    for i, sp in enumerate(species_list):
        name = sp["species_name"]
        if name in done_species:
            continue

        # Search SRA
        try:
            count, uids = search_sra(name, api_key)
        except Exception as e:
            print("  ERROR searching {}: {}".format(name, e))
            row = {
                "species_name": name,
                "tip_label": sp["tip_label"],
                "family": sp["family"],
                "clade": sp["clade"],
                "total_rnaseq_runs": "ERROR",
                "male_runs": 0, "female_runs": 0, "unknown_sex_runs": 0,
                "has_male": False, "has_female": False, "has_both_sexes": False,
                "tissues": "", "platforms": "", "example_accessions": "",
            }
            all_rows.append(row)
            time.sleep(delay)
            continue

        time.sleep(delay)

        if count == 0:
            row = {
                "species_name": name,
                "tip_label": sp["tip_label"],
                "family": sp["family"],
                "clade": sp["clade"],
                "total_rnaseq_runs": 0,
                "male_runs": 0, "female_runs": 0, "unknown_sex_runs": 0,
                "has_male": False, "has_female": False, "has_both_sexes": False,
                "tissues": "", "platforms": "", "example_accessions": "",
            }
            all_rows.append(row)
            if (i + 1) % 25 == 0:
                print("  {}/{} species queried...".format(i + 1, len(species_list)))
            continue

        # Fetch detailed info
        try:
            records = fetch_run_info(uids[:200], api_key)  # cap at 200 runs
        except Exception as e:
            print("  ERROR fetching {}: {}".format(name, e))
            records = []

        time.sleep(delay)

        # Tally
        male_n = 0
        female_n = 0
        unknown_n = 0
        tissues = set()
        platforms = set()
        accessions = []

        for rec in records:
            sex_class = classify_sex(rec["sex"])
            if sex_class == "male":
                male_n += 1
            elif sex_class == "female":
                female_n += 1
            else:
                unknown_n += 1

            if rec["tissue"]:
                tissues.add(rec["tissue"].lower())
            if rec["platform"]:
                platforms.add(rec["platform"])
            if rec["accession"] and len(accessions) < 5:
                accessions.append(rec["accession"])

        row = {
            "species_name": name,
            "tip_label": sp["tip_label"],
            "family": sp["family"],
            "clade": sp["clade"],
            "total_rnaseq_runs": count,
            "male_runs": male_n,
            "female_runs": female_n,
            "unknown_sex_runs": unknown_n,
            "has_male": male_n > 0,
            "has_female": female_n > 0,
            "has_both_sexes": male_n > 0 and female_n > 0,
            "tissues": "; ".join(sorted(tissues)[:10]),
            "platforms": "; ".join(sorted(platforms)),
            "example_accessions": "; ".join(accessions),
        }
        all_rows.append(row)

        if male_n > 0 or female_n > 0:
            print("  {} — {} runs (M={}, F={}) {}".format(
                name, count, male_n, female_n,
                "*** BOTH ***" if (male_n > 0 and female_n > 0) else ""))

        if (i + 1) % 25 == 0:
            print("  {}/{} species queried...".format(i + 1, len(species_list)))

        # Checkpoint every 50 species
        if (i + 1) % 50 == 0:
            write_csv(OUT_CSV, fieldnames, all_rows)

    # Final write
    write_csv(OUT_CSV, fieldnames, all_rows)

    # Summary
    write_summary(all_rows)


def write_csv(path, fieldnames, rows):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in rows:
            w.writerow(row)


def write_summary(rows):
    total = len(rows)
    has_rnaseq = sum(1 for r in rows if int(r.get("total_rnaseq_runs", 0) or 0) > 0)
    has_male = sum(1 for r in rows if str(r.get("has_male", "")) == "True")
    has_female = sum(1 for r in rows if str(r.get("has_female", "")) == "True")
    has_both = sum(1 for r in rows if str(r.get("has_both_sexes", "")) == "True")

    lines = [
        "SCARAB SRA RNA-seq Survey Summary",
        "==================================",
        "Total species queried: {}".format(total),
        "Species with any RNA-seq: {} ({:.0%})".format(has_rnaseq, has_rnaseq/total if total else 0),
        "Species with male RNA-seq: {} ({:.0%})".format(has_male, has_male/total if total else 0),
        "Species with female RNA-seq: {} ({:.0%})".format(has_female, has_female/total if total else 0),
        "Species with BOTH sexes: {} ({:.0%})".format(has_both, has_both/total if total else 0),
        "",
        "By clade:",
    ]

    # Group by clade
    clades = defaultdict(lambda: {"total": 0, "rnaseq": 0, "male": 0, "female": 0, "both": 0})
    for r in rows:
        cl = r.get("clade", "unknown")
        clades[cl]["total"] += 1
        if int(r.get("total_rnaseq_runs", 0) or 0) > 0:
            clades[cl]["rnaseq"] += 1
        if str(r.get("has_male", "")) == "True":
            clades[cl]["male"] += 1
        if str(r.get("has_female", "")) == "True":
            clades[cl]["female"] += 1
        if str(r.get("has_both_sexes", "")) == "True":
            clades[cl]["both"] += 1

    for cl in sorted(clades.keys()):
        c = clades[cl]
        lines.append("  {}: {}/{} RNA-seq, {}/{} both sexes".format(
            cl, c["rnaseq"], c["total"], c["both"], c["total"]))

    summary = "\n".join(lines)
    print("\n" + summary)

    with open(OUT_SUMMARY, "w") as f:
        f.write(summary + "\n")

    # List species with both sexes
    both_list = [r for r in rows if str(r.get("has_both_sexes", "")) == "True"]
    if both_list:
        print("\nSpecies with both male and female RNA-seq:")
        for r in sorted(both_list, key=lambda x: x["species_name"]):
            print("  {} ({}) — M={} F={} runs".format(
                r["species_name"], r["family"],
                r["male_runs"], r["female_runs"]))


if __name__ == "__main__":
    main()
