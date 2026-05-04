# Family coverage report — Tier-2 reconciliation addendum

The original report (`family_coverage_report.md`) was generated from
`best_assembly_per_species.csv` only and therefore counts **nuclear
genomes only**. This addendum reconciles the report against the actual
Tier 1+2 inputs that will feed Phase 1 BUSCO extraction.

## Tier-2 inputs missing from the original report

| Family | Suborder | Species | Source | Path |
|--------|----------|---------|--------|------|
| Cupedidae | Archostemata | *Priacma serrata* | TSA GACO00000000.1 (transcriptome) | `$SCRATCH/tob/transcriptomes/Priacma_serrata_GACO00000000.1.fasta.gz` |
| Micromalthidae | Archostemata | *Micromalthus debilis* | TSA GDOQ00000000.1 (transcriptome) | `$SCRATCH/tob/transcriptomes/Micromalthus_debilis_GDOQ00000000.1.fasta.gz` |
| Hydroscaphidae | Myxophaga | *Hydroscapha redfordi* | TSA GDMJ00000000.1 (transcriptome) | `$SCRATCH/tob/transcriptomes/Hydroscapha_redfordi_GDMJ00000000.1.fasta.gz` |
| Lepiceridae | Myxophaga | *Lepicerus* sp. AD-2013 | TSA GAZB00000000.2 (transcriptome) | `$SCRATCH/tob/transcriptomes/Lepicerus_sp_GAZB00000000.2.fasta.gz` |
| Sphaeriusidae | Myxophaga | *Sphaerius* sp. + *S.* cf. *minutus* | DIY SPAdes from SRR21231095/096 | `$SCRATCH/tob/sphaerius/assemblies/{species}/contigs.fasta` (Phase 0 step 06 output) |

## Corrections to the original report

### "Myxophaga (all 4 families) absent" — INCORRECT

All four extant Myxophaga families are covered:

| Family | Coverage source | Status |
|--------|-----------------|--------|
| Hydroscaphidae | Tier-2 TSA | ready |
| Lepiceridae | Tier-2 TSA | ready |
| Sphaeriusidae (×2 spp) | Tier-2 DIY assembly | pending Phase 0 step 06 |
| Torridincolidae | none | confirmed Tier-3-only (Sanger / mitogenome only — no genome or transcriptome anywhere in NCBI as of 2026-05-03) |

The deep root of the Coleoptera tree IS supportable by TOB once Phase 0 step 06 completes.

### "Cupedidae contig-level only" — MISLEADING

Cupedidae has *Priacma serrata* via the GACO TSA transcriptome, not the unusable 12 Mb / 4.8 kb-N50 nuclear assembly that the genomes-only winner table points at. BUSCO will run in transcriptome mode against the TSA — this is the actual Cupedidae input.

### "Singleton family Cupedidae as only Archostemata" — INCORRECT

Two of three sequenceable Archostemata families are covered (Cupedidae *Priacma*, Micromalthidae *Micromalthus*). Ommatidae remains Tier-3-only. Crowsoniellidae and Jurodidae have no data anywhere.

## Updated Tier 1+2 family coverage

| Tier | Source | Family count |
|------|--------|--------------|
| 1 (genomes from `best_assembly_per_species.csv`) | NCBI assemblies | 61 |
| 2 (TSAs + DIY) | This addendum | +5 (Cupedidae, Micromalthidae, Hydroscaphidae, Lepiceridae, Sphaeriusidae) |
| **Combined Tier 1+2** | | **~66 of 187 families = 35.3%** |

The original report's other findings (Derodontidae, Lymexylidae, Dryophthoridae, Gyrinidae, Erotylidae absent; 27 singleton families; etc.) remain valid and unaffected by Tier-2 reconciliation.

## Action items still applicable from original report

- **Derodontidae + Lymexylidae** (entire superfamilies absent) — search non-NCBI repos via the GoaT API per `non_ncbi_genome_survey.md`
- **Dryophthoridae** (~1,200 spp) — likely available; GoaT diff
- **Gyrinidae** (Adephaga gap) — check NCBI for chromosome-level submissions since the snapshot
- **Erotylidae** (3,500+ spp) — same
- **Ommatidae + Torridincolidae** — Tier-3-only confirmed; mitogenome cross-check via `coleoptera_mitogenomes.csv`
