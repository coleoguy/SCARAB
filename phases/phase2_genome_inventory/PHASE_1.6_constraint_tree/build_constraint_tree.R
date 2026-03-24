#!/usr/bin/env Rscript
################################################################################
# build_constraint_tree.R
# Build a Coleoptera constraint tree with Neuropterida outgroups
# Based on McKenna et al. (2019) beetle backbone topology
################################################################################

# Load required library
library(ape)

# Set up paths
script_dir <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)[1])))
catalog_path <- file.path(script_dir, "../../../data/genomes/genome_catalog.csv")
output_nwk <- file.path(script_dir, "constraint_tree.nwk")
output_summary <- file.path(script_dir, "tree_summary.txt")

cat("Reading catalog from:", catalog_path, "\n")

# Read genome catalog
if (!file.exists(catalog_path)) {
  stop("Catalog file not found at: ", catalog_path)
}
catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)

# Filter to recommended/primary selections
# Use include_recommended == "yes"
selected <- catalog[catalog$include_recommended == "yes", ]

cat("Total species in catalog:", nrow(catalog), "\n")
cat("Selected species (include_recommended='yes'):", nrow(selected), "\n")

# Create clean tip labels: genus_species
selected$tip_label <- gsub(" ", "_", selected$species_name)

# Separate ingroup (Coleoptera) and outgroup (Neuropterida)
coleoptera <- selected[selected$order == "Coleoptera", ]
neuropterida <- selected[selected$order %in% c("Neuroptera", "Megaloptera", "Raphidioptera"), ]

cat("\nColeoptera species:", nrow(coleoptera), "\n")
cat("Neuropterida species:", nrow(neuropterida), "\n")

# Get unique families in Coleoptera with their species
col_families <- unique(coleoptera$family[coleoptera$family != ""])
cat("Coleoptera families represented:", length(col_families), "\n")

# Organize species by family and suborder
family_groups <- list()
for (fam in col_families) {
  fam_species <- coleoptera$tip_label[coleoptera$family == fam]
  if (length(fam_species) > 0) {
    family_groups[[fam]] <- fam_species
  }
}

################################################################################
# Helper function: Create a polytomy for a family
# Returns Newick string with all species at same level (within-family unresolved)
################################################################################
create_family_polytomy <- function(species_labels) {
  # Format: (sp1:1.0,sp2:1.0,...,spN:1.0)
  sp_str <- paste(paste0(species_labels, ":1.0"), collapse = ",")
  return(paste0("(", sp_str, ")"))
}

# Helper function: Create a clade for a family
# If family exists in data, return polytomy; otherwise return empty placeholder
create_clade <- function(family_name, families_data) {
  if (family_name %in% names(families_data) && length(families_data[[family_name]]) > 0) {
    return(create_family_polytomy(families_data[[family_name]]))
  } else {
    # Family not in our data; return a dummy taxon
    return(paste0("missing_", family_name, ":1.0"))
  }
}

# Helper function: Create Adephaga clade
# (Gyrinidae, (Haliplidae, (Noteridae, (Dytiscidae, (Trachypachidae, Carabidae)))))
create_adephaga_clade <- function(families_data) {
  gyrinidae <- create_clade("Gyrinidae", families_data)
  haliplidae <- create_clade("Haliplidae", families_data)
  noteridae <- create_clade("Noteridae", families_data)
  dytiscidae <- create_clade("Dytiscidae", families_data)
  trachypachidae <- create_clade("Trachypachidae", families_data)
  carabidae <- create_clade("Carabidae", families_data)

  # Build nested structure
  carab_trachyp <- paste0("(", trachypachidae, ":1.0,", carabidae, ":1.0):1.0")
  dyt_clade <- paste0("(", dytiscidae, ":1.0,", carab_trachyp, "):1.0")
  not_clade <- paste0("(", noteridae, ":1.0,", dyt_clade, "):1.0")
  hal_clade <- paste0("(", haliplidae, ":1.0,", not_clade, "):1.0")
  adephaga <- paste0("(", gyrinidae, ":1.0,", hal_clade, "):1.0")

  return(adephaga)
}

# Helper function: Create Elateriformia
# (Buprestidae, (Byrrhidae, (Elateridae, (Cantharidae, Lampyridae))))
create_elateriformia <- function(families_data) {
  buprestidae <- create_clade("Buprestidae", families_data)
  byrrhidae <- create_clade("Byrrhidae", families_data)
  elateridae <- create_clade("Elateridae", families_data)
  cantharidae <- create_clade("Cantharidae", families_data)
  lampyridae <- create_clade("Lampyridae", families_data)

  lamp_canth <- paste0("(", cantharidae, ":1.0,", lampyridae, ":1.0):1.0")
  elat_clade <- paste0("(", elateridae, ":1.0,", lamp_canth, "):1.0")
  byrr_clade <- paste0("(", byrrhidae, ":1.0,", elat_clade, "):1.0")
  elateriformia <- paste0("(", buprestidae, ":1.0,", byrr_clade, "):1.0")

  return(elateriformia)
}

# Helper function: Create Staphyliniformia
# (Hydrophilidae, (Staphylinidae, Silphidae))
create_staphyliniformia <- function(families_data) {
  hydrophilidae <- create_clade("Hydrophilidae", families_data)
  staphylinidae <- create_clade("Staphylinidae", families_data)
  silphidae <- create_clade("Silphidae", families_data)

  staph_silph <- paste0("(", staphylinidae, ":1.0,", silphidae, ":1.0):1.0")
  staphyliniformia <- paste0("(", hydrophilidae, ":1.0,", staph_silph, "):1.0")

  return(staphyliniformia)
}

# Helper function: Create Scarabaeiformia
# (Scarabaeidae, Lucanidae)
create_scarabaeiformia <- function(families_data) {
  scarabaeidae <- create_clade("Scarabaeidae", families_data)
  lucanidae <- create_clade("Lucanidae", families_data)

  scarabaeiformia <- paste0("(", scarabaeidae, ":1.0,", lucanidae, ":1.0):1.0")

  return(scarabaeiformia)
}

# Helper function: Create Cucujiformia
# (Coccinellidae, (Tenebrionidae, (Meloidae, (Cerambycidae, (Chrysomelidae, (Curculionidae, Anthribidae))))))
create_cucujiformia <- function(families_data) {
  coccinellidae <- create_clade("Coccinellidae", families_data)
  tenebrionidae <- create_clade("Tenebrionidae", families_data)
  meloidae <- create_clade("Meloidae", families_data)
  cerambycidae <- create_clade("Cerambycidae", families_data)
  chrysomelidae <- create_clade("Chrysomelidae", families_data)
  curculionidae <- create_clade("Curculionidae", families_data)
  anthribidae <- create_clade("Anthribidae", families_data)

  # Build nested structure from deepest to shallowest
  curc_anthr <- paste0("(", curculionidae, ":1.0,", anthribidae, ":1.0):1.0")
  chrys_clade <- paste0("(", chrysomelidae, ":1.0,", curc_anthr, "):1.0")
  ceramb_clade <- paste0("(", cerambycidae, ":1.0,", chrys_clade, "):1.0")
  mel_clade <- paste0("(", meloidae, ":1.0,", ceramb_clade, "):1.0")
  tenebr_clade <- paste0("(", tenebrionidae, ":1.0,", mel_clade, "):1.0")
  cucujiformia <- paste0("(", coccinellidae, ":1.0,", tenebr_clade, "):1.0")

  return(cucujiformia)
}

# Helper function: Create Archostemata clade
# (Micromalthidae, Cupedidae)
create_archostemata <- function(families_data) {
  micromalthidae <- create_clade("Micromalthidae", families_data)
  cupedidae <- create_clade("Cupedidae", families_data)

  archostemata <- paste0("(", micromalthidae, ":1.0,", cupedidae, ":1.0):1.0")

  return(archostemata)
}

################################################################################
# Helper function: Build constraint tree structure
################################################################################
build_backbone <- function(families_data) {
  # Create placeholders for each major group, then replace with actual species

  # Adephaga: (Gyrinidae, (Haliplidae, (Noteridae, (Dytiscidae, (Trachypachidae, Carabidae)))))
  adephaga <- create_adephaga_clade(families_data)

  # Polyphaga subgroups
  scirtoidea <- create_clade("Scirtidae", families_data)

  elateriformia <- create_elateriformia(families_data)
  staphyliniformia <- create_staphyliniformia(families_data)
  scarabaeiformia <- create_scarabaeiformia(families_data)
  cucujiformia <- create_cucujiformia(families_data)

  # Polyphaga backbone: ((Scirtoidea, Elateriformia), (Staphyliniformia, (Scarabaeiformia, Cucujiformia)))
  # Simplified: ((Scirtoidea, Elateriformia), ((Staphyliniformia, Scarabaeiformia), Cucujiformia))
  polyphaga <- paste0(
    "((",
    scirtoidea, ":1.0,",
    elateriformia, ":1.0",
    "):1.0,(",
    "(", staphyliniformia, ":1.0,", scarabaeiformia, ":1.0):1.0,",
    cucujiformia, ":1.0",
    "):1.0)",
    ":1.0"
  )

  # Archostemata: (Micromalthidae, Cupedidae)
  archostemata <- create_archostemata(families_data)

  # Coleoptera backbone: ((Archostemata, Adephaga), Polyphaga)
  coleoptera_backbone <- paste0(
    "((", archostemata, ":1.0,", adephaga, ":1.0):1.0,",
    polyphaga, ":1.0):1.0"
  )

  return(coleoptera_backbone)
}

################################################################################
# Build the complete tree
################################################################################

cat("\nBuilding constraint tree backbone...\n")

# Build Coleoptera backbone
coleoptera_tree <- build_backbone(family_groups)

# Build Neuropterida outgroup
# Structure: ((Raphidioptera, (Megaloptera, Neuroptera)))
# We have data for these orders
neuroptera_species <- neuropterida$tip_label[neuropterida$order == "Neuroptera"]
megaloptera_species <- neuropterida$tip_label[neuropterida$order == "Megaloptera"]
raphidioptera_species <- neuropterida$tip_label[neuropterida$order == "Raphidioptera"]

# Create polytomies for each order (if they have species)
neuroptera_clade <- if (length(neuroptera_species) > 0) {
  create_family_polytomy(neuroptera_species)
} else {
  "missing_Neuroptera:1.0"
}

megaloptera_clade <- if (length(megaloptera_species) > 0) {
  create_family_polytomy(megaloptera_species)
} else {
  "missing_Megaloptera:1.0"
}

raphidioptera_clade <- if (length(raphidioptera_species) > 0) {
  create_family_polytomy(raphidioptera_species)
} else {
  "missing_Raphidioptera:1.0"
}

# Combine Neuropterida: ((Raphidioptera, (Megaloptera, Neuroptera)))
neuropterida_tree <- paste0(
  "((", raphidioptera_clade, ":1.0,(",
  megaloptera_clade, ":1.0,", neuroptera_clade, ":1.0):1.0):1.0)"
)

# Complete tree: (Neuropterida, Coleoptera), rooted on Neuropterida
complete_tree <- paste0(
  "(", neuropterida_tree, ":1.0,", coleoptera_tree, ":1.0):1.0;"
)

cat("Tree structure built (Newick format).\n")

################################################################################
# Validation
################################################################################

cat("\nValidating tree...\n")

# Extract all tips from tree using a more robust method
# Look for pattern: word_word or word_word_word etc followed by :1.0
tip_pattern <- "([a-zA-Z_][a-zA-Z0-9_]*)(?=:1\\.0)"
all_matches <- gregexpr(tip_pattern, complete_tree, perl = TRUE)
tip_labels_in_tree <- unlist(regmatches(complete_tree, all_matches))

# Count tips
num_tips <- length(tip_labels_in_tree[!grepl("^missing_", tip_labels_in_tree)])
num_selected <- nrow(selected)

cat("Tips in tree (excluding missing families):", num_tips, "\n")
cat("Selected species in catalog:", num_selected, "\n")

# Check for duplicates
if (any(duplicated(tip_labels_in_tree))) {
  dup_tips <- unique(tip_labels_in_tree[duplicated(tip_labels_in_tree)])
  cat("WARNING: Duplicate tips found:", paste(dup_tips, collapse=", "), "\n")
} else {
  cat("No duplicate tips found.\n")
}

# Check for missing species
all_selected_labels <- selected$tip_label
missing_from_tree <- setdiff(all_selected_labels, tip_labels_in_tree)
missing_from_tree <- missing_from_tree[!grepl("^missing_", missing_from_tree)]

if (length(missing_from_tree) > 0) {
  cat("WARNING: Species in catalog but not in tree:", length(missing_from_tree), "\n")
  cat(paste(head(missing_from_tree, 10), collapse=", "), "\n")
}

# Check for extra species in tree
extra_in_tree <- setdiff(tip_labels_in_tree[!grepl("^missing_", tip_labels_in_tree)], all_selected_labels)
if (length(extra_in_tree) > 0) {
  cat("WARNING: Species in tree but not in catalog:", paste(extra_in_tree, collapse=", "), "\n")
}

################################################################################
# Write outputs
################################################################################

cat("\nWriting output files...\n")

# Write Newick file
writeLines(complete_tree, output_nwk)
cat("Newick tree written to:", output_nwk, "\n")

# Write summary file
summary_text <- c(
  "Constraint Tree Summary",
  "======================",
  "",
  paste("Date built:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste("Catalog source:", catalog_path),
  "",
  "SELECTION STATISTICS",
  paste("Total species in catalog:", nrow(catalog)),
  paste("Selected species (include_recommended='yes'):", nrow(selected)),
  paste("  - Coleoptera:", nrow(coleoptera)),
  paste("  - Neuropterida:", nrow(neuropterida)),
  "",
  "COLEOPTERA FAMILIES INCLUDED",
  paste("Total families with representatives:", length(col_families)),
  ""
)

# Add family summary
family_summary <- sapply(col_families, function(fam) {
  count <- length(family_groups[[fam]])
  paste(fam, ":", count, "species")
})
summary_text <- c(summary_text, sort(family_summary))

summary_text <- c(
  summary_text,
  "",
  "NEUROPTERIDA OUTGROUPS",
  paste("Raphidioptera species:", length(raphidioptera_species)),
  paste("Megaloptera species:", length(megaloptera_species)),
  paste("Neuroptera species:", length(neuroptera_species)),
  "",
  "TREE VALIDATION",
  paste("Total tips in tree (excluding missing):", num_tips),
  paste("Duplicate tips:", if (any(duplicated(tip_labels_in_tree))) "YES - ERROR" else "No"),
  paste("Missing from tree:", length(missing_from_tree)),
  paste("Extra in tree:", length(extra_in_tree)),
  "",
  "TOPOLOGY",
  "Rooted on: Neuropterida",
  "Constraint topology follows: McKenna et al. (2019) Coleoptera backbone",
  "Within-family structure: Unresolved polytomies (suitable for Cactus)",
  "Branch lengths: Uniform 1.0",
  "",
  "FILES GENERATED",
  paste("- Newick tree:", output_nwk),
  paste("- Summary:", output_summary)
)

writeLines(summary_text, output_summary)
cat("Summary written to:", output_summary, "\n")

################################################################################
# Try to parse and validate with ape
################################################################################

cat("\nAttempting to parse tree with ape library...\n")
tryCatch({
  tree_obj <- read.tree(text = complete_tree)
  cat("Successfully parsed tree with ape.\n")
  cat("Tree has", length(tree_obj$tip.label), "tips.\n")
  cat("Tree is", if (is.null(tree_obj$edge.length)) "UNRESOLVED" else "RESOLVED", "\n")
  cat("Tips in tree:\n")
  for (tip in sort(tree_obj$tip.label)) {
    if (!grepl("^missing_", tip)) {
      cat("  ", tip, "\n")
    }
  }
}, error = function(e) {
  cat("ERROR parsing tree with ape:", e$message, "\n")
})

cat("\n*** Build complete ***\n")
