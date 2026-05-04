#!/usr/bin/env python3
"""
05_concat_per_family.py -- Concatenate per-locus alignments into per-family
supermatrices with RAxML-format partition files.

For each family in $SCRATCH/tob/alignments/:
  - Reads all {LOCUS}.trim.fasta files
  - Applies 30% occupancy filter: drops taxa present in <30% of loci
  - Concatenates retained taxa into a supermatrix FASTA
  - Writes RAxML partition file (DNA, one block per locus)
  - Writes a summary TSV: taxa count, locus count, occupancy stats

Python 3.6 compatible: no f-strings, no walrus, no pathlib.join tricks.

Usage:
    python 05_concat_per_family.py

Outputs per family (in $SCRATCH/tob/supermatrices/{FAMILY}/):
    supermatrix.fasta       - concatenated alignment
    partitions.txt          - RAxML partition file
    occupancy.tsv           - per-taxon occupancy table
    summary.tsv             - family-level summary
"""

import os
import sys
import csv
import glob

# --- Configuration ---
SCRATCH_TOB = os.path.join(os.environ.get("SCRATCH", "/scratch/user/blackmon"), "tob")
ALN_DIR = os.path.join(SCRATCH_TOB, "alignments")
OUT_DIR = os.path.join(SCRATCH_TOB, "supermatrices")
LOG_FILE = os.path.join(SCRATCH_TOB, "logs", "05_concat.log")
OCCUPANCY_MIN = 0.30  # 30% per workflow_v1.md locked decision
LOCI_ORDER = ["COI", "16S", "18S", "28S", "CAD", "EF1a", "ArgK", "RNApol2", "wingless"]

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(os.path.join(SCRATCH_TOB, "logs"), exist_ok=True)


def read_fasta(path):
    """Returns dict of {seq_id: sequence_string}. No Biopython to keep it lean."""
    seqs = {}
    current_id = None
    current_seq = []
    with open(path, "r") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith(">"):
                if current_id is not None:
                    seqs[current_id] = "".join(current_seq)
                current_id = line[1:].split()[0]
                current_seq = []
            else:
                current_seq.append(line)
        if current_id is not None:
            seqs[current_id] = "".join(current_seq)
    return seqs


def write_fasta(seqs, path):
    with open(path, "w") as fh:
        for sid, seq in sorted(seqs.items()):
            fh.write(">" + sid + "\n")
            fh.write(seq + "\n")


def process_family(family_dir, family_name, log_fh):
    """Build supermatrix for one family. Returns summary dict or None if skipped."""
    # Collect available loci
    locus_seqs = {}   # {locus: {taxon: seq}}
    locus_len = {}    # {locus: alignment_length}

    for locus in LOCI_ORDER:
        fasta_path = os.path.join(family_dir, locus + ".trim.fasta")
        if not os.path.isfile(fasta_path) or os.path.getsize(fasta_path) == 0:
            continue
        seqs = read_fasta(fasta_path)
        if len(seqs) == 0:
            continue
        # All seqs in an alignment should be same length; take first
        lengths = set(len(s) for s in seqs.values())
        if len(lengths) > 1:
            log_fh.write("WARNING: unequal lengths in {}/{}.trim.fasta\n".format(
                family_name, locus))
        locus_seqs[locus] = seqs
        locus_len[locus] = max(lengths)

    if not locus_seqs:
        log_fh.write("SKIP {}: no trimmed alignments\n".format(family_name))
        return None

    # All taxa across all loci
    all_taxa = set()
    for seqs in locus_seqs.values():
        all_taxa.update(seqs.keys())

    n_loci = len(locus_seqs)

    # Compute per-taxon occupancy (fraction of loci present)
    taxon_presence = {}
    for taxon in all_taxa:
        count = sum(1 for seqs in locus_seqs.values() if taxon in seqs)
        taxon_presence[taxon] = float(count) / float(n_loci)

    # Apply 30% occupancy filter
    retained_taxa = [t for t, occ in taxon_presence.items()
                     if occ >= OCCUPANCY_MIN]
    dropped_taxa = [t for t, occ in taxon_presence.items()
                    if occ < OCCUPANCY_MIN]

    if len(retained_taxa) < 4:
        log_fh.write("SKIP {}: only {} taxa after occupancy filter (need >=4)\n".format(
            family_name, len(retained_taxa)))
        return None

    # Build concatenated supermatrix
    # Gap character for missing locus data
    concat = {taxon: [] for taxon in retained_taxa}
    partition_rows = []
    pos = 1

    for locus in LOCI_ORDER:
        if locus not in locus_seqs:
            continue
        seqs = locus_seqs[locus]
        aln_len = locus_len[locus]
        gap_block = "-" * aln_len

        for taxon in retained_taxa:
            if taxon in seqs:
                concat[taxon].append(seqs[taxon])
            else:
                concat[taxon].append(gap_block)

        end = pos + aln_len - 1
        partition_rows.append("DNA, {} = {}-{}".format(locus, pos, end))
        pos = end + 1

    # Finalize sequences
    final_seqs = {}
    for taxon in retained_taxa:
        final_seqs[taxon] = "".join(concat[taxon])

    # Write outputs
    fam_outdir = os.path.join(OUT_DIR, family_name)
    os.makedirs(fam_outdir, exist_ok=True)

    write_fasta(final_seqs, os.path.join(fam_outdir, "supermatrix.fasta"))

    with open(os.path.join(fam_outdir, "partitions.txt"), "w") as fh:
        for row in partition_rows:
            fh.write(row + "\n")

    # Occupancy table
    with open(os.path.join(fam_outdir, "occupancy.tsv"), "w") as fh:
        fh.write("taxon\tloci_present\tn_loci\toccupancy\tstatus\n")
        for taxon in sorted(all_taxa):
            count = sum(1 for seqs in locus_seqs.values() if taxon in seqs)
            occ = taxon_presence[taxon]
            status = "retained" if taxon in retained_taxa else "dropped"
            fh.write("{}\t{}\t{}\t{:.3f}\t{}\n".format(
                taxon, count, n_loci, occ, status))

    total_len = sum(locus_len[l] for l in LOCI_ORDER if l in locus_len)
    summary = {
        "family": family_name,
        "n_loci": n_loci,
        "n_taxa_retained": len(retained_taxa),
        "n_taxa_dropped": len(dropped_taxa),
        "supermatrix_length": total_len,
        "status": "ok"
    }
    log_fh.write("OK {}: {} taxa retained, {} dropped, {} loci, {} cols\n".format(
        family_name, len(retained_taxa), len(dropped_taxa), n_loci, total_len))
    return summary


def main():
    if not os.path.isdir(ALN_DIR):
        sys.stderr.write("ERROR: alignment directory not found: {}\n".format(ALN_DIR))
        sys.exit(1)

    families = sorted(os.listdir(ALN_DIR))
    summaries = []

    with open(LOG_FILE, "w") as log_fh:
        for family_name in families:
            family_dir = os.path.join(ALN_DIR, family_name)
            if not os.path.isdir(family_dir):
                continue
            summary = process_family(family_dir, family_name, log_fh)
            if summary is not None:
                summaries.append(summary)

    # Write global summary
    summary_path = os.path.join(SCRATCH_TOB, "supermatrices", "summary_all_families.tsv")
    with open(summary_path, "w") as fh:
        writer = csv.DictWriter(fh, fieldnames=[
            "family", "n_loci", "n_taxa_retained", "n_taxa_dropped",
            "supermatrix_length", "status"],
            delimiter="\t")
        writer.writeheader()
        for row in summaries:
            writer.writerow(row)

    print("Processed {} families.".format(len(summaries)))
    print("Summary: {}".format(summary_path))
    print("Log: {}".format(LOG_FILE))


if __name__ == "__main__":
    main()
