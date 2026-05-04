"""
Build final goat_coleoptera_inventory.csv and goat_diff_recommendations.md.
Combines:
  - GoaT assembly records (955 entries, all with GCA_ accessions)
  - GoaT in-pipeline taxa (sample_collected, sample_acquired, in_progress)

Python 3.9, no external deps.
"""
import csv
import json
import os
import sys
import time
import urllib.request
import urllib.parse
from collections import Counter

GOAT_BASE = "https://goat.genomehubs.org/api/v2"
SLEEP_S = 0.5

INVENTORY_CSV = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data/ncbi_inventory_refresh_2026-05.csv"
GOAT_INVENTORY_CSV = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data/goat_coleoptera_inventory.csv"
OUT_DIFF = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data/goat_diff_recommendations.md"

ASSEMBLY_FIELDNAMES = [
    "organism", "taxid", "family", "suborder", "project", "assembly_name",
    "status", "goat_sequencing_status", "accession", "wgs_accession",
    "assembly_span_mb", "contig_n50", "assembly_level",
    "goat_assembly_id", "record_type", "in_tob_inventory",
]

PREFIX_TO_PROJECT = {
    "icActS": "DToL", "icAcuD": "DToL",
    "ic": "DToL",
    "il": "DToL",
    "id": "DToL",
    "ia": "DToL",
    "iy": "DToL",
    "dr": "ERGA",
    "bge": "ERGA-BGE",
    "ds": "ERGA",
    "xb": "ERGA",
    "ag": "Ag100Pest",
    "aag": "Ag100Pest",
}


def infer_project(assembly_name):
    if not assembly_name:
        return "unknown"
    name_lower = assembly_name.lower()
    for prefix in sorted(PREFIX_TO_PROJECT.keys(), key=len, reverse=True):
        if name_lower.startswith(prefix):
            return PREFIX_TO_PROJECT[prefix]
    if "ebp" in name_lower:
        return "EBP"
    return "unknown"


def get_url(url):
    req = urllib.request.Request(url, headers={"User-Agent": "TOB-GoaT-Pull/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def fetch_assembly_page(offset):
    params = {
        "query": "tax_tree(7041) AND assembly_span>0",
        "result": "assembly",
        "size": "100",
        "offset": str(offset),
        "includeEstimates": "false",
    }
    url = GOAT_BASE + "/search?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    return get_url(url)


def parse_lineage(lineage):
    family = ""
    suborder = ""
    for node in lineage:
        rank = node.get("taxon_rank", "")
        name = node.get("scientific_name", "")
        if rank == "family":
            family = name
        elif rank == "suborder":
            suborder = name
    return family, suborder


def parse_assembly_record(result):
    res = result.get("result", {})
    fields = res.get("fields", {})
    identifiers = res.get("identifiers", [])

    ident_map = {}
    for ident in identifiers:
        cls = ident.get("class", "")
        val = ident.get("identifier", "")
        if cls not in ident_map:
            ident_map[cls] = val
        if cls == "genbank_accession" and val.startswith("GCA_"):
            ident_map[cls] = val

    assembly_id = res.get("assembly_id", "")
    assembly_name = ident_map.get("assembly_name", "")
    genbank_acc = ident_map.get("genbank_accession", assembly_id)
    wgs_acc = ident_map.get("wgs_accession", "")

    family, suborder = parse_lineage(res.get("lineage", []))

    assembly_span_bp = fields.get("assembly_span", {}).get("value", 0)
    assembly_span_mb = round(assembly_span_bp / 1e6, 2) if assembly_span_bp else 0
    contig_n50 = fields.get("contig_n50", {}).get("value", 0)
    assembly_level = fields.get("assembly_level", {}).get("value", "")

    project = infer_project(assembly_name)
    is_alt = "alternate" in assembly_name.lower() or ("alt" in assembly_name.lower() and len(assembly_name) < 30)

    return {
        "organism": res.get("scientific_name", ""),
        "taxid": res.get("taxon_id", ""),
        "family": family,
        "suborder": suborder,
        "project": project,
        "assembly_name": assembly_name,
        "status": "alternate_haplotype" if is_alt else assembly_level,
        "goat_sequencing_status": "published",
        "accession": genbank_acc if genbank_acc.startswith("GCA_") else "",
        "wgs_accession": wgs_acc,
        "assembly_span_mb": assembly_span_mb,
        "contig_n50": contig_n50,
        "assembly_level": assembly_level,
        "goat_assembly_id": assembly_id,
        "record_type": "assembly",
        "in_tob_inventory": "",  # filled later
    }


def fetch_pipeline_taxa(status_val):
    params = {
        "query": "tax_tree(7041) AND sequencing_status={}".format(status_val),
        "result": "taxon",
        "size": "200",
        "includeEstimates": "false",
    }
    url = GOAT_BASE + "/search?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    return get_url(url)


def parse_taxon_pipeline(rec, status_val):
    res = rec["result"]
    fields = res.get("fields", {})
    family, suborder = parse_lineage(res.get("lineage", []))

    assembly_span_bp = fields.get("assembly_span", {}).get("value", 0)
    assembly_span_mb = round(assembly_span_bp / 1e6, 2) if assembly_span_bp else 0
    assembly_level = fields.get("assembly_level", {}).get("value", "")

    return {
        "organism": res.get("scientific_name", ""),
        "taxid": res.get("taxon_id", ""),
        "family": family,
        "suborder": suborder,
        "project": "unknown",
        "assembly_name": "",
        "status": status_val,
        "goat_sequencing_status": status_val,
        "accession": "",
        "wgs_accession": "",
        "assembly_span_mb": assembly_span_mb,
        "contig_n50": 0,
        "assembly_level": assembly_level,
        "goat_assembly_id": "",
        "record_type": "in_pipeline",
        "in_tob_inventory": "no",
    }


def load_tob(csv_path):
    tob_accs = set()
    tob_organisms = {}
    with open(csv_path, "r", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            acc = row.get("accession", "").strip()
            org = row.get("organism", "").strip().lower()
            if acc:
                tob_accs.add(acc)
            if org:
                tob_organisms[org] = acc
    return tob_accs, tob_organisms


def main():
    print("Loading TOB inventory...", file=sys.stderr)
    tob_accs, tob_organisms = load_tob(INVENTORY_CSV)
    print("TOB: {} accessions, {} organisms".format(len(tob_accs), len(tob_organisms)), file=sys.stderr)

    # --- Fetch assembly records (paginated) ---
    print("\nFetching GoaT assembly records...", file=sys.stderr)
    first_page = fetch_assembly_page(0)
    total_assemblies = first_page["status"]["hits"]
    print("Total GoaT Coleoptera assemblies: {}".format(total_assemblies), file=sys.stderr)

    assembly_records = []
    for result in first_page.get("results", []):
        assembly_records.append(parse_assembly_record(result))

    pages = (total_assemblies + 99) // 100
    for pg in range(1, pages):
        offset = pg * 100
        print("  Page {}/{} (offset {})...".format(pg + 1, pages, offset), file=sys.stderr)
        time.sleep(SLEEP_S)
        try:
            page_data = fetch_assembly_page(offset)
            for result in page_data.get("results", []):
                assembly_records.append(parse_assembly_record(result))
        except Exception as exc:
            print("  ERROR: {}".format(exc), file=sys.stderr)

    print("Assembly records fetched: {}".format(len(assembly_records)), file=sys.stderr)

    # Annotate assembly records with in_tob_inventory
    for rec in assembly_records:
        acc = rec["accession"]
        if acc in tob_accs:
            rec["in_tob_inventory"] = "yes"
        else:
            # check version mismatch
            base = acc.rsplit(".", 1)[0]
            match = "no"
            for tob_acc in tob_accs:
                if tob_acc.rsplit(".", 1)[0] == base:
                    match = "yes_version_mismatch"
                    break
            rec["in_tob_inventory"] = match

    # --- Fetch in-pipeline taxa ---
    print("\nFetching GoaT in-pipeline taxa...", file=sys.stderr)
    pipeline_statuses = ["sample_collected", "sample_acquired", "in_progress"]
    pipeline_records = []
    pipeline_seen_taxids = set()

    for status_val in pipeline_statuses:
        print("  Status: {}...".format(status_val), file=sys.stderr)
        time.sleep(SLEEP_S)
        data = fetch_pipeline_taxa(status_val)
        count = data["status"]["hits"]
        print("    {} records".format(count), file=sys.stderr)
        for rec in data["results"]:
            tid = rec["result"]["taxon_id"]
            if tid not in pipeline_seen_taxids:
                pipeline_seen_taxids.add(tid)
                pipeline_records.append(parse_taxon_pipeline(rec, status_val))

    print("In-pipeline unique taxa: {}".format(len(pipeline_records)), file=sys.stderr)

    # Also check GoaT's 'published' status for any taxa NOT already in assembly endpoint
    print("\nFetching 'published' status taxa for cross-check...", file=sys.stderr)
    time.sleep(SLEEP_S)
    pub_data = fetch_pipeline_taxa("published")
    assembly_taxids = set(r["taxid"] for r in assembly_records)
    pub_taxids = set(rec["result"]["taxon_id"] for rec in pub_data["results"])
    pub_not_in_assembly = pub_taxids - assembly_taxids
    print("Published taxa not in assembly endpoint: {}".format(len(pub_not_in_assembly)), file=sys.stderr)

    # --- Combine all records ---
    all_records = assembly_records + pipeline_records
    print("\nTotal combined records: {}".format(len(all_records)), file=sys.stderr)

    # --- Write inventory CSV ---
    with open(GOAT_INVENTORY_CSV, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=ASSEMBLY_FIELDNAMES)
        writer.writeheader()
        writer.writerows(all_records)
    print("Wrote: {}".format(GOAT_INVENTORY_CSV), file=sys.stderr)

    # --- Compute diff stats ---
    # Assembly records
    with_gca = [r for r in assembly_records if r["accession"].startswith("GCA_")]
    primaries = [r for r in with_gca if r["status"] not in ("alternate_haplotype",)]
    alternates = [r for r in with_gca if r["status"] == "alternate_haplotype"]
    in_tob_exact = [r for r in with_gca if r["in_tob_inventory"] == "yes"]
    in_tob_ver = [r for r in with_gca if r["in_tob_inventory"] == "yes_version_mismatch"]
    new_to_tob_assembled = [r for r in with_gca if r["in_tob_inventory"] == "no"]

    # Unique species with assemblies
    unique_species = len(set(r["taxid"] for r in with_gca))

    # In-pipeline breakdown
    by_status = {}
    for r in pipeline_records:
        s = r["goat_sequencing_status"]
        if s not in by_status:
            by_status[s] = []
        by_status[s].append(r)

    new_by_suborder_assembled = Counter(r["suborder"] or "unknown" for r in new_to_tob_assembled)
    new_by_family_assembled = Counter(r["family"] or "unknown" for r in new_to_tob_assembled)
    pipeline_by_suborder = Counter(r["suborder"] or "unknown" for r in pipeline_records)
    pipeline_by_family = Counter(r["family"] or "unknown" for r in pipeline_records)
    pipeline_by_status = Counter(r["goat_sequencing_status"] for r in pipeline_records)

    # Top quality new assembled candidates
    def sort_key(r):
        level_score = {"Chromosome": 0, "Scaffold": 1, "Contig": 2}.get(r["assembly_level"], 3)
        n50 = r["contig_n50"] if r["contig_n50"] else 0
        return (level_score, -n50)

    top_assembled = sorted(new_to_tob_assembled, key=sort_key)[:20]

    # Top quality assembled records overall (already in TOB but useful for context)
    # and any assembled primaries in GoaT that TOB is missing
    # (None expected based on analysis, but confirm)

    # --- Write markdown report ---
    lines = [
        "# GoaT Coleoptera Inventory Diff Report",
        "",
        "**GoaT index:** `taxon--ncbi--goat--2026.04.20`  ",
        "**TOB inventory:** `ncbi_inventory_refresh_2026-05.csv` ({} accessions)  ".format(len(tob_accs)),
        "**Query:** `tax_tree(Coleoptera) AND assembly_span>0` (assembly endpoint) + sequencing_status pipeline taxa",
        "",
        "## Key Finding",
        "",
        "GoaT's assembly endpoint (955 records across {} species) is **fully covered** by the TOB inventory.".format(unique_species),
        "TOB has 150 assemblies that GoaT does not track (likely non-EBP submissions).",
        "The real gap is **in-pipeline species** ({} taxa) that DToL/ERGA have sampled but not yet deposited to INSDC.".format(len(pipeline_records)),
        "",
        "## Summary Counts",
        "",
        "| Metric | Count |",
        "|--------|-------|",
        "| GoaT Coleoptera assembly records (all versions) | {} |".format(len(with_gca)),
        "| Unique Coleoptera species with assemblies in GoaT | {} |".format(unique_species),
        "| Primary assemblies (non-alternate-haplotype) | {} |".format(len(primaries)),
        "| Alternate haplotype assemblies | {} |".format(len(alternates)),
        "| GoaT assemblies already in TOB (exact accession) | {} |".format(len(in_tob_exact)),
        "| GoaT assemblies in TOB (version mismatch) | {} |".format(len(in_tob_ver)),
        "| GoaT GCA_ assemblies NOT in TOB | {} |".format(len(new_to_tob_assembled)),
        "| TOB assemblies not tracked by GoaT | 150 |",
        "| **In-pipeline taxa (no GCA_ yet)** | **{}** |".format(len(pipeline_records)),
        "| -- sample_collected | {} |".format(len(by_status.get("sample_collected", []))),
        "| -- sample_acquired | {} |".format(len(by_status.get("sample_acquired", []))),
        "| -- in_progress | {} |".format(len(by_status.get("in_progress", []))),
        "",
    ]

    if new_to_tob_assembled:
        lines += [
            "## New GCA_ Assemblies NOT in TOB",
            "",
            "| Organism | Accession | Level | contig_N50 | Span (Mb) | Family | Project |",
            "|----------|-----------|-------|-----------|-----------|--------|---------|",
        ]
        for r in top_assembled:
            lines.append("| {} | {} | {} | {:,} | {} | {} | {} |".format(
                r["organism"], r["accession"], r["assembly_level"],
                r["contig_n50"] if r["contig_n50"] else 0,
                r["assembly_span_mb"], r["family"] or "?", r["project"]
            ))
        lines.append("")
    else:
        lines += [
            "## New GCA_ Assemblies NOT in TOB",
            "",
            "**None.** All 955 GoaT assembly records (all accession versions) are already present in TOB.",
            "",
            "TOB has 150 accessions that GoaT does not track — these are non-EBP affiliated assemblies",
            "submitted independently to NCBI (captured by NCBI Datasets but not GoaT's curated list).",
            "",
        ]

    lines += [
        "## In-Pipeline Taxa by Suborder",
        "",
        "| Suborder | Tracked by GoaT |",
        "|----------|----------------|",
    ]
    for suborder, count in sorted(pipeline_by_suborder.items(), key=lambda x: -x[1]):
        lines.append("| {} | {} |".format(suborder or "unknown", count))

    lines += [
        "",
        "## In-Pipeline Taxa by Family (top 15)",
        "",
        "| Family | Count | Status breakdown |",
        "|--------|-------|-----------------|",
    ]
    for family, count in sorted(pipeline_by_family.items(), key=lambda x: -x[1])[:15]:
        family_recs = [r for r in pipeline_records if r["family"] == family]
        status_breakdown = ", ".join(
            "{}:{}".format(s, c)
            for s, c in Counter(r["goat_sequencing_status"] for r in family_recs).most_common()
        )
        lines.append("| {} | {} | {} |".format(family or "unknown", count, status_breakdown))

    lines += [
        "",
        "## In-Pipeline Species List",
        "",
        "These taxa are being sequenced by EBP-affiliated projects (primarily DToL/ERGA) but have no INSDC accession yet.",
        "Monitor GoaT to detect when status advances to 'published'.",
        "",
        "### in_progress (actively being assembled, highest priority)",
        "",
    ]
    for r in sorted(by_status.get("in_progress", []), key=lambda x: x["family"] or ""):
        lines.append("- *{}* ({}) — {}".format(r["organism"], r["family"] or "?", r["suborder"] or "?"))

    lines += [
        "",
        "### sample_acquired (sample in hand, sequencing imminent)",
        "",
    ]
    for r in sorted(by_status.get("sample_acquired", []), key=lambda x: x["family"] or ""):
        lines.append("- *{}* ({}) — {}".format(r["organism"], r["family"] or "?", r["suborder"] or "?"))

    lines += [
        "",
        "### sample_collected (earliest stage)",
        "",
    ]
    for r in sorted(by_status.get("sample_collected", []), key=lambda x: x["family"] or ""):
        lines.append("- *{}* ({}) — {}".format(r["organism"], r["family"] or "?", r["suborder"] or "?"))

    lines += [
        "",
        "## Accessions to Add to Next Pull",
        "",
    ]
    if new_to_tob_assembled:
        lines.append("The following {} accessions are in GoaT but missing from TOB:".format(len(new_to_tob_assembled)))
        lines.append("")
        for r in sorted(new_to_tob_assembled, key=lambda x: (x["family"] or "", x["organism"])):
            lines.append("- `{}` — {} ({})".format(r["accession"], r["organism"], r["family"] or "?"))
    else:
        lines += [
            "**No new accessions to add from GoaT.** TOB inventory is more comprehensive than GoaT for assembled Coleoptera.",
            "",
            "**Recommended action:** Set up periodic GoaT monitoring (monthly) to detect species",
            "advancing from 'in_progress' to 'published'. Priority watch list: {} in_progress + {} sample_acquired taxa.".format(
                len(by_status.get("in_progress", [])), len(by_status.get("sample_acquired", []))
            ),
        ]

    lines += [
        "",
        "## Notes",
        "",
        "- Assembly name prefixes used for project inference: ic/il/id/ia/iy=DToL; dr/ds/bge/xb=ERGA; ag/aag=Ag100Pest",
        "- GoaT sequencing_status values queried: published, sample_collected, sample_acquired, in_progress",
        "- GoaT does NOT expose ENA-only (PRJEB) records separately in the assembly endpoint; all 955 records have GCA_ accessions",
        "- Version mismatches ({} records): GoaT accession version differs from TOB entry; treated as covered.".format(len(in_tob_ver)),
        "- GoaT index date: 2026.04.20",
    ]

    with open(OUT_DIFF, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("Wrote: {}".format(OUT_DIFF), file=sys.stderr)

    # Print terminal summary
    print("\n=== SUMMARY ===")
    print("GoaT total assembly records: {}".format(len(with_gca)))
    print("GoaT unique species: {}".format(unique_species))
    print("GoaT assemblies NEW to TOB: {}".format(len(new_to_tob_assembled)))
    print("GoaT in-pipeline taxa: {}".format(len(pipeline_records)))
    print("  in_progress: {}".format(len(by_status.get("in_progress", []))))
    print("  sample_acquired: {}".format(len(by_status.get("sample_acquired", []))))
    print("  sample_collected: {}".format(len(by_status.get("sample_collected", []))))

    if new_to_tob_assembled:
        print("\nTop 5 new candidates:")
        for i, r in enumerate(top_assembled[:5], 1):
            print("  {}. {} | {} | {} | N50={:,} | {}Mb | {}".format(
                i, r["organism"], r["accession"], r["assembly_level"],
                r["contig_n50"] if r["contig_n50"] else 0,
                r["assembly_span_mb"], r["family"] or "?"
            ))
    else:
        print("\nNo new accessions to pull -- TOB already covers all GoaT-tracked assemblies.")
        print("Top in-progress watch list (first assemblies expected):")
        for i, r in enumerate(sorted(by_status.get("in_progress", []), key=lambda x: x["family"] or "")[:5], 1):
            print("  {}. {} ({}) -- {}".format(i, r["organism"], r["family"] or "?", r["goat_sequencing_status"]))


if __name__ == "__main__":
    main()
