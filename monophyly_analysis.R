#!/usr/bin/env Rscript
# Comprehensive monophyly analysis of 478-tip beetle tree
# Against full 1121-taxon genome catalog

library(ape)

# Set paths
tree_path <- "/sessions/youthful-sweet-heisenberg/mnt/SCARAB/scarab_478_rooted.nwk"
catalog_path <- "/sessions/youthful-sweet-heisenberg/mnt/SCARAB/data/genomes/genome_catalog.csv"

cat("=== MONOPHYLY ANALYSIS FOR 478-TIP BEETLE TREE ===\n\n")
cat("Reading tree from:", tree_path, "\n")
tree <- read.tree(tree_path)

cat("Tree summary:\n")
cat("  Number of tips:", length(tree$tip.label), "\n")
cat("  Sample tips (first 10):", paste(head(tree$tip.label, 10), collapse=", "), "\n\n")

# Read catalog
cat("Reading catalog from:", catalog_path, "\n")
catalog <- read.csv(catalog_path, stringsAsFactors=FALSE)
cat("Catalog summary:\n")
cat("  Number of rows:", nrow(catalog), "\n")
cat("  Columns:", paste(colnames(catalog), collapse=", "), "\n\n")

# === STEP 1: MAP TREE TIPS TO CATALOG ===
cat("=== STEP 1: MAPPING TREE TIPS TO CATALOG ===\n\n")

# Replace underscores with spaces in tree tips
tree_tips_with_spaces <- gsub("_", " ", tree$tip.label)

# Create mapping
mapping <- data.frame(
  tip_label = tree$tip.label,
  tip_label_spaced = tree_tips_with_spaces,
  catalog_row = NA,
  genus = NA,
  family = NA,
  superfamily = NA,
  suborder = NA,
  order = NA,
  stringsAsFactors = FALSE
)

# Match tips to catalog
matched_count <- 0
unmatched_tips <- c()

for (i in seq_along(tree$tip.label)) {
  spaced_name <- tree_tips_with_spaces[i]

  # Find first matching row in catalog
  match_idx <- which(catalog$species_name == spaced_name)[1]

  if (!is.na(match_idx)) {
    mapping$catalog_row[i] <- match_idx
    mapping$genus[i] <- catalog$genus[match_idx]
    mapping$family[i] <- catalog$family[match_idx]
    mapping$superfamily[i] <- catalog$superfamily[match_idx]
    mapping$suborder[i] <- catalog$suborder[match_idx]
    mapping$order[i] <- catalog$order[match_idx]
    matched_count <- matched_count + 1
  } else {
    unmatched_tips <- c(unmatched_tips, tree$tip.label[i])
  }
}

cat("Mapping results:\n")
cat("  Total tips in tree:", nrow(mapping), "\n")
cat("  Successfully mapped:", matched_count, "\n")
cat("  Failed to map:", length(unmatched_tips), "\n\n")

if (length(unmatched_tips) > 0) {
  cat("UNMATCHED TIPS (", length(unmatched_tips), " total):\n", sep="")
  for (tip in unmatched_tips) {
    cat("  -", tip, "\n")
  }
  cat("\n")
} else {
  cat("All 478 tips successfully mapped!\n\n")
}

# Attach mapping to tree for convenience
tree$mapping <- mapping

# === STEP 2: EXTRACT GENE TREES FOR EACH TAXONOMIC LEVEL ===
cat("=== STEP 2: MONOPHYLY TESTING BY TAXONOMIC LEVEL ===\n\n")

# For each level, test monophyly
test_monophyly_level <- function(tree, mapping, level_col, level_name) {

  cat("Testing monophyly at level:", level_name, "\n")
  cat(paste(rep("=", 50), collapse=""), "\n\n")

  # Get unique groups at this level (non-NA only)
  groups <- unique(mapping[[level_col]])
  groups <- groups[!is.na(groups)]

  cat("Number of groups at", level_name, "level:", length(groups), "\n\n")

  # Filter to groups with >= 2 tips
  group_counts <- table(mapping[[level_col]])
  groups_to_test <- names(group_counts)[group_counts >= 2]

  cat("Groups with >= 2 tips:", length(groups_to_test), "\n\n")

  results <- list()
  non_monophyletic <- list()

  for (group in groups_to_test) {
    # Get indices of tips in this group
    group_tips <- mapping$tip_label[mapping[[level_col]] == group & !is.na(mapping[[level_col]])]

    if (length(group_tips) < 2) next

    # Test monophyly using ape::is.monophyletic()
    mono_result <- is.monophyletic(tree, group_tips)

    results[[group]] <- list(
      n_tips = length(group_tips),
      is_monophyletic = mono_result,
      tips = group_tips
    )

    # If NOT monophyletic, get details
    if (!mono_result) {
      mrca_node <- getMRCA(tree, group_tips)
      clade_size <- length(tree$tip.label[extract.clade(tree, mrca_node)$tip.label %in% tree$tip.label])

      # Get all tips descending from MRCA
      mrca_clade <- extract.clade(tree, mrca_node)
      mrca_tips <- mrca_clade$tip.label

      # Find intruders (tips in MRCA but not in group)
      intruder_tips <- setdiff(mrca_tips, group_tips)
      intruder_taxa <- c()

      if (length(intruder_tips) > 0) {
        for (intruder_tip in intruder_tips) {
          idx <- which(mapping$tip_label == intruder_tip)
          if (length(idx) > 0) {
            fam <- mapping$family[idx]
            gen <- mapping$genus[idx]
            intruder_taxa <- c(intruder_taxa, paste(gen, "(", fam, ")", sep=""))
          }
        }
      }

      non_monophyletic[[group]] <- list(
        n_tips_in_group = length(group_tips),
        mrca_node = mrca_node,
        total_tips_in_mrca_clade = length(mrca_tips),
        n_intruders = length(intruder_tips),
        intruder_taxa = intruder_taxa
      )
    }
  }

  return(list(
    results = results,
    non_monophyletic = non_monophyletic,
    groups_to_test = groups_to_test
  ))
}

# Test each level
levels <- list(
  genus = "genus",
  family = "family",
  superfamily = "superfamily",
  suborder = "suborder",
  order = "order"
)

all_results <- list()

for (level_name in names(levels)) {
  all_results[[level_name]] <- test_monophyly_level(
    tree, mapping, levels[[level_name]], level_name
  )
}

# === STEP 3: REPORT NON-MONOPHYLETIC GROUPS ===
cat("\n\n=== STEP 3: NON-MONOPHYLETIC GROUPS ===\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

for (level_name in names(all_results)) {
  level_res <- all_results[[level_name]]
  non_mono <- level_res$non_monophyletic

  if (length(non_mono) > 0) {
    cat("Level: ", toupper(level_name), " (", length(non_mono), " non-monophyletic groups)\n", sep="")
    cat(paste(rep("-", 70), collapse=""), "\n\n")

    for (group_name in names(non_mono)) {
      group_info <- non_mono[[group_name]]
      cat("GROUP:", group_name, "\n")
      cat("  Tips in group:", group_info$n_tips_in_group, "\n")
      cat("  Tips in MRCA clade:", group_info$total_tips_in_mrca_clade, "\n")
      cat("  Number of intruders:", group_info$n_intruders, "\n")

      if (group_info$n_intruders > 0) {
        cat("  Intruding taxa:\n")
        for (intruder in group_info$intruder_taxa) {
          cat("    -", intruder, "\n")
        }
      }
      cat("\n")
    }
    cat("\n")
  }
}

# === STEP 4: SPECIFIC TESTS ===
cat("\n=== STEP 4: SPECIFIC GROUP MONOPHYLY TESTS ===\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

# Helper function to test specific groups
test_specific_group <- function(tree, mapping, tip_names_to_test, group_label) {

  # Handle multiple possible tip formats
  if (is.character(tip_names_to_test)) {
    # Try to match tip labels
    potential_tips <- c()
    for (test_name in tip_names_to_test) {
      idx <- grep(test_name, mapping$tip_label, ignore.case=TRUE)
      if (length(idx) > 0) {
        potential_tips <- c(potential_tips, mapping$tip_label[idx])
      }
    }
    tip_names_to_test <- potential_tips
  }

  if (length(tip_names_to_test) < 2) {
    cat(group_label, ": INSUFFICIENT TIPS (found", length(tip_names_to_test), ")\n\n")
    return(NULL)
  }

  mono <- is.monophyletic(tree, tip_names_to_test)
  mrca_node <- getMRCA(tree, tip_names_to_test)
  mrca_clade <- extract.clade(tree, mrca_node)
  mrca_tips <- mrca_clade$tip.label

  cat("GROUP:", group_label, "\n")
  cat("  Tips in group:", length(tip_names_to_test), "\n")
  cat("  Monophyletic:", mono, "\n")
  cat("  MRCA node:", mrca_node, "\n")
  cat("  Total tips in MRCA clade:", length(mrca_tips), "\n")

  if (!mono) {
    intruder_tips <- setdiff(mrca_tips, tip_names_to_test)
    cat("  Number of intruders:", length(intruder_tips), "\n")
    cat("  Intruding taxa:\n")

    for (intruder_tip in intruder_tips) {
      idx <- which(mapping$tip_label == intruder_tip)
      if (length(idx) > 0) {
        fam <- mapping$family[idx]
        gen <- mapping$genus[idx]
        cat("    -", gen, "(", fam, ")\n", sep="")
      }
    }
  }
  cat("\n")

  return(list(mono=mono, n_tips=length(tip_names_to_test), n_mrca=length(mrca_tips)))
}

# 1. Neuropterida (Neuroptera + Megaloptera + Raphidioptera)
cat("1. NEUROPTERIDA (Neuroptera + Megaloptera + Raphidioptera)\n")
cat(paste(rep("-", 70), collapse=""), "\n")

neuroptera_tips <- mapping$tip_label[mapping$order == "Neuroptera" & !is.na(mapping$order)]
megaloptera_tips <- mapping$tip_label[mapping$order == "Megaloptera" & !is.na(mapping$order)]
raphidioptera_tips <- mapping$tip_label[mapping$order == "Raphidioptera" & !is.na(mapping$order)]
neuropterida_tips <- c(neuroptera_tips, megaloptera_tips, raphidioptera_tips)

cat("Neuroptera tips:", length(neuroptera_tips), "\n")
cat("Megaloptera tips:", length(megaloptera_tips), "\n")
cat("Raphidioptera tips:", length(raphidioptera_tips), "\n")
cat("Total Neuropterida tips:", length(neuropterida_tips), "\n\n")

test_specific_group(tree, mapping, neuropterida_tips, "Neuropterida (all)")
cat("\n")

# 2. Coleoptera
cat("2. COLEOPTERA (all)\n")
cat(paste(rep("-", 70), collapse=""), "\n")

coleoptera_tips <- mapping$tip_label[mapping$order == "Coleoptera" & !is.na(mapping$order)]
cat("Total Coleoptera tips:", length(coleoptera_tips), "\n\n")
test_specific_group(tree, mapping, coleoptera_tips, "Coleoptera")
cat("\n")

# 3. Adephaga
cat("3. ADEPHAGA (suborder)\n")
cat(paste(rep("-", 70), collapse=""), "\n")

adephaga_tips <- mapping$tip_label[mapping$suborder == "Adephaga" & !is.na(mapping$suborder)]
cat("Total Adephaga tips:", length(adephaga_tips), "\n\n")
test_specific_group(tree, mapping, adephaga_tips, "Adephaga")
cat("\n")

# 4. Polyphaga
cat("4. POLYPHAGA (suborder)\n")
cat(paste(rep("-", 70), collapse=""), "\n")

polyphaga_tips <- mapping$tip_label[mapping$suborder == "Polyphaga" & !is.na(mapping$suborder)]
cat("Total Polyphaga tips:", length(polyphaga_tips), "\n\n")
test_specific_group(tree, mapping, polyphaga_tips, "Polyphaga")
cat("\n")

# 5. Polyphaga series (based on superfamily)
cat("5. POLYPHAGA SERIES (based on superfamily)\n")
cat(paste(rep("-", 70), collapse=""), "\n\n")

# Get unique superfamilies in Polyphaga
polyphaga_superfamilies <- unique(mapping$superfamily[mapping$suborder == "Polyphaga" & !is.na(mapping$superfamily)])
polyphaga_superfamilies <- polyphaga_superfamilies[!is.na(polyphaga_superfamilies)]

cat("Polyphaga superfamilies found:\n")
for (sf in sort(polyphaga_superfamilies)) {
  sf_tips <- mapping$tip_label[mapping$superfamily == sf & mapping$suborder == "Polyphaga" & !is.na(mapping$superfamily)]
  cat("  ", sf, ": ", length(sf_tips), " tips\n", sep="")
}
cat("\n")

# Test each superfamily for monophyly
cat("Testing monophyly of Polyphaga superfamilies:\n")
for (sf in sort(polyphaga_superfamilies)) {
  sf_tips <- mapping$tip_label[mapping$superfamily == sf & mapping$suborder == "Polyphaga" & !is.na(mapping$superfamily)]
  if (length(sf_tips) >= 2) {
    test_specific_group(tree, mapping, sf_tips, paste("Superfamily:", sf))
  }
}

# === STEP 5: SUPERFAMILY ANALYSIS ===
cat("=== STEP 5: SUPERFAMILY MONOPHYLY SUMMARY ===\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

all_superfamilies <- unique(mapping$superfamily)
all_superfamilies <- all_superfamilies[!is.na(all_superfamilies)]

superfamily_results <- data.frame(
  superfamily = character(),
  n_tips = integer(),
  is_monophyletic = logical(),
  n_intruders = integer(),
  stringsAsFactors = FALSE
)

for (sf in sort(all_superfamilies)) {
  sf_tips <- mapping$tip_label[mapping$superfamily == sf & !is.na(mapping$superfamily)]

  if (length(sf_tips) >= 2) {
    mono <- is.monophyletic(tree, sf_tips)

    n_intruders <- 0
    if (!mono) {
      mrca_node <- getMRCA(tree, sf_tips)
      mrca_clade <- extract.clade(tree, mrca_node)
      mrca_tips <- mrca_clade$tip.label
      n_intruders <- length(setdiff(mrca_tips, sf_tips))
    }

    superfamily_results <- rbind(superfamily_results, data.frame(
      superfamily = sf,
      n_tips = length(sf_tips),
      is_monophyletic = mono,
      n_intruders = n_intruders,
      stringsAsFactors = FALSE
    ))
  }
}

# Sort by monophyly status then by superfamily name
superfamily_results <- superfamily_results[order(!superfamily_results$is_monophyletic, superfamily_results$superfamily), ]

cat("SUPERFAMILY MONOPHYLY TABLE:\n")
cat(paste(rep("-", 80), collapse=""), "\n")
cat(sprintf("%-30s %8s %13s %12s\n", "Superfamily", "N Tips", "Monophyletic", "N Intruders"))
cat(paste(rep("-", 80), collapse=""), "\n")

for (i in seq_len(nrow(superfamily_results))) {
  row <- superfamily_results[i, ]
  mono_str <- if (row$is_monophyletic) "YES" else "NO"
  intruder_str <- if (row$is_monophyletic) "-" else as.character(row$n_intruders)
  cat(sprintf("%-30s %8d %13s %12s\n",
              row$superfamily, row$n_tips, mono_str, intruder_str))
}
cat("\n")

# === FINAL SUMMARY ===
cat("\n=== FINAL SUMMARY ===\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

cat("Tree statistics:\n")
cat("  Total tips:", length(tree$tip.label), "\n")
cat("  Tips successfully mapped:", matched_count, "\n")
cat("  Mapping success rate:", round(100*matched_count/length(tree$tip.label), 1), "%\n\n")

cat("Monophyly summary by level:\n")
for (level_name in names(all_results)) {
  level_res <- all_results[[level_name]]
  n_tested <- length(level_res$groups_to_test)
  n_non_mono <- length(level_res$non_monophyletic)
  n_mono <- n_tested - n_non_mono

  cat(sprintf("  %-15s: %3d tested, %3d monophyletic, %3d non-monophyletic (%.1f%%)\n",
              level_name, n_tested, n_mono, n_non_mono, 100*n_non_mono/n_tested))
}

cat("\nSuperfamily monophyly:\n")
n_sf_total <- nrow(superfamily_results)
n_sf_mono <- sum(superfamily_results$is_monophyletic)
n_sf_non_mono <- sum(!superfamily_results$is_monophyletic)

cat(sprintf("  Total superfamilies: %d\n", n_sf_total))
cat(sprintf("  Monophyletic: %d (%.1f%%)\n", n_sf_mono, 100*n_sf_mono/n_sf_total))
cat(sprintf("  Non-monophyletic: %d (%.1f%%)\n", n_sf_non_mono, 100*n_sf_non_mono/n_sf_total))

cat("\nKey findings:\n")

# Check major groups
coleoptera_mono <- is.monophyletic(tree, mapping$tip_label[mapping$order == "Coleoptera" & !is.na(mapping$order)])
adephaga_mono <- is.monophyletic(tree, mapping$tip_label[mapping$suborder == "Adephaga" & !is.na(mapping$suborder)])
polyphaga_mono <- is.monophyletic(tree, mapping$tip_label[mapping$suborder == "Polyphaga" & !is.na(mapping$suborder)])

cat("  Coleoptera monophyletic:", coleoptera_mono, "\n")
cat("  Adephaga monophyletic:", adephaga_mono, "\n")
cat("  Polyphaga monophyletic:", polyphaga_mono, "\n")

cat("\n")
cat("Analysis complete.\n")
