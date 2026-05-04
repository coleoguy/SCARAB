#!/bin/bash
# ============================================================================
# 08_bacoca.slurm — Compositional bias check on a 50-locus subsample
# ============================================================================
#
# Purpose:
#   Detect base-composition heterogeneity across taxa using BaCoCa
#   (Kocot et al. 2013) on a random 50-locus subsample of the trimmed
#   per-locus alignments.  Per workflow_v1.md notes/08: insect mega-trees
#   are historically burned by base-composition bias; this is a mandatory
#   pre-approval check before locking the backbone.
#
# Fallback:
#   If BaCoCa is unavailable on Grace (no module found), the script falls
#   back to an IQ-TREE GHOST (heterotachy + compositional) test using
#   --test-only on the 50-locus subsample.
#
# Prerequisites:
#   03_filter_align.slurm complete: per_locus_trimmed/*.trim exist.
#
# Resources: short partition, 4 cores, 16 GB, 2 h.
#
# Usage:
#   sbatch 08_bacoca.slurm
#
# TODO (Heath): Confirm whether BaCoCa has been installed to a shared location
#   on Grace (e.g. ~/bin/bacoca.pl) or whether the Conda fallback should be
#   the primary path.  BaCoCa is a Perl script; load GCCcore and check.
# ============================================================================

#SBATCH --job-name=tob_bacoca
#SBATCH --partition=short
#SBATCH --time=2:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=/scratch/user/blackmon/tob/logs/bacoca_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/bacoca_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TOB="${SCRATCH}/tob"
TRIM_DIR="${TOB}/orthologs/per_locus_trimmed"
OUT_DIR="${TOB}/phylogenomics/bacoca"
SUBSAMPLE_N=50
NCPUS=${SLURM_CPUS_PER_TASK:-4}
SEED=42

# BaCoCa script location — set if installed manually
# TODO: confirm correct path with Heath.
BACOCA_SCRIPT="${HOME}/bin/BaCoCa.pl"

mkdir -p "${OUT_DIR}/subsample_alns" "${TOB}/logs"

echo "============================================================"
echo "TOB Phase 1 -- Compositional Bias (BaCoCa / IQ-TREE GHOST)"
echo "Job: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "============================================================"
echo ""

# ============================================================================
# 1. SUBSAMPLE 50 LOCI RANDOMLY
# ============================================================================

echo "[1] Subsampling ${SUBSAMPLE_N} loci from ${TRIM_DIR}..."

TRIM_FILES=($(ls "${TRIM_DIR}"/*.trim 2>/dev/null))
N_TOTAL=${#TRIM_FILES[@]}
echo "    Total trimmed loci: ${N_TOTAL}"

if [ "${N_TOTAL}" -lt "${SUBSAMPLE_N}" ]; then
    echo "    WARNING: fewer than ${SUBSAMPLE_N} loci available; using all ${N_TOTAL}."
    SUBSAMPLE_N="${N_TOTAL}"
fi

# Reproducible random subsample using python3 (no shuf on older HPC)
python3 - "${TRIM_DIR}" "${OUT_DIR}/subsample_alns" "${SUBSAMPLE_N}" "${SEED}" << 'PYEOF'
import os
import sys
import glob
import random

trim_dir     = sys.argv[1]
out_dir      = sys.argv[2]
n_sub        = int(sys.argv[3])
seed         = int(sys.argv[4])

files = sorted(glob.glob(os.path.join(trim_dir, "*.trim")))
random.seed(seed)
chosen = random.sample(files, min(n_sub, len(files)))

for src in chosen:
    dst = os.path.join(out_dir, os.path.basename(src))
    with open(src, "r") as fh_in, open(dst, "w") as fh_out:
        fh_out.write(fh_in.read())

print("  Subsample written: %d files -> %s" % (len(chosen), out_dir))
PYEOF

echo ""

# ============================================================================
# 2. CONCATENATE SUBSAMPLE FOR BaCoCa / GHOST
# ============================================================================

echo "[2] Concatenating subsample..."
SUBSAMPLE_SUPER="${OUT_DIR}/subsample_supermatrix.fasta"
python3 /dev/stdin "${OUT_DIR}/subsample_alns" "${SUBSAMPLE_SUPER}" << 'PYEOF2'
import os
import sys
import glob

trim_dir = sys.argv[1]
out_path = sys.argv[2]

files = sorted(glob.glob(os.path.join(trim_dir, "*.trim")))
all_taxa = set()
loci = []
for f in files:
    seqs = {}
    cur_header = None
    parts = []
    with open(f, "r") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith(">"):
                if cur_header:
                    seqs[cur_header] = "".join(parts)
                cur_header = line[1:].split()[0]
                parts = []
            else:
                parts.append(line)
        if cur_header:
            seqs[cur_header] = "".join(parts)
    if not seqs:
        continue
    aln_len = max(len(s) for s in seqs.values())
    all_taxa.update(seqs.keys())
    loci.append((aln_len, seqs))

all_taxa_sorted = sorted(all_taxa)
taxon_frags = {t: [] for t in all_taxa_sorted}
for aln_len, seqs in loci:
    gap = "-" * aln_len
    for t in all_taxa_sorted:
        taxon_frags[t].append(seqs.get(t, gap))

with open(out_path, "w") as fh:
    for t in all_taxa_sorted:
        fh.write(">%s\n" % t)
        seq = "".join(taxon_frags[t])
        for i in range(0, len(seq), 80):
            fh.write(seq[i:i+80] + "\n")

print("  Subsample supermatrix: %d taxa x %d aa -> %s" % (
    len(all_taxa_sorted), sum(l for l, _ in loci), out_path))
PYEOF2

echo ""

# ============================================================================
# 3A. TRY BACOCA
# ============================================================================

BACOCA_RAN=0

if [ -f "${BACOCA_SCRIPT}" ]; then
    echo "[3A] Running BaCoCa..."
    module load GCCcore/12.3.0  # Perl is available after this

    # BaCoCa requires individual alignment files, not a concatenation.
    # Run on the subsample_alns/ directory.
    perl "${BACOCA_SCRIPT}" \
        -i "${OUT_DIR}/subsample_alns/" \
        -o "${OUT_DIR}/bacoca_output" \
        2>&1 | tail -30

    BACOCA_RAN=1
    echo "    BaCoCa output: ${OUT_DIR}/bacoca_output/"
else
    echo "[3A] BaCoCa script not found at ${BACOCA_SCRIPT} — skipping BaCoCa."
    echo "    TODO: Install BaCoCa (download from https://github.com/AlexKnyshov/BaCoCa)"
    echo "    or provide the correct path in BACOCA_SCRIPT."
fi

# ============================================================================
# 3B. IQ-TREE GHOST FALLBACK (or supplementary)
# ============================================================================

echo ""
echo "[3B] IQ-TREE GHOST compositional heterogeneity test..."

module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

# GHOST (General Heterogeneous Evolution On a Single Topology) uses
# mixture of rates + substitution processes to detect heterotachy and
# compositional heterogeneity.
# --test-only applies to an existing tree if available.

CONCAT_TREE="${TOB}/phylogenomics/concat_iqtree/concat.treefile"

GHOST_ARGS="-s ${SUBSAMPLE_SUPER} --prefix ${OUT_DIR}/ghost -m LG+C20+F+G4 --nt ${NCPUS}"

if [ -f "${CONCAT_TREE}" ]; then
    GHOST_ARGS="${GHOST_ARGS} -te ${CONCAT_TREE}"
    echo "    Using fixed topology: ${CONCAT_TREE}"
fi

iqtree2 ${GHOST_ARGS} 2>&1 | tail -20

echo ""
echo "============================================================"
echo "COMPOSITIONAL BIAS CHECK COMPLETE"
echo "  Subsample:          ${SUBSAMPLE_N} loci"
echo "  Subsample matrix:   ${SUBSAMPLE_SUPER}"
if [ "${BACOCA_RAN}" -eq 1 ]; then
echo "  BaCoCa output:      ${OUT_DIR}/bacoca_output/"
fi
echo "  GHOST output:       ${OUT_DIR}/ghost.iqtree"
echo ""
echo "ACTION REQUIRED:"
echo "  Review BaCoCa RCV values and GHOST log-likelihood table."
echo "  Flag any taxa with extreme base composition for Heath's review"
echo "  before approving Phase 2 submission."
echo "============================================================"
echo "Finished: $(date)"
