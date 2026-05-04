# Creedy et al. 2025 — Retrieval Provenance Notes

## Citation

Creedy TJ, Ding Y, Gregory KM, Swaby L, Zhang F, Vogler AP. 2025. Bioinformatics of Combined Nuclear and Mitochondrial Phylogenomics to Define Key Nodes for the Classification of Coleoptera. *Systematic Biology* 75(3):445–467.

- Published DOI: https://doi.org/10.1093/sysbio/syaf031
- bioRxiv preprint DOI: https://doi.org/10.1101/2024.10.26.620449 (posted 2024-10-29)
- PMID: 41288263 / PMCID: PMC13048007
- Dryad data deposit: https://doi.org/10.5061/dryad.zkh1893f4 (currently under embargo/private — returns 404 or "cannot be viewed")

## What Was Retrieved

### Full text
- Retrieved via PMC (PMC13048007) using PubMed MCP `get_full_text_article`. Full article text obtained.
- Journal PDF not retrievable: OUP returns HTTP 403; bioRxiv PDF blocked by Cloudflare.

### Supplementary structure (from OUP article page)
The supplement is deposited on Dryad (`10.5061/dryad.zkh1893f4`). Files identified from in-text references:

| Supplement | Content | Relevant to TOB? |
|-----------|---------|-----------------|
| S1 | Parameter specs for mitocorrect annotation tool | No |
| S2 | **Newick files of 4 phylogenies with clades mapped + CSV** | YES — constraint tree |
| S3 | Metadata for 491 terminal taxa | Possibly |
| S4 | 36 nuclear trees (6 matrices × 6 models) | No |
| S5 | **Strict consensus of 83 nuclear backbone nodes** | YES — this IS the IQ-TREE constraint backbone |
| S6 | 482 mitogenome dataset info | No |
| S7 | Matrix specs (13 PCG alignments) | No |
| S8 | **Newick of final constrained mitogenome tree** | YES — final tree |
| S9 | PDF phylogram of 491 mitogenomes | Reference only |

**Critical files for TOB Phase 1**: S2 (Newick + CSV), S5 (83 backbone nodes), S8 (final constrained tree). All are on Dryad and not currently downloadable.

## Key Numbers

- **83 nodes**: universal strict consensus across 30 nuclear trees (5 models × 6 matrices; ASTRAL excluded)
- **84 nodes**: independently identified as stable scaffold from comparing 4 studies (nuclear + mito); Table 3 in paper
- These two sets overlap but are independently derived (paper notes the similar numbers are coincidental)
- Studies compared: Creedy2025 mito tree, Zhang et al. (2018/reanalyzed by Cai 2022), McKenna et al. (2019), Cai et al. (2022)

## Node Content Extracted from Full Text

The paper's Results section explicitly describes the following universally supported nodes (these are the basis for `creedy2025_constraint_nodes.csv`):

**Suborder-level (4 suborders)**
- Polyphaga, Adephaga, Myxophaga, Archostemata each monophyletic
- Topology: (Polyphaga (Adephaga (Myxophaga + Archostemata)))

**Adephaga**
- Gyrinidae sister to all others
- Geadephaga and Hydradephaga each monophyletic
- Cicindelidae sister to remaining Geadephaga
- Dytiscoidea (internal position of Hygrobiidae variable = unstable node)

**Polyphaga Series (Infraorders)**
- Arrangement: (Scirtiformia (Elateriformia (Staphyliniformia incl. Scarabaeiformia (Bostrichiformia, Cucujiformia))))
- Each series monophyletic

**Elateriformia**
- (Dascilloidea (Elateroidea (Byrrhoidea + Buprestoidea)))
- Byrrhoidea monophyly uncertain (node 25 = disputed)

**Staphyliniformia**
- ((Hydrophyloidea + Histeroidea) (Staphylinoidea + Scarabaeoidea))

**Cucujiformia**
- (Cleroidea (Coccinelloidea ((Lymexyloidea + Tenebrionoidea) (Cucujoidea s.str. (Curculionoidea + Chrysomeloidea)))))
- Cleroidea/Coccinelloidea position debated in some analyses (nodes 52, 56, 61, 70)
- Cucujoidea monophyly uncertain (node 70)

## What Is Missing / Cannot Be Delivered

1. **creedy2025_constraint.nwk** — NOT created. The Newick string for the 83-node backbone (S5) and final constrained tree (S8) are in Dryad, which is inaccessible (embargo). No Newick string appears in the main paper or bioRxiv HTML.

2. **Complete Table 3** — The full enumerated list of 84 nodes with all columns is in the paper's Table 3 (paywalled HTML rendering, not in PMC XML) and S2 CSV (Dryad). The CSV (`creedy2025_constraint_nodes.csv`) was built from explicit text in the Results/Discussion sections only (~45 entries covering the major clades described). It does NOT capture the full 84-node table.

3. **PDF** — Not retrieved. OUP paywall (HTTP 403); bioRxiv blocked.

## Recommended Next Steps

1. **Access Dryad directly** once embargo lifts: https://doi.org/10.5061/dryad.zkh1893f4
   - S2 CSV = complete Table 3 as a machine-readable file
   - S5 = strict consensus backbone (83 nodes, multifurcating Newick) → directly usable as IQ-TREE `-g backbone.tre`
   - S8 = final constrained tree (491 taxa)

2. **Email corresponding author** (Alfried Vogler, a.vogler@nhm.ac.uk / Imperial College London) requesting S5 (the backbone constraint Newick). This is standard in the community.

3. **TAMU library access**: The published PDF is accessible via TAMU proxy. URL: https://proxy.library.tamu.edu/login?url=https://academic.oup.com/sysbio/article/75/3/445/8342120 — requires manual browser login.

4. **GitHub**: Code at https://github.com/tjcreedy/phylostuff and https://github.com/tjcreedy/mitocorrect — no tree data files stored there.

## Retrieval Log

| Source | Attempt | Result |
|--------|---------|--------|
| OUP journal page (PDF) | fetch_paper.py HTTP 403 | Failed |
| bioRxiv PDF direct curl | HTTP 403 (Cloudflare) | Failed |
| Unpaywall | No OA location | Failed |
| PMC full text (PMC13048007) | get_full_text_article MCP | SUCCESS — full text retrieved |
| Dryad API v2 | 404 / "cannot be viewed" | Failed — dataset private/embargoed |
| Dryad DOI redirect | 404 | Failed |
| bioRxiv JATS XML | Empty/blocked | Failed |
| OUP article page (HTML) | WebFetch | Partial success — supplement list extracted |

Retrieved: 2026-05-03
