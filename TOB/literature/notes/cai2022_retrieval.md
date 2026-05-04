# Cai et al. 2022 — Retrieval and Extraction Notes

## Citation
Cai C, Tihelka E, Giacomelli M, Lawrence JF, Slipinski A, et al. 2022.
Integrated phylogenomics and fossil data illuminate the evolution of beetles.
*Royal Society Open Science* 9: 211771.
DOI: 10.1098/rsos.211771
PMID: 35345430 | PMC: PMC8941382

## Files Retrieved

| File | Source | Size | Notes |
|------|--------|------|-------|
| `literature/pdfs/Cai_2022_RoyalSociety_rsos_211771.pdf` | CORE.ac.uk (Bristol Explore repository) | 1.1 MB, 20 pp | Publisher CC-BY PDF |
| `literature/pdfs/Cai_2022_supplementary.pdf` | Figshare collection 5894006, article 19355213, file 34704922 | 1.3 MB, 98 pp | Full supplementary document |

Figshare API endpoint used: `https://api.figshare.com/v2/articles/19355213/files`
Direct download: `https://ndownloader.figshare.com/files/34704922`

## Supplementary Document Structure

| Section | Pages (PDF) |
|---------|------------|
| Taxonomic treatment | 2–12 |
| Notes on beetle classification | 13–15 |
| Classification of beetles (families/subfamilies) | 16–33 |
| **Phylogenetic and age justifications for fossil calibrations** | **34–54** |
| Beetle phylogeny and evolutionary timescale (figures S1–S10) | 55–73 |
| Supplementary references | 74–98 |

## Calibration Table Source

All 57 calibrations were extracted from pages 34–54 of `Cai_2022_supplementary.pdf`.
The calibrations are presented as free-form prose (not a numbered table), one
per node, with consistent structure:
- Node N: [clade split]: [min Ma] – [max Ma]
- Fossil taxon and specimen
- Phylogenetic justification
- Minimum age
- Soft maximum age
- Age justification

**No separate Table S2 file exists.** The paper's Methods section refers to
"electronic supplementary material, table S2" but this is the prose section
starting page 34 of the single supplementary PDF.

## Extraction Method

Text extracted via pdfplumber (Python) from pages 33–54.
Regex parsing on node headers, fossil lines, and age lines.
All 57 nodes confirmed extracted; verified against node numbers on Figure 1
of main paper (calibrated nodes 1–57 labeled on phylogeny).

## Calibration Summary

| Category | Count |
|----------|-------|
| Total calibrations | 57 |
| Applicable at TOB family level | 51 (including node 1 as root-bounding anchor is possible, but node 1 is marked Y here since it can bound the root) |
| Not applicable (outgroup or subfamily-level) | 6 (nodes 1, 27, 28, 29, 56, 57) |
| Strictly applicable at TOB internal nodes | 51 |
| Burmese amber calibrations (total) | 9 |
| Burmese amber AND applicable at TOB scope | 8 |

**Nodes not applicable at TOB scope** (outgroup or subfamily-level; 6 total):
- Node 1: Neuropterida–Coleoptera split (above crown Coleoptera; outgroup node)
- Node 27: Paederinae–Staphylininae split (Staphylinidae subfamilies)
- Node 28: Silphinae–Staphylinidae partim (same fossil as node 25)
- Node 29: Apateticinae–Osoriinae split (Staphylinidae subfamilies); also Burmese amber
- Node 56: Sagrinae–Bruchinae split (Chrysomelidae subfamilies)
- Node 57: Galerucinae–Chrysomelinae split (Chrysomelidae subfamilies)

Node 1 is the outgroup-to-Coleoptera split (Neuropterida sister node). Marked N
in CSV. It could serve as a maximum-age root anchor in treePL if outgroups are
included; if so, effectively 52 usable constraints.

**Burmese amber calibrations** (9 nodes total, 8 applicable at TOB scope):
- Node 12: Crown Psephenidae (98.17 Ma) — applicable
- Node 17: Elateridae(Lissomini)–Lycidae (98.17 Ma) — applicable
- Node 18: Lampyridae–Phengodidae+Rhagophthalmidae (98.17 Ma) — applicable
- Node 29: Apateticinae–Osoriinae, Staphylinidae (98.17 Ma) — subfamily-level, NOT applicable
- Node 31: Crown Bostrichidae (98.17 Ma) — applicable
- Node 37: Rhipiphoridae–Mordellidae (98.17 Ma) — applicable
- Node 41: Crown Zopheridae (98.17 Ma) — applicable
- Node 44: Crown Endomychidae (98.17 Ma) — applicable
- Node 50: Crown Silvanidae (98.17 Ma) — applicable

All Burmese amber nodes share the same minimum age constraint: 98.17 Ma
(lowermost Cenomanian, from Noije Bum, Hukawng Valley, northern Myanmar).
The controversy over Burmese amber age (91–99 Ma range debated in literature)
means these 8 applicable nodes should all be varied together in a sensitivity analysis.

## Assemblage Summary

| Assemblage | Node count |
|------------|-----------|
| Daohugou/Jiulongshan Formation, Inner Mongolia (Middle Jurassic ~165 Ma) | 18 |
| Burmese amber, Myanmar (lowermost Cenomanian ~98.17 Ma) | 10 |
| Yixian Formation / Jehol Biota, Liaoning (Early Cretaceous ~122.2 Ma) | 7 |
| Lebanese amber, Lebanon (Barremian ~125 Ma) | 6 |
| Karabastau Formation, Karatau, Kazakhstan (Late Jurassic ~155 Ma) | 5 |
| Crato Formation, Brazil (Aptian ~112.6 Ma) | 2 |
| Eocene French amber / Oise amber (~53 Ma) | 2 |
| Late Permian (various, Changhsingian) | 2 |
| Various other single-site | 5 |

## Caveats

1. Node 28 reuses the same fossil specimen as node 25 (Mesecanus communis); this
   is explicit in the paper ("As for node 25"). In treePL, these cannot both be
   applied if they share the same MRCA node on the TOB tree.

2. Node 1 calibrates a node outside crown Coleoptera (the Neuropterida split).
   Whether it is usable in treePL depends on whether the TOB analysis includes
   outgroup taxa resolving this node. Marked `applies_at_TOB_scope = N` in CSV
   but flagged here as potentially useful as a root bounding constraint.

3. Soft maximum ages: Cai et al. use "soft" bounds throughout (2.5% tail
   probability per MCMCtree convention). treePL uses hard bounds by default;
   operators should decide whether to use the Cai maxima as hard or soft.

4. Node 45 (Crown Coccinellidae): authors state soft max = 125 Ma (Lebanese amber);
   the CSV correctly reflects min=53 Ma, max=125 Ma.

5. Node 4 soft maximum is listed as 251.878 Ma in the text, not 251.878 as written
   in the node header (155 Ma – 251.878 Ma). Both correct in CSV.
