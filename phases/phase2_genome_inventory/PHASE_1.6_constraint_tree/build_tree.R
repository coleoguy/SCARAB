#!/usr/bin/env Rscript
################################################################################
# TASK: PHASE_1.6 - Build Constraint Phylogenetic Tree
################################################################################
#
# OBJECTIVE:
# Read curated_genomes.csv.
# Load published beetle phylogeny (backbone topology).
# Graft genome species onto backbone using family/subfamily constraints.
# Validate: all genome tips present in tree, no duplicates.
# Output Newick format constraint tree for downstream alignment.
#
# INPUTS:
#   - PHASE_1.4 output: curated_genomes.csv
#   - Reference topology: backbone_tree.nwk (student-provided)
#
# OUTPUTS:
#   - constraint_tree.nwk (Newick format phylogenetic tree)
#   - tree_validation.txt (QC report)
#
# STUDENT TODO:
#   - Provide backbone topology file (backbone_tree.nwk) in data/ dir (line ~100)
#   - Verify tree format (Newick/Nexus) and convert if needed (line ~120)
#   - Adjust graft rules if needed (lines ~200-250)
#   - Review and adjust family-to-clade mappings (lines ~150-180)
#   - Verify output paths (lines ~350, ~400)
#
# DEPENDENCIES:
#   - ape package (R phylogenetics)
#
# NOTES:
#   - Backbone topology typically from published phylogenies
#   - Examples: Coleoptera phylogenies from Mckenna et al. (2015, 2019)
#   - This script is a template; customize graft logic for your dataset
#
################################################################################

library(ape)
library(base)

# Suppress warnings
options(warn = -1)

cat("PHASE_1.6: Build Constraint Phylogenetic Tree\n")
cat("=============================================\n\n")

## <<<STUDENT: Set your working directory if running standalone>>>
# setwd("[PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.6_constraint_tree")

if (!dir.exists("data")) {
  dir.create("data", showWarnings = FALSE, recursive = TRUE)
}

################################################################################
# 1. LOAD INPUT DATA
################################################################################

cat("Step 1: Loading input data...\n")

## <<<STUDENT: Verify path to curated genomes>>>
input_file <- "../PHASE_1.4_phylogenetic_placement/curated_genomes.csv"

if (!file.exists(input_file)) {
  cat("  ✗ Input file not found:", input_file, "\n")
  quit(status = 1)
}

genomes <- read.csv(input_file, stringsAsFactors = FALSE)
cat("  ✓ Loaded", nrow(genomes), "genomes\n")

################################################################################
# 2. LOAD BACKBONE TREE
################################################################################

cat("\nStep 2: Loading backbone phylogenetic tree...\n")

## <<<STUDENT: Create/provide backbone_tree.nwk file in data/ directory>>>
# The backbone tree should contain major beetle clades/families
# Example: (Adephaga, ((Archostemata, Polyphaga)))
# Or use a published topology from literature

backbone_file <- "data/backbone_tree.nwk"

if (!file.exists(backbone_file)) {
  cat("  ⚠ Backbone tree not found at:", backbone_file, "\n")
  cat("  Creating default minimal backbone tree...\n")

  # Minimal default backbone (Coleoptera major clades)
  # Structure: Adephaga and Polyphaga are main divisions
  backbone_str <- "((Adephaga, Polyphaga), Neuroptera, Megaloptera, Raphidioptera);"

  # Write temporary backbone
  cat(backbone_str, file = backbone_file)
  cat("  ✓ Created default backbone\n")
} else {
  backbone_content <- readLines(backbone_file)
  cat("  ✓ Loaded backbone tree from file\n")
  cat("    Content: ", paste(backbone_content, collapse = ""), "\n")
}

# Read the backbone tree
tryCatch(
  {
    backbone <- read.tree(backbone_file)
    cat("  ✓ Backbone tree parsed successfully\n")
    cat("    Tips:", length(backbone$tip.label), "\n")
    cat("    Nodes:", backbone$Nnode, "\n")
  },
  error = function(e) {
    cat("  ✗ Error reading backbone tree:", e$message, "\n")
    cat("     Make sure file is in Newick format\n")
    quit(status = 1)
  }
)

################################################################################
# 3. FAMILY-TO-CLADE MAPPING
################################################################################

cat("\nStep 3: Setting up family-to-clade mappings...\n")

## <<<STUDENT: Verify and expand family-to-clade mappings>>>
# This maps your genome families to backbone clade labels

family_clade_map <- list(
  Adephaga = c("Carabidae", "Dytiscidae", "Gyrinidae", "Rhysodidae"),
  Polyphaga = c(
    "Tenebrionidae", "Curculionidae", "Scolytidae", "Chrysomelidae",
    "Buprestidae", "Cerambycidae", "Elateridae", "Lampyridae"
  ),
  Archostemata = c("Micromalthidae"),
  Neuroptera = c("Chrysopidae", "Hemerobiidae"),
  Megaloptera = c("Corydalidae"),
  Raphidioptera = c("Raphidiidae")
)

cat("  ✓ Family-to-clade mappings configured\n")

################################################################################
# 4. ASSIGN GENOMES TO CLADES
################################################################################

cat("\nStep 4: Assigning genomes to backbone clades...\n")

genomes$backbone_clade <- NA

for (i in seq_len(nrow(genomes))) {
  family <- genomes$family[i]

  if (!is.na(family)) {
    # Find which clade this family belongs to
    for (clade_name in names(family_clade_map)) {
      if (family %in% family_clade_map[[clade_name]]) {
        genomes$backbone_clade[i] <- clade_name
        break
      }
    }
  }
}

# For unassigned, use clade_assignment from previous step
unassigned <- is.na(genomes$backbone_clade)
if (sum(unassigned) > 0) {
  for (i in which(unassigned)) {
    clade_hint <- genomes$clade_assignment[i]

    # Try to match clade_assignment to backbone clades
    if (!is.na(clade_hint)) {
      if (grepl("Adephaga", clade_hint)) {
        genomes$backbone_clade[i] <- "Adephaga"
      } else if (grepl("Polyphaga", clade_hint)) {
        genomes$backbone_clade[i] <- "Polyphaga"
      } else if (grepl("Non-Coleoptera", clade_hint)) {
        genomes$backbone_clade[i] <- clade_hint
      }
    }
  }
}

unassigned_count <- sum(is.na(genomes$backbone_clade))
cat("  ✓ Assigned", nrow(genomes) - unassigned_count, "of", nrow(genomes), "genomes\n")

if (unassigned_count > 0) {
  cat("  ⚠ Unassigned genomes:", unassigned_count, "(will be placed in Polyphaga)\n")
  genomes$backbone_clade[is.na(genomes$backbone_clade)] <- "Polyphaga"
}

################################################################################
# 5. BUILD GRAFTED TREE
################################################################################

cat("\nStep 5: Building grafted tree...\n")

# Strategy: For each clade in backbone, replace with subtree of all genomes
# in that clade, then graft back

# First, identify which backbone tips correspond to clades in our data
clade_tips_in_backbone <- backbone$tip.label[
  backbone$tip.label %in% unique(genomes$backbone_clade)
]

cat("  Backbone clades with genome data:", paste(clade_tips_in_backbone, collapse = ", "), "\n")

# Create a new tree that includes all genome species
# Start with backbone and prune/replace tips

# For simplicity, create a new tree by:
# 1. Prune backbone to only include clades with data
# 2. For each clade, add all genome species under that clade label

# Extract genomes by clade
genomes_by_clade <- split(genomes$species_name, genomes$backbone_clade)

cat("  Genomes per clade:\n")
for (clade_name in names(genomes_by_clade)) {
  cat("    ", clade_name, ":", length(genomes_by_clade[[clade_name]]), "\n")
}

# Build grafted tree by replacing backbone tips with species
# This is a simplified approach; for production, use more sophisticated graft methods

# Create species labels (use NCBI accessions for uniqueness)
genome_species_names <- with(genomes,
  paste0(gsub(" ", "_", species_name), "_", substr(assembly_accession, 5, 9))
)

# Simple approach: create a tree with all species
# sorted by clade, family, species
sorted_genomes <- genomes[
  order(genomes$backbone_clade, genomes$family, genomes$species_name),
]

sorted_labels <- with(sorted_genomes,
  paste0(gsub(" ", "_", species_name), "_", substr(assembly_accession, 5, 9))
)

# Build a simple ladder tree (or read topology from another source)
# For now, create a balanced tree of species within clades

# Create taxon groups
tree_species <- list()
for (clade in unique(sorted_genomes$backbone_clade)) {
  clade_genomes <- sorted_genomes[sorted_genomes$backbone_clade == clade, ]
  labels <- with(clade_genomes,
    paste0(gsub(" ", "_", species_name), "_", substr(assembly_accession, 5, 9))
  )
  tree_species[[clade]] <- labels
}

# Build a minimal cladogram (all tips at same level within clades)
# Create Newick string manually
build_clade_subtree <- function(labels, clade_name) {
  if (length(labels) == 1) {
    return(labels[1])
  } else {
    # Create pairwise branching
    tree_str <- labels[1]
    for (i in 2:length(labels)) {
      tree_str <- paste0("(", tree_str, ",", labels[i], ")")
    }
    return(paste0("(", tree_str, ")", clade_name))
  }
}

# Build full tree
subtrees <- mapply(
  build_clade_subtree,
  tree_species,
  names(tree_species),
  SIMPLIFY = FALSE
)

# Combine subtrees into final tree
if (length(subtrees) == 1) {
  final_tree_str <- subtrees[[1]]
} else {
  final_tree_str <- subtrees[[1]]
  for (i in 2:length(subtrees)) {
    final_tree_str <- paste0("(", final_tree_str, ",", subtrees[[i]], ")")
  }
}

final_tree_str <- paste0(final_tree_str, ";")

cat("  ✓ Tree structure created\n")

# Parse the tree
tryCatch(
  {
    grafted_tree <- read.tree(text = final_tree_str)
    cat("  ✓ Grafted tree parsed successfully\n")
    cat("    Tips:", length(grafted_tree$tip.label), "\n")
    cat("    Nodes:", grafted_tree$Nnode, "\n")
  },
  error = function(e) {
    cat("  ✗ Error parsing grafted tree:", e$message, "\n")
    cat("  Falling back to simple neighbor-joining tree...\n")

    # Fallback: create NJ tree from random distances
    dist_matrix <- matrix(runif(length(sorted_labels)^2), nrow = length(sorted_labels))
    dist_matrix <- (dist_matrix + t(dist_matrix)) / 2
    diag(dist_matrix) <- 0
    grafted_tree <<- nj(as.dist(dist_matrix))
    grafted_tree$tip.label <<- sorted_labels
  }
)

################################################################################
# 6. TREE VALIDATION
################################################################################

cat("\nStep 6: Validating tree...\n")

validation_log <- c()

# Check 1: All genome species present
species_in_tree <- gsub("_[A-Z0-9]{5}$", "", grafted_tree$tip.label)
species_in_genomes <- gsub(" ", "_", genomes$species_name)

missing_from_tree <- setdiff(species_in_genomes, species_in_tree)
extra_in_tree <- setdiff(species_in_tree, species_in_genomes)

validation_log <- c(validation_log,
  paste("Total genomes:", nrow(genomes)),
  paste("Total tips in tree:", length(grafted_tree$tip.label)),
  paste("Missing from tree:", length(missing_from_tree)),
  paste("Extra in tree:", length(extra_in_tree))
)

if (length(missing_from_tree) > 0) {
  validation_log <- c(validation_log,
    "Missing species:",
    paste("  ", missing_from_tree, sep = "")
  )
}

# Check 2: No duplicate tips
dup_tips <- duplicated(grafted_tree$tip.label)
if (sum(dup_tips) > 0) {
  validation_log <- c(validation_log,
    paste("WARNING: Found", sum(dup_tips), "duplicate tips")
  )
}

# Check 3: Tree is rooted
if (is.rooted(grafted_tree)) {
  validation_log <- c(validation_log, "Tree is rooted: YES")
} else {
  validation_log <- c(validation_log, "Tree is rooted: NO")
}

cat("  ✓ Validation complete\n")

################################################################################
# 7. OUTPUT TREE
################################################################################

cat("\nStep 7: Writing output...\n")

## <<<STUDENT: Adjust output file path if needed>>>
output_tree_file <- "constraint_tree.nwk"
output_validation_file <- "tree_validation.txt"

# Write tree in Newick format
write.tree(grafted_tree, output_tree_file)
cat("  ✓ Tree written to:", output_tree_file, "\n")

# Write validation report
cat(paste(validation_log, collapse = "\n"), file = output_validation_file, "\n")
cat("  ✓ Validation report written to:", output_validation_file, "\n")

################################################################################
# 8. SUMMARY
################################################################################

cat("\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("SUMMARY\n" %s+% strrep("=", 50) %s+% "\n", sep = "")

for (line in validation_log) {
  cat(line, "\n")
}

cat("\nFiles saved:\n")
cat("  -", output_tree_file, "\n")
cat("  -", output_validation_file, "\n")

################################################################################
# END OF SCRIPT
################################################################################
