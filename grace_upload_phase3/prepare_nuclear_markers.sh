#!/bin/bash
# ============================================================================
# prepare_nuclear_markers.sh — Download BUSCO insecta marker genes for
# multi-locus nuclear guide tree construction
# ============================================================================
#
# Run on Grace LOGIN NODE (requires internet access — compute nodes don't
# have internet).
#
# This script:
#   1. Downloads the BUSCO insecta_odb10 lineage dataset (~130 MB)
#   2. Extracts conserved single-copy reference protein sequences
#   3. Selects the 15 longest genes (most phylogenetic signal)
#   4. Writes marker_proteins.fasta for use by the SLURM tree-building job
#
# Why BUSCO genes instead of COI?
#   COI is mitochondrial. Many genome assemblies are nuclear-only, so BLAST
#   found COI in only 182/439 genomes (41%). BUSCO genes are nuclear,
#   single-copy, and universally conserved — expected hit rate >95%.
#
# Output:
#   $SCRATCH/scarab/nuclear_markers/marker_proteins.fasta  (15 reference proteins)
#   $SCRATCH/scarab/nuclear_markers/marker_genes.tsv       (gene metadata)
#
# Usage:
#   bash prepare_nuclear_markers.sh
#
# After this completes, submit the SLURM job:
#   sbatch extract_nuclear_markers_and_build_tree.slurm
# ============================================================================

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
MARKER_DIR="${PROJECT_DIR}/nuclear_markers"
N_MARKERS=15

echo "============================================================"
echo "SCARAB — Prepare Nuclear Marker Genes for Guide Tree"
echo "Started: $(date)"
echo "============================================================"
echo ""

# ============================================================================
# 1. DOWNLOAD BUSCO INSECTA LINEAGE DATA
# ============================================================================

mkdir -p "$MARKER_DIR"
cd "$MARKER_DIR"

if [ -f "marker_proteins.fasta" ] && [ $(grep -c "^>" "marker_proteins.fasta") -ge "$N_MARKERS" ]; then
    echo "marker_proteins.fasta already exists with $(grep -c '^>' marker_proteins.fasta) sequences."
    echo "Delete it to re-download. Exiting."
    exit 0
fi

echo "[1/3] Downloading BUSCO insecta_odb10 lineage data..."

# Try multiple URLs (the date suffix changes between BUSCO releases)
DOWNLOADED=false
for URL in \
    "https://busco-data.ezlab.org/v5/data/lineages/insecta_odb10.2024-01-08.tar.gz" \
    "https://busco-data.ezlab.org/v5/data/lineages/insecta_odb10.2020-09-10.tar.gz" \
    "https://busco-data.ezlab.org/v5/data/lineages/insecta_odb10.tar.gz"; do
    echo "  Trying: $URL"
    if wget -q --timeout=30 "$URL" -O insecta_odb10.tar.gz 2>/dev/null; then
        DOWNLOADED=true
        echo "  Download successful."
        break
    fi
done

if [ "$DOWNLOADED" = false ]; then
    # Try to find URL from directory listing
    echo "  Direct URLs failed. Checking BUSCO data server index..."
    LISTING=$(wget -q -O - "https://busco-data.ezlab.org/v5/data/lineages/" 2>/dev/null || true)
    URL=$(echo "$LISTING" | grep -oP 'href="(insecta_odb10[^"]*\.tar\.gz)"' | head -1 | grep -oP '"[^"]*"' | tr -d '"')
    if [ -n "$URL" ]; then
        echo "  Found: $URL"
        wget -q "https://busco-data.ezlab.org/v5/data/lineages/$URL" -O insecta_odb10.tar.gz
        DOWNLOADED=true
    fi
fi

if [ "$DOWNLOADED" = false ]; then
    echo ""
    echo "ERROR: Could not download BUSCO insecta_odb10 data."
    echo "Please download manually from https://busco-data.ezlab.org/v5/data/lineages/"
    echo "and place insecta_odb10.tar.gz in: $MARKER_DIR/"
    exit 1
fi

echo "  Extracting..."
tar xzf insecta_odb10.tar.gz
echo ""

# Find the extracted directory (name varies by version)
BUSCO_DIR=$(find . -maxdepth 1 -type d -name "insecta_odb10*" | head -1)
if [ -z "$BUSCO_DIR" ]; then
    echo "ERROR: Extraction produced no insecta_odb10* directory."
    echo "Contents of $MARKER_DIR:"
    ls -la
    exit 1
fi
echo "  BUSCO data directory: $BUSCO_DIR"

# ============================================================================
# 2. EXTRACT REFERENCE PROTEIN SEQUENCES
# ============================================================================

echo "[2/3] Extracting reference protein sequences..."

python3 - "$BUSCO_DIR" "$N_MARKERS" "$MARKER_DIR" << 'PYEOF'
import sys, os, re
from collections import defaultdict

busco_dir = sys.argv[1]
n_markers = int(sys.argv[2])
output_dir = sys.argv[3]

# --- Strategy A: Use ancestral sequences (one per gene, ideal) ---
ancestral_file = os.path.join(busco_dir, "ancestral")
ancestral_variants = os.path.join(busco_dir, "ancestral_variants")

# --- Strategy B: Use refseq_db.faa + ogs.id.info (multiple seqs per gene) ---
refseq_file = None
for name in ["refseq_db.faa", "refseq_db.fasta"]:
    path = os.path.join(busco_dir, name)
    if os.path.exists(path):
        refseq_file = path
        break

info_file = os.path.join(busco_dir, "info", "ogs.id.info")

# --- Strategy C: Use HMM consensus (last resort) ---
hmm_dir = os.path.join(busco_dir, "hmms")

# Try lengths_cutoff for expected lengths
lengths_file = os.path.join(busco_dir, "lengths_cutoff")
expected_lengths = {}
if os.path.exists(lengths_file):
    with open(lengths_file) as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 3:
                og_id = parts[0]
                try:
                    # Format varies: some have OG_ID mean sd, others OG_ID sd mean
                    vals = [float(x) for x in parts[1:]]
                    expected_lengths[og_id] = max(vals)  # use the larger value as proxy for length
                except ValueError:
                    continue
    print(f"  lengths_cutoff: {len(expected_lengths)} genes with expected lengths")

# ---- Try Strategy A first ----
gene_seqs = {}  # og_id -> protein_sequence

if os.path.exists(ancestral_file) and os.path.getsize(ancestral_file) > 100:
    print(f"  Using ancestral sequences from: {ancestral_file}")
    current_id = None
    current_seq = []
    with open(ancestral_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if current_id and current_seq:
                    gene_seqs[current_id] = "".join(current_seq)
                current_id = line[1:].split()[0]
                current_seq = []
            elif line:
                current_seq.append(line)
    if current_id and current_seq:
        gene_seqs[current_id] = "".join(current_seq)
    print(f"  Found {len(gene_seqs)} ancestral sequences")

elif os.path.exists(ancestral_variants) and os.path.getsize(ancestral_variants) > 100:
    print(f"  Using ancestral_variants from: {ancestral_variants}")
    current_id = None
    current_seq = []
    with open(ancestral_variants) as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if current_id and current_seq:
                    gene_seqs[current_id] = "".join(current_seq)
                current_id = line[1:].split()[0]
                current_seq = []
            elif line:
                current_seq.append(line)
    if current_id and current_seq:
        gene_seqs[current_id] = "".join(current_seq)
    print(f"  Found {len(gene_seqs)} ancestral variant sequences")

# ---- Try Strategy B if A didn't work ----
if len(gene_seqs) < n_markers and refseq_file and os.path.exists(info_file):
    print(f"  Using refseq_db + ogs.id.info mapping")

    # Parse OG mapping: seq_id -> og_id
    seq_to_og = {}
    with open(info_file) as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 2:
                seq_to_og[parts[1]] = parts[0]
            elif len(parts) >= 2:
                # Try space-separated
                parts = line.strip().split()
                if len(parts) >= 2:
                    seq_to_og[parts[1]] = parts[0]

    print(f"  OG mapping: {len(seq_to_og)} sequences -> OGs")

    # Parse refseq_db.faa
    og_sequences = defaultdict(list)  # og_id -> [(seq_id, sequence)]
    current_id = None
    current_seq = []
    with open(refseq_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if current_id and current_seq:
                    seq = "".join(current_seq)
                    og = seq_to_og.get(current_id)
                    if og:
                        og_sequences[og].append((current_id, seq))
                current_id = line[1:].split()[0]
                current_seq = []
            elif line:
                current_seq.append(line)
    if current_id and current_seq:
        seq = "".join(current_seq)
        og = seq_to_og.get(current_id)
        if og:
            og_sequences[og].append((current_id, seq))

    print(f"  Reference sequences grouped into {len(og_sequences)} OGs")

    # For each OG, pick the longest sequence as representative
    for og_id, seqs in og_sequences.items():
        if og_id not in gene_seqs:
            longest = max(seqs, key=lambda x: len(x[1]))
            gene_seqs[og_id] = longest[1]

    print(f"  Total gene representatives: {len(gene_seqs)}")

# ---- Check we have enough ----
if len(gene_seqs) < n_markers:
    print(f"\n  ERROR: Only found {len(gene_seqs)} gene sequences, need {n_markers}.")
    print(f"  BUSCO directory contents:")
    for item in sorted(os.listdir(busco_dir)):
        path = os.path.join(busco_dir, item)
        size = os.path.getsize(path) if os.path.isfile(path) else "dir"
        print(f"    {item}  ({size})")
    sys.exit(1)

# ---- Select top N by sequence length ----
# Longer proteins = more phylogenetic signal
sorted_genes = sorted(gene_seqs.items(), key=lambda x: len(x[1]), reverse=True)
selected = sorted_genes[:n_markers]

print(f"\n  Selected {n_markers} marker genes:")
print(f"  {'Gene_ID':<25s} {'Length (aa)':>12s}")
print(f"  {'-'*25} {'-'*12}")

# Write marker_proteins.fasta
fasta_path = os.path.join(output_dir, "marker_proteins.fasta")
tsv_path = os.path.join(output_dir, "marker_genes.tsv")

with open(fasta_path, "w") as fasta_out, open(tsv_path, "w") as tsv_out:
    tsv_out.write("gene_id\tlength_aa\texpected_length\n")
    for og_id, seq in selected:
        # Clean sequence: remove gaps, stops, whitespace
        seq_clean = re.sub(r'[\s\-\*\.]', '', seq)
        print(f"  {og_id:<25s} {len(seq_clean):>12d}")
        fasta_out.write(f">{og_id}\n{seq_clean}\n")
        exp_len = expected_lengths.get(og_id, "NA")
        tsv_out.write(f"{og_id}\t{len(seq_clean)}\t{exp_len}\n")

print(f"\n  Written: {fasta_path}")
print(f"  Written: {tsv_path}")
PYEOF

echo ""

# ============================================================================
# 3. VERIFY AND CLEAN UP
# ============================================================================

echo "[3/3] Verifying output..."

N_SEQS=$(grep -c "^>" "$MARKER_DIR/marker_proteins.fasta" || true)
if [ "$N_SEQS" -ge "$N_MARKERS" ]; then
    echo "  marker_proteins.fasta: ${N_SEQS} protein sequences — OK"
else
    echo "  ERROR: Only ${N_SEQS} sequences in marker_proteins.fasta (need ${N_MARKERS})"
    exit 1
fi

# Clean up tarball (keep extracted data for reference)
rm -f insecta_odb10.tar.gz

echo ""
echo "============================================================"
echo "NUCLEAR MARKERS READY"
echo "============================================================"
echo ""
echo "  Markers:  $MARKER_DIR/marker_proteins.fasta"
echo "  Metadata: $MARKER_DIR/marker_genes.tsv"
echo ""
echo "NEXT STEP:"
echo "  sbatch extract_nuclear_markers_and_build_tree.slurm"
echo ""
echo "Finished: $(date)"
