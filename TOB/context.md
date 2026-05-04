# TOB — Tree of Beetles

**Goal.** Build the most complete Coleoptera phylogeny ever assembled. Phylogenomic backbone covering all four suborders (Archostemata, Myxophaga, Adephaga, Polyphaga) + species-level fill-in across all ~180 families using mined GenBank data, with fossil-calibrated divergence dates.

**PI.** Heath Blackmon, TAMU.

**Status.** Scoping. Project initiated 2026-05-03 by splitting from SCARAB.

## Relationship to SCARAB

SCARAB (478-beetle ProgressiveCactus alignment) is paused at git tag `scarab-pause-2026-05-03`. The pause was triggered by realizing the species tree is critical input infrastructure for Cactus, and the SCARAB tree (439 tips) was missing both Archostemata and Myxophaga — leaving the deep root of the beetle tree unresolvable from genomic data alone.

TOB exists to build that tree properly. Once TOB delivers a fossil-dated, fully-rooted Coleoptera phylogeny with all suborders represented, SCARAB can resume with a real guide tree.

The 478 SCARAB genomes are the Tier-1 input to TOB — they are not lost, they are the starting material.

## Strategy: divide by data tier, not by family

Earlier (rejected) plan: family-by-family ML on whatever GenBank has, then graft families onto a self-built backbone. Rejected because (a) building a backbone from sparse Sanger markers is the weakest link, (b) "all sequences per family" produces a junk drawer of incompatible markers, (c) family-level ML without backbone constraint floats every family independently in topology space, (d) full Bayesian dating across the whole tree is computationally infeasible.

Adopted plan: hierarchical, with backbone phylogenomics constraining everything below.

| Tier | Data | Source | Est. taxa | Use |
|------|------|--------|-----------|-----|
| 1 | Whole genomes | SCARAB 478 + new releases + Strepsiptera outgroups | ~500 | Backbone (Polyphaga + Adephaga) |
| 2 | Assembled transcriptomes (TSA) + DIY assemblies of Sphaerius WGS | NCBI TSA, McKenna 2019, Sphaerius SRA | ~10–20 critical taxa | Backbone (Archostemata + Myxophaga) |
| 3 | Multi-locus Sanger | GenBank mining via PyPHLAWD or SuperCRUNCH | ~10,000–30,000 | Family-internal species placement, constrained to backbone |
| 4 | COI barcodes | BOLD / GenBank | ~50,000+ | Optional, low confidence |

**Inference workflow:**
1. Backbone: Tier 1+2 ortholog matrix → IQ-TREE concatenated + ASTRAL coalescent species tree. Cross-validate.
2. Family ML: per-family supermatrix from Tier 3, IQ-TREE with `-g backbone.tre` constraint. Bootstrap each.
3. Synthesis: graft family trees onto backbone at stem nodes.
4. Dating: treePL with Coleoptera fossil priors. Jackknife replicates for date CIs.

## Verified data inventory (NCBI, 2026-05-03)

**Polyphaga + Adephaga genomes (Tier 1):** 478 in SCARAB catalog (`data/genomes/genome_catalog_primary.csv`). Refresh against NCBI Datasets to capture 2024–2026 releases — likely 50–100 new candidates.

**Strepsiptera outgroups (Tier 1):** 4 genomes; best is *Xenos peckii* GCA_040167675 (7.4 Mb N50, 2024).

**Archostemata (Tier 2):**
- Cupedidae: TSA *Priacma serrata* (GACO01) ✓
- Micromalthidae: TSA *Micromalthus debilis* (GDOQ00000000.1) ✓
- Ommatidae: only mitogenome (NC_011328.1, *T. bruchi*) + 6 Sanger markers — no transcriptome anywhere in NCBI under any genus
- Crowsoniellidae, Jurodidae: zero data

**Myxophaga (Tier 2):**
- Hydroscaphidae: TSA *Hydroscapha redfordi* (GDMJ00000000.1) ✓
- Lepiceridae: TSA *Lepicerus* sp. AD-2013 (GAZB00000000.2) ✓
- Sphaeriusidae: 2 raw WGS sets in SRA (PRJNA870497, OSU 2023): SRR21231095 (*Sphaerius* sp. Arizona, 18.4 Gbases HiSeq) + SRR21231096 (*Sphaerius* cf. *minutus*, 16.1 Gbases). Need to assemble ourselves.
- Torridincolidae: only Sanger markers — Tier 3 only

**Result:** 6 of 8 ancient-suborder families have phylogenomic-grade data. Ommatidae and Torridincolidae will only be placeable at the Sanger-marker tier.

## Open inquiries

- **McKenna 2019 PNAS supplement:** check whether *Tetraphalerus* (Ommatidae) transcriptome data exists in non-NCBI repository (ButterflyBase, journal supplement, Dryad). If yes, retrieve. If no, consider direct inquiry to McKenna group.
- **Refresh Tier 1 inventory:** rerun NCBI Datasets query for all Coleoptera + Strepsiptera + Neuropterida genomes deposited since SCARAB catalog was assembled. Darwin Tree of Life and BAT1K-adjacent projects have accelerated submissions.

## Pending tasks (not started)

1. ~~Literature review~~ — DONE 2026-05-03 (8 lit-review agents). See [literature/notes/](literature/notes/) and the synthesis at [workflow_v1.md](workflow_v1.md).
2. ~~Refresh NCBI genome inventory~~ — DONE 2026-05-03. **546 new candidates** found (323 include, 176 conditional, 47 exclude); 101 are chromosome-level. See [data/ncbi_inventory_refresh_2026-05.csv](data/ncbi_inventory_refresh_2026-05.csv) and [notes](data/ncbi_inventory_refresh_notes.md).
3. *Sphaerius* DIY assembly on Grace (see plan below).
4. Tier-2 transcriptome retrieval and BUSCO extraction pipeline.
5. ~~Decide GenBank mining tool~~ — DECIDED: SuperCRUNCH primary, phylotaR fallback. See [workflow_v1.md](workflow_v1.md).
6. ~~Fossil calibration set assembly~~ — DECIDED: Cai et al. 2022 starting set (~25 nodes applicable at TOB scope). See [workflow_v1.md](workflow_v1.md).

**Locked methodology** is captured in [workflow_v1.md](workflow_v1.md). Read that before any Phase-1+ work.

## Sphaerius DIY assembly plan (deferred)

When ready, on Grace:
- Tool: SPAdes (PE-150 Illumina, no long reads)
- Resources: 32 cores, 200 GB RAM, 36–48h wall, bigmem partition
- Pipeline: prefetch + fasterq-dump (login node) → fastp QC → SPAdes per accession → BUSCO insecta_odb10 → ortholog FASTAs join Tier 1+2 matrix
- Coverage: 23×–170× depending on actual genome size (unknown for Myxophaga; tiny insect → likely 200–500 Mb)
- Two **different species** in the run set — assemble independently, get 2 myxophagan tips

## Key references

- McKenna et al. 2019 PNAS — phylogenomic backbone (89 taxa, 4,818 nuclear genes)
- Zhang et al. 2018 Nat Commun — Coleoptera transcriptomes (95 taxa, AHE)
- Bocak et al. 2014 Syst Biol — precedent ~8,000-species mega-phylogeny + lessons
- Smith & Brown 2018 Am J Bot — backbone + grafting done well
- Smith & Walker 2019 — PyPHLAWD (GenBank mining pipeline)
- Portik & Wiens 2020 MEE — SuperCRUNCH (alternative GenBank pipeline)
- treePL (Smith & O'Meara 2012) — penalized likelihood dating at scale

## Working-tree note

At project split (2026-05-03) SCARAB had uncommitted modifications to `context.md` and 4 untracked items in `grace_upload_phase3/`, `manuscript/drafts/`, `results/species_tree/`. These were not committed by the TOB-creation step — they remain in the working tree for Heath to handle independently.
