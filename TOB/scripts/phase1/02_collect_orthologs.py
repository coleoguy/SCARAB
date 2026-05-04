#!/usr/bin/env python3
# =============================================================================
# 02_collect_orthologs.py
# =============================================================================
# Collect single-copy BUSCO protein sequences from all per-sample BUSCO
# results and emit one per-locus multi-FASTA file.
#
# Python 3.6-compatible (no f-strings, no walrus, no capture_output).
#
# Usage:
#   python3 02_collect_orthologs.py \
#       <manifest>     -- $SCRATCH/tob/inputs/genome_fnas.txt
#       <busco_root>   -- $SCRATCH/tob/orthologs/busco_results/
#       <per_locus_dir>-- $SCRATCH/tob/orthologs/per_locus/
#
# Output:
#   <per_locus_dir>/{BUSCO_ID}.faa  -- one file per locus, all taxa
#   <per_locus_dir>/../collect_stats.tsv  -- per-sample BUSCO completeness
#
# Label convention:
#   The sequence header in each .faa is >{LABEL}  where LABEL is the
#   per-sample directory name under busco_root (same label assigned by
#   01_busco_array.slurm).
# =============================================================================

import os
import sys
import glob

def derive_label(path):
    """Replicate the label logic from 01_busco_array.slurm."""
    parent = os.path.basename(os.path.dirname(path))
    if parent == "data":
        parent = os.path.basename(
            os.path.dirname(os.path.dirname(path))
        )
    label = parent
    for ext in (".fna", ".fasta", ".fa", ".gz"):
        if label.endswith(ext):
            label = label[:-len(ext)]
    return label


def read_fasta(fasta_path):
    """Return dict {header_without_gt: sequence} from a FASTA file."""
    seqs = {}
    current_header = None
    parts = []
    with open(fasta_path, "r") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith(">"):
                if current_header is not None:
                    seqs[current_header] = "".join(parts)
                current_header = line[1:].split()[0]
                parts = []
            else:
                parts.append(line)
        if current_header is not None:
            seqs[current_header] = "".join(parts)
    return seqs


def main():
    if len(sys.argv) != 4:
        sys.stderr.write(
            "Usage: python3 02_collect_orthologs.py "
            "<manifest> <busco_root> <per_locus_dir>\n"
        )
        sys.exit(1)

    manifest_path = sys.argv[1]
    busco_root    = sys.argv[2]
    per_locus_dir = sys.argv[3]

    os.makedirs(per_locus_dir, exist_ok=True)
    stats_path = os.path.join(os.path.dirname(per_locus_dir), "collect_stats.tsv")

    # Read manifest
    with open(manifest_path, "r") as fh:
        input_paths = [l.strip() for l in fh if l.strip()]

    print("Inputs in manifest: %d" % len(input_paths))

    # {busco_id: {label: protein_seq}}
    locus_dict = {}
    stats_rows = []

    for input_path in input_paths:
        label = derive_label(input_path)
        sample_dir = os.path.join(busco_root, label)

        if not os.path.isdir(sample_dir):
            print("  MISSING busco dir: %s (label=%s)" % (sample_dir, label))
            stats_rows.append("%s\tMISSING\t0\t0\t0" % label)
            continue

        # Locate single-copy protein sequences directory
        # BUSCO 6 layout: run_insecta_odb10/busco_sequences/single_copy_busco_sequences/
        sc_dirs = glob.glob(
            os.path.join(sample_dir, "run_insecta_odb10",
                         "busco_sequences", "single_copy_busco_sequences")
        )
        if not sc_dirs:
            # Fallback for older BUSCO layout
            sc_dirs = glob.glob(
                os.path.join(sample_dir, "run_*",
                             "busco_sequences", "single_copy_busco_sequences")
            )
        if not sc_dirs:
            print("  WARNING: no single_copy dir for %s" % label)
            stats_rows.append("%s\tNO_SC_DIR\t0\t0\t0" % label)
            continue

        sc_dir = sc_dirs[0]
        faa_files = glob.glob(os.path.join(sc_dir, "*.faa"))
        n_sc = len(faa_files)

        # Parse short summary for completeness
        summary_files = glob.glob(
            os.path.join(sample_dir, "short_summary*.txt")
        )
        completeness = "?"
        if summary_files:
            with open(summary_files[0], "r") as sh:
                for line in sh:
                    if "Complete BUSCOs" in line and "%" in line:
                        completeness = line.strip().split()[-1].strip("()")
                        break

        n_collected = 0
        for faa_path in faa_files:
            busco_id = os.path.splitext(os.path.basename(faa_path))[0]
            seqs = read_fasta(faa_path)
            if not seqs:
                continue
            # Take first (and usually only) sequence
            seq = list(seqs.values())[0]
            if busco_id not in locus_dict:
                locus_dict[busco_id] = {}
            locus_dict[busco_id][label] = seq
            n_collected += 1

        print("  %s: %d single-copy BUSCOs  completeness=%s" % (
            label, n_collected, completeness))
        stats_rows.append("%s\t%s\t%d" % (label, completeness, n_collected))

    print("")
    print("Total loci with at least 1 sequence: %d" % len(locus_dict))

    # Write per-locus FASTAs
    n_written = 0
    for busco_id in sorted(locus_dict.keys()):
        out_path = os.path.join(per_locus_dir, "%s.faa" % busco_id)
        with open(out_path, "w") as fh:
            for label in sorted(locus_dict[busco_id].keys()):
                fh.write(">%s\n" % label)
                seq = locus_dict[busco_id][label]
                for i in range(0, len(seq), 80):
                    fh.write(seq[i:i+80] + "\n")
        n_written += 1

    print("Per-locus FASTAs written: %d -> %s" % (n_written, per_locus_dir))

    # Write stats
    with open(stats_path, "w") as fh:
        fh.write("label\tcompleteness\tn_single_copy_buscos\n")
        for row in stats_rows:
            fh.write(row + "\n")
    print("Stats: %s" % stats_path)

    print("DONE.")


if __name__ == "__main__":
    main()
