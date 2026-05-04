# TOB Phase 1 Input Manifest Summary

Generated: 2026-05-03

## Total inputs: 583

| Category | Count |
|----------|-------|
| Tier 1 (genome assemblies, beetle ingroup) | 571 |
| Tier 2 (transcriptomes + DIY assemblies) | 6 |
| Outgroup (Hymenoptera) | 6 |
| **TOTAL** | **583** |

Tier 2 breakdown: 4 TSA transcriptomes + 2 Sphaerius DIY assemblies (pending).
Outgroup breakdown: 3 Hymenoptera genomes in CSV (Mengenillidae, Stylopidia suborders) + 3 explicit Hymenoptera outgroup genomes.

---

## By suborder

| Suborder | Count |
|----------|-------|
| Polyphaga | 513 |
| Adephaga | 57 |
| Hymenoptera (outgroup) | 3 |
| Archostemata | 3 |
| Stylopidia (outgroup) | 2 |
| Myxophaga | 4 |
| Mengenillidia (outgroup) | 1 |

---

## File presence

| Status | Count |
|--------|-------|
| Present on Grace | 454 |
| Pending | 129 |

### Pending breakdown

- **127 genomes** listed as `source=scarab` in `best_assembly_per_species.csv` but not found in either
  `/scratch/user/blackmon/tob/genomes/scarab_existing/` or
  `/scratch/user/blackmon/tob/genomes/ncbi_dataset/data/`.
  These accessions exist in the original SCARAB project (`/scratch/user/blackmon/scarab/genomes/`)
  but were not symlinked into the TOB genomes directory. They need to be symlinked or re-fetched.
  Examples include many small/poor assemblies (Copris fidius, Caccobius, Nanos spp., Leptinotarsa
  species panel, Galerucella spp., various Dynastini, etc.).

- **2 Sphaerius DIY assemblies** — Phase 0 step 06 (Flye assembly) has not yet been run.
  Expected paths:
  - `/scratch/user/blackmon/tob/sphaerius/assemblies/Arizona/contigs.fasta`
  - `/scratch/user/blackmon/tob/sphaerius/assemblies/Texas/contigs.fasta`

---

## BUSCO mode

| Mode | Count |
|------|-------|
| genome | 579 |
| transcriptome | 4 |

All genome-mode inputs use `.fna` (NCBI dataset layout).
Transcriptome-mode inputs are `.fasta.gz` TSA files.

---

## Concerns flagged for Heath

### 1. 127 "scarab-source" winners missing from TOB genome directories
These accessions appear in `best_assembly_per_species.csv` with `winner_source=scarab` but are
absent from both TOB genome directories. The SCARAB `scarab_existing/` symlink farm has 439
entries; the missing 127 were apparently never included. Options:
- Add symlinks from `/scratch/user/blackmon/scarab/genomes/<ACC>/` into
  `/scratch/user/blackmon/tob/genomes/scarab_existing/`
- Or pull fresh from NCBI if some accessions have been superseded

Notable missing groups: all 8 Leptinotarsa species panel, 3 Galerucella spp., 4 Dynastes spp.
(alternative versions of already-present Dynastes), multiple small scarab-survey assemblies.

### 2. 44 true orphan GCA_ accessions in scarab_existing (no matching CSV winner)
These genomes are symlinked into `tob/genomes/scarab_existing/` but no row in
`best_assembly_per_species.csv` selects them as a winner. They are almost certainly "loser"
assemblies from multi-assembly species (the CSV picked a better version). Not a problem —
just dead weight in the symlink farm. They will be ignored by the BUSCO pipeline.

### 3. 15 GCF_ accessions in scarab_existing that are GCF/GCA pairs of CSV winners
GCF_ versions of 15 species are symlinked (e.g., `GCF_000699045.2` for Agrilus planipennis
while the CSV winner is `GCA_000699045.2`). These are RefSeq vs GenBank alternates for the same
assembly. The CSV winner (GCA) is correctly found in `ncbi_new/`, so no action needed.

### 4. 2 GCF_ true orphans in scarab_existing with no CSV link
- `GCF_022605725.1` and `GCF_905475395.1` — these GCF_ assemblies have no matched GCA_ winner
  in the CSV. Their species may have been dropped from the 574-winner list. Verify whether
  these species are genuinely excluded or were accidentally omitted from `best_assembly_per_species.csv`.

### 5. Sphaerius DIY assemblies pending
Phase 0 step 06 must be run before Phase 1 BUSCO can proceed for these 2 tip labels.

### 6. Priacma serrata: genome vs TSA conflict
The CSV (row 466) lists `GCA_000281835.1` (Contig genome, source=scarab) as the winner for
Priacma serrata — but it is not in the TOB genome directories (it is in the missing-127 list).
Separately, a TSA for Priacma (`Priacma_serrata_GACO00000000.1.fasta.gz`) is present in the
transcriptomes directory and appears as a Tier 2 row in this manifest. These are two separate
tip representations. Clarify: should BUSCO be run on the genome (if symlinked) or the TSA,
and should only one Priacma row be in the final seqfile?

---

## Key paths referenced

| Directory | Role |
|-----------|------|
| `/scratch/user/blackmon/tob/genomes/scarab_existing/<ACC>/ncbi_dataset/data/<ACC>/*_genomic.fna` | Tier 1, scarab-source |
| `/scratch/user/blackmon/tob/genomes/ncbi_dataset/data/<ACC>/*_genomic.fna` | Tier 1, new-pull |
| `/scratch/user/blackmon/tob/transcriptomes/*.fasta.gz` | Tier 2 TSA |
| `/scratch/user/blackmon/tob/sphaerius/assemblies/*/contigs.fasta` | Tier 2 DIY (pending) |
| `/scratch/user/blackmon/tob/outgroups/hymenoptera/ncbi_dataset/data/<ACC>/*_genomic.fna` | Outgroup |
