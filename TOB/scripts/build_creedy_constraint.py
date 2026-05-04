#!/usr/bin/env python3
"""
build_creedy_constraint.py
Build IQ-TREE multifurcating constraint Newick from Creedy et al. 2025
narrative constraint nodes (43 CSV rows) + TOB taxa.

Outputs:
  TOB/data/creedy2025_constraint_fallback.nwk
  TOB/data/creedy2025_constraint_taxon_map.csv
  TOB/literature/notes/creedy2025_constraint_fallback_notes.md
"""

import csv
import collections
import os

# ---------------------------------------------------------------
# PATHS
# ---------------------------------------------------------------
BASE = "/Users/blackmon/Desktop/GitHub/SCARAB/TOB"
ASSEMBLY_CSV  = os.path.join(BASE, "data/best_assembly_per_species.csv")
BOUCHARD_CSV  = os.path.join(BASE, "data/bouchard2024_ncbi_reconciliation.csv")
OUT_NWK  = os.path.join(BASE, "data/creedy2025_constraint_fallback.nwk")
OUT_MAP  = os.path.join(BASE, "data/creedy2025_constraint_taxon_map.csv")
OUT_NOTES= os.path.join(BASE, "literature/notes/creedy2025_constraint_fallback_notes.md")

# ---------------------------------------------------------------
# BOUCHARD FAMILY -> SUPERFAMILY MAP
# ---------------------------------------------------------------
fam_to_superfam = {}
with open(BOUCHARD_CSV) as fh:
    for row in csv.DictReader(fh):
        fam = row["bouchard_family"].strip()
        sf  = row["bouchard_superfamily"].strip()
        if fam and sf:
            fam_to_superfam[fam.lower()] = sf

# Hand entries for families absent from Bouchard superfamily column
EXTRA_SF = {
    "carabidae":      "Caraboidea",
    "cicindelidae":   "Caraboidea",
    "rhysodidae":     "Caraboidea",
    "dytiscidae":     "Dytiscoidea",
    "amphizoidae":    "Dytiscoidea",
    "aspidytidae":    "Dytiscoidea",
    "meruidae":       "Dytiscoidea",
    "noteridae":      "Dytiscoidea",
    "hygrobiidae":    "Dytiscoidea",
    "trachypachidae": "Trachypachoidea",
    "haliplidae":     "Haliploidea",
    "silphidae":      "Staphylinoidea",
    "apionidae":      "Curculionoidea",
    "erirhinidae":    "Curculionoidea",
    "nosodendridae":  "Nosodendroidea",
    "derodontidae":   "Derodontoidea",
    "clambidae":      "Clamboidea",
    "eucinetidae":    "Clamboidea",
    "scirtidae":      "Scirtoidea",
    "decliniidae":    "Scirtoidea",
}
for k, v in EXTRA_SF.items():
    if not fam_to_superfam.get(k):
        fam_to_superfam[k] = v

# ---------------------------------------------------------------
# LOAD GENOME TAXA
# ---------------------------------------------------------------
genome_tips = []
with open(ASSEMBLY_CSV) as fh:
    for row in csv.DictReader(fh):
        family   = row["family"].strip()
        suborder = row["suborder"].strip()
        accession= row["winner_accession"].strip()
        # Skip Strepsiptera outgroups
        if suborder in ("Stylopidia", "Mengenillidia"):
            continue
        sf = fam_to_superfam.get(family.lower(), "")
        genome_tips.append({
            "tip":          accession,
            "genus_species":row["organism"].strip(),
            "family":       family,
            "superfamily":  sf,
            "suborder":     suborder,
            "source_tier":  "genome",
        })

# ---------------------------------------------------------------
# TIER-2 TRANSCRIPTOMES
# ---------------------------------------------------------------
TRANSCRIPTOMES = [
    {"tip": "Priacma_serrata_GACO00000000.1",
     "genus_species": "Priacma serrata",
     "family": "Cupedidae", "superfamily": "Cupedoidea",
     "suborder": "Archostemata", "source_tier": "transcriptome"},
    {"tip": "Micromalthus_debilis_GBKV00000000.1",
     "genus_species": "Micromalthus debilis",
     "family": "Micromalthidae", "superfamily": "Cupedoidea",
     "suborder": "Archostemata", "source_tier": "transcriptome"},
    {"tip": "Hydroscapha_natans_GACH00000000.1",
     "genus_species": "Hydroscapha natans",
     "family": "Hydroscaphidae", "superfamily": "Sphaeriusoidea",
     "suborder": "Myxophaga", "source_tier": "transcriptome"},
    {"tip": "Lepicerus_inaequalis_GACD00000000.1",
     "genus_species": "Lepicerus inaequalis",
     "family": "Lepiceridae", "superfamily": "Lepiceroidea",
     "suborder": "Myxophaga", "source_tier": "transcriptome"},
]

# ---------------------------------------------------------------
# HYMENOPTERA OUTGROUP ANCHORS
# ---------------------------------------------------------------
OUTGROUPS = [
    {"tip": "Apis_mellifera_GCF_003254395.2",
     "genus_species": "Apis mellifera",
     "family": "Apidae", "superfamily": "Apoidea",
     "suborder": "Hymenoptera", "source_tier": "outgroup"},
    {"tip": "Nasonia_vitripennis_GCF_009193385.2",
     "genus_species": "Nasonia vitripennis",
     "family": "Pteromalidae", "superfamily": "Chalcidoidea",
     "suborder": "Hymenoptera", "source_tier": "outgroup"},
    {"tip": "Athalia_rosae_GCF_000344095.2",
     "genus_species": "Athalia rosae",
     "family": "Tenthredinidae", "superfamily": "Tenthredinoidea",
     "suborder": "Hymenoptera", "source_tier": "outgroup"},
]

# ---------------------------------------------------------------
# SPHAERIUS DIY (pending — placeholder labels)
# ---------------------------------------------------------------
SPHAERIUS_DIY = [
    {"tip": "Sphaerius_sp1_DIY",
     "genus_species": "Sphaerius sp. 1",
     "family": "Sphaeriusidae", "superfamily": "Sphaeriusoidea",
     "suborder": "Myxophaga", "source_tier": "DIY_assembly"},
    {"tip": "Sphaerius_sp2_DIY",
     "genus_species": "Sphaerius sp. 2",
     "family": "Sphaeriusidae", "superfamily": "Sphaeriusoidea",
     "suborder": "Myxophaga", "source_tier": "DIY_assembly"},
]

ALL_TIPS = genome_tips + TRANSCRIPTOMES + OUTGROUPS + SPHAERIUS_DIY

# ---------------------------------------------------------------
# MEMBERSHIP HELPERS
# ---------------------------------------------------------------

def by_suborder(tips, *suborders):
    so = set(s.lower() for s in suborders)
    return [t for t in tips if t["suborder"].lower() in so]

def by_family(tips, *families):
    fams = set(f.lower() for f in families)
    return [t for t in tips if t["family"].lower() in fams]

def by_superfamily(tips, *superfamilies):
    sfs = set(s.lower() for s in superfamilies)
    return [t for t in tips if t["superfamily"].lower() in sfs]

def clade_star(tip_list):
    """Format a tip list as a monophyletic star node."""
    if not tip_list:
        return None
    if len(tip_list) == 1:
        return tip_list[0]["tip"]
    return "({})".format(",".join(t["tip"] for t in tip_list))

# ---------------------------------------------------------------
# DEFINE CLADE MEMBERSHIP
# ---------------------------------------------------------------
coleoptera_tips = [t for t in ALL_TIPS if t["suborder"] not in ("Hymenoptera",)]

polyphaga_tips     = by_suborder(coleoptera_tips, "Polyphaga")
adephaga_tips      = by_suborder(coleoptera_tips, "Adephaga")
myxophaga_tips     = by_suborder(coleoptera_tips, "Myxophaga")
archostemata_tips  = by_suborder(coleoptera_tips, "Archostemata")

# Adephaga subgroups
gyrinidae_tips          = by_family(adephaga_tips, "Gyrinidae")
haliplidae_tips_l       = by_family(adephaga_tips, "Haliplidae")
trachypachidae_tips_l   = by_family(adephaga_tips, "Trachypachidae")
geadephaga_tips         = by_family(adephaga_tips,
    "Carabidae", "Cicindelidae", "Rhysodidae", "Trachypachidae")
cicindelidae_tips       = by_family(geadephaga_tips, "Cicindelidae")
rhysodidae_tips_l       = by_family(geadephaga_tips, "Rhysodidae")
carabidae_tips_l        = by_family(geadephaga_tips, "Carabidae")
remaining_geadephaga    = [t for t in geadephaga_tips
                           if t["family"].lower() != "cicindelidae"]
hydradephaga_tips       = by_superfamily(adephaga_tips, "Dytiscoidea")
dytiscoidea_tips        = hydradephaga_tips

# Polyphaga series
scirtiformia_tips   = by_superfamily(polyphaga_tips, "Scirtoidea", "Clamboidea")
elateriformia_tips  = by_superfamily(polyphaga_tips,
    "Elateroidea", "Dascilloidea", "Buprestoidea", "Byrrhoidea", "Dryopoidea",
    "Rhinorhipoidea")
staphyliniformia_tips = by_superfamily(polyphaga_tips,
    "Hydrophiloidea", "Histeroidea", "Staphylinoidea", "Scarabaeoidea",
    "Nosodendroidea")
scarabaeiformia_tips  = by_superfamily(polyphaga_tips, "Scarabaeoidea")
bostrichiformia_tips  = by_superfamily(polyphaga_tips, "Bostrichoidea", "Derodontoidea")
cucujiformia_tips     = by_superfamily(polyphaga_tips,
    "Cleroidea", "Coccinelloidea", "Lymexyloidea", "Tenebrionoidea",
    "Cucujoidea", "Curculionoidea", "Chrysomeloidea",
    "Nitiduloidea", "Erotyloidea")

# Cucujiformia superfamilies
cleroidea_tips      = by_superfamily(cucujiformia_tips, "Cleroidea")
coccinelloidea_tips = by_superfamily(cucujiformia_tips, "Coccinelloidea")
lymexyloidea_tips   = by_superfamily(cucujiformia_tips, "Lymexyloidea")
tenebrionoidea_tips = by_superfamily(cucujiformia_tips, "Tenebrionoidea")
cucujoidea_ss_tips  = by_superfamily(cucujiformia_tips, "Cucujoidea")
curculionoidea_tips = by_superfamily(cucujiformia_tips, "Curculionoidea")
chrysomeloidea_tips = by_superfamily(cucujiformia_tips, "Chrysomeloidea")
lyme_tene_tips      = lymexyloidea_tips + tenebrionoidea_tips
curculo_chryso_tips = curculionoidea_tips + chrysomeloidea_tips

# Staphyliniformia superfamilies
hydrophiloidea_tips = by_superfamily(polyphaga_tips, "Hydrophiloidea")
histeroidea_tips    = by_superfamily(polyphaga_tips, "Histeroidea")
staphylinoidea_tips = by_superfamily(polyphaga_tips, "Staphylinoidea", "Nosodendroidea")
hydro_histo_tips    = hydrophiloidea_tips + histeroidea_tips
staphyl_scarab_tips = staphylinoidea_tips + scarabaeiformia_tips

# Elateriformia superfamilies
dascilloidea_tips   = by_superfamily(polyphaga_tips, "Dascilloidea")
elateroidea_tips    = by_superfamily(polyphaga_tips, "Elateroidea")
byrrhoidea_tips     = by_superfamily(polyphaga_tips, "Byrrhoidea")
buprestoidea_tips   = by_superfamily(polyphaga_tips, "Buprestoidea")
byr_bup_tips        = byrrhoidea_tips + buprestoidea_tips

# ---------------------------------------------------------------
# CLADE REGISTRY (for taxon map CSV)
# ---------------------------------------------------------------
CLADE_REGISTRY = collections.OrderedDict([
    ("Coleoptera",                     coleoptera_tips),
    ("Polyphaga",                      polyphaga_tips),
    ("Adephaga",                       adephaga_tips),
    ("Myxophaga",                      myxophaga_tips),
    ("Archostemata",                   archostemata_tips),
    ("Gyrinidae",                      gyrinidae_tips),
    ("remaining_Adephaga",             [t for t in adephaga_tips if t["family"].lower() != "gyrinidae"]),
    ("Geadephaga",                     geadephaga_tips),
    ("Hydradephaga",                   hydradephaga_tips),
    ("Cicindelidae",                   cicindelidae_tips),
    ("remaining_Geadephaga",           remaining_geadephaga),
    ("Carabidae",                      carabidae_tips_l),
    ("Dytiscoidea",                    dytiscoidea_tips),
    ("Scirtiformia",                   scirtiformia_tips),
    ("Elateriformia",                  elateriformia_tips),
    ("Staphyliniformia",               staphyliniformia_tips),
    ("Scarabaeiformia",                scarabaeiformia_tips),
    ("Bostrichiformia",                bostrichiformia_tips),
    ("Cucujiformia",                   cucujiformia_tips),
    ("Cleroidea",                      cleroidea_tips),
    ("Coccinelloidea",                 coccinelloidea_tips),
    ("Lymexyloidea",                   lymexyloidea_tips),
    ("Tenebrionoidea",                 tenebrionoidea_tips),
    ("Lymexyloidea+Tenebrionoidea",    lyme_tene_tips),
    ("Cucujoidea_ss",                  cucujoidea_ss_tips),
    ("Curculionoidea",                 curculionoidea_tips),
    ("Chrysomeloidea",                 chrysomeloidea_tips),
    ("Curculionoidea+Chrysomeloidea",  curculo_chryso_tips),
    ("Hydrophiloidea",                 hydrophiloidea_tips),
    ("Histeroidea",                    histeroidea_tips),
    ("Hydrophiloidea+Histeroidea",     hydro_histo_tips),
    ("Staphylinoidea",                 staphylinoidea_tips),
    ("Staphylinoidea+Scarabaeoidea",   staphyl_scarab_tips),
    ("Scarabaeoidea",                  scarabaeiformia_tips),
    ("Dascilloidea",                   dascilloidea_tips),
    ("Elateroidea",                    elateroidea_tips),
    ("Byrrhoidea",                     byrrhoidea_tips),
    ("Buprestoidea",                   buprestoidea_tips),
    ("Byrrhoidea+Buprestoidea",        byr_bup_tips),
])

# Diagnose
enforceable = []
dropped = []
for cn, tl in CLADE_REGISTRY.items():
    n = len(tl)
    if n < 2:
        dropped.append((cn, n, [t["tip"] for t in tl]))
    else:
        enforceable.append((cn, n, tl))

print("=== CLADE SIZES ===")
for cn, n, tl in enforceable:
    print("  ENFORCE  {:50s}  n={:4d}".format(cn, n))
for cn, n, tl in dropped:
    print("  DROPPED  {:50s}  n={:4d}  tips={}".format(cn, n, tl))

# ---------------------------------------------------------------
# BUILD CONSTRAINT NEWICK (bottom-up)
# ---------------------------------------------------------------

# --- Geadephaga ---
# If Cicindelidae present: (Cicindelidae, (Rhysodidae, Carabidae))
# If absent: flat star of Geadephaga taxa
geo_parts = []
if cicindelidae_tips:
    geo_parts.append(clade_star(cicindelidae_tips))
inner = []
if rhysodidae_tips_l:
    inner.append(clade_star(rhysodidae_tips_l))
if carabidae_tips_l:
    inner.append(clade_star(carabidae_tips_l))
if len(inner) > 1:
    geo_parts.append("({})".format(",".join(inner)))
elif inner:
    geo_parts.append(inner[0])
geadephaga_nwk = "({})".format(",".join(p for p in geo_parts if p)) if len(geo_parts) > 1 else (geo_parts[0] if geo_parts else clade_star(geadephaga_tips))

# --- Hydradephaga (Dytiscoidea star) ---
hydradephaga_nwk = clade_star(hydradephaga_tips)

# --- Remaining Adephaga (after Gyrinidae) ---
# Multifurcating: Haliplidae, Trachypachidae, Hydradephaga, Geadephaga
rem_parts = []
if haliplidae_tips_l:
    rem_parts.append(clade_star(haliplidae_tips_l))
if trachypachidae_tips_l:
    rem_parts.append(clade_star(trachypachidae_tips_l))
if hydradephaga_nwk:
    rem_parts.append(hydradephaga_nwk)
if geadephaga_nwk:
    rem_parts.append(geadephaga_nwk)
rem_adephaga_nwk = "({})".format(",".join(rem_parts)) if rem_parts else None

# --- Full Adephaga: (Gyrinidae, remaining_Adephaga) ---
ade_parts = [clade_star(gyrinidae_tips), rem_adephaga_nwk] if rem_adephaga_nwk else [clade_star(adephaga_tips)]
adephaga_nwk = "({})".format(",".join(p for p in ade_parts if p))

# --- Myxophaga + Archostemata ---
myx_arch_parts = []
if myxophaga_tips:
    myx_arch_parts.append(clade_star(myxophaga_tips))
if archostemata_tips:
    myx_arch_parts.append(clade_star(archostemata_tips))
myx_arch_nwk = "({})".format(",".join(myx_arch_parts)) if len(myx_arch_parts) > 1 else (myx_arch_parts[0] if myx_arch_parts else None)

# --- Elateriformia: (Dascilloidea (Elateroidea (Byrrhoidea+Buprestoidea))) ---
# Unassigned within Elateriformia (e.g. Dryopoidea) added as loose multifurcating tips
elat_assigned = set(t["tip"] for t in dascilloidea_tips + elateroidea_tips + byr_bup_tips)
elat_leftover = [t for t in elateriformia_tips if t["tip"] not in elat_assigned]
elat_inner = "({},{})".format(clade_star(elateroidea_tips), clade_star(byr_bup_tips)) if (elateroidea_tips and byr_bup_tips) else (clade_star(elateroidea_tips) if elateroidea_tips else None)
elat_parts = []
if dascilloidea_tips:
    elat_parts.append(clade_star(dascilloidea_tips))
if elat_inner:
    elat_parts.append(elat_inner)
if elat_leftover:
    elat_parts.append(clade_star(elat_leftover))
elateriformia_nwk = "({})".format(",".join(elat_parts)) if len(elat_parts) > 1 else (elat_parts[0] if elat_parts else clade_star(elateriformia_tips))

# --- Staphyliniformia: (Hydrophiloidea+Histeroidea)(Staphylinoidea+Scarabaeoidea) ---
staph_parts = []
if hydro_histo_tips:
    staph_parts.append(clade_star(hydro_histo_tips))
if staphyl_scarab_tips:
    staph_parts.append(clade_star(staphyl_scarab_tips))
staphyliniformia_nwk = "({})".format(",".join(staph_parts)) if len(staph_parts) > 1 else (staph_parts[0] if staph_parts else clade_star(staphyliniformia_tips))

# --- Cucujiformia: (Cleroidea (Coccinelloidea ((Lyme+Tene)(Cucuj_ss (Curculo+Chryso))))) ---
# Unassigned within Cucujiformia (Nitiduloidea, Erotyloidea) appended multifurcating
cuco_assigned = set(t["tip"] for t in
    cleroidea_tips + coccinelloidea_tips + lyme_tene_tips +
    cucujoidea_ss_tips + curculo_chryso_tips)
cuco_leftover = [t for t in cucujiformia_tips if t["tip"] not in cuco_assigned]
curculo_chryso_nwk = clade_star(curculo_chryso_tips)
cucuj_ss_nwk       = clade_star(cucujoidea_ss_tips)
inner_cuco = "({},{})".format(cucuj_ss_nwk, curculo_chryso_nwk) if (cucuj_ss_nwk and curculo_chryso_nwk) else (cucuj_ss_nwk or curculo_chryso_nwk)
lyme_tene_nwk = clade_star(lyme_tene_tips)
mid_cuco = "({},{})".format(lyme_tene_nwk, inner_cuco) if (lyme_tene_nwk and inner_cuco) else (lyme_tene_nwk or inner_cuco)
coccinelloidea_nwk = clade_star(coccinelloidea_tips)
outer_cuco = "({},{})".format(coccinelloidea_nwk, mid_cuco) if (coccinelloidea_nwk and mid_cuco) else (coccinelloidea_nwk or mid_cuco)
cleroidea_nwk = clade_star(cleroidea_tips)
# Build cucujiformia with leftover added at the top level
cuco_parts = []
if cleroidea_nwk:
    cuco_parts.append(cleroidea_nwk)
if outer_cuco:
    cuco_parts.append(outer_cuco)
if cuco_leftover:
    cuco_parts.append(clade_star(cuco_leftover))
cucujiformia_nwk = "({})".format(",".join(cuco_parts)) if len(cuco_parts) > 1 else (cuco_parts[0] if cuco_parts else clade_star(cucujiformia_tips))

# --- Bostrichiformia + Cucujiformia ---
bosto_nwk = clade_star(bostrichiformia_tips)
bosto_cuco_nwk = "({},{})".format(bosto_nwk, cucujiformia_nwk) if (bosto_nwk and cucujiformia_nwk) else (bosto_nwk or cucujiformia_nwk)

# --- Staphyliniformia + (Bostrichiformia + Cucujiformia) ---
staph_bosto_cuco = "({},{})".format(staphyliniformia_nwk, bosto_cuco_nwk) if (staphyliniformia_nwk and bosto_cuco_nwk) else (staphyliniformia_nwk or bosto_cuco_nwk)

# --- Elateriformia + upper Polyphaga ---
elat_upper = "({},{})".format(elateriformia_nwk, staph_bosto_cuco) if (elateriformia_nwk and staph_bosto_cuco) else (elateriformia_nwk or staph_bosto_cuco)

# --- Full Polyphaga: (Scirtiformia, elat_upper) ---
# Check for unassigned Polyphaga
assigned_set = set(t["tip"] for t in
    scirtiformia_tips + elateriformia_tips + staphyliniformia_tips +
    bostrichiformia_tips + cucujiformia_tips)
unassigned = [t for t in polyphaga_tips if t["tip"] not in assigned_set]
poly_parts = []
if scirtiformia_tips:
    poly_parts.append(clade_star(scirtiformia_tips))
if elat_upper:
    poly_parts.append(elat_upper)
if unassigned:
    poly_parts.append(clade_star(unassigned))
polyphaga_nwk = "({})".format(",".join(poly_parts)) if len(poly_parts) > 1 else (poly_parts[0] if poly_parts else clade_star(polyphaga_tips))

# --- Root: (outgroups, (Polyphaga, (Adephaga, Myx+Arch))) ---
coleoptera_nwk = "({},{})".format(polyphaga_nwk, "({},{})".format(adephaga_nwk, myx_arch_nwk)) if myx_arch_nwk else "({},{})".format(polyphaga_nwk, adephaga_nwk)
outgroup_nwk = clade_star(OUTGROUPS)
full_nwk = "({},{});".format(outgroup_nwk, coleoptera_nwk)

if unassigned:
    print("\nWARN: {} Polyphaga tips unassigned to any series:".format(len(unassigned)))
    for t in unassigned[:5]:
        print("  ", t["tip"], t["family"], t["superfamily"])

print("\nNewick length (chars):", len(full_nwk))
print("Preview:", full_nwk[:300])

# ---------------------------------------------------------------
# WRITE NWK
# ---------------------------------------------------------------
with open(OUT_NWK, "w") as fh:
    fh.write(full_nwk + "\n")
print("\nWrote:", OUT_NWK)

# ---------------------------------------------------------------
# WRITE TAXON MAP CSV
# ---------------------------------------------------------------
tip_to_clades = collections.defaultdict(list)
for clade_name, tip_list in CLADE_REGISTRY.items():
    for t in tip_list:
        tip_to_clades[t["tip"]].append(clade_name)

with open(OUT_MAP, "w") as fh:
    writer = csv.writer(fh)
    writer.writerow(["tip_label","source_tier","family","superfamily","suborder","which_creedy_clades"])
    for t in ALL_TIPS:
        clades = "|".join(tip_to_clades.get(t["tip"], []))
        writer.writerow([
            t["tip"], t["source_tier"], t["family"],
            t.get("superfamily",""), t["suborder"], clades,
        ])
print("Wrote:", OUT_MAP)

# ---------------------------------------------------------------
# WRITE NOTES MD
# ---------------------------------------------------------------
n_all      = len(ALL_TIPS)
n_coleo    = len(coleoptera_tips)
n_enforce  = len(enforceable)
n_drop     = len(dropped)

lines = [
    "# Creedy 2025 Constraint Fallback -- Notes",
    "",
    "Generated by: `TOB/scripts/build_creedy_constraint.py`",
    "Date: 2026-05-03",
    "",
    "## Label Scheme",
    "",
    "| Source tier | Label format | Example |",
    "|-------------|-------------|---------|",
    "| Genome assembly (574 species) | `<assembly_accession>` | `GCA_035320865.1` |",
    "| Tier-2 transcriptome (4 spp) | `<Genus>_<species>_<TSA_accession>` | `Priacma_serrata_GACO00000000.1` |",
    "| Sphaerius DIY assemblies (2 spp) | `<Genus>_<species>_DIY` | `Sphaerius_sp1_DIY` |",
    "| Hymenoptera outgroups (3 spp) | `<Genus>_<species>_<RefSeq_accession>` | `Apis_mellifera_GCF_003254395.2` |",
    "",
    "Tip labels must be propagated identically into BUSCO/ASTRAL/IQ-TREE sample names.",
    "For genome tips, the BUSCO output directory must be named `<accession>/` exactly.",
    "For transcriptomes and outgroups, the FASTA header prefix must match the tip label above.",
    "",
    "## Coverage Summary",
    "",
    "| Category | Count |",
    "|----------|-------|",
    "| Total TOB tips in constraint tree | {} |".format(n_all),
    "| Coleoptera tips | {} |".format(n_coleo),
    "| Genome assemblies | {} |".format(len(genome_tips)),
    "| Tier-2 transcriptomes | 4 |",
    "| Hymenoptera outgroup anchors | 3 |",
    "| Sphaerius DIY (pending) | 2 |",
    "| Creedy clades enforced (>=2 TOB taxa) | {} |".format(n_enforce),
    "| Creedy clades dropped (<2 TOB taxa) | {} |".format(n_drop),
    "",
    "## Creedy Clades Enforced as Monophyletic",
    "",
]
for cn, n, tl in enforceable:
    lines.append("- **{}** -- {} TOB tips".format(cn, n))

lines += [
    "",
    "## Creedy Clades Dropped (< 2 TOB taxa)",
    "",
]
if dropped:
    for cn, n, tl in dropped:
        lines.append("- **{}** -- {} TOB tips  (tips: {})".format(cn, n, tl))
else:
    lines.append("_(none)_")

lines += [
    "",
    "## Mapping Issues for Heath to Review",
    "",
    "1. **Carabidae / Dytiscidae superfamily** -- Bouchard2024 leaves these blank (they are the",
    "   nominate families of their superfamilies). Manually assigned Carabidae -> Caraboidea,",
    "   Dytiscidae -> Dytiscoidea.",
    "",
    "2. **Silphidae** -- Bouchard2024 entry absent; assigned to Staphylinoidea.",
    "",
    "3. **Apionidae / Erirhinidae** -- Bouchard2024 absent; assigned to Curculionoidea.",
    "",
    "4. **Strepsiptera** -- Mengenillidae/Stylopidae/Xenidae rows in best_assembly_per_species.csv",
    "   were excluded from the constraint tree (not Coleoptera).",
    "",
    "5. **Haliplidae placement** -- Creedy does not specify Haliplidae within Adephaga;",
    "   placed as multifurcating within remaining Adephaga (after Gyrinidae sister node).",
    "",
    "6. **Sphaerius DIY labels** -- Placeholder labels Sphaerius_sp1_DIY / Sphaerius_sp2_DIY.",
    "   Update to accession-based labels once assemblies are deposited.",
    "",
    "7. **Suborder topology** -- (Polyphaga (Adephaga (Myxophaga+Archostemata))) follows the",
    "   nuclear phylogenomic result in Creedy et al. 2025. The Dayhoff+90% exception is noted",
    "   in the CSV but not encoded; the nuclear result is used as the fallback constraint.",
    "",
    "8. **Cucujoidea sensu stricto scope** -- Bouchard superfamily label 'Cucujoidea' covers",
    "   Cryptophagidae, Cucujidae, Silvanidae, Laemophloeidae, Phalacridae, etc. Families",
    "   Bouchard assigns to Nitiduloidea or Erotyloidea are inside Cucujiformia but not",
    "   constrained to Cucujoidea s.s. here.",
    "",
    "## IQ-TREE Usage",
    "",
    "```bash",
    "iqtree2 -s concat_alignment.phy -m LG+C60+F+R \\",
    "        -g creedy2025_constraint_fallback.nwk \\",
    "        --prefix TOB_constrained -B 1000 -T AUTO",
    "```",
    "",
    "The `-g` flag enforces constraint tree topology (monophyly of all constrained clades).",
    "Taxa absent from the constraint tree are placed freely by IQ-TREE.",
]

with open(OUT_NOTES, "w") as fh:
    fh.write("\n".join(lines) + "\n")
print("Wrote:", OUT_NOTES)

print("\n=== DONE ===")
print("Total tips: {}  |  Coleoptera: {}  |  Enforced clades: {}  |  Dropped: {}".format(
    n_all, n_coleo, n_enforce, n_drop))
