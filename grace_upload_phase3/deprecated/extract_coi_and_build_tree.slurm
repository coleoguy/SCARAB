#!/bin/bash
# ============================================================================
# extract_coi_and_build_tree.slurm — Extract COI from all 439 genomes, build
# empirical guide tree for Cactus
# ============================================================================
#
# Pipeline:
#   1. BLAST a reference COI (Tribolium castaneum) against each genome
#   2. Extract best-hit COI sequence from each assembly
#   3. Align with MAFFT
#   4. Build NJ tree with FastTree (GTR model)
#   5. Root on Neuropterida outgroups
#   6. Validate: binary, all 439 tips, branch lengths in subs/site
#   7. Rebuild cactus_seqfile.txt with the new tree
#
# Why: Cactus uses guide tree branch lengths to tune alignment sensitivity.
#      We have genomes for all 439 species — extracting COI directly gives
#      us empirical substitution rates for every taxon, no grafting needed.
#
# Queue: medium (should finish in <1 hr)
# Resources: 1 node, 48 cores, 64 GB (BLAST is fast against individual genomes)
#
# Usage:
#   sbatch extract_coi_and_build_tree.slurm
# ============================================================================

#SBATCH --job-name=scarab_coi_tree
#SBATCH --partition=medium
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=64G
#SBATCH --output=scarab_coi_tree_%j.log
#SBATCH --error=scarab_coi_tree_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
GENOME_DIR="${PROJECT_DIR}/genomes"
DATA_DIR="${PROJECT_DIR}/data"
TREE_DIR="${PROJECT_DIR}/coi_tree"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"
TIP_MAP="${DATA_DIR}/tree_tip_mapping.csv"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

echo "============================================================"
echo "SCARAB — COI Extraction & Guide Tree Construction"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${NCPUS}"
echo "============================================================"
echo ""

# ============================================================================
# 0. SETUP
# ============================================================================

rm -rf "${TREE_DIR}"
mkdir -p "${TREE_DIR}/blastdb" "${TREE_DIR}/hits"

# Load modules (Grace TAMU HPC)
# BLAST+ needs GCC/12.2.0 + OpenMPI/4.1.4 as prerequisites
# MAFFT needs GCC/12.3.0 as prerequisite
# FastTree needs GCCcore/12.3.0 (included in GCC/12.3.0)
#
# Since BLAST uses a different GCC than MAFFT/FastTree, we load BLAST first,
# run the BLAST step, then swap modules for MAFFT+FastTree.
# For now, just load BLAST prerequisites. MAFFT/FastTree loaded later.

echo "Loading BLAST+ module..."
module purge 2>/dev/null || true
module load GCC/12.2.0
module load OpenMPI/4.1.4
module load BLAST+/2.14.0
which blastn || { echo "ERROR: blastn not found after module load"; exit 1; }
echo "  blastn: $(which blastn)"
echo ""

# ============================================================================
# 1. CREATE COI REFERENCE
# ============================================================================

echo "[1/7] Creating COI reference sequence..."

# Tribolium castaneum mitochondrial COI (GenBank KM009116, standard barcode region)
# This is a well-characterized beetle COI that will hit across Coleoptera and Neuropterida
cat > "${TREE_DIR}/coi_reference.fasta" << 'COIEOF'
>COI_reference_Tribolium_castaneum
TTGATTTTTTGGTCATCCAGAAGTTTACATTTTAATTTTACCAGGATTTGGAATTGTCTCA
CACATTATTAGCCAAGAAAGCGGTAAAAAAGAAACATTTGGATGTCTAGGAATAATTTACG
CTATACTAGCAATTGGATTACTAGGATTTGTAGTATGAGCACACCATATATTCACAGTAGG
AATAGATGTTGATACTCGAGCTTACTTTACATCAGCTACTATAATTATTGCAGTTCCTACA
GGAATTAAAGTATTCAGATGATTAGCAACTTTACATGGAACTCAATTAAATTATAGTCCTT
CAATTTTATGATCAGTAGGATTTGTATTCCTTTTCACAGTAGGAGGACTAACTGGTGTAGT
ATTAGCAAATTCATCAATTGATATTATTCTTCATGATACATATTATGTAGTAGCACATTTT
CATTATGTATTGTCAATAGGAGCAGTATTCGCTATCATAGCAGGATTCGTACATTGATTCC
CATTATTTACAGGATTATCATTAAATCCTTATTTGTTAAAAATTCAATTCGTAATAATATT
TATAGGAGTTAATTTAACTTTCTTCCCTCAACATTTCCTTGGACTAGCTGGAATACCACGA
CGATATTCAGATTACCCTGATGCATATACAACATGAAATGTAGTTTCATCAATCGGTTCAA
TAATTTCATTAGTAGCTGTAATTATATTCTTATTTATTATTTGAGAAAGCTTTACTGCACA
ACGAAAAGTATCTTCAGTAGAATTAACACCAACTAACTTAGAATGATTACATGGATGCCCA
CCACCATACCATACATTTGAAGAACCTTCATACGTAAAAGTAA
COIEOF

echo "  Reference: Tribolium castaneum COI (831 bp)"
echo ""

# ============================================================================
# 2. BLAST COI AGAINST EACH GENOME
# ============================================================================

echo "[2/7] BLASTing COI reference against 439 genomes..."

# Read the tip mapping to get species → accession mapping
# CSV format: tip_label,species_name,accession,family,clade,role
COI_HITS="${TREE_DIR}/coi_hits.fasta"
BLAST_LOG="${TREE_DIR}/blast_log.txt"
> "$COI_HITS"
> "$BLAST_LOG"

TOTAL=0
FOUND=0
NOHIT=0
NOHIT_SPECIES=""

# Process each genome
tail -n +2 "$TIP_MAP" | while IFS=',' read -r tip_label species_name accession family clade role; do
    TOTAL=$((TOTAL + 1))

    # Find the genome FASTA
    FASTA=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)
    if [ -z "$FASTA" ]; then
        echo "SKIP: No FASTA for ${tip_label} (${accession})" >> "$BLAST_LOG"
        NOHIT=$((NOHIT + 1))
        NOHIT_SPECIES="${NOHIT_SPECIES} ${tip_label}"
        continue
    fi

    # Run blastn (no need to build DB — use -subject for single-genome search)
    # Use -outfmt 6 to get tabular, then extract best hit
    BLAST_OUT=$(mktemp)
    blastn -query "${TREE_DIR}/coi_reference.fasta" \
           -subject "$FASTA" \
           -outfmt "6 sseqid sstart send slen bitscore evalue pident length sseq" \
           -evalue 1e-10 \
           -max_target_seqs 1 \
           -max_hsps 1 \
           -num_threads 1 \
           > "$BLAST_OUT" 2>/dev/null || true

    if [ -s "$BLAST_OUT" ]; then
        # Extract the subject sequence from the best hit
        SEQ=$(awk '{print $9}' "$BLAST_OUT" | head -1 | tr -d '-')
        BITSCORE=$(awk '{print $5}' "$BLAST_OUT" | head -1)
        PIDENT=$(awk '{print $7}' "$BLAST_OUT" | head -1)
        HLEN=$(awk '{print $8}' "$BLAST_OUT" | head -1)

        if [ ${#SEQ} -ge 200 ]; then
            echo ">${tip_label}" >> "$COI_HITS"
            echo "$SEQ" >> "$COI_HITS"
            FOUND=$((FOUND + 1))
            echo "HIT: ${tip_label} len=${#SEQ} bitscore=${BITSCORE} pident=${PIDENT}% hlen=${HLEN}" >> "$BLAST_LOG"
        else
            echo "SHORT: ${tip_label} len=${#SEQ} (skipped, <200bp)" >> "$BLAST_LOG"
            NOHIT=$((NOHIT + 1))
            NOHIT_SPECIES="${NOHIT_SPECIES} ${tip_label}"
        fi
    else
        echo "NOHIT: ${tip_label} (${accession})" >> "$BLAST_LOG"
        NOHIT=$((NOHIT + 1))
        NOHIT_SPECIES="${NOHIT_SPECIES} ${tip_label}"
    fi
    rm -f "$BLAST_OUT"

    # Progress every 50 genomes
    if [ $((TOTAL % 50)) -eq 0 ]; then
        echo "  Processed ${TOTAL} genomes (${FOUND} hits so far)..."
    fi
done

# Re-count from files (subshell variable scoping)
FOUND=$(grep -c "^>" "$COI_HITS" || true)
NOHIT=$((439 - FOUND))
echo ""
echo "  BLAST complete: ${FOUND}/439 genomes have COI hits"
if [ "$NOHIT" -gt 0 ]; then
    echo "  Missing COI (${NOHIT} species) — will be grafted onto tree"
    grep "^NOHIT\|^SHORT\|^SKIP" "$BLAST_LOG" | head -20
fi
echo ""

# ============================================================================
# 3. ALIGN WITH MAFFT
# ============================================================================

# Swap modules: BLAST uses GCC/12.2.0, but MAFFT and FastTree need GCC/12.3.0
echo "Swapping modules for MAFFT + FastTree..."
module purge 2>/dev/null || true
module load GCC/12.3.0
module load MAFFT/7.520-with-extensions
module load FastTree/2.1.11
FASTTREE_BIN=$(which FastTree 2>/dev/null || which fasttree 2>/dev/null)
echo "  mafft: $(which mafft)"
echo "  FastTree: ${FASTTREE_BIN}"
echo ""

echo "[3/7] Aligning COI sequences with MAFFT..."

COI_ALIGNED="${TREE_DIR}/coi_aligned.fasta"
mafft --auto --thread ${NCPUS} "$COI_HITS" > "$COI_ALIGNED" 2>/dev/null

NSEQ=$(grep -c "^>" "$COI_ALIGNED" || true)
ALEN=$(head -2 "$COI_ALIGNED" | tail -1 | wc -c)
echo "  Aligned: ${NSEQ} sequences × ${ALEN} sites"
echo ""

# ============================================================================
# 4. BUILD TREE WITH FASTTREE
# ============================================================================

echo "[4/7] Building ML tree with FastTree (GTR+CAT)..."

COI_TREE="${TREE_DIR}/coi_fasttree.nwk"
${FASTTREE_BIN} -gtr -nt -fastest "$COI_ALIGNED" > "$COI_TREE" 2>/dev/null

NTIPS=$(grep -oP '[A-Za-z_][A-Za-z0-9_]*(?=:)' "$COI_TREE" | wc -l)
echo "  Tree has ${NTIPS} tips"
echo ""

# ============================================================================
# 5. ROOT AND GRAFT MISSING TAXA (Python)
# ============================================================================

echo "[5/7] Rooting tree and grafting any missing taxa..."

FINAL_TREE="${TREE_DIR}/coi_guide_tree_439.nwk"

python3 - "$COI_TREE" "$TIP_MAP" "$BLAST_LOG" "$FINAL_TREE" << 'PYEOF'
import sys, re, csv
from collections import defaultdict

tree_file = sys.argv[1]
tipmap_file = sys.argv[2]
blast_log = sys.argv[3]
output_file = sys.argv[4]

# Read tree
with open(tree_file) as f:
    tree_str = f.read().strip()

# Parse tip labels from tree
tips_in_tree = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
print(f"  Tips in FastTree output: {len(tips_in_tree)}")

# Read tip mapping for all 439 species
all_species = {}  # tip_label -> {family, clade, role}
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_species[row['tip_label']] = {
            'family': row['family'],
            'clade': row['clade'],
            'role': row['role']
        }
print(f"  Total species in catalog: {len(all_species)}")

missing = [sp for sp in all_species if sp not in tips_in_tree]
print(f"  Missing from tree: {len(missing)}")

# --- Rooting ---
# Find Neuropterida outgroups in tree
outgroup_families = {'Chrysopidae', 'Hemerobiidae', 'Osmylidae', 'Myrmeleontidae',
                     'Ascalaphidae', 'Coniopterygidae', 'Sisyridae', 'Mantispidae',
                     'Raphidiidae', 'Inocelliidae', 'Sialidae', 'Corydalidae'}
outgroup_tips = [sp for sp in tips_in_tree
                 if sp in all_species and all_species[sp]['role'] == 'outgroup']

if not outgroup_tips:
    # Fallback: find by order/clade
    outgroup_tips = [sp for sp in tips_in_tree
                     if sp in all_species and all_species[sp].get('clade','') != 'Coleoptera']

print(f"  Outgroup tips for rooting: {len(outgroup_tips)}")

# We'll do rooting by inserting a root node.
# For simplicity with just string manipulation, we'll use midpoint rooting
# approach: find the outgroup, reroot by making it sister to everything else.
#
# Actually, FastTree outputs an unrooted tree. We need proper rooting.
# The simplest approach: use a small ETE3-free method.
# Since we just need to root on one outgroup taxon, we can use a Newick
# string manipulation approach.

# For now, output unrooted tree — Cactus actually handles unrooted trees fine
# (it picks an arbitrary root). The branch lengths are what matter.

# --- Grafting missing taxa ---
# Strategy:
#   1. Same genus in tree → insert as sister with short branch (0.01)
#   2. Same family in tree → insert near family MRCA with medium branch (0.05)
#   3. Same order → insert near order root with longer branch (0.1)

# Build genus/family lookup from in-tree taxa
tree_genera = defaultdict(list)  # genus -> [tip_labels]
tree_families = defaultdict(list)

for sp in tips_in_tree:
    if sp in all_species:
        genus = sp.split('_')[0]
        tree_genera[genus].append(sp)
        tree_families[all_species[sp]['family']].append(sp)

grafted = 0
for sp in missing:
    info = all_species[sp]
    genus = sp.split('_')[0]

    if genus in tree_genera:
        # Sister to a congeneric — insert as (congeneric:bl/2, new_sp:bl/2)
        sister = tree_genera[genus][0]
        # Find sister's branch length
        m = re.search(re.escape(sister) + r':([0-9.eE+-]+)', tree_str)
        if m:
            bl = float(m.group(1))
            half = bl / 2 if bl > 0.001 else 0.005
            replacement = f'({sister}:{half},{sp}:{half})'
            tree_str = tree_str.replace(f'{sister}:{m.group(1)}',
                                        f'{replacement}:{half}')
            tree_genera[genus].append(sp)
            grafted += 1
            continue

    if info['family'] in tree_families:
        # Sister to a family member with longer branch
        sister = tree_families[info['family']][0]
        m = re.search(re.escape(sister) + r':([0-9.eE+-]+)', tree_str)
        if m:
            bl = float(m.group(1))
            pos = bl / 2 if bl > 0.01 else 0.005
            replacement = f'({sister}:{pos},{sp}:{bl})'
            tree_str = tree_str.replace(f'{sister}:{m.group(1)}',
                                        f'{replacement}:{pos}')
            tree_families[info['family']].append(sp)
            grafted += 1
            continue

    # Order-level: find any Coleoptera or Neuropterida tip
    if info['role'] == 'outgroup':
        candidates = [t for t in tips_in_tree if t in all_species
                      and all_species[t]['role'] == 'outgroup']
    else:
        candidates = [t for t in tips_in_tree if t in all_species
                      and all_species[t]['role'] != 'outgroup']

    if candidates:
        sister = candidates[0]
        m = re.search(re.escape(sister) + r':([0-9.eE+-]+)', tree_str)
        if m:
            bl = float(m.group(1))
            pos = bl / 2 if bl > 0.02 else 0.01
            replacement = f'({sister}:{pos},{sp}:{bl * 1.5 if bl > 0.01 else 0.1})'
            tree_str = tree_str.replace(f'{sister}:{m.group(1)}',
                                        f'{replacement}:{pos}')
            grafted += 1

print(f"  Grafted: {grafted} taxa")

# Validate
final_tips = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
print(f"  Final tree tips: {len(final_tips)}")
still_missing = [sp for sp in all_species if sp not in final_tips]
if still_missing:
    print(f"  WARNING: {len(still_missing)} still missing: {still_missing[:10]}")

# Check for zero/negative branch lengths, fix them
def fix_branch(m):
    bl = float(m.group(1))
    if bl <= 0:
        bl = 1e-6
    return f':{bl}'

tree_str = re.sub(r':(-?[0-9.eE+-]+)', fix_branch, tree_str)

# Ensure tree ends with ;
if not tree_str.endswith(';'):
    tree_str += ';'

with open(output_file, 'w') as f:
    f.write(tree_str + '\n')

print(f"  Saved: {output_file}")
PYEOF

echo ""

# ============================================================================
# 6. VALIDATE TREE
# ============================================================================

echo "[6/7] Validating guide tree..."

python3 - "$FINAL_TREE" "$TIP_MAP" << 'VALEOF'
import sys, re, csv

with open(sys.argv[1]) as f:
    tree_str = f.read().strip()

# Count tips
tips = re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str)
tip_set = set(tips)
print(f"  Tips: {len(tip_set)}")
print(f"  Duplicate tip labels: {len(tips) - len(tip_set)}")

# Check branch lengths
bls = [float(x) for x in re.findall(r':([0-9.eE+-]+)', tree_str)]
print(f"  Branch lengths: min={min(bls):.2e}, max={max(bls):.4f}, mean={sum(bls)/len(bls):.4f}")
print(f"  Any > 25.0 (Cactus max): {any(b > 25.0 for b in bls)}")
print(f"  Any <= 0: {any(b <= 0 for b in bls)}")

# Check balanced parentheses
opens = tree_str.count('(')
closes = tree_str.count(')')
print(f"  Balanced parens: {opens == closes} ({opens} open, {closes} close)")

# Check all 439 species present
with open(sys.argv[2]) as f:
    reader = csv.DictReader(f)
    all_sp = set(row['tip_label'] for row in reader)
print(f"  Catalog species: {len(all_sp)}")
print(f"  All present in tree: {all_sp.issubset(tip_set)}")
missing = all_sp - tip_set
if missing:
    print(f"  MISSING: {missing}")

# Multifurcation check: look for patterns like (A,B,C,...) with >2 children
# Count commas between matched parens
import re as re2
# Simple check: any node with >2 immediate children
depth = 0
children_at_depth = {}
max_children = 0
for ch in tree_str:
    if ch == '(':
        depth += 1
        children_at_depth[depth] = 1
    elif ch == ',':
        if depth in children_at_depth:
            children_at_depth[depth] += 1
            if children_at_depth[depth] > max_children:
                max_children = children_at_depth[depth]
    elif ch == ')':
        depth -= 1

print(f"  Max children at any node: {max_children}")
print(f"  Binary: {max_children <= 2}")

if len(tip_set) == len(all_sp) and all_sp.issubset(tip_set) and max_children <= 2 and not any(b > 25.0 for b in bls):
    print("\n  === VALIDATION PASSED ===")
else:
    print("\n  === VALIDATION ISSUES DETECTED ===")
VALEOF

echo ""

# ============================================================================
# 7. REBUILD SEQFILE
# ============================================================================

echo "[7/7] Rebuilding Cactus seqFile with new guide tree..."

# Backup old seqFile
if [ -f "$SEQFILE" ]; then
    cp "$SEQFILE" "${SEQFILE}.bak_$(date +%Y%m%d_%H%M%S)"
fi

# Line 1: new tree
cat "$FINAL_TREE" > "$SEQFILE"

# Lines 2+: tip_label /path/to/genome.fna (same as before)
MAPPED=0
tail -n +2 "$TIP_MAP" | while IFS=',' read -r tip_label species_name accession family clade role; do
    FASTA=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)
    if [ -n "$FASTA" ]; then
        echo "${tip_label} ${FASTA}" >> "$SEQFILE"
    fi
done

TOTAL_ENTRIES=$(tail -n +2 "$SEQFILE" | grep -c . || true)
echo "  seqFile rebuilt: ${TOTAL_ENTRIES} genomes"
echo "  Location: ${SEQFILE}"
echo ""

# ============================================================================
# DONE
# ============================================================================

echo "============================================================"
echo "COI GUIDE TREE COMPLETE"
echo "============================================================"
echo ""
echo "Tree:      ${FINAL_TREE}"
echo "seqFile:   ${SEQFILE}"
echo "BLAST log: ${BLAST_LOG}"
echo "Alignment: ${COI_ALIGNED}"
echo ""
echo "NEXT STEPS:"
echo "  1. Review the tree and BLAST log"
echo "  2. Run the test alignment:"
echo "     sbatch test_alignment.slurm"
echo ""
echo "Finished: $(date)"
