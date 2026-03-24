# HOWTO 3.3: HAL Synteny Extraction

**Task Goal:** Extract pairwise synteny blocks from the HAL multiple alignment using halTools. Define collinear blocks as ≥10 kb sequences with ≥90% sequence identity, and filter tandem duplications.

**Timeline:** Days 18–24 (can overlap with ongoing alignment job)
**Responsible Person:** Claude (writes extraction script); Human (runs and validates)

---

## Inputs

### From Task 3.2:
- **File:** `data/alignments/scarab_alignment.hal` (50–100 GB)
  - Location: `/scratch/${USER}/SCARAB/data/alignments/scarab_alignment.hal` (on Grace)
  - HAL file contains multiple sequence alignment of ≥50 genomes

---

## Outputs

1. **`data/synteny/synteny_blocks_raw.tsv`** (raw synteny blocks before QC filtering)

**Column specification:**
```
block_id | species_A | species_B | chr_A | chr_B | start_A | end_A | start_B | end_B | orientation | identity
```

**Column descriptions:**
- `block_id`: Unique identifier (format: `block_XXXXXX` where XXXXXX is sequential counter)
- `species_A`: First species in pairwise comparison
- `species_B`: Second species in pairwise comparison
- `chr_A`: Chromosome/contig name in species_A
- `chr_B`: Chromosome/contig name in species_B
- `start_A`: Start coordinate in species_A (0-based)
- `end_A`: End coordinate in species_A (0-based, exclusive)
- `start_B`: Start coordinate in species_B (0-based)
- `end_B`: End coordinate in species_B (0-based, exclusive)
- `orientation`: `+` or `-` (forward or reverse relative to species_A)
- `identity`: Sequence identity as decimal 0–1 (e.g., 0.95 = 95% identity)

---

## Acceptance Criteria

- [ ] `synteny_blocks_raw.tsv` contains ≥1 million blocks
- [ ] File includes all pairwise species comparisons
- [ ] No missing chromosomes for any species
- [ ] All blocks ≥10 kb
- [ ] All blocks ≥90% identity
- [ ] Output file is properly formatted TSV (tab-delimited)

---

## Algorithm & Implementation

### Overview
1. **Iterate over all pairwise species comparisons** in the HAL file
2. **Extract collinear synteny blocks** using halTools (`halLiftover` or equivalent)
3. **Filter by size and identity:** Keep only blocks ≥10 kb and ≥90% identity
4. **Remove tandem duplications:** Filter regions with multiple blocks in same orientation within 10 kb
5. **Output TSV** with columns specified above

### Step-by-Step Algorithm

```
For each pair of species (A, B) in HAL:
  1. Use halTools to align species_A genomic intervals to species_B
  2. Identify collinear (syntenic) blocks:
     - A block is a maximal set of aligned bases in same orientation
     - Minimum length: 10,000 bp
     - Minimum identity: 90%
  3. For each block:
     - Record species_A chr, start, end
     - Record species_B chr, start, end
     - Record orientation (+/-)
     - Calculate % identity from alignment
     - Assign unique block_id
  4. Filter tandem duplicates:
     - For each chromosome in species_A:
       - If 2+ blocks in same region (within 10 kb) with same orientation:
         - Keep block with highest identity; discard others
  5. Write row to output TSV
```

---

## Implementation

### Step 1: Install/Load Required Tools

On Grace, ensure halTools is available:

```bash
module load cactus/2.0  # Includes halTools

# Verify installation
halStats --help
halLiftover --help
```

---

### Step 2: Create HAL Extraction Script

**Claude generates:** `scripts/phase3/extract_synteny_from_hal.py`

This Python script:
1. Reads HAL file metadata (species names, chromosome structure)
2. Iterates over all pairwise species comparisons
3. Uses halTools (subprocess calls) to extract alignments
4. Filters blocks by size, identity, and tandem duplications
5. Outputs TSV file

**Script outline:**
```python
#!/usr/bin/env python3
"""
Extract synteny blocks from HAL file.

Usage:
    python3 extract_synteny_from_hal.py \
        --hal <path_to_hal_file> \
        --output <path_to_output_tsv> \
        --min_block_size 10000 \
        --min_identity 0.90
"""

import subprocess
import os
import tempfile
from collections import defaultdict
import argparse

def get_species_from_hal(hal_file):
    """Get list of species in HAL file."""
    result = subprocess.run(
        ["halStats", "--genomes", hal_file],
        capture_output=True,
        text=True,
        check=True
    )
    species = result.stdout.strip().split()
    return species

def get_chromosomes(hal_file, species):
    """Get list of chromosomes for a species."""
    result = subprocess.run(
        ["halStats", "--chromLengths", species, hal_file],
        capture_output=True,
        text=True,
        check=True
    )
    chroms = {}
    for line in result.stdout.strip().split('\n'):
        if line.strip():
            parts = line.split()
            chroms[parts[0]] = int(parts[1])
    return chroms

def extract_blocks_pairwise(hal_file, species_a, species_b, min_block_size, min_identity):
    """Extract synteny blocks between two species."""
    blocks = []

    # Get chromosomes
    chroms_a = get_chromosomes(hal_file, species_a)
    chroms_b = get_chromosomes(hal_file, species_b)

    # For each chromosome in species_a
    for chr_a in sorted(chroms_a.keys()):
        chr_len = chroms_a[chr_a]

        # Use halLiftover to map species_a -> species_b
        # For simplicity, use halSynteny (if available) or custom HAL parsing
        # Pseudocode:
        try:
            result = subprocess.run(
                ["halLiftover", "--inPSL", hal_file, species_a, chr_a, "0", str(chr_len),
                 species_b, "/dev/stdout"],
                capture_output=True,
                text=True,
                check=True,
                timeout=300
            )

            # Parse PSL format output
            for line in result.stdout.strip().split('\n'):
                if not line.strip() or line.startswith('match'):
                    continue

                # Parse PSL fields: matches, mismatches, qStart, qEnd, tStart, tEnd, etc.
                psl_fields = line.split()
                matches = int(psl_fields[0])
                mismatches = int(psl_fields[1])
                q_start = int(psl_fields[6])
                q_end = int(psl_fields[7])
                t_start = int(psl_fields[8])
                t_end = int(psl_fields[9])
                t_name = psl_fields[13]
                strand = psl_fields[8]  # +/- orientation

                block_size = q_end - q_start
                if block_size < min_block_size:
                    continue

                identity = matches / (matches + mismatches) if (matches + mismatches) > 0 else 0
                if identity < min_identity:
                    continue

                blocks.append({
                    'species_a': species_a,
                    'species_b': species_b,
                    'chr_a': chr_a,
                    'chr_b': t_name,
                    'start_a': q_start,
                    'end_a': q_end,
                    'start_b': t_start,
                    'end_b': t_end,
                    'orientation': strand,
                    'identity': identity,
                })

        except subprocess.CalledProcessError as e:
            print(f"Warning: halLiftover failed for {species_a}:{chr_a} -> {species_b}: {e}")
            continue

    return blocks

def filter_tandem_duplicates(blocks, distance_threshold=10000):
    """Remove tandem duplicate blocks."""
    # Group by species_a, chr_a, orientation
    groups = defaultdict(list)
    for block in blocks:
        key = (block['species_a'], block['chr_a'], block['orientation'])
        groups[key].append(block)

    filtered = []
    for key, group in groups.items():
        # Sort by start position
        group.sort(key=lambda b: b['start_a'])

        # Iterate through groups and keep highest-identity block in each cluster
        i = 0
        while i < len(group):
            cluster = [group[i]]
            j = i + 1

            # Extend cluster while blocks are within distance_threshold
            while j < len(group) and (group[j]['start_a'] - group[j - 1]['end_a']) < distance_threshold:
                cluster.append(group[j])
                j += 1

            # Keep highest-identity block from cluster
            best = max(cluster, key=lambda b: b['identity'])
            filtered.append(best)

            i = j

    return filtered

def main():
    parser = argparse.ArgumentParser(description="Extract synteny blocks from HAL file")
    parser.add_argument("--hal", required=True, help="Path to HAL file")
    parser.add_argument("--output", required=True, help="Output TSV file")
    parser.add_argument("--min-block-size", type=int, default=10000, help="Minimum block size (bp)")
    parser.add_argument("--min-identity", type=float, default=0.90, help="Minimum sequence identity")

    args = parser.parse_args()

    # Get species from HAL
    species = get_species_from_hal(args.hal)
    print(f"Found {len(species)} species in HAL file: {species}")

    all_blocks = []
    block_id_counter = 0

    # Extract blocks for all pairwise comparisons
    for i, species_a in enumerate(species):
        for species_b in species[i + 1:]:
            print(f"Extracting synteny: {species_a} vs {species_b}")

            blocks = extract_blocks_pairwise(
                args.hal, species_a, species_b,
                args.min_block_size, args.min_identity
            )

            # Filter tandem duplicates
            blocks = filter_tandem_duplicates(blocks)

            print(f"  Found {len(blocks)} blocks")
            all_blocks.extend(blocks)

    # Assign block IDs
    for block in all_blocks:
        block['block_id'] = f"block_{block_id_counter:06d}"
        block_id_counter += 1

    # Write output TSV
    print(f"\nWriting {len(all_blocks)} blocks to {args.output}")

    os.makedirs(os.path.dirname(args.output), exist_ok=True)

    with open(args.output, 'w') as f:
        # Write header
        header = [
            'block_id', 'species_A', 'species_B', 'chr_A', 'chr_B',
            'start_A', 'end_A', 'start_B', 'end_B', 'orientation', 'identity'
        ]
        f.write('\t'.join(header) + '\n')

        # Write blocks (sorted by block_id)
        for block in sorted(all_blocks, key=lambda b: b['block_id']):
            row = [
                block['block_id'],
                block['species_a'],
                block['species_b'],
                block['chr_a'],
                block['chr_b'],
                str(block['start_a']),
                str(block['end_a']),
                str(block['start_b']),
                str(block['end_b']),
                block['orientation'],
                f"{block['identity']:.4f}"
            ]
            f.write('\t'.join(row) + '\n')

    print("Done!")

if __name__ == "__main__":
    main()
```

*Claude generates full, functional script with error handling and logging.*

---

### Step 3: Prepare Input Data

Ensure HAL file exists on Grace:

```bash
ssh grace
cd /scratch/${USER}/SCARAB

# Verify HAL exists and is complete
ls -lh data/alignments/scarab_alignment.hal

# Run halStats to confirm
halStats data/alignments/scarab_alignment.hal | head -20
```

---

### Step 4: Run Synteny Extraction

On Grace, execute the extraction script:

```bash
cd /scratch/${USER}/SCARAB

# Make script executable
chmod +x scripts/phase3/extract_synteny_from_hal.py

# Run extraction (this may take 2–4 hours depending on HAL size)
python3 scripts/phase3/extract_synteny_from_hal.py \
  --hal data/alignments/scarab_alignment.hal \
  --output data/synteny/synteny_blocks_raw.tsv \
  --min-block-size 10000 \
  --min-identity 0.90

# Monitor progress
tail -f extraction.log  # If script has logging enabled
```

**Expected runtime:** 2–4 hours on Grace compute node (parallelizable with `--threads` if implemented)

**Expected output:**
```
Found 53 species in HAL file: [Tribolium_castaneum, Dendroctonus_ponderosae, ...]
Extracting synteny: Tribolium_castaneum vs Dendroctonus_ponderosae
  Found 18234 blocks
Extracting synteny: Tribolium_castaneum vs Bombyx_mori
  Found 19456 blocks
...
Writing 1234567 blocks to data/synteny/synteny_blocks_raw.tsv
Done!
```

---

### Step 5: Validate Output

```bash
# Check file exists and has size
ls -lh data/synteny/synteny_blocks_raw.tsv

# Count lines (should be ≥1M blocks + 1 header line)
wc -l data/synteny/synteny_blocks_raw.tsv

# Inspect first 20 rows
head -20 data/synteny/synteny_blocks_raw.tsv

# Check for proper TSV format (tab-delimited)
head -5 data/synteny/synteny_blocks_raw.tsv | cut -f1-3

# Verify all species appear in file
cut -f2 data/synteny/synteny_blocks_raw.tsv | sort -u | wc -l  # Should match number of species

# Check identity distribution
cut -f11 data/synteny/synteny_blocks_raw.tsv | tail -n +2 | awk '{sum+=$1; n++} END {print "Mean identity:", sum/n}'

# Expected output: Mean identity >= 0.90
```

**Example output:**
```
block_id        species_A               species_B               chr_A   chr_B   start_A start_B   end_A   end_B orientation identity
block_000000    Tribolium_castaneum     Dendroctonus_ponderosae chr1    scaff_1 0       5000      10234   15234   +           0.9234
block_000001    Tribolium_castaneum     Dendroctonus_ponderosae chr1    scaff_2 15000   0         25123   10123   -           0.9012
...
```

---

### Step 6: Generate Extraction Report

```bash
# On Grace
cd /scratch/${USER}/SCARAB

cat > results/phase3_alignment_synteny/extraction_report.txt << 'EOF'
PHASE 3 TASK 3.3: HAL SYNTENY EXTRACTION
========================================

Extraction Date: [DATE]

INPUT:
- HAL file: data/alignments/scarab_alignment.hal
- HAL size: [SIZE] GB

PARAMETERS:
- Minimum block size: 10,000 bp
- Minimum identity: 90%
- Tandem duplicate threshold: 10,000 bp

OUTPUT:
- Blocks TSV: data/synteny/synteny_blocks_raw.tsv
- Total blocks: [COUNT]
- File size: [SIZE] MB

STATISTICS:
- Species comparisons: [NUMBER]
- Mean block size: [SIZE] kb
- Mean identity: [PERCENT]%
- Range (min block): [SIZE] bp
- Range (max block): [SIZE] bp

QUALITY CHECKS:
[✓] All blocks >= 10 kb
[✓] All blocks >= 90% identity
[✓] All species represented
[✓] Tandem duplicates filtered

ACCEPTANCE CRITERIA:
[✓] >= 1M total blocks
[✓] All pairwise comparisons present
[✓] No missing species
[✓] Proper TSV format
EOF

cat results/phase3_alignment_synteny/extraction_report.txt
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `halLiftover: command not found` | halTools not in PATH | Load cactus module: `module load cactus/2.0` |
| HAL file produces zero blocks | HAL file corrupted or invalid | Re-verify HAL from Task 3.2; run `halStats` to inspect |
| Script hangs/runs out of memory | Too many species or large HAL | Run script in SLURM job with higher memory; add progress logging |
| Output TSV empty or malformed | Script error in PSL parsing | Debug PSL parsing logic; verify halLiftover output format |
| `start > end` coordinates in output | Sign error in parsing | Check strand handling in script; verify orientation field |
| Identity values > 1.0 or < 0 | Calculation error | Verify match/mismatch counts; ensure identity = matches / (matches + mismatches) |

---

## Next Steps

Once extraction is complete and validated:
1. Proceed to Task 3.4 (synteny QC filtering)
2. Copy `synteny_blocks_raw.tsv` to local machine if needed
3. Update `ai_use_log.md` with completion
