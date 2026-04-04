#!/bin/bash
# ============================================================================
# P5b_build_supermatrix.slurm — Build concatenated supermatrix from alignments
# ============================================================================
#
# Purpose:
#   Concatenate all per-gene MAFFT alignments into a supermatrix FASTA.
#   Gap-fills taxa absent from any locus. Also writes a RAxML-format
#   partitions file for reference.
#
# Prerequisites:
#   P4+P5 complete: per_gene_alignments/*.aln must exist
#
# Output:
#   $PHYLO_DIR/concatenated_supermatrix.fasta  — one sequence per taxon
#   $PHYLO_DIR/partitions.txt                  — LG, locus_N = start-end
#
# Resources: 1 node, 4 cores, 32GB, 4h wall
# ============================================================================

#SBATCH --job-name=scarab_P5b_supermatrix
#SBATCH --partition=medium
#SBATCH --time=4:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=scarab_P5b_supermatrix_%j.log
#SBATCH --error=scarab_P5b_supermatrix_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
ALN_DIR="${PHYLO_DIR}/per_gene_alignments"
SUPERMATRIX="${PHYLO_DIR}/concatenated_supermatrix.fasta"
PARTITIONS="${PHYLO_DIR}/partitions.txt"

echo "============================================================"
echo "SCARAB P.5b -- Build Concatenated Supermatrix"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "============================================================"
echo ""

if [ ! -d "${ALN_DIR}" ]; then
    echo "ERROR: ${ALN_DIR} not found."
    exit 1
fi

N_ALN=$(ls "${ALN_DIR}"/*.aln 2>/dev/null | wc -l)
echo "  Alignment files found: ${N_ALN}"

if [ "${N_ALN}" -eq 0 ]; then
    echo "ERROR: No .aln files found in ${ALN_DIR}"
    exit 1
fi

# Run Python supermatrix builder (Python 3.6 compatible)
python3 - "${ALN_DIR}" "${SUPERMATRIX}" "${PARTITIONS}" << 'PYEOF'
import sys
import os
import glob

aln_dir = sys.argv[1]
supermatrix_path = sys.argv[2]
partitions_path = sys.argv[3]

aln_files = sorted(glob.glob(os.path.join(aln_dir, "*.aln")))
print("  Parsing %d alignment files..." % len(aln_files))

# Pass 1: collect all taxa and alignment lengths
all_taxa = set()
locus_info = []  # list of (locus_name, length, {taxon: seq})

for i, aln_file in enumerate(aln_files):
    locus_name = os.path.splitext(os.path.basename(aln_file))[0]
    seqs = {}
    current_taxon = None
    current_seq_parts = []

    with open(aln_file) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('>'):
                if current_taxon is not None:
                    seqs[current_taxon] = ''.join(current_seq_parts)
                current_taxon = line[1:].split()[0]
                current_seq_parts = []
            else:
                current_seq_parts.append(line)
        if current_taxon is not None:
            seqs[current_taxon] = ''.join(current_seq_parts)

    if not seqs:
        print("  WARNING: %s has no sequences, skipping" % locus_name)
        continue

    # All sequences in a locus must be same length (it's an alignment)
    lengths = set(len(s) for s in seqs.values())
    if len(lengths) > 1:
        # Use most common length
        from collections import Counter
        length_counts = Counter(len(s) for s in seqs.values())
        aln_len = length_counts.most_common(1)[0][0]
        print("  WARNING: %s has mixed lengths %s, using %d" % (locus_name, lengths, aln_len))
        # Trim/pad to aln_len
        fixed = {}
        for t, s in seqs.items():
            if len(s) == aln_len:
                fixed[t] = s
            elif len(s) > aln_len:
                fixed[t] = s[:aln_len]
            else:
                fixed[t] = s + '-' * (aln_len - len(s))
        seqs = fixed
    else:
        aln_len = lengths.pop()

    all_taxa.update(seqs.keys())
    locus_info.append((locus_name, aln_len, seqs))

    if (i + 1) % 100 == 0:
        print("  ... processed %d / %d loci" % (i + 1, len(aln_files)))

print("  Loci retained: %d" % len(locus_info))
print("  Total taxa: %d" % len(all_taxa))

all_taxa_sorted = sorted(all_taxa)

# Pass 2: concatenate
print("  Building supermatrix...")
# Build full sequences in memory: taxon -> list of seq fragments
taxon_seqs = {t: [] for t in all_taxa_sorted}

pos = 1
partitions_lines = []

for locus_name, aln_len, seqs in locus_info:
    gap_str = '-' * aln_len
    for t in all_taxa_sorted:
        taxon_seqs[t].append(seqs.get(t, gap_str))
    partitions_lines.append("LG, %s = %d-%d" % (locus_name, pos, pos + aln_len - 1))
    pos += aln_len

total_len = pos - 1
print("  Total alignment length: %d bp" % total_len)

# Write supermatrix
print("  Writing %s ..." % supermatrix_path)
with open(supermatrix_path, 'w') as f:
    for t in all_taxa_sorted:
        f.write('>%s\n' % t)
        seq = ''.join(taxon_seqs[t])
        # Write in 80-char lines
        for j in range(0, len(seq), 80):
            f.write(seq[j:j+80] + '\n')

print("  Writing %s ..." % partitions_path)
with open(partitions_path, 'w') as f:
    for line in partitions_lines:
        f.write(line + '\n')

print("")
print("  DONE.")
print("  Supermatrix: %d taxa x %d bp" % (len(all_taxa_sorted), total_len))
print("  Partitions: %d loci" % len(partitions_lines))
PYEOF

# Verify output
N_TAXA=$(grep -c "^>" "${SUPERMATRIX}")
N_PARTS=$(wc -l < "${PARTITIONS}")
FSIZE=$(du -sh "${SUPERMATRIX}" | cut -f1)

echo ""
echo "============================================================"
echo "P.5b COMPLETE"
echo "============================================================"
echo "  Supermatrix: ${SUPERMATRIX}"
echo "  Taxa: ${N_TAXA}"
echo "  Partitions: ${N_PARTS} loci"
echo "  File size: ${FSIZE}"
echo ""
echo "NEXT STEPS:"
echo "  sbatch P6_astral_species_tree.slurm"
echo "  sbatch P7_concat_iqtree.slurm"
echo "============================================================"
echo "Finished: $(date)"
