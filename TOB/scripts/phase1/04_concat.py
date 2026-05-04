#!/usr/bin/env python3
# =============================================================================
# 04_concat.py
# =============================================================================
# Concatenate all trimmed per-locus alignments into a supermatrix.
# Missing taxa for a given locus are gap-filled with '-'.
#
# Python 3.6-compatible (no f-strings, no walrus, no capture_output).
#
# Usage:
#   python3 04_concat.py \
#       <trimmed_dir>      -- $SCRATCH/tob/orthologs/per_locus_trimmed/
#       <supermatrix_out>  -- $SCRATCH/tob/phylogenomics/supermatrix.fasta
#       <partitions_out>   -- $SCRATCH/tob/phylogenomics/partitions.txt
#
# Outputs:
#   supermatrix.fasta  — FASTA, one sequence per taxon across all loci.
#   partitions.txt     — RAxML-format partition file (LG, locus = start-end).
#   concat_stats.txt   — per-locus retained length + occupancy stats.
#
# IQ-TREE note:
#   Missing-taxon positions are '-' (gap), which IQ-TREE treats as unknown
#   amino acid.  For protein models this is correct; do not use '?' here
#   because FASTA protein parsers interpret it inconsistently.
# =============================================================================

import os
import sys
import glob

def read_fasta(path):
    """Return list of (header, sequence) preserving order."""
    records = []
    current_header = None
    parts = []
    with open(path, "r") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith(">"):
                if current_header is not None:
                    records.append((current_header, "".join(parts)))
                current_header = line[1:].split()[0]
                parts = []
            else:
                parts.append(line)
        if current_header is not None:
            records.append((current_header, "".join(parts)))
    return records


def write_fasta(path, records, line_width=80):
    with open(path, "w") as fh:
        for header, seq in records:
            fh.write(">%s\n" % header)
            for i in range(0, len(seq), line_width):
                fh.write(seq[i:i+line_width] + "\n")


def main():
    if len(sys.argv) != 4:
        sys.stderr.write(
            "Usage: python3 04_concat.py "
            "<trimmed_dir> <supermatrix_out> <partitions_out>\n"
        )
        sys.exit(1)

    trimmed_dir    = sys.argv[1]
    supermatrix_out = sys.argv[2]
    partitions_out  = sys.argv[3]

    out_dir = os.path.dirname(supermatrix_out)
    os.makedirs(out_dir, exist_ok=True)
    stats_out = os.path.join(out_dir, "concat_stats.txt")

    trim_files = sorted(glob.glob(os.path.join(trimmed_dir, "*.trim")))
    if not trim_files:
        sys.stderr.write("ERROR: No .trim files found in %s\n" % trimmed_dir)
        sys.exit(1)

    print("Trimmed alignments found: %d" % len(trim_files))

    # Pass 1: collect all taxa and locus data
    all_taxa = set()
    locus_info = []   # list of (locus_name, aln_len, {taxon: seq})

    for i, trim_file in enumerate(trim_files):
        locus_name = os.path.splitext(os.path.basename(trim_file))[0]
        records = read_fasta(trim_file)
        if not records:
            print("  WARNING: %s is empty, skipping" % locus_name)
            continue

        seqs = {}
        for header, seq in records:
            seqs[header] = seq
            all_taxa.add(header)

        # Verify uniform length (should be true post-trimAl)
        lengths = set(len(s) for s in seqs.values())
        if len(lengths) > 1:
            # Use modal length
            from collections import Counter
            modal_len = Counter(len(s) for s in seqs.values()).most_common(1)[0][0]
            fixed = {}
            for t, s in seqs.items():
                if len(s) == modal_len:
                    fixed[t] = s
                elif len(s) > modal_len:
                    fixed[t] = s[:modal_len]
                else:
                    fixed[t] = s + "-" * (modal_len - len(s))
            seqs = fixed
            aln_len = modal_len
            print("  WARNING: %s had mixed lengths, normalised to %d" % (
                locus_name, modal_len))
        else:
            aln_len = lengths.pop()

        if aln_len == 0:
            print("  WARNING: %s has zero-length alignment, skipping" % locus_name)
            continue

        locus_info.append((locus_name, aln_len, seqs))

        if (i + 1) % 100 == 0:
            print("  ... parsed %d / %d loci" % (i + 1, len(trim_files)))

    print("")
    print("Loci retained:    %d" % len(locus_info))
    print("Total taxa found: %d" % len(all_taxa))

    all_taxa_sorted = sorted(all_taxa)

    # Pass 2: build supermatrix
    print("Building supermatrix...")
    taxon_fragments = {t: [] for t in all_taxa_sorted}
    partition_lines = []
    stats_lines = []
    pos = 1

    for locus_name, aln_len, seqs in locus_info:
        gap_str = "-" * aln_len
        n_present = 0
        for t in all_taxa_sorted:
            if t in seqs:
                taxon_fragments[t].append(seqs[t])
                n_present += 1
            else:
                taxon_fragments[t].append(gap_str)
        partition_lines.append(
            "LG, %s = %d-%d" % (locus_name, pos, pos + aln_len - 1)
        )
        stats_lines.append(
            "%s\t%d\t%d\t%.3f" % (
                locus_name, aln_len, n_present,
                float(n_present) / len(all_taxa_sorted)
            )
        )
        pos += aln_len

    total_len = pos - 1
    print("Total supermatrix length: %d aa" % total_len)

    # Write supermatrix
    print("Writing %s ..." % supermatrix_out)
    with open(supermatrix_out, "w") as fh:
        for t in all_taxa_sorted:
            fh.write(">%s\n" % t)
            seq = "".join(taxon_fragments[t])
            for i in range(0, len(seq), 80):
                fh.write(seq[i:i+80] + "\n")

    # Write partitions
    print("Writing %s ..." % partitions_out)
    with open(partitions_out, "w") as fh:
        for line in partition_lines:
            fh.write(line + "\n")

    # Write stats
    with open(stats_out, "w") as fh:
        fh.write("locus\ttrimmed_len\tn_taxa\toccupancy\n")
        for line in stats_lines:
            fh.write(line + "\n")

    print("")
    print("DONE.")
    print("  Supermatrix:  %d taxa x %d aa" % (len(all_taxa_sorted), total_len))
    print("  Partitions:   %d loci -> %s" % (len(partition_lines), partitions_out))
    print("  Stats:        %s" % stats_out)


if __name__ == "__main__":
    main()
