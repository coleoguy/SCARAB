# HOWTO 2.6: Build Constraint Phylogenetic Tree

**Phase:** Phase 2 - Genome Inventory & QC
**Task:** 2.6 Construct Phylogenetic Constraint Tree for Alignment
**Timeline:** Day 6 (~0.5 day, can run in parallel after Task 2.4 complete)
**Executor:** Team

---

## OBJECTIVE

Build a phylogenetic constraint tree incorporating all selected Coleoptera species (from curated_genomes.csv). The tree defines the evolutionary relationships to be respected during whole-genome alignment (progressiveCactus uses this as a constraint). The topology should be based on published phylogenetic literature with species assignments derived from Task 2.4 clade curation.

**Output acceptance criteria:** Valid Newick format, all species included, monophyletic major clades, topology well-cited

---

## INPUT

**From Task 2.4:** `SCARAB/data/genomes/curated_genomes.csv` (all rows, includes clade_position)

---

## OUTPUT (Exact Filename & Location)

### Output: Constraint Tree in Newick Format
**Path:** `SCARAB/data/genomes/constraint_tree.nwk`

**Format:** Newick tree file (text, one line, rooted binary tree)

**Example structure (simplified, not real data):**
```newick
(((Tribolium_castaneum:1,Tenebrio_molitor:1)Tenebrionidae:5,(Dendroctonus_ponderosae:1,Ips_typographus:1)Scolytinae:5)Polyphaga:10,(Carabdis_granulatus:1,Pterostichus_vernalis:1)Carabidae)Coleoptera;
```

**Key requirements:**
- **Rooted tree:** One outgroup to root (e.g., earliest-diverging Coleoptera clade)
- **Binary (bifurcating):** Each internal node has exactly 2 children (may include polytomies if uncertainty)
- **All species included:** All organisms from curated_genomes.csv (include_yn="YES" AND "NO" both included, but see note below)
- **Species names:** Underscores instead of spaces (e.g., "Tribolium_castaneum" not "Tribolium castaneum")
- **Branch lengths optional:** Can be 1:1 (all equal) or estimated from literature
- **Valid syntax:** Can be read by R `ape::read.tree()` without errors

---

## COLEOPTERA PHYLOGENETIC BACKBONE

The constraint tree is based on published Coleoptera phylogeny. Key references:

**Primary topology sources (pick one or combine):**
1. **Slipinski et al. (2011)** - Coleoptera comprehensive phylogeny, Zoological Scripta 40:472-476
   - Defines major clades: Archaeorhyncha, Myxophaga, Adephaga, Polyphaga
   - Polyphaga subgroups: Staphylinomorpha, Scarabaeoidea, Curculionoidea, Elateroidea, Cucujoidea, etc.

2. **McKenna et al. (2015)** - Phylogenomic resolution of Coleoptera, Systematic Entomology 40:35-53
   - More recent, includes molecular data
   - Similar overall topology but updated relationships

3. **Hunt et al. (2007)** - A comprehensive phylogeny of beetles reflecting the new classification, Zoological Journal of the Linnean Society 148:1-158
   - Foundational, widely used, very detailed

4. **Recent phylogenomic studies** - Search Google Scholar for "Coleoptera phylogenomics [2018-2026]"

**Strategy:** Use one well-established backbone (e.g., Slipinski), then assign your specific species to clades based on their clade_position from Task 2.4.

---

## BUILDING THE TREE (Workflow)

### Step 1: Extract Species List and Clade Assignments

```r
library(ape)
library(dplyr)

# Load curated genomes
curated <- read.csv("SCARAB/data/genomes/curated_genomes.csv", stringsAsFactors = FALSE)

# Extract species to include in tree
species_list <- curated %>%
  filter(!is.na(clade_position)) %>%
  select(organism, family, clade_position) %>%
  arrange(clade_position, organism)

cat("Species to include in constraint tree:\n")
print(head(species_list, 20))

cat(paste("\nTotal species:", nrow(species_list), "\n"))

# Summarize by clade
cat("\nSpecies by clade:\n")
print(table(species_list$clade_position))
```

---

### Step 2: Define Clade Backbone Topology

Create a text file defining the major clades and their hierarchical relationships. Example structure:

```
Coleoptera
├── Archaeorhyncha (basal, may have 1-2 species)
├── Myxophaga (basal aquatic, may have few species)
├── Adephaga
│   ├── Carabidae (ground beetles)
│   ├── Dytiscidae (diving beetles)
│   └── Other Adephaga
└── Polyphaga
    ├── Staphylinomorpha
    ├── Scarabaeoidea
    ├── Curculionoidea
    ├── Elateroidea
    ├── Cucujoidea
    └── Other Polyphaga
```

---

### Step 3: Assign Species to Clades

From curated_genomes.csv, your clade_position assignments tell you where each species goes. Organize them by clade:

```r
# Group species by clade
by_clade <- split(species_list, species_list$clade_position)

for (clade in names(by_clade)) {
  cat(paste("\n", clade, ":\n"))
  cat(paste("  ", paste(by_clade[[clade]]$organism, collapse=", "), "\n"))
}
```

---

### Step 4: Construct Newick String Manually (or Programmatically)

**Option A: Manual Construction (For ~50 species, feasible)**

Build Newick string by hand, organizing species into nested parentheses:

**Example template:**
```newick
(
  (
    (Archaeorhyncha_species1:1)Archaeorhyncha:5,
    (Myxophaga_species1:1)Myxophaga:5
  )Basal:10,
  (
    ((Carabid_species1:1,Carabid_species2:1)Carabidae:5)Adephaga:10,
    (
      ((Staphylin_species1:1,Staphylin_species2:1)Staphylinomorpha:5),
      ((Scarab_species1:1,Scarab_species2:1)Scarabaeoidea:5),
      ((Curcul_species1:1,Curcul_species2:1)Curculionoidea:5),
      ((Elatero_species1:1,Elatero_species2:1)Elateroidea:5),
      ((Cucujoi_species1:1,Cucujoi_species2:1)Cucujoidea:5)
    )Polyphaga:8
  )Higher:15
)Coleoptera;
```

**Tips:**
- Replace species with actual names from your list
- Use underscores in species names: Tribolium_castaneum
- Each nested level adds 5-10 branch length units (arbitrary but helps readability)
- Root the tree with the earliest-diverging clade (Archaeorhyncha or Myxophaga)

---

**Option B: Programmatic Construction with R**

```r
library(ape)
library(dplyr)

# Load curated genomes
curated <- read.csv("SCARAB/data/genomes/curated_genomes.csv", stringsAsFactors = FALSE)
species_info <- curated %>%
  filter(!is.na(clade_position)) %>%
  arrange(clade_position, organism)

# Replace spaces with underscores
species_info$organism_newick <- gsub(" ", "_", species_info$organism)

# Define clade structure (manual mapping from clade_position to nested structure)
# This requires subjective decisions about tree structure

# Create a simple backbone tree
# (Archaeorhyncha, (Myxophaga, (Adephaga, Polyphaga)))

# Helper function to create subtrees
make_clade <- function(species_names, clade_name) {
  if (length(species_names) == 1) {
    return(species_names[1])
  } else if (length(species_names) == 2) {
    return(paste0("(", species_names[1], ":1,", species_names[2], ":1)", clade_name, ":1"))
  } else {
    # For >2 species, create balanced binary tree or polytomy
    mid <- ceiling(length(species_names) / 2)
    left <- make_clade(species_names[1:mid], "")
    right <- make_clade(species_names[(mid+1):length(species_names)], "")
    return(paste0("(", left, ",", right, ")", clade_name, ":1"))
  }
}

# Organize species by clade and build tree
clades_defined <- list(
  Archaeorhyncha = species_info$organism_newick[species_info$clade_position == "Archaeorhyncha"],
  Myxophaga = species_info$organism_newick[species_info$clade_position == "Myxophaga"],
  Adephaga = species_info$organism_newick[species_info$clade_position == "Adephaga"],
  Polyphaga = species_info$organism_newick[species_info$clade_position == "Polyphaga"]
)

# Build clades (remove empty clades)
clades_defined <- clades_defined[sapply(clades_defined, length) > 0]

# Build overall tree
clade_strings <- mapply(make_clade, clades_defined, names(clades_defined), SIMPLIFY = FALSE)
backbone <- paste0("(", paste(unlist(clade_strings), collapse = ","), ")Coleoptera;")

# Validate
tree <- read.tree(text = backbone)
cat(paste("Tree has", length(tree$tip.label), "species\n"))

# Save
write.tree(tree, "SCARAB/data/genomes/constraint_tree.nwk")
cat("Constraint tree saved\n")
```

---

### Step 5: Validate Newick Format

```r
library(ape)

# Read tree and check validity
tree <- tryCatch({
  read.tree("SCARAB/data/genomes/constraint_tree.nwk")
}, error = function(e) {
  cat("ERROR reading tree:", e$message, "\n")
  return(NULL)
})

if (!is.null(tree)) {
  cat("Tree is valid Newick\n")
  cat(paste("Number of species:", length(tree$tip.label), "\n"))
  cat(paste("Is rooted:", is.rooted(tree), "\n"))
  cat(paste("Is binary:", is.binary(tree), "\n"))

  # Check all species from curated genome present
  species_newick <- gsub(" ", "_", curated$organism[curated$include_yn == "YES"])
  in_tree <- sum(species_newick %in% tree$tip.label)
  cat(paste("Species in tree:", in_tree, "/", length(species_newick), "\n"))

  # List any missing species
  missing <- species_newick[!(species_newick %in% tree$tip.label)]
  if (length(missing) > 0) {
    cat("Missing from tree:\n")
    print(missing)
  }
}
```

---

## CLADE DEFINITIONS (Reference for Assignments)

Use these major Coleoptera clades when building tree:

| Clade | Families (Examples) | Notes |
|-------|-------------------|-------|
| **Archaeorhyncha** | Micropeplidae, Archostemata | Basal, small families |
| **Myxophaga** | Hydroscaphidae, Sphaeriusidae | Aquatic, basal |
| **Adephaga** | Carabidae, Dytiscidae, Gyrinidae | Mostly predatory |
| **Polyphaga_Staphylinomorpha** | Staphylinidae, Silphidae | Rove beetles |
| **Polyphaga_Scarabaeoidea** | Scarabaeidae, Lucanidae | Dung/rhinoceros beetles |
| **Polyphaga_Curculionoidea** | Curculionidae, Brentidae | Weevils |
| **Polyphaga_Elateroidea** | Elateridae, Lampyridae | Click beetles, fireflies |
| **Polyphaga_Cucujoidea** | Tenebrionidae, Coccinellidae | Diverse small families |

---

## BRANCH LENGTHS (Optional)

You can set all branch lengths to 1 (for equal weighting) or estimate from literature:

**Simple approach (all equal):**
```
(species1:1,species2:1):1;
```

**With estimated branch lengths (more complex):**
- Requires additional phylogenetic analysis or estimates from published trees
- Advanced topic; often not critical for constraint tree

**Recommendation:** Use uniform branch lengths (1) for constraint tree; progressiveCactus uses topology primarily, not branch length

---

## EXAMPLE CONSTRAINT TREE (Real Data Format)

```newick
((((((Tribolium_castaneum,Tenebrio_molitor),Alphitobius_diaperinus),Blaps_mortisaga),Melanostoma_picicornis),((((Dendroctonus_ponderosae,Ips_typographus),Xyleborinus_saxesenii),(Phyllobius_pomacei,Sitobion_avenae)),(((Carabdis_granulatus,Pterostichus_vernalis),Cicindela_campestris),((Dytiscus_marginalis,Hydaticus_transversalis),(Gyrinus_minutus))))),(((Silpha_atrata,Phosphuga_atrata),(Creophilus_maxillosus,Staphylinus_olens))));
```

---

## ACCEPTANCE CRITERIA

Task 2.6 is complete when:

- [ ] Constraint tree in valid Newick format (readable by `ape::read.tree()`)
- [ ] Tree is rooted (one root node)
- [ ] Tree is binary or mostly binary (may have polytomies for uncertain relationships)
- [ ] All selected species (include_yn="YES") are in the tree
- [ ] Species names use underscores (no spaces): Genus_species
- [ ] Major clades (Archaeorhyncha, Myxophaga, Adephaga, Polyphaga) are monophyletic
- [ ] Topology is justified by citation to published literature (Slipinski, McKenna, Hunt, etc.)
- [ ] File saved in exact path: `SCARAB/data/genomes/constraint_tree.nwk`
- [ ] File is plain text (one line Newick string, ends with semicolon)

---

## TROUBLESHOOTING

**"Error in read.tree(): Expected ')' but found..."**
→ Check Newick syntax: missing parentheses, semicolon, or misspelled species name

**"Tree has only N species but I input M"**
→ Check that all species names exactly match (underscores, capitalization)

**"Tree is not rooted"**
→ Ensure tree has a true root; may need to specify outgroup

---

## NEXT STEP

Once Task 2.6 is complete, proceed to **HOWTO_07_qc_report.md** (Task 2.7, final synthesis).

---

*HOWTO 2.6 | Phase 2 Task 6 | SCARAB | Draft: 2026-03-21*
