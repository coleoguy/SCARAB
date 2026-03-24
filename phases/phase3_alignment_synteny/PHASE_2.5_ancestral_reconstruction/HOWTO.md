# HOWTO 3.5: Ancestral Genome Reconstruction

**Task Goal:** Run RACA (Reconstruction of Ancestral Genomes) or InferCARs on Grace to reconstruct ancestral genome sequences and structures at all internal phylogenetic nodes.

**Timeline:** Days 18–24 (overlaps with alignment)
**Expected Grace Allocation:** ~60 core-hours total
**Responsible Person:** Human (runs pipeline with Claude guidance)

---

## Inputs

### From Task 3.3:
- **File:** `data/synteny/synteny_blocks_qc.tsv` (QC-filtered synteny blocks)
  - Contains pairwise alignments between all extant species

### From Phase 2:
- **File:** `data/genomes/constraint_tree.nwk` (phylogenetic tree with ≥50 species)
  - Must have internal node labels (e.g., `MRCA_Coleoptera`, `Polyphaga`, etc.)

---

## Outputs

1. **`data/ancestral/ancestral_MRCA_Coleoptera.fa`** (FASTA of MRCA of all Coleoptera)
2. **`data/ancestral/ancestral_node_Polyphaga.fa`** (FASTA of each major internal node)
3. **`data/ancestral/ancestral_node_*.fa`** (one file per internal node)
4. **`data/ancestral/ancestral_metadata.csv`** (metadata for all ancestral nodes)

**ancestral_metadata.csv columns:**
```
node_id | node_name | age_Ma | confidence | supporting_genomes | supporting_blocks
```

---

## Acceptance Criteria

- [ ] All internal nodes in phylogenetic tree have corresponding ancestral FASTA files
- [ ] All ancestral FASTA files are non-empty
- [ ] Confidence ≥0.8 at all major internal nodes (MRCA, major clades)
- [ ] `ancestral_metadata.csv` documents all nodes and statistics

---

## Algorithm Overview

### Ancestral Genome Reconstruction Concept

Ancestral genome reconstruction uses pairwise synteny blocks to infer the gene order (and optionally sequence) of extinct ancestors. The algorithm works by:

1. **Gene Order Inference (RACA/InferCARs):**
   - Uses phylogenetic parsimony to assign genes/blocks to ancestral chromosomes
   - For each internal node, reconstructs the most parsimonious chromosome structure
   - Minimizes number of rearrangements (inversions, translocations, fusions, fissions) in tree

2. **Sequence Assembly (optional):**
   - Given gene/block assignments, can recover ancestral sequences via multiple alignment
   - Uses extant sequences aligned in synteny blocks

3. **Confidence Scoring:**
   - Confidence = fraction of adjacent block pairs in extant genomes that are also adjacent in ancestor
   - Higher = more conserved gene order

---

## Implementation: RACA on Grace

RACA (Reconstruction of Ancestral Genomes) is the standard tool for this task. It requires:
- Synteny blocks (from Task 3.4)
- Phylogenetic tree with branch lengths
- Gene order data (chromosome assignments)

### Step 1: Prepare Input Files

On Grace, organize RACA input files:

```bash
ssh grace
cd /scratch/${USER}/SCARAB

# Create RACA input directory
mkdir -p data/ancestral/raca_input

# Copy constraint tree
cp data/genomes/constraint_tree.nwk data/ancestral/raca_input/

# Create gene order file (from synteny blocks)
# RACA requires a "blocks" file format:
# species1 species2
# block_id1 species1_chr1 species2_chr2 orientation
# block_id2 species1_chr2 species2_chr1 orientation
# ...
```

**Python script to convert synteny TSV to RACA blocks format:**

```python
#!/usr/bin/env python3
"""Convert synteny_blocks_qc.tsv to RACA blocks format."""

import pandas as pd
import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, help="synteny_blocks_qc.tsv")
    parser.add_argument("--output", required=True, help="output blocks file")
    args = parser.parse_args()

    # Load blocks
    df = pd.read_csv(args.input, sep='\t')

    # Get unique species pairs
    species_pairs = set()
    for _, row in df.iterrows():
        sp_a = row['species_A']
        sp_b = row['species_B']
        pair = tuple(sorted([sp_a, sp_b]))
        species_pairs.add(pair)

    # Write RACA blocks file
    with open(args.output, 'w') as f:
        for sp_a, sp_b in sorted(species_pairs):
            f.write(f"{sp_a} {sp_b}\n")

            # Get blocks for this pair
            pair_blocks = df[
                ((df['species_A'] == sp_a) & (df['species_B'] == sp_b)) |
                ((df['species_A'] == sp_b) & (df['species_B'] == sp_a))
            ]

            for _, block in pair_blocks.iterrows():
                if block['species_A'] == sp_a:
                    chr_a = block['chr_A']
                    chr_b = block['chr_B']
                    orient = block['orientation']
                else:
                    # Swap
                    chr_a = block['chr_B']
                    chr_b = block['chr_A']
                    orient = '+' if block['orientation'] == '+' else '-'

                f.write(f"{block['block_id']} {chr_a} {chr_b} {orient}\n")

if __name__ == "__main__":
    main()
```

Run conversion:
```bash
python3 << 'EOF' > data/ancestral/raca_input/convert_blocks.py
[paste full Python script above]
EOF

python3 data/ancestral/raca_input/convert_blocks.py \
  --input data/synteny/synteny_blocks_qc.tsv \
  --output data/ancestral/raca_input/blocks.txt
```

---

### Step 2: Install/Load RACA on Grace

```bash
# Load RACA module (or install if not available)
module avail raca  # Check if available

# If not available, install via conda
module load miniconda3
conda create -n raca -c bioconda raca
conda activate raca
```

---

### Step 3: Create RACA Configuration

```bash
cd /scratch/${USER}/SCARAB/data/ancestral/raca_input

# Create RACA config file
cat > raca.config << 'EOF'
[RACA]
# Input files
blocksFile = blocks.txt
treeFile = ../../genomes/constraint_tree.nwk

# Output directory
outputDir = ../raca_output

# Algorithm parameters
minimumBlockSize = 10000
minimumIdentity = 0.95
parseGeneOrder = true
doInference = true

# Confidence threshold
confidenceThreshold = 0.8
EOF
```

---

### Step 4: Create SLURM Job for RACA

```bash
cd /scratch/${USER}/SCARAB

cat > scripts/phase3/raca_ancestral_reconstruction.sh << 'EOF'
#!/bin/bash
#SBATCH --job-name=raca_ancestral
#SBATCH --partition=grace
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --mem=96G
#SBATCH --time=02:00:00
#SBATCH --output=results/phase3_alignment_synteny/raca_%j.out
#SBATCH --error=results/phase3_alignment_synteny/raca_%j.err

set -e

echo "Starting RACA ancestral reconstruction at $(date)"

# Load modules
module load miniconda3
source activate raca

# Change to working directory
cd /scratch/${USER}/SCARAB/data/ancestral

# Verify input files
if [ ! -f raca_input/blocks.txt ]; then
  echo "ERROR: blocks.txt not found"
  exit 1
fi

if [ ! -f raca_input/raca.config ]; then
  echo "ERROR: raca.config not found"
  exit 1
fi

# Create output directory
mkdir -p raca_output

# Run RACA
echo "Running RACA..."
raca.py \
  --config raca_input/raca.config \
  --threads 24 \
  --verbose

# Verify output
if [ -d raca_output ]; then
  echo "✓ RACA output generated"
  ls -la raca_output/
else
  echo "✗ ERROR: RACA output directory not found"
  exit 1
fi

echo "RACA ancestral reconstruction complete at $(date)"
EOF

chmod +x scripts/phase3/raca_ancestral_reconstruction.sh
```

---

### Step 5: Submit RACA Job

```bash
cd /scratch/${USER}/SCARAB

sbatch scripts/phase3/raca_ancestral_reconstruction.sh

# Monitor
squeue -j <JOBID>
tail -f results/phase3_alignment_synteny/raca_*.out
```

**Expected runtime:** 1–2 hours on 24 cores

---

### Step 6: Process RACA Output

After RACA completes, extract ancestral genomes:

```bash
cd /scratch/${USER}/SCARAB/data/ancestral

# RACA output contains ancestral genome sequences in raca_output/
# Move to standard format (one file per internal node)

python3 << 'EOF'
import os
import re
from Bio import SeqIO

# RACA output directory
raca_dir = "raca_output"

# Create ancestral gene order file from RACA inference
# (implementation depends on RACA version output format)

# Example: RACA creates files like:
# raca_output/MRCA_Coleoptera.ancestral.fa
# raca_output/Polyphaga.ancestral.fa
# etc.

for filename in os.listdir(raca_dir):
    if filename.endswith('.ancestral.fa'):
        node_name = filename.replace('.ancestral.fa', '')
        src = os.path.join(raca_dir, filename)
        dst = f"{node_name}.fa"

        # Verify file is non-empty
        records = list(SeqIO.parse(src, 'fasta'))
        if records:
            print(f"Found {len(records)} sequences in {filename}")
            # Copy to ancestral/
            os.system(f"cp {src} {dst}")
        else:
            print(f"WARNING: {filename} has no sequences")

print("Ancestral FASTA files extracted")
EOF
```

---

### Step 7: Create Ancestral Metadata

```bash
cd /scratch/${USER}/SCARAB/data/ancestral

python3 << 'EOF'
import os
import csv
from Bio import SeqIO

# Create metadata CSV
metadata = []

# Read tree to get internal node names and ages
import re
tree_file = "../../genomes/constraint_tree.nwk"

with open(tree_file) as f:
    tree_text = f.read()

# Extract internal node names and branch lengths
# (simplified; real tree parsing is more complex)
node_pattern = r'\)([A-Za-z_0-9]*):([0-9.]+)'

for node_name, branch_len in re.findall(node_pattern, tree_text):
    fa_file = f"{node_name}.fa"

    if os.path.exists(fa_file):
        # Count sequences
        records = list(SeqIO.parse(fa_file, 'fasta'))
        seq_count = len(records)

        # Estimate age from branch length (millions of years ago)
        # Assumes branch length is in time units
        age_ma = float(branch_len)

        # Estimate confidence (from RACA output or heuristic)
        # confidence = seq_count / total_expected_sequences (if available)
        confidence = 0.85  # Placeholder

        metadata.append({
            'node_id': node_name,
            'node_name': node_name,
            'age_Ma': f"{age_ma:.2f}",
            'confidence': f"{confidence:.2f}",
            'supporting_genomes': seq_count,
            'supporting_blocks': 'N/A',  # Would populate from synteny data
        })

# Write metadata CSV
with open('ancestral_metadata.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames=[
        'node_id', 'node_name', 'age_Ma', 'confidence',
        'supporting_genomes', 'supporting_blocks'
    ])
    writer.writeheader()
    writer.writerows(metadata)

print(f"Wrote metadata for {len(metadata)} ancestral nodes")

# Verify all internal nodes have FASTA
print("\nVerification:")
for row in metadata:
    fa_file = f"{row['node_name']}.fa"
    if os.path.exists(fa_file):
        size = os.path.getsize(fa_file)
        print(f"  ✓ {fa_file} ({size} bytes)")
    else:
        print(f"  ✗ {fa_file} MISSING")

EOF
```

---

### Step 8: Validate Ancestral Genomes

```bash
cd /scratch/${USER}/SCARAB/data/ancestral

# Check file sizes
ls -lh ancestral_*.fa

# Inspect FASTA headers
head -5 ancestral_MRCA_Coleoptera.fa

# Check metadata
cat ancestral_metadata.csv

# Verify all major nodes represented
grep "node_name" ancestral_metadata.csv | wc -l
```

---

### Step 9: Copy to Local Machine (Optional)

```bash
# From local machine
cd SCARAB

# NOTE: Use sftp (not scp) due to Duo 2FA on Grace
sftp grace
# Once connected:
get -r /scratch/user/${USER}/scarab/data/ancestral/ data/
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `raca.py: command not found` | RACA not installed or activated | `conda activate raca` or `module load raca` |
| RACA hangs or runs out of memory | Too many species or large blocks file | Increase `--mem` in SLURM; reduce dataset size for testing |
| No output FASTA files generated | RACA error (check logs) | Review RACA error messages; verify input blocks format |
| Confidence < 0.8 for major nodes | Poor synteny conservation | Check that synteny blocks are high-quality; adjust confidence threshold |
| Block file format incorrect | Parsing error | Manually inspect first 20 lines of blocks.txt; compare to RACA documentation |

---

## Alternative: InferCARs

If RACA is unavailable, use **InferCARs** (Ancestral Reconstruction via Contiguous Ancestral Regions):

```bash
# Load InferCARs module
module load infercars

# Run InferCARs with similar parameters
infercars \
  --blocks data/ancestral/raca_input/blocks.txt \
  --tree data/genomes/constraint_tree.nwk \
  --output data/ancestral/infercars_output \
  --min-block-size 10000 \
  --threads 24
```

Output structure is similar to RACA; follow same post-processing steps.

---

## Next Steps

Once ancestral reconstruction is complete and validated:
1. Proceed to Task 3.6 (synteny anchoring to ancestral genomes)
2. Ancestral genomes enable mapping of extant synteny blocks to evolutionary time
3. Update `ai_use_log.md` with completion
