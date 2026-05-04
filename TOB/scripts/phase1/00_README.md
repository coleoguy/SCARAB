# TOB Phase 1 — Backbone Inference

Infers the Coleoptera backbone (ML + coalescent) from BUSCO orthologs across all
Tier-1+2 inputs (~580 genome assemblies, 4 transcriptomes, 2 *Sphaerius* DIY
assemblies, 3 Hymenoptera anchors).

**Gate:** Phase 0 must be complete and Heath-approved before submitting any
Phase 1 job.

---

## Prerequisites

- SSH ControlMaster open (`ssh -fN blackmon@grace.hprc.tamu.edu`, approve Duo).
- Phase 0 complete: `$SCRATCH/tob/genomes/` populated; all inputs catalogued in
  `$SCRATCH/tob/logs/phase0_manifest.txt`.
- Repo pulled on Grace: `cd ~/SCARAB && git pull`.
- Scripts copied to scratch:
  ```
  cp ~/SCARAB/TOB/scripts/phase1/*.slurm $SCRATCH/tob/scripts/phase1/
  cp ~/SCRATCH/tob/scripts/phase1/*.py   $SCRATCH/tob/scripts/phase1/
  ```
- BUSCO lineage database already on Grace:
  `$SCRATCH/tob/busco_downloads/lineages/insecta_odb10/`
  (Download once on login node:
  `busco --download insecta_odb10 --download_path $SCRATCH/tob/busco_downloads/`)

## Topology constraint

`05_iqtree_concat.slurm` accepts an optional `-g CONSTRAINT_TREE` path
via the `CONSTRAINT` variable at the top of the script.  Set it to the
Creedy-2025-derived constraint tree when it is available.  If the variable
is empty the script runs unconstrained — acceptable for a first pass.

---

## Order of operations

| Step | Script | Partition | Wall | Approx. runtime |
|------|--------|-----------|------|-----------------|
| 1 | `01_busco_array.slurm` | medium (bigmem for transcriptomes) | 12 h | ~1–3 h per task; 580 parallel |
| 2 | `02_collect_orthologs.py` | login node | — | 15–30 min |
| 3 | `03_filter_align.slurm` | medium | 12 h | 30–90 min per locus; up to 1,367 parallel |
| 4 | `04_concat.py` | login node | — | 20–60 min |
| 5a | `05_iqtree_concat.slurm` | bigmem | 2 days | 24–72 h |
| 5b | `06_astral.slurm` | medium | 12 h | 2–8 h total (gene trees in array + ASTER) |
| 6 | `07_concordance.slurm` | bigmem | 1 day | 4–12 h |
| 7 | `08_bacoca.slurm` | short | 2 h | 30–60 min |

Steps 5a and 5b can run in parallel once step 4 is done.

### 1. Build BUSCO input manifest

On the login node, build the list of all assemblies:

```bash
cd $SCRATCH/tob

# Genome FNAs (ncbi_dataset layout)
find genomes/ncbi_dataset/data -name "*.fna" > inputs/genome_fnas.txt

# Scarab symlinks (each ACC dir contains one *.fna)
find genomes/scarab_existing -name "*.fna" >> inputs/genome_fnas.txt

# Transcriptomes
find transcriptomes -name "*.fasta.gz" >> inputs/genome_fnas.txt

# Sphaerius DIY
find sphaerius/assemblies -name "contigs.fasta" >> inputs/genome_fnas.txt

# Hymenoptera outgroups
find outgroups/hymenoptera -name "*.fna" >> inputs/genome_fnas.txt

wc -l inputs/genome_fnas.txt   # expect ~585–595

# Create taxon-label mapping (ACC -> sample name)
# Edit inputs/taxon_labels.tsv if tip labels need renaming.
```

### 2. Submit BUSCO array

```bash
N=$(wc -l < $SCRATCH/tob/inputs/genome_fnas.txt)
cd $SCRATCH/tob/scripts/phase1
sbatch --array=1-${N}%100 01_busco_array.slurm
```

Throttle at 100 concurrent tasks (BUSCO is memory-hungry; 100 × 16 G = 1.6 TB
aggregate, well within medium-partition capacity).

### 3. Collect orthologs

After all BUSCO tasks complete:

```bash
python3 02_collect_orthologs.py \
    $SCRATCH/tob/inputs/genome_fnas.txt \
    $SCRATCH/tob/orthologs/busco_results/ \
    $SCRATCH/tob/orthologs/per_locus/
```

### 4. Filter, align, trim

```bash
ls $SCRATCH/tob/orthologs/per_locus/*.faa | \
  xargs -I{} basename {} .faa > $SCRATCH/tob/inputs/loci_all.txt
N=$(wc -l < $SCRATCH/tob/inputs/loci_all.txt)
sbatch --array=1-${N}%200 03_filter_align.slurm
```

### 5. Build supermatrix

```bash
python3 04_concat.py \
    $SCRATCH/tob/orthologs/per_locus_trimmed/ \
    $SCRATCH/tob/phylogenomics/supermatrix.fasta \
    $SCRATCH/tob/phylogenomics/partitions.txt
```

### 6. IQ-TREE + ASTRAL (run in parallel)

```bash
sbatch 05_iqtree_concat.slurm
sbatch 06_astral.slurm
```

### 7. Concordance

After both 05 and 06 complete:

```bash
sbatch 07_concordance.slurm
```

### 8. Compositional bias check

```bash
sbatch 08_bacoca.slurm
```

---

## Outputs

| File | Contents |
|------|----------|
| `$SCRATCH/tob/orthologs/busco_results/{LABEL}/` | Per-sample BUSCO output |
| `$SCRATCH/tob/orthologs/per_locus/{BUSCO_ID}.faa` | Raw per-locus protein FASTA |
| `$SCRATCH/tob/orthologs/per_locus_filtered/{BUSCO_ID}.faa` | After >=50% occupancy filter |
| `$SCRATCH/tob/orthologs/per_locus_aln/{BUSCO_ID}.aln` | MAFFT-LINSI aligned |
| `$SCRATCH/tob/orthologs/per_locus_trimmed/{BUSCO_ID}.trim` | trimAl trimmed |
| `$SCRATCH/tob/phylogenomics/supermatrix.fasta` | Concatenated supermatrix |
| `$SCRATCH/tob/phylogenomics/partitions.txt` | RAxML-format partition file |
| `$SCRATCH/tob/phylogenomics/concat_iqtree/concat.treefile` | ML concatenation tree |
| `$SCRATCH/tob/phylogenomics/gene_trees/*.treefile` | Per-locus gene trees |
| `$SCRATCH/tob/phylogenomics/astral/astral_species_tree.nwk` | ASTRAL-III species tree |
| `$SCRATCH/tob/phylogenomics/concordance/` | gCF + sCF results |
| `$SCRATCH/tob/phylogenomics/bacoca/` | Compositional bias tables + plots |

---

## Grace constraints (from CLAUDE.md)

- Python 3.6 only — no f-strings, no walrus operator, no `pathlib` `read_text()`.
- Compute nodes have no internet.
- `$SCRATCH` = `/scratch/user/blackmon/`; TOB dir = `$SCRATCH/tob/`.
- Max array size 1,001 (index 0–1000); split larger arrays.
- File transfer: sftp only.

## Quality gate

**Do not advance to Phase 2 until Heath has reviewed** the ML vs ASTRAL concordance,
BaCoCa compositional bias report, and per-node support values.
