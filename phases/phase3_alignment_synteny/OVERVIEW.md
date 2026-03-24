# Phase 3: Whole-Genome Alignment & Synteny

**Timeline:** Days 7–24 (18 days)
**Expected Grace Allocation:** ~160,000–430,000 core-hours (revised estimate for 438 genomes; subtree decomposition reduces walltime to 24–36 hrs)
**Key Dependencies:** Phase 2 outputs (genome FASTAs, constraint tree)

## Phase Goal

Align all 439 beetle and neuropterid genomes using ProgressiveCactus on the TAMU Grace cluster, extract synteny blocks from the resulting multiple alignment (HAL format), apply quality control filters, and reconstruct ancestral genomes at internal phylogenetic nodes.

## Phase Overview

This phase performs computationally intensive whole-genome alignment and builds the foundation for downstream rearrangement analysis. ProgressiveCactus is a progressive multiple alignment algorithm optimized for large-scale comparative genomics; it runs on Grace and produces HAL (Hierarchical Alignment) files that preserve phylogenetic structure. From the HAL, we extract pairwise synteny blocks, filter by identity and size criteria, anchor blocks to ancestral genomes, and ultimately track conserved gene orders across the Coleoptera phylogeny.

**Compressed Timeline:**
- Days 7–8: Pipeline setup and validation on 3 small genomes
- Days 8–24: Full alignment runs on Grace (≈2–3 weeks wall-clock time, overlapping with other tasks)
- Days 18–24: Synteny extraction, QC filtering, ancestral reconstruction (while alignment continues)

## Phase Inputs

### From Phase 2:
- **data/genomes/fasta_urls.csv**
  - Columns: species, genome_id, fasta_url, checksum_sha256, assembly_date
  - One row per species (439 genomes)

- **data/genomes/constraint_tree.nwk**
  - Newick phylogenetic tree with 439 tips (one per species), calibrated branch lengths
  - Internal nodes labeled with clade names (e.g., `Polyphaga`, `MRCA_Coleoptera`)

## Phase Tasks

### Task 3.1: Pipeline Setup & Validation
**HOWTO file:** `HOWTO_01_pipeline_setup.md`

Write Snakemake workflow for ProgressiveCactus on Grace. Define SLURM resource tiers (small/medium/large genomes with CPU/RAM/wall-time specifications). Test on 3 small genomes using the Grace `short` partition.

**Outputs:**
- `scripts/phase3/alignment_snakefile.smk` (Snakemake workflow)
- `scripts/phase3/cactus_config.xml` (ProgressiveCactus configuration)
- `scripts/phase3/grace_slurm_template.sh` (SLURM job submission template)
- `results/phase3_alignment_synteny/validation_report.txt` (test results on 3 genomes)

**AI Tracking:** All scripts written by Claude; logged in `ai_use_log.md`. Human must review before submission to Grace.

---

### Task 3.2: Full Alignment on Grace
**HOWTO file:** `HOWTO_02_full_alignment.md`

Download all genome FASTAs to Grace `/scratch`, validate checksums, submit full ProgressiveCactus alignment. Provide step-by-step Grace commands (sbatch, squeue, mmlsquota monitoring).

**Expected Duration:** 2–3 weeks wall-clock time on Grace.

**Outputs:**
- `data/alignments/scarab_alignment.hal` (50–100 GB HAL file on Grace `/scratch`)
- `results/phase3_alignment_synteny/alignment_logs/` (SLURM stdout/stderr logs)

**Acceptance Criteria:**
- HAL file size > 50 GB
- All 439 genomes aligned into HAL
- No SLURM errors in logs
- Checksum validation passed for all input FASTAs

---

### Task 3.3: HAL Synteny Extraction
**HOWTO file:** `HOWTO_03_hal_synteny_extraction.md`

Extract synteny blocks from the HAL file using halTools. Define collinear blocks as ≥10 kb sequences with ≥90% sequence identity. Remove tandem duplicates to avoid inflating block counts.

**Algorithm:**
1. Iterate over all pairwise species comparisons
2. Extract collinear blocks ≥10 kb, ≥90% identity
3. Filter tandem duplications within 10 kb
4. Output TSV with one row per block

**Output Columns:**
```
block_id | species_A | species_B | chr_A | chr_B | start_A | end_A | start_B | end_B | orientation | identity
```

**Outputs:**
- `data/synteny/synteny_blocks_raw.tsv` (raw blocks before filtering)

**Acceptance Criteria:**
- ≥1M synteny blocks total
- Blocks span all pairwise comparisons
- No missing chromosomes or species

---

### Task 3.4: Synteny Quality Control
**HOWTO file:** `HOWTO_04_synteny_qc.md`

Apply QC filters to remove low-confidence blocks:
- Remove blocks with <95% sequence identity
- Remove blocks <10 kb
- Remove regions with >2 fold-back inversions per 100 kb (potential misalignments)
- Remove self-alignments (same species, same chromosome)

**Output Columns:** Same as `synteny_blocks_raw.tsv`, but filtered.

**Outputs:**
- `data/synteny/synteny_blocks_qc.tsv` (filtered blocks)
- `results/phase3_alignment_synteny/synteny_qc_log.txt` (QC statistics)

**Acceptance Criteria:**
- ≥90% of raw blocks pass QC
- No blocks with identity < 95%
- QC log documents filter thresholds and counts removed

---

### Task 3.5: Ancestral Genome Reconstruction
**HOWTO file:** `HOWTO_05_ancestral_reconstruction.md`

Run RACA (Reconstruction of Ancestral Genomes) or InferCARs on Grace to reconstruct ancestral genomes at all internal phylogenetic nodes. This builds proto-karyotypes at major divergence points.

**Grace Resources:**
- Partition: `grace`
- CPU: 24 cores per node
- Memory: 96 GB RAM
- Wall-time: 2 hours per node
- Total estimated: ~60 core-hours

**Outputs:**
- `data/ancestral/ancestral_MRCA_Coleoptera.fa` (FASTA of MRCA of all Coleoptera)
- `data/ancestral/ancestral_node_Polyphaga.fa` (FASTA of each internal node; one file per node)
- `data/ancestral/ancestral_metadata.csv` (node metadata)

**ancestral_metadata.csv columns:**
```
node_id | node_name | age_Ma | confidence | supporting_genomes | supporting_blocks
```

**Acceptance Criteria:**
- All internal nodes reconstructed
- Confidence ≥0.8 at all major nodes (MRCA, crown Polyphaga, etc.)
- All FASTA files present and non-empty

---

### Task 3.6: Synteny Anchoring to Ancestral Genomes
**HOWTO file:** `HOWTO_06_synteny_anchoring.md`

Map QC-filtered synteny blocks onto reconstructed ancestral genomes via BLAST. This anchors each extant synteny block to its ancestral homolog, enabling tracking of conserved gene order through time.

**Algorithm:**
1. BLAST each block's sequence against all ancestral genomes
2. Keep top hit (≥90% identity, ≥80% coverage)
3. Annotate block with ancestral node, chromosome, coordinates
4. Compute conservation score = fraction of blocks with strong ancestral match

**Output Columns:**
```
block_id | species_A | species_B | chr_A | chr_B | start_A | end_A | start_B | end_B | orientation | identity | ancestral_node | ancestral_chr | ancestral_start | ancestral_end | conservation_score
```

**Outputs:**
- `data/synteny/synteny_anchored.tsv` (blocks with ancestral mappings)

**Acceptance Criteria:**
- ≥95% of QC-filtered blocks anchored to ancestral genomes
- conservation_score ≥0.8 for >90% of blocks

---

## Data File Organization

```
SCARAB/
├── data/
│   ├── genomes/
│   │   ├── fasta_urls.csv           (from Phase 2)
│   │   └── constraint_tree.nwk      (from Phase 2)
│   ├── alignments/
│   │   └── scarab_alignment.hal (output Task 3.2; on Grace /scratch)
│   ├── synteny/
│   │   ├── synteny_blocks_raw.tsv   (output Task 3.3)
│   │   ├── synteny_blocks_qc.tsv    (output Task 3.4)
│   │   └── synteny_anchored.tsv     (output Task 3.6)
│   └── ancestral/
│       ├── ancestral_MRCA_Coleoptera.fa  (output Task 3.5)
│       ├── ancestral_node_*.fa           (output Task 3.5, one per node)
│       └── ancestral_metadata.csv        (output Task 3.5)
├── scripts/phase3/
│   ├── alignment_snakefile.smk      (output Task 3.1)
│   ├── cactus_config.xml            (output Task 3.1)
│   └── grace_slurm_template.sh      (output Task 3.1)
└── results/phase3_alignment_synteny/
    ├── validation_report.txt        (output Task 3.1)
    ├── alignment_logs/              (output Task 3.2)
    ├── synteny_qc_log.txt           (output Task 3.4)
    └── [additional logs/figures]
```

## Critical Notes

### Grace Cluster Constraints
- **Scratch Quota:** Monitor `/scratch` disk usage with `mmlsquota`. HAL files are large (~50–100 GB); ensure sufficient quota remains.
- **Queue Depth:** ProgressiveCactus jobs may queue for 1–2 days on Grace during busy periods. Submit early (Day 8) to ensure completion by Day 24.
- **Time Limits:** Always request ≥1 week wall-time for full alignment. Default Grace jobs may be killed if queue requires slots.

### AI Use Tracking
- All Snakemake, SLURM, and Python scripts written by Claude are logged in `ai_use_log.md` with timestamps and summaries.
- Human reviews all scripts before submission to Grace.
- Any modifications made by human are noted in project git history.

### Checksum Validation
- All downloaded genomes must pass SHA256 checksum validation before alignment.
- Corrupted FASTAs will cause ProgressiveCactus to fail silently or produce invalid HAL files.

---

## Next Phase
Phase 4 consumes outputs from Tasks 3.6 (synteny_anchored.tsv), 3.5 (ancestral genomes), and Phase 2 (constraint_tree.nwk) to call chromosomal rearrangements and reconstruct ancestral karyotypes.
