#!/usr/bin/env Rscript
# ============================================================================
# sensitivity_subsample.R -- Test species tree robustness to Stevens element
# representation bias by subsampling equal loci per element
# ============================================================================
#
# Purpose:
#   Randomly subsample N loci per Stevens element (or max available if < N),
#   build wASTRAL trees from each subsample, and compare topology to the
#   full 1,286-locus tree via Robinson-Foulds distance.
#
# Prerequisites:
#   - busco_tribolium_stevens_map.tsv (Stevens element assignments)
#   - per_gene_trees/*.treefile (completed gene trees)
#   - Full wASTRAL species tree (from P6)
#   - ASTER module available on Grace
#
# Usage:
#   Rscript sensitivity_subsample.R \
#     --map /path/to/busco_tribolium_stevens_map.tsv \
#     --treedir /path/to/per_gene_trees \
#     --reftree /path/to/wastral_species_tree_rooted.nwk \
#     --outdir /path/to/sensitivity_output \
#     --nloci 100 \
#     --nreps 10
#
# Output:
#   - Per-replicate subsampled gene tree files
#   - Per-replicate wASTRAL trees
#   - Summary CSV: replicate, n_loci, n_elements, RF_distance, normalized_RF
#   - Console summary of RF distances
# ============================================================================

suppressPackageStartupMessages({
    library(ape)
    library(phangorn)
})

# ============================================================================
# Parse arguments
# ============================================================================

args <- commandArgs(trailingOnly = TRUE)

# Defaults
map_file <- NULL
tree_dir <- NULL
ref_tree_file <- NULL
out_dir <- "sensitivity_output"
n_loci <- 100
n_reps <- 10

i <- 1
while (i <= length(args)) {
    if (args[i] == "--map") {
        map_file <- args[i + 1]; i <- i + 2
    } else if (args[i] == "--treedir") {
        tree_dir <- args[i + 1]; i <- i + 2
    } else if (args[i] == "--reftree") {
        ref_tree_file <- args[i + 1]; i <- i + 2
    } else if (args[i] == "--outdir") {
        out_dir <- args[i + 1]; i <- i + 2
    } else if (args[i] == "--nloci") {
        n_loci <- as.integer(args[i + 1]); i <- i + 2
    } else if (args[i] == "--nreps") {
        n_reps <- as.integer(args[i + 1]); i <- i + 2
    } else {
        stop(paste("Unknown argument:", args[i]))
    }
}

if (is.null(map_file) || is.null(tree_dir) || is.null(ref_tree_file)) {
    stop("Required: --map, --treedir, --reftree")
}

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ============================================================================
# Load Stevens element mapping
# ============================================================================

cat("Loading Stevens element mapping...\n")
element_map <- read.delim(map_file, stringsAsFactors = FALSE)

# Expect columns: busco_id, chromosome, tribolium_scaffold, stevens_element
if (!"stevens_element" %in% names(element_map)) {
    stop("Expected column 'stevens_element' in map file")
}

# Filter to loci with known element assignments
element_map <- element_map[element_map$stevens_element != "UNKNOWN" &
                           element_map$stevens_element != "", ]

cat(sprintf("  Loci with element assignments: %d\n", nrow(element_map)))
cat(sprintf("  Elements: %s\n", paste(sort(unique(element_map$stevens_element)),
                                       collapse = ", ")))

# ============================================================================
# Check which loci have completed gene trees
# ============================================================================

cat("Checking available gene trees...\n")
available_trees <- list.files(tree_dir, pattern = "\\.treefile$", full.names = FALSE)
available_loci <- sub("\\.treefile$", "", available_trees)

element_map <- element_map[element_map$busco_id %in% available_loci, ]
cat(sprintf("  Loci with both element assignment and gene tree: %d\n",
            nrow(element_map)))

# Loci per element
loci_per_element <- table(element_map$stevens_element)
cat("  Loci per element:\n")
for (elem in sort(names(loci_per_element))) {
    cat(sprintf("    %s: %d\n", elem, loci_per_element[elem]))
}

# ============================================================================
# Load reference tree
# ============================================================================

cat("Loading reference tree...\n")
ref_tree <- read.tree(ref_tree_file)
cat(sprintf("  Reference tree tips: %d\n", Ntip(ref_tree)))

# ============================================================================
# Run subsampling replicates
# ============================================================================

cat(sprintf("\nRunning %d subsampling replicates (%d loci per element)...\n",
            n_reps, n_loci))

results <- data.frame(
    replicate = integer(n_reps),
    n_loci = integer(n_reps),
    n_elements = integer(n_reps),
    rf_distance = numeric(n_reps),
    normalized_rf = numeric(n_reps),
    stringsAsFactors = FALSE
)

elements <- sort(unique(element_map$stevens_element))

for (rep in seq_len(n_reps)) {
    cat(sprintf("  Replicate %d/%d: ", rep, n_reps))

    # Subsample n_loci per element (or max available)
    sampled_loci <- character(0)
    for (elem in elements) {
        elem_loci <- element_map$busco_id[element_map$stevens_element == elem]
        n_sample <- min(n_loci, length(elem_loci))
        sampled_loci <- c(sampled_loci, sample(elem_loci, n_sample))
    }

    cat(sprintf("%d loci sampled. ", length(sampled_loci)))

    # Collect gene trees for this subsample
    gene_trees_file <- file.path(out_dir,
                                  sprintf("subsample_rep%02d_genetrees.nwk", rep))
    tree_lines <- character(0)
    for (locus in sampled_loci) {
        tf <- file.path(tree_dir, paste0(locus, ".treefile"))
        if (file.exists(tf)) {
            tree_lines <- c(tree_lines, readLines(tf, warn = FALSE)[1])
        }
    }
    writeLines(tree_lines, gene_trees_file)

    # Run wASTRAL on subsample
    wastral_out <- file.path(out_dir,
                              sprintf("subsample_rep%02d_wastral.nwk", rep))
    wastral_cmd <- sprintf("wastral -t 4 -o %s %s 2>/dev/null",
                           shQuote(wastral_out), shQuote(gene_trees_file))
    system(wastral_cmd)

    # Compare topology via RF distance
    if (file.exists(wastral_out)) {
        sub_tree <- tryCatch(read.tree(wastral_out), error = function(e) NULL)
        if (!is.null(sub_tree)) {
            # Prune to shared tips
            shared_tips <- intersect(ref_tree$tip.label, sub_tree$tip.label)
            ref_pruned <- drop.tip(ref_tree,
                                   setdiff(ref_tree$tip.label, shared_tips))
            sub_pruned <- drop.tip(sub_tree,
                                   setdiff(sub_tree$tip.label, shared_tips))

            rf <- RF.dist(ref_pruned, sub_pruned, normalize = FALSE)
            max_rf <- 2 * (length(shared_tips) - 3)
            norm_rf <- rf / max_rf

            results$replicate[rep] <- rep
            results$n_loci[rep] <- length(sampled_loci)
            results$n_elements[rep] <- length(elements)
            results$rf_distance[rep] <- rf
            results$normalized_rf[rep] <- norm_rf

            cat(sprintf("RF = %d (%.3f normalized)\n", rf, norm_rf))
        } else {
            cat("wASTRAL tree unreadable\n")
            results$replicate[rep] <- rep
            results$n_loci[rep] <- length(sampled_loci)
            results$n_elements[rep] <- length(elements)
            results$rf_distance[rep] <- NA
            results$normalized_rf[rep] <- NA
        }
    } else {
        cat("wASTRAL failed\n")
        results$replicate[rep] <- rep
        results$n_loci[rep] <- length(sampled_loci)
        results$n_elements[rep] <- length(elements)
        results$rf_distance[rep] <- NA
        results$normalized_rf[rep] <- NA
    }
}

# ============================================================================
# Summary
# ============================================================================

results_file <- file.path(out_dir, "sensitivity_results.csv")
write.csv(results, results_file, row.names = FALSE)

cat("\n============================================================\n")
cat("SENSITIVITY SUBSAMPLE RESULTS\n")
cat("============================================================\n")
cat(sprintf("  Replicates: %d\n", n_reps))
cat(sprintf("  Loci per element (target): %d\n", n_loci))
cat(sprintf("  Mean RF distance: %.1f\n", mean(results$rf_distance, na.rm = TRUE)))
cat(sprintf("  Mean normalized RF: %.4f\n",
            mean(results$normalized_rf, na.rm = TRUE)))
cat(sprintf("  Range normalized RF: %.4f - %.4f\n",
            min(results$normalized_rf, na.rm = TRUE),
            max(results$normalized_rf, na.rm = TRUE)))
cat(sprintf("  Results written: %s\n", results_file))
cat("============================================================\n")
