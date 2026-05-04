#!/usr/bin/env python3
"""
TOB NCBI Inventory Refresh — 2026-05
Queries NCBI for all current assemblies under Coleoptera + outgroup taxa,
diffs against SCARAB catalog, scores new candidates.

Corrected field names from esummary JSON:
  assemblystatus   (not assemblylevel)
  contign50        (not contig_n50)
  scaffoldn50      (not scaffold_n50)
  submitterorganization (not submitter)
  total_length extracted from meta XML
  asmreleasedate_genbank for submission_date
"""

import json
import urllib.request
import urllib.parse
import time
import sys
import os
import csv
import re

# ── Configuration ────────────────────────────────────────────────────────────
EUTILS = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
SLEEP  = 0.4   # seconds between requests
RETMAX = 500   # chunk size for esummary POST

TAXA = [
    # (display_name, search_term)
    ("Coleoptera",    "txid7041[Organism:exp]"),
    ("Strepsiptera",  "Strepsiptera[Organism]"),
    ("Neuroptera",    "txid7515[Organism:exp]"),
    ("Megaloptera",   "txid7461[Organism:exp]"),
    ("Raphidioptera", "txid7445[Organism:exp]"),
]

SCARAB_CSV = "/Users/blackmon/Desktop/GitHub/SCARAB/data/genomes/genome_catalog_primary.csv"
OUT_DIR    = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data"
OUT_CSV    = os.path.join(OUT_DIR, "ncbi_inventory_refresh_2026-05.csv")
OUT_MD     = os.path.join(OUT_DIR, "ncbi_inventory_refresh_notes.md")

# ── Helpers ──────────────────────────────────────────────────────────────────

def fetch_url(url, retries=5, backoff=2.0):
    """GET url → parsed JSON, with retry on 429/transient errors."""
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                raw = r.read().decode("utf-8")
            return json.loads(raw)
        except Exception as e:
            code = getattr(e, "code", 0)
            if attempt < retries - 1:
                wait = backoff * (2 ** attempt)
                print("  [retry {}/{}] {} — sleeping {:.1f}s".format(
                    attempt+1, retries, e, wait), file=sys.stderr)
                time.sleep(wait)
            else:
                raise
    raise RuntimeError("Failed after {} retries: {}".format(retries, url))


def fetch_post(url, params, retries=5, backoff=2.0):
    """POST params → parsed JSON, with retry."""
    data = urllib.parse.urlencode(params).encode("utf-8")
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data, method="POST")
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read().decode("utf-8")
            return json.loads(raw)
        except Exception as e:
            if attempt < retries - 1:
                wait = backoff * (2 ** attempt)
                print("  [retry {}/{}] {} — sleeping {:.1f}s".format(
                    attempt+1, retries, e, wait), file=sys.stderr)
                time.sleep(wait)
            else:
                raise
    raise RuntimeError("POST failed after {} retries".format(retries))


def esearch_all_uids(term, db="assembly"):
    """Return list of all assembly UIDs for a search term."""
    count_url = "{}/esearch.fcgi?db={}&retmode=json&retmax=0&term={}".format(
        EUTILS, db, urllib.parse.quote(term))
    data = fetch_url(count_url)
    time.sleep(SLEEP)
    count = int(data["esearchresult"]["count"])
    print("  '{}' → {} assemblies".format(term, count), file=sys.stderr)
    if count == 0:
        return []

    all_url = "{}/esearch.fcgi?db={}&retmode=json&retmax={}&term={}".format(
        EUTILS, db, count + 50, urllib.parse.quote(term))
    data2 = fetch_url(all_url)
    time.sleep(SLEEP)
    return data2["esearchresult"]["idlist"]


def esummary_batch(uids, db="assembly"):
    """Fetch esummary via POST for batches of UIDs."""
    results = {}
    base_url = "{}/esummary.fcgi".format(EUTILS)
    for i in range(0, len(uids), RETMAX):
        chunk = uids[i:i+RETMAX]
        params = {"db": db, "retmode": "json", "id": ",".join(chunk)}
        data = fetch_post(base_url, params)
        time.sleep(SLEEP)
        result = data.get("result", {})
        for uid in result.get("uids", []):
            results[uid] = result[uid]
        print("  esummary chunk {}-{}/{} ({} records so far)".format(
            i+1, min(i+RETMAX, len(uids)), len(uids), len(results)), file=sys.stderr)
    return results


def extract_total_length(meta):
    """Pull total_length from the embedded Stats XML in the meta field."""
    m = re.search(r'category="total_length" sequence_tag="all">(\d+)<', meta)
    return int(m.group(1)) if m else 0


def parse_assembly_summary(uid, doc):
    """Extract standardised fields from an esummary doc (corrected field names)."""
    acc = doc.get("assemblyaccession", "")
    synonyms = doc.get("synonym", {})
    gca = synonyms.get("genbank", "") or acc

    organism   = doc.get("speciesname", "") or doc.get("organism", "")
    # strip trailing " (beetles)" etc added by NCBI
    organism   = re.sub(r'\s*\([^)]+\)\s*$', '', organism).strip()
    taxid      = str(doc.get("taxid", ""))
    level      = doc.get("assemblystatus", "")
    contig_n50  = int(doc.get("contign50",  0) or 0)
    scaffold_n50 = int(doc.get("scaffoldn50", 0) or 0)
    meta       = doc.get("meta", "")
    total_len  = extract_total_length(meta)
    # submission date: prefer genbank release date
    sub_date = (doc.get("asmreleasedate_genbank", "") or
                doc.get("submissiondate", ""))[:10].replace("/", "-")
    submitter  = doc.get("submitterorganization", "")

    return {
        "accession":      gca or acc,
        "uid":            uid,
        "organism":       organism,
        "taxid":          taxid,
        "assembly_level": level,
        "contig_N50":     contig_n50,
        "scaffold_N50":   scaffold_n50,
        "total_length_mb": round(total_len / 1e6, 2) if total_len else 0,
        "submission_date": sub_date,
        "submitter":       submitter,
    }


def fetch_taxon_lineage(taxid):
    """Return (family, suborder) via efetch taxonomy XML."""
    url = "{}/efetch.fcgi?db=taxonomy&id={}&retmode=xml".format(EUTILS, taxid)
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            raw = r.read().decode("utf-8")
        time.sleep(SLEEP)
    except Exception as e:
        print("  [taxon error] taxid={}: {}".format(taxid, e), file=sys.stderr)
        return ("", "")

    family   = ""
    suborder = ""

    # parse LineageEx taxon blocks
    taxon_blocks = re.findall(r'<Taxon>(.*?)</Taxon>', raw, re.DOTALL)
    for block in taxon_blocks:
        rank_m = re.search(r'<Rank>(.*?)</Rank>', block)
        name_m = re.search(r'<ScientificName>(.*?)</ScientificName>', block)
        if rank_m and name_m:
            rank = rank_m.group(1).strip()
            name = name_m.group(1).strip()
            if rank == "family" and not family:
                family = name
            elif rank == "suborder" and not suborder:
                suborder = name

    return (family, suborder)


def score_assembly(level, contig_n50):
    """Return (tob_score, tob_recommendation)."""
    lvl = level.lower()
    if "chromosome" in lvl:
        if contig_n50 >= 1_000_000:
            return ("A", "include")
        else:
            return ("B", "include")
    elif "scaffold" in lvl:
        if contig_n50 >= 100_000:
            return ("C", "include")
        elif contig_n50 >= 10_000:
            return ("D", "conditional")
        else:
            return ("E", "exclude")
    elif "contig" in lvl:
        if contig_n50 >= 30_000:
            return ("D", "conditional")
        elif contig_n50 >= 10_000:
            return ("E", "exclude")
        else:
            return ("F", "exclude")
    else:
        # Unknown/Complete Genome — use N50 heuristic
        if contig_n50 >= 1_000_000:
            return ("A", "include")
        elif contig_n50 >= 100_000:
            return ("C", "include")
        elif contig_n50 >= 30_000:
            return ("D", "conditional")
        else:
            return ("E", "exclude")


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # 1. Read SCARAB catalog
    print("Reading SCARAB catalog...", file=sys.stderr)
    scarab_accessions = set()
    with open(SCARAB_CSV, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            acc = row["assembly_accession"].strip()
            if acc:
                scarab_accessions.add(acc)
    print("SCARAB catalog: {} accessions".format(len(scarab_accessions)), file=sys.stderr)

    # 2. Query NCBI for each taxon
    all_assemblies = {}   # accession → record dict
    uid_to_taxon   = {}   # uid → query_taxon label

    for taxon_name, term in TAXA:
        print("\n[{}] term='{}'".format(taxon_name, term), file=sys.stderr)
        uids = esearch_all_uids(term)
        if not uids:
            continue
        summaries = esummary_batch(uids)
        for uid, doc in summaries.items():
            if uid == "uids":
                continue
            rec = parse_assembly_summary(uid, doc)
            acc = rec["accession"]
            if acc and acc not in all_assemblies:
                rec["query_taxon"] = taxon_name
                all_assemblies[acc] = rec
            # if already present from an earlier taxon query, skip (keep first)

    print("\nTotal unique assemblies: {}".format(len(all_assemblies)), file=sys.stderr)

    # 3. Diff
    new_accessions = set(a for a in all_assemblies if a not in scarab_accessions)
    print("New (not in SCARAB): {}".format(len(new_accessions)), file=sys.stderr)

    # 4. Taxonomy lookup — cache by taxid
    taxon_cache = {}
    print("\nLooking up taxonomy ({} unique taxids)...".format(
        len(set(r["taxid"] for r in all_assemblies.values()))), file=sys.stderr)
    lookup_count = 0
    for acc, rec in all_assemblies.items():
        taxid = rec["taxid"]
        if taxid not in taxon_cache:
            taxon_cache[taxid] = fetch_taxon_lineage(taxid)
            lookup_count += 1
            if lookup_count % 50 == 0:
                print("  {} taxid lookups done".format(lookup_count), file=sys.stderr)
    print("Taxonomy lookups complete: {} unique taxids".format(lookup_count), file=sys.stderr)

    # 5. Build output rows
    out_rows = []
    for acc, rec in all_assemblies.items():
        taxid = rec["taxid"]
        family, suborder = taxon_cache.get(taxid, ("", ""))
        in_scarab = "yes" if acc in scarab_accessions else "no"
        tob_score, tob_rec = score_assembly(rec["assembly_level"], rec["contig_N50"])

        out_rows.append({
            "accession":          acc,
            "organism":           rec["organism"],
            "taxid":              taxid,
            "family":             family,
            "suborder":           suborder,
            "assembly_level":     rec["assembly_level"],
            "contig_N50":         rec["contig_N50"],
            "scaffold_N50":       rec["scaffold_N50"],
            "total_length_mb":    rec["total_length_mb"],
            "submission_date":    rec["submission_date"],
            "submitter":          rec["submitter"],
            "in_scarab_catalog":  in_scarab,
            "tob_score":          tob_score,
            "tob_recommendation": tob_rec,
        })

    score_order = {"A":0,"B":1,"C":2,"D":3,"E":4,"F":5,"":6}
    out_rows.sort(key=lambda r: (
        0 if r["in_scarab_catalog"] == "no" else 1,
        score_order.get(r["tob_score"], 6),
        -r["contig_N50"]
    ))

    # 6a. Write CSV
    fieldnames = [
        "accession","organism","taxid","family","suborder",
        "assembly_level","contig_N50","scaffold_N50","total_length_mb",
        "submission_date","submitter","in_scarab_catalog","tob_score","tob_recommendation"
    ]
    with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)
    print("\nWrote {}".format(OUT_CSV), file=sys.stderr)

    # ── Markdown notes ─────────────────────────────────────────────────────
    new_rows = [r for r in out_rows if r["in_scarab_catalog"] == "no"]

    sub_counts = {}
    for r in new_rows:
        s = r["suborder"] or r.get("query_taxon", "Unknown")
        sub_counts[s] = sub_counts.get(s, 0) + 1

    fam_counts = {}
    for r in new_rows:
        s = r["family"] or "Unknown"
        fam_counts[s] = fam_counts.get(s, 0) + 1

    lvl_counts_new = {}
    for r in new_rows:
        l = r["assembly_level"] or "Unknown"
        lvl_counts_new[l] = lvl_counts_new.get(l, 0) + 1

    all_lvl_counts = {}
    for r in out_rows:
        l = r["assembly_level"] or "Unknown"
        all_lvl_counts[l] = all_lvl_counts.get(l, 0) + 1

    rec_counts = {}
    for r in new_rows:
        rc = r["tob_recommendation"]
        rec_counts[rc] = rec_counts.get(rc, 0) + 1

    top10 = sorted(new_rows, key=lambda r: (score_order.get(r["tob_score"],6), -r["contig_N50"]))[:10]

    # top families (new)
    top_fams = sorted(fam_counts.items(), key=lambda x: -x[1])[:20]

    md_lines = [
        "# TOB NCBI Inventory Refresh — 2026-05",
        "",
        "## Overview",
        "",
        "| Metric | Count |",
        "|--------|-------|",
        "| Total NCBI assemblies (Coleoptera + Strepsiptera + Neuropterida) | {} |".format(len(out_rows)),
        "| SCARAB catalog assemblies | {} |".format(len(scarab_accessions)),
        "| New candidates (not in SCARAB) | {} |".format(len(new_rows)),
        "",
        "## Assembly Level Distribution — all NCBI",
        "",
        "| Level | Count |",
        "|-------|-------|",
    ]
    for lvl, cnt in sorted(all_lvl_counts.items(), key=lambda x: -x[1]):
        md_lines.append("| {} | {} |".format(lvl, cnt))

    md_lines += [
        "",
        "## New Candidates by Suborder",
        "",
        "| Suborder / Group | New Assemblies |",
        "|-----------------|----------------|",
    ]
    for sub, cnt in sorted(sub_counts.items(), key=lambda x: -x[1]):
        md_lines.append("| {} | {} |".format(sub or "Unknown", cnt))

    md_lines += [
        "",
        "## New Candidates — Top 20 Families",
        "",
        "| Family | Count |",
        "|--------|-------|",
    ]
    for fam, cnt in top_fams:
        md_lines.append("| {} | {} |".format(fam, cnt))

    md_lines += [
        "",
        "## New Candidates by Assembly Level",
        "",
        "| Level | Count |",
        "|-------|-------|",
    ]
    for lvl, cnt in sorted(lvl_counts_new.items(), key=lambda x: -x[1]):
        md_lines.append("| {} | {} |".format(lvl, cnt))

    md_lines += [
        "",
        "## TOB Recommendation Summary (new candidates only)",
        "",
        "| Recommendation | Count |",
        "|---------------|-------|",
    ]
    for rc, cnt in sorted(rec_counts.items(), key=lambda x: -x[1]):
        md_lines.append("| {} | {} |".format(rc, cnt))

    md_lines += [
        "",
        "## Top 10 Highest-Quality New Entries",
        "",
        "| Rank | Organism | Accession | Level | Contig N50 | Score |",
        "|-----|---------|-----------|-------|-----------|-------|",
    ]
    for i, r in enumerate(top10, 1):
        n50_fmt = "{:,}".format(r["contig_N50"])
        md_lines.append("| {} | {} | {} | {} | {} | {} |".format(
            i, r["organism"], r["accession"], r["assembly_level"], n50_fmt, r["tob_score"]))

    md_lines += [
        "",
        "## Adoption Strategy",
        "",
        ("Score A/B (chromosome-level): Incorporate immediately into TOB alignment. "
         "These are high-quality, near-complete assemblies with contiguous chromosomal scaffolds "
         "suitable for whole-genome alignment and synteny block inference. "
         "Priority for DToL/i5K releases filling undersampled families."),
        "",
        ("Score C (scaffold-level, contig N50 >= 100 kb): Include if the taxon fills a "
         "family-level gap in the current SCARAB tree or represents a flagship clade "
         "(Archostemata, Myxophaga, underrepresented Adephaga). "
         "Verify submitter bioproject for contamination flags before downloading."),
        "",
        ("Score D (contig or scaffold, N50 10-100 kb): Conditional inclusion for "
         "phylogenomics (gene-tree inference) but not WGA. "
         "Flag for future re-sequencing; include only if family is entirely absent."),
        "",
        ("Score E/F (contig N50 < 10 kb): Exclude. Too fragmented for reliable "
         "gene-boundary detection or synteny analysis."),
        "",
        ("Priority taxa: Any Archostemata (Cupedidae, Micromalthidae, Ommatidae) — "
         "the most basal Coleoptera suborder and currently undersampled. "
         "All Strepsiptera (sister to Coleoptera, key outgroup). "
         "DToL/Wellcome Sanger Institute releases are typically chromosome-level and should "
         "be fast-tracked."),
        "",
        "---",
        "_Generated by TOB ncbi_inventory_refresh.py, 2026-05-03_",
    ]

    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(md_lines) + "\n")
    print("Wrote {}".format(OUT_MD), file=sys.stderr)

    # ── Console summary ────────────────────────────────────────────────────
    print("\n=== SUMMARY ===")
    print("Total NCBI assemblies : {}".format(len(out_rows)))
    print("SCARAB catalog        : {}".format(len(scarab_accessions)))
    print("New candidates        : {}".format(len(new_rows)))
    print("\nNew by suborder/group:")
    for sub, cnt in sorted(sub_counts.items(), key=lambda x: -x[1]):
        print("  {:35s} {}".format(sub or "Unknown", cnt))
    print("\nNew by assembly level:")
    for lvl, cnt in sorted(lvl_counts_new.items(), key=lambda x: -x[1]):
        print("  {:25s} {}".format(lvl, cnt))
    print("\nNew by recommendation:")
    for rc, cnt in sorted(rec_counts.items(), key=lambda x: -x[1]):
        print("  {:20s} {}".format(rc, cnt))
    print("\nTop 10 new by quality:")
    for r in top10:
        print("  [{}] {:<45s} {}  N50={:>12,}  {}".format(
            r["tob_score"], r["organism"], r["accession"],
            r["contig_N50"], r["assembly_level"]))


if __name__ == "__main__":
    main()
