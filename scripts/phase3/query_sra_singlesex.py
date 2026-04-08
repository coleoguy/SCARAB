#!/usr/bin/env python3
"""
Query NCBI SRA for per-run metadata for male-only and female-only species.

Usage:
    python3 scripts/phase3/query_sra_singlesex.py [--api-key KEY] [--resume]

Output: results/sra_rnaseq_runs_singlesex.csv
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

SURVEY_CSV = "results/sra_rnaseq_survey.csv"
TIP_MAP = "data/genomes/tree_tip_mapping.csv"
OUT_CSV = "results/sra_rnaseq_runs_singlesex.csv"
ESEARCH = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
EFETCH = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

FIELDNAMES = [
    "species_name", "tip_label", "family", "clade",
    "srr_accession", "srx_accession", "sex", "sex_raw",
    "tissue", "dev_stage", "spots", "bases",
    "platform", "layout", "sample_attrs",
]


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--api-key", default=os.environ.get("NCBI_API_KEY", ""))
    p.add_argument("--resume", action="store_true")
    return p.parse_args()


def eutil_get(url, params, api_key, max_retries=3):
    if api_key:
        params["api_key"] = api_key
    query = urllib.parse.urlencode(params)
    full_url = "{}?{}".format(url, query)
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(full_url)
            req.add_header("User-Agent", "SCARAB-SRA-singlesex/1.0")
            resp = urllib.request.urlopen(req, timeout=30)
            return resp.read().decode("utf-8")
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(2 * (attempt + 1))
            else:
                raise


def search_sra(species, api_key):
    query = '"{}"[Organism] AND "RNA-Seq"[Strategy]'.format(species)
    params = {"db": "sra", "term": query, "retmax": "500", "usehistory": "n"}
    xml_text = eutil_get(ESEARCH, params, api_key)
    root = ET.fromstring(xml_text)
    count = int(root.find("Count").text) if root.find("Count") is not None else 0
    uids = [uid.text for uid in root.findall(".//IdList/Id")]
    return count, uids


def classify_sex(sex_str):
    s = sex_str.lower().strip()
    if not s or s in ("not applicable", "not collected", "not determined",
                      "missing", "n/a", "unknown", "pooled", "mixed"):
        return "unknown"
    if "female" in s:
        return "female"
    if "male" in s:
        return "male"
    return "unknown"


def parse_runs_from_packages(xml_text, species_info):
    rows = []
    if not xml_text.strip().startswith("<?xml"):
        xml_text = '<?xml version="1.0"?><ROOT>' + xml_text + '</ROOT>'
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        xml_text = "<ROOT>" + xml_text + "</ROOT>"
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError:
            return rows

    for pkg in root.iter("EXPERIMENT_PACKAGE"):
        srx = ""
        exp = pkg.find(".//EXPERIMENT")
        if exp is not None:
            srx = exp.get("accession", "")
        title = ""
        title_el = pkg.find(".//EXPERIMENT//TITLE")
        if title_el is not None and title_el.text:
            title = title_el.text.strip()

        platform = ""
        plat_el = pkg.find(".//PLATFORM")
        if plat_el is not None and len(plat_el) > 0:
            platform = plat_el[0].tag

        layout = ""
        layout_el = pkg.find(".//LIBRARY_LAYOUT")
        if layout_el is not None and len(layout_el) > 0:
            layout = layout_el[0].tag

        sex_raw = ""
        sex = "unknown"
        tissue = ""
        dev_stage = ""
        sample_attrs_str = ""

        sample = pkg.find(".//SAMPLE")
        if sample is not None:
            attrs = {}
            for sa in sample.findall(".//SAMPLE_ATTRIBUTE"):
                tag_el = sa.find("TAG")
                val_el = sa.find("VALUE")
                if tag_el is not None and val_el is not None:
                    tag = tag_el.text.strip().lower() if tag_el.text else ""
                    val = val_el.text.strip() if val_el.text else ""
                    attrs[tag] = val

            sample_attrs_str = "; ".join(
                "{}={}".format(k, v) for k, v in sorted(attrs.items()))

            for key in ["sex", "gender"]:
                if key in attrs:
                    sex_raw = attrs[key]
                    break
            if not sex_raw:
                all_text = " ".join(attrs.values()) + " " + title
                all_lower = all_text.lower()
                if re.search(r'\bmale\b', all_lower) and not re.search(r'\bfemale\b', all_lower):
                    sex_raw = "male (inferred)"
                elif re.search(r'\bfemale\b', all_lower):
                    sex_raw = "female (inferred)"
            sex = classify_sex(sex_raw)

            for key in ["tissue", "tissue_type", "organ", "body part",
                         "cell_type", "isolation source", "sample type"]:
                if key in attrs and attrs[key]:
                    tissue = attrs[key]
                    break

            for key in ["dev_stage", "developmental stage", "development stage",
                         "life stage", "age"]:
                if key in attrs and attrs[key]:
                    dev_stage = attrs[key]
                    break

        for run_el in pkg.iter("RUN"):
            srr = run_el.get("accession", "")
            if not srr:
                continue
            spots = run_el.get("total_spots", "0")
            bases = run_el.get("total_bases", "0")
            rows.append({
                "species_name": species_info["species_name"],
                "tip_label": species_info["tip_label"],
                "family": species_info["family"],
                "clade": species_info["clade"],
                "srr_accession": srr,
                "srx_accession": srx,
                "sex": sex,
                "sex_raw": sex_raw,
                "tissue": tissue,
                "dev_stage": dev_stage,
                "spots": int(spots) if spots else 0,
                "bases": int(bases) if bases else 0,
                "platform": platform,
                "layout": layout,
                "sample_attrs": sample_attrs_str,
            })
    return rows


def write_csv(path, rows):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDNAMES)
        w.writeheader()
        for row in rows:
            w.writerow(row)


def main():
    args = parse_args()
    api_key = args.api_key
    delay = 0.11 if api_key else 0.35

    # Find male-only and female-only species
    singlesex_species = []
    with open(SURVEY_CSV) as f:
        reader = csv.DictReader(f)
        for row in reader:
            has_m = row["has_male"] == "True"
            has_f = row["has_female"] == "True"
            both = row["has_both_sexes"] == "True"
            if (has_m or has_f) and not both:
                singlesex_species.append(row["species_name"])

    tip_map = {}
    with open(TIP_MAP) as f:
        reader = csv.DictReader(f)
        for row in reader:
            tip_map[row["species_name"]] = {
                "species_name": row["species_name"],
                "tip_label": row["tip_label"],
                "family": row["family"],
                "clade": row["clade"],
            }

    print("Querying {} single-sex species...".format(len(singlesex_species)))

    done_species = set()
    all_rows = []
    if args.resume and os.path.exists(OUT_CSV):
        with open(OUT_CSV) as f:
            for row in csv.DictReader(f):
                all_rows.append(row)
                done_species.add(row["species_name"])
        print("Resuming: {} done".format(len(done_species)))

    os.makedirs("results", exist_ok=True)

    for i, species in enumerate(singlesex_species):
        if species in done_species:
            continue

        sp_info = tip_map.get(species, {
            "species_name": species, "tip_label": "", "family": "", "clade": ""})

        try:
            count, uids = search_sra(species, api_key)
        except Exception as e:
            print("  ERROR {}: {}".format(species, e))
            time.sleep(delay)
            continue
        time.sleep(delay)

        if count == 0:
            continue

        species_rows = []
        for batch_start in range(0, len(uids), 50):
            batch = uids[batch_start:batch_start + 50]
            try:
                params = {"db": "sra", "id": ",".join(batch),
                          "rettype": "xml", "retmode": "xml"}
                xml_text = eutil_get(EFETCH, params, api_key)
                species_rows.extend(parse_runs_from_packages(xml_text, sp_info))
            except Exception as e:
                print("  ERROR fetching {}: {}".format(species, e))
            time.sleep(delay)

        all_rows.extend(species_rows)
        n_m = sum(1 for r in species_rows if r["sex"] == "male")
        n_f = sum(1 for r in species_rows if r["sex"] == "female")
        if n_m > 0 or n_f > 0:
            print("  {:<40s} {:>3d} runs (M={} F={})".format(
                species, len(species_rows), n_m, n_f))

        if (i + 1) % 10 == 0:
            write_csv(OUT_CSV, all_rows)

    write_csv(OUT_CSV, all_rows)

    n_species = len(set(r["species_name"] for r in all_rows))
    n_m = sum(1 for r in all_rows if r["sex"] == "male")
    n_f = sum(1 for r in all_rows if r["sex"] == "female")
    print("\n=== SUMMARY ===")
    print("Species: {}, Runs: {} (M={} F={} U={})".format(
        n_species, len(all_rows), n_m, n_f, len(all_rows) - n_m - n_f))


if __name__ == "__main__":
    main()
