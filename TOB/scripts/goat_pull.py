"""
GoaT Coleoptera assembly pull + diff against TOB inventory.
Python 3.9, no f-strings (Grace compat style), no external deps beyond stdlib.
"""
import csv
import json
import os
import sys
import time
import urllib.request
import urllib.parse

GOAT_BASE = "https://goat.genomehubs.org/api/v2"
QUERY = "tax_tree(7041) AND assembly_span>0"
PAGE_SIZE = 100
SLEEP_S = 0.5

INVENTORY_CSV = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data/ncbi_inventory_refresh_2026-05.csv"
OUT_INVENTORY = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data/goat_coleoptera_inventory.csv"
OUT_DIFF = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB/data/goat_diff_recommendations.md"

# Assembly name prefixes -> project mapping (GoaT/DToL naming conventions)
PREFIX_TO_PROJECT = {
    "ic": "DToL",
    "il": "DToL",
    "id": "DToL",
    "ia": "DToL",
    "iy": "DToL",
    "dr": "ERGA",  # ERGA Iberian
    "bge": "ERGA-BGE",
    "ds": "ERGA",
    "xb": "ERGA",
    "ag": "Ag100Pest",
    "idcol": "i5k",
    "aag": "Ag100Pest",
}

KNOWN_PROJECTS = {
    "DToL": ["ic", "il", "id", "ia", "iy"],
    "ERGA": ["dr", "ds", "bge", "xb"],
    "Ag100Pest": ["ag", "aag"],
}


def infer_project(assembly_name):
    """Infer sequencing project from assembly name prefix convention."""
    if not assembly_name:
        return "unknown"
    name_lower = assembly_name.lower()
    # Try common prefixes in order of length (longest first to avoid false matches)
    for prefix in sorted(PREFIX_TO_PROJECT.keys(), key=len, reverse=True):
        if name_lower.startswith(prefix):
            return PREFIX_TO_PROJECT[prefix]
    # Check for EBP-style names
    if "ebp" in name_lower:
        return "EBP"
    if "caltech" in name_lower or "dovetail" in name_lower:
        return "other"
    return "unknown"


def fetch_page(offset):
    """Fetch one page of GoaT assembly results."""
    params = {
        "query": QUERY,
        "result": "assembly",
        "size": str(PAGE_SIZE),
        "offset": str(offset),
        "includeEstimates": "false",
    }
    url = GOAT_BASE + "/search?" + urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
    req = urllib.request.Request(url, headers={"User-Agent": "TOB-GoaT-Pull/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def parse_assembly(result):
    """Extract fields from a single GoaT assembly result dict."""
    res = result.get("result", {})
    fields = res.get("fields", {})
    identifiers = res.get("identifiers", [])

    # Get all identifier values by class
    ident_map = {}
    for ident in identifiers:
        cls = ident.get("class", "")
        val = ident.get("identifier", "")
        if cls not in ident_map:
            ident_map[cls] = val
        # Prefer GCA_ accessions over GCF_
        if cls == "genbank_accession" and val.startswith("GCA_"):
            ident_map[cls] = val

    assembly_id = res.get("assembly_id", "")
    assembly_name = ident_map.get("assembly_name", "")
    genbank_acc = ident_map.get("genbank_accession", assembly_id)
    refseq_acc = ident_map.get("refseq_accession", "")
    ena_acc = ""
    # ENA/PRJEB accessions sometimes appear in bioproject field or wgs_accession
    wgs_acc = ident_map.get("wgs_accession", "")

    # Flag ENA-only records (PRJEB or ERZ accessions, no GCA_)
    is_ena_only = (
        genbank_acc
        and not genbank_acc.startswith("GCA_")
        and not genbank_acc.startswith("GCF_")
    )
    if not genbank_acc.startswith("GCA_") and not genbank_acc.startswith("GCF_"):
        ena_acc = genbank_acc
        genbank_acc = ""

    # Taxonomy lineage
    lineage = res.get("lineage", [])
    family = ""
    suborder = ""
    for node in lineage:
        rank = node.get("taxon_rank", "")
        name = node.get("scientific_name", "")
        if rank == "family":
            family = name
        elif rank == "suborder":
            suborder = name

    # Assembly metrics
    assembly_span_bp = fields.get("assembly_span", {}).get("value", 0)
    assembly_span_mb = round(assembly_span_bp / 1e6, 2) if assembly_span_bp else 0
    contig_n50 = fields.get("contig_n50", {}).get("value", 0)
    assembly_level = fields.get("assembly_level", {}).get("value", "")

    # Infer project
    project = infer_project(assembly_name)

    return {
        "organism": res.get("scientific_name", ""),
        "taxid": res.get("taxon_id", ""),
        "family": family,
        "suborder": suborder,
        "project": project,
        "assembly_name": assembly_name,
        "status": assembly_level if assembly_level else "assembled",
        "accession": genbank_acc,
        "ena_accession": ena_acc,
        "wgs_accession": wgs_acc,
        "refseq_accession": refseq_acc,
        "assembly_span_mb": assembly_span_mb,
        "contig_n50": contig_n50,
        "goat_assembly_id": assembly_id,
        "is_ena_only": "yes" if is_ena_only else "no",
    }


def load_tob_accessions(csv_path):
    """Load set of accessions from TOB inventory CSV."""
    accessions = set()
    with open(csv_path, "r", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            acc = row.get("accession", "").strip()
            if acc:
                accessions.add(acc)
    return accessions


def main():
    print("Loading TOB inventory...", file=sys.stderr)
    tob_accessions = load_tob_accessions(INVENTORY_CSV)
    print("TOB accessions loaded: {}".format(len(tob_accessions)), file=sys.stderr)

    # First call to get total count
    print("Probing GoaT total count...", file=sys.stderr)
    first_page = fetch_page(0)
    total_hits = first_page["status"]["hits"]
    print("GoaT total Coleoptera assemblies: {}".format(total_hits), file=sys.stderr)

    all_records = []
    pages = (total_hits + PAGE_SIZE - 1) // PAGE_SIZE

    # Process first page
    for result in first_page.get("results", []):
        all_records.append(parse_assembly(result))

    # Remaining pages
    for page_idx in range(1, pages):
        offset = page_idx * PAGE_SIZE
        print(
            "Fetching page {}/{} (offset {})...".format(page_idx + 1, pages, offset),
            file=sys.stderr,
        )
        time.sleep(SLEEP_S)
        try:
            page_data = fetch_page(offset)
            for result in page_data.get("results", []):
                all_records.append(parse_assembly(result))
        except Exception as exc:
            print("ERROR on page {}: {}".format(page_idx, exc), file=sys.stderr)
            time.sleep(2)
            # Retry once
            try:
                page_data = fetch_page(offset)
                for result in page_data.get("results", []):
                    all_records.append(parse_assembly(result))
            except Exception as exc2:
                print("RETRY FAILED: {}".format(exc2), file=sys.stderr)

    print("Total records parsed: {}".format(len(all_records)), file=sys.stderr)

    # Annotate in_tob_inventory
    for rec in all_records:
        acc = rec["accession"]
        # Also check if goat_assembly_id is in inventory (handles version mismatches partially)
        in_tob = "yes" if acc and acc in tob_accessions else "no"
        # If not found by exact match, try base accession (strip .X version)
        if in_tob == "no" and acc:
            base = acc.rsplit(".", 1)[0]
            for tob_acc in tob_accessions:
                if tob_acc.rsplit(".", 1)[0] == base:
                    in_tob = "yes_version_mismatch"
                    break
        rec["in_tob_inventory"] = in_tob

    # Write main inventory CSV
    fieldnames = [
        "organism", "taxid", "family", "suborder", "project", "assembly_name",
        "status", "accession", "ena_accession", "wgs_accession", "refseq_accession",
        "assembly_span_mb", "contig_n50", "goat_assembly_id", "is_ena_only",
        "in_tob_inventory",
    ]
    with open(OUT_INVENTORY, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_records)
    print("Wrote: {}".format(OUT_INVENTORY), file=sys.stderr)

    # --- Compute diff stats ---
    total = len(all_records)
    with_accession = [r for r in all_records if r["accession"] and r["accession"].startswith("GCA_")]
    in_pipeline = [r for r in all_records if not r["accession"] or not r["accession"].startswith("GCA_")]
    new_to_tob = [r for r in with_accession if r["in_tob_inventory"] == "no"]
    version_mismatch = [r for r in all_records if r["in_tob_inventory"] == "yes_version_mismatch"]
    ena_only = [r for r in all_records if r["is_ena_only"] == "yes"]
    already_in_tob = [r for r in with_accession if r["in_tob_inventory"] in ("yes", "yes_version_mismatch")]

    # Count by suborder and family for new records
    from collections import Counter
    new_by_suborder = Counter(r["suborder"] or "unknown" for r in new_to_tob)
    new_by_family = Counter(r["family"] or "unknown" for r in new_to_tob)
    inpipe_by_suborder = Counter(r["suborder"] or "unknown" for r in in_pipeline)
    inpipe_by_family = Counter(r["family"] or "unknown" for r in in_pipeline)

    # Top new candidates by contig_n50 (chromosomal assemblies first, then by n50)
    def sort_key(r):
        level_score = {"Chromosome": 0, "Scaffold": 1, "Contig": 2}.get(r["status"], 3)
        n50 = r["contig_n50"] if r["contig_n50"] else 0
        return (level_score, -n50)

    top_new = sorted(new_to_tob, key=sort_key)[:20]

    # Project breakdown for new records
    new_by_project = Counter(r["project"] for r in new_to_tob)

    # Write markdown diff report
    lines = [
        "# GoaT Coleoptera Inventory Diff Report",
        "",
        "Generated against GoaT index: `taxon--ncbi--goat--2026.04.20`",
        "TOB inventory: `ncbi_inventory_refresh_2026-05.csv` ({} accessions)".format(len(tob_accessions)),
        "",
        "## Summary Counts",
        "",
        "| Metric | Count |",
        "|--------|-------|",
        "| Total GoaT Coleoptera assembly records | {} |".format(total),
        "| Records with GCA_ accession (assembled) | {} |".format(len(with_accession)),
        "| Records without GCA_ accession (in-pipeline or ENA-only) | {} |".format(len(in_pipeline)),
        "| ENA-only (PRJEB/non-GCA) records | {} |".format(len(ena_only)),
        "| Already in TOB inventory (exact match) | {} |".format(len([r for r in with_accession if r["in_tob_inventory"] == "yes"])),
        "| Already in TOB (version mismatch) | {} |".format(len(version_mismatch)),
        "| **NEW to TOB (GCA_ accession not in inventory)** | **{}** |".format(len(new_to_tob)),
        "",
        "## New Records by Suborder",
        "",
        "| Suborder | New assemblies |",
        "|----------|---------------|",
    ]
    for suborder, count in sorted(new_by_suborder.items(), key=lambda x: -x[1]):
        lines.append("| {} | {} |".format(suborder or "unknown", count))

    lines += [
        "",
        "## New Records by Family (top 20)",
        "",
        "| Family | New assemblies |",
        "|--------|---------------|",
    ]
    for family, count in sorted(new_by_family.items(), key=lambda x: -x[1])[:20]:
        lines.append("| {} | {} |".format(family or "unknown", count))

    lines += [
        "",
        "## In-Pipeline Records by Suborder (no GCA_ yet)",
        "",
        "| Suborder | In-pipeline |",
        "|----------|------------|",
    ]
    for suborder, count in sorted(inpipe_by_suborder.items(), key=lambda x: -x[1]):
        lines.append("| {} | {} |".format(suborder or "unknown", count))

    lines += [
        "",
        "## In-Pipeline Records by Family (top 20)",
        "",
        "| Family | In-pipeline |",
        "|--------|------------|",
    ]
    for family, count in sorted(inpipe_by_family.items(), key=lambda x: -x[1])[:20]:
        lines.append("| {} | {} |".format(family or "unknown", count))

    lines += [
        "",
        "## New Records by Inferred Project",
        "",
        "| Project | New assemblies |",
        "|---------|---------------|",
    ]
    for proj, count in sorted(new_by_project.items(), key=lambda x: -x[1]):
        lines.append("| {} | {} |".format(proj, count))

    lines += [
        "",
        "## ENA-Only Records (need separate ENA query for FASTA)",
        "",
        "These records have non-GCA_ identifiers and may require ENA portal download.",
        "",
    ]
    for r in sorted(ena_only, key=lambda x: x["organism"])[:30]:
        lines.append("- `{}` — {} (GoaT ID: {})".format(
            r["goat_assembly_id"], r["organism"], r["goat_assembly_id"]
        ))
    if len(ena_only) > 30:
        lines.append("- ... and {} more (see goat_coleoptera_inventory.csv)".format(len(ena_only) - 30))

    lines += [
        "",
        "## Top 20 New Candidates (sorted by assembly quality)",
        "",
        "Ranked: Chromosome-level first, then by contig N50 descending.",
        "",
        "| # | Organism | Accession | Status | contig_N50 | Span (Mb) | Family | Project |",
        "|---|----------|-----------|--------|-----------|-----------|--------|---------|",
    ]
    for i, r in enumerate(top_new, 1):
        lines.append("| {} | {} | {} | {} | {:,} | {} | {} | {} |".format(
            i,
            r["organism"],
            r["accession"],
            r["status"],
            r["contig_n50"] if r["contig_n50"] else 0,
            r["assembly_span_mb"],
            r["family"] or "?",
            r["project"],
        ))

    lines += [
        "",
        "## Accessions to Add to Next Pull",
        "",
        "All {} new GCA_ accessions not currently in TOB inventory:".format(len(new_to_tob)),
        "",
    ]
    for r in sorted(new_to_tob, key=lambda x: (x["family"] or "", x["organism"])):
        lines.append("- `{}` — {} ({})".format(r["accession"], r["organism"], r["family"] or "?"))

    lines += [
        "",
        "## Notes",
        "",
        "- Assembly name prefixes used for project inference: ic/il/id/ia/iy=DToL; dr/ds/bge/xb=ERGA; ag/aag=Ag100Pest",
        "- 'unknown' project = no recognized prefix (likely independent submissions or small initiatives)",
        "- Version mismatches ({} records): GoaT accession version differs from TOB; treat as already covered.".format(len(version_mismatch)),
        "- ENA-only records ({} total) require separate ENA portal query to obtain FASTA.".format(len(ena_only)),
    ]

    with open(OUT_DIFF, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("Wrote: {}".format(OUT_DIFF), file=sys.stderr)

    # Print summary to stdout
    print("\n=== SUMMARY ===")
    print("GoaT total records (Coleoptera, assembly_span>0): {}".format(total))
    print("With GCA_ accession: {}".format(len(with_accession)))
    print("In-pipeline (no GCA_): {}".format(len(in_pipeline)))
    print("ENA-only: {}".format(len(ena_only)))
    print("Already in TOB: {}".format(len(already_in_tob)))
    print("NEW to TOB: {}".format(len(new_to_tob)))
    print()
    print("Top 5 new candidates by quality:")
    for i, r in enumerate(top_new[:5], 1):
        print("  {}. {} | {} | {} | N50={:,} | {}Mb | {} | {}".format(
            i, r["organism"], r["accession"], r["status"],
            r["contig_n50"] if r["contig_n50"] else 0,
            r["assembly_span_mb"], r["family"] or "?", r["project"]
        ))


if __name__ == "__main__":
    main()
