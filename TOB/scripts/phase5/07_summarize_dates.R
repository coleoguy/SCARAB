#!/usr/bin/env Rscript
# =============================================================================
# 07_summarize_dates.R
# =============================================================================
# Purpose:
#   1. Read the 100 bootstrap dated trees and compute 95% HPD (highest posterior
#      density) intervals on every internal node age.
#   2. Read the calibration jackknife trees and compute per-node sensitivity:
#      which fossil calibrations most shift node ages when removed.
#   3. Read the Burmese amber sensitivity trees (with/without amber).
#   4. Output:
#      (a) tob_dated_hpd.tre        -- consensus dated tree with HPD on nodes
#      (b) node_ages_bootstrap.csv  -- all node ages across 100 bootstrap trees
#      (c) node_sensitivity.csv     -- per-node jackknife sensitivity table
#      (d) amber_sensitivity.csv    -- per-node amber vs no-amber age comparison
#
# Dependencies:
#   ape, phangorn (for tree handling and node matching)
#   HDInterval (for HPD calculation)
#
# Usage (Grace, after loading R module):
#   module purge && module load GCC/13.3.0 R/4.4.2
#   Rscript 07_summarize_dates.R
#
# Runtime: ~10-60 min depending on tree size and number of bootstrap trees.
# =============================================================================

library(ape)
library(HDInterval)

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRATCH  <- Sys.getenv("SCRATCH", "/scratch/user/blackmon")
TOB      <- file.path(SCRATCH, "tob")
DATING   <- file.path(TOB, "dating")
SUMMARY  <- file.path(DATING, "summary")
LOG_DIR  <- file.path(TOB, "logs")

PRIMARY_TREE    <- file.path(DATING, "tob_dated.tre")
BS_DIR          <- file.path(DATING, "bootstrap")
JK_DIR          <- file.path(DATING, "jackknife")
AMBER_WITH      <- file.path(DATING, "amber_sensitivity", "dated_with_amber.tre")
AMBER_WITHOUT   <- file.path(DATING, "amber_sensitivity", "dated_without_amber.tre")

N_BS <- 100   # Number of bootstrap trees expected

dir.create(SUMMARY, recursive = TRUE, showWarnings = FALSE)

cat("=============================================================\n")
cat("TOB Phase 5 -- Summarize Divergence Dates\n")
cat("Started:", format(Sys.time()), "\n")
cat("=============================================================\n\n")

# =============================================================================
# HELPER: read all trees matching a glob pattern
# =============================================================================

read_dated_trees <- function(dir_path, pattern) {
  files <- sort(list.files(dir_path, pattern = pattern, full.names = TRUE))
  if (length(files) == 0) {
    stop(paste("No files matching", pattern, "in", dir_path))
  }
  cat("  Reading", length(files), "trees from", dir_path, "\n")
  trees <- lapply(files, function(f) {
    tr <- tryCatch(read.tree(f), error = function(e) {
      cat("  WARNING: could not read", f, ":", conditionMessage(e), "\n")
      NULL
    })
    tr
  })
  trees <- trees[!sapply(trees, is.null)]
  cat("  Successfully read:", length(trees), "\n")
  trees
}

# =============================================================================
# HELPER: extract node ages from a single ultrametric tree
# Returns named numeric vector: node_label -> age (distance from root)
# =============================================================================

node_ages_from_tree <- function(tree) {
  if (!is.ultrametric(tree, tol = 0.01)) {
    # treePL output may have tiny rounding; force
    tree <- force.ultrametric(tree, method = "extend")
  }
  ages <- branching.times(tree)
  ages
}

# =============================================================================
# HELPER: match nodes across trees via tip-set identity
# Returns a matrix: rows = nodes in primary tree, cols = bootstrap replicates
# Each cell = node age in that replicate (NA if node not found)
# =============================================================================

match_node_ages <- function(primary_tree, tree_list) {
  primary_ages  <- node_ages_from_tree(primary_tree)
  n_nodes       <- length(primary_ages)
  n_trees       <- length(tree_list)
  ntips         <- length(primary_tree$tip.label)

  cat("  Primary tree:", ntips, "tips,", n_nodes, "internal nodes\n")

  # Build tip-set fingerprint for each node in primary tree
  primary_node_ids <- (ntips + 1):(ntips + n_nodes)

  get_tipset <- function(tree, node) {
    desc <- Descendants(tree, node, type = "tips")
    sort(tree$tip.label[desc])
  }

  primary_tipsets <- lapply(primary_node_ids, function(nd) {
    get_tipset(primary_tree, nd)
  })

  # Matrix to collect ages
  age_matrix <- matrix(NA_real_, nrow = n_nodes, ncol = n_trees)
  rownames(age_matrix) <- names(primary_ages)

  for (j in seq_len(n_trees)) {
    tr <- tree_list[[j]]
    if (is.null(tr)) next
    tr_ages <- tryCatch(node_ages_from_tree(tr), error = function(e) NULL)
    if (is.null(tr_ages)) next

    tr_ntips  <- length(tr$tip.label)
    tr_nodes  <- (tr_ntips + 1):(tr_ntips + length(tr_ages))

    tr_tipsets <- lapply(tr_nodes, get_tipset, tree = tr)

    for (i in seq_len(n_nodes)) {
      ps <- primary_tipsets[[i]]
      # Find matching node in bootstrap tree
      match_idx <- which(sapply(tr_tipsets, function(ts) identical(ts, ps)))
      if (length(match_idx) == 1) {
        age_matrix[i, j] <- tr_ages[match_idx]
      }
      # If node not found (topology differs), leave as NA
    }
  }

  age_matrix
}

# =============================================================================
# 1. PRIMARY TREE
# =============================================================================

cat("Reading primary dated tree...\n")
if (!file.exists(PRIMARY_TREE)) {
  stop(paste("Primary tree not found:", PRIMARY_TREE))
}
primary_tree <- read.tree(PRIMARY_TREE)
cat("  Tips:", length(primary_tree$tip.label), "\n\n")

# =============================================================================
# 2. BOOTSTRAP DATED TREES — 95% HPD on every node
# =============================================================================

cat("--- Bootstrap uncertainty (", N_BS, "trees) ---\n")
bs_trees <- read_dated_trees(BS_DIR, "^dated_bs_[0-9]+\\.tre$")

if (length(bs_trees) < 10) {
  cat("WARNING: fewer than 10 bootstrap trees found. HPD will be unreliable.\n\n")
}

cat("Matching nodes across bootstrap trees...\n")
bs_age_matrix <- match_node_ages(primary_tree, bs_trees)

# Write full bootstrap age matrix
bs_out <- as.data.frame(bs_age_matrix)
bs_out$node_label <- rownames(bs_age_matrix)
bs_out$primary_age <- node_ages_from_tree(primary_tree)
bs_out$mean_bs_age <- rowMeans(bs_age_matrix, na.rm = TRUE)
bs_out$sd_bs_age   <- apply(bs_age_matrix, 1, sd, na.rm = TRUE)
bs_out$n_matched   <- rowSums(!is.na(bs_age_matrix))

# HPD
hpd_mat <- t(apply(bs_age_matrix, 1, function(x) {
  x_valid <- x[!is.na(x)]
  if (length(x_valid) < 4) return(c(lower = NA_real_, upper = NA_real_))
  h <- hdi(x_valid, credMass = 0.95)
  c(lower = unname(h["lower"]), upper = unname(h["upper"]))
}))
bs_out$hpd95_lower <- hpd_mat[, "lower"]
bs_out$hpd95_upper <- hpd_mat[, "upper"]

write.csv(bs_out[, c("node_label", "primary_age", "mean_bs_age", "sd_bs_age",
                      "hpd95_lower", "hpd95_upper", "n_matched")],
          file.path(SUMMARY, "node_ages_bootstrap.csv"), row.names = FALSE)
cat("  Written:", file.path(SUMMARY, "node_ages_bootstrap.csv"), "\n\n")

# Annotate primary tree with HPD: write node labels as "age[lower-upper]"
hpd_tree <- primary_tree
node_ages_primary <- node_ages_from_tree(primary_tree)
ntips_p <- length(primary_tree$tip.label)

new_labels <- character(length(node_ages_primary))
for (i in seq_along(node_ages_primary)) {
  age    <- round(node_ages_primary[i], 2)
  lo     <- ifelse(is.na(bs_out$hpd95_lower[i]), "NA",
                   round(bs_out$hpd95_lower[i], 2))
  hi     <- ifelse(is.na(bs_out$hpd95_upper[i]), "NA",
                   round(bs_out$hpd95_upper[i], 2))
  new_labels[i] <- paste0(age, "[", lo, "-", hi, "]")
}
hpd_tree$node.label <- new_labels

hpd_tre_path <- file.path(SUMMARY, "tob_dated_hpd.tre")
write.tree(hpd_tree, file = hpd_tre_path)
cat("  HPD-annotated tree written:", hpd_tre_path, "\n\n")

# =============================================================================
# 3. JACKKNIFE CALIBRATION SENSITIVITY
# =============================================================================

cat("--- Calibration jackknife sensitivity ---\n")
jk_files <- sort(list.files(JK_DIR, pattern = "^dated_jk_.*\\.tre$", full.names = TRUE))
cat("  Jackknife tree files found:", length(jk_files), "\n")

if (length(jk_files) == 0) {
  cat("  WARNING: No jackknife trees found. Skipping sensitivity analysis.\n\n")
} else {
  # Extract dropped-calibration label from filenames: dated_jk_N_drop_LABEL.tre
  extract_dropped <- function(f) {
    bn <- basename(f)
    # Pattern: dated_jk_<N>_drop_<LABEL>.tre
    sub("^dated_jk_[0-9]+_drop_(.+)\\.tre$", "\\1", bn)
  }

  primary_ages_vec <- node_ages_from_tree(primary_tree)
  sens_rows <- vector("list", length(jk_files))

  for (k in seq_along(jk_files)) {
    f       <- jk_files[[k]]
    dropped <- extract_dropped(f)
    tr_jk   <- tryCatch(read.tree(f), error = function(e) NULL)
    if (is.null(tr_jk)) {
      cat("  WARNING: could not read", basename(f), "\n")
      next
    }
    jk_ages <- tryCatch(node_ages_from_tree(tr_jk), error = function(e) NULL)
    if (is.null(jk_ages)) next

    # Match primary nodes to jk tree
    jk_age_vec <- match_node_ages(primary_tree, list(tr_jk))[, 1]
    delta <- jk_age_vec - primary_ages_vec

    sens_rows[[k]] <- data.frame(
      dropped_calibration = dropped,
      node_label          = names(primary_ages_vec),
      primary_age_Ma      = primary_ages_vec,
      jk_age_Ma           = jk_age_vec,
      delta_Ma            = delta,
      pct_change          = 100 * delta / primary_ages_vec,
      stringsAsFactors    = FALSE
    )
  }

  sens_df <- do.call(rbind, sens_rows[!sapply(sens_rows, is.null)])

  write.csv(sens_df, file.path(SUMMARY, "node_sensitivity.csv"), row.names = FALSE)
  cat("  Written:", file.path(SUMMARY, "node_sensitivity.csv"), "\n")

  # Most influential fossil per node: calibration whose removal causes largest |delta|
  most_influential <- tapply(seq_len(nrow(sens_df)), sens_df$node_label, function(idx) {
    sub_df <- sens_df[idx, ]
    sub_df[which.max(abs(sub_df$delta_Ma)), c("dropped_calibration", "delta_Ma", "pct_change")]
  })
  top_df <- do.call(rbind, most_influential)
  top_df$node_label <- names(most_influential)
  write.csv(top_df, file.path(SUMMARY, "most_influential_fossil_per_node.csv"), row.names = FALSE)
  cat("  Written:", file.path(SUMMARY, "most_influential_fossil_per_node.csv"), "\n\n")
}

# =============================================================================
# 4. BURMESE AMBER SENSITIVITY
# =============================================================================

cat("--- Burmese amber sensitivity ---\n")

if (!file.exists(AMBER_WITH) || !file.exists(AMBER_WITHOUT)) {
  cat("  WARNING: amber sensitivity trees not found. Skipping.\n")
  cat("  Expected:\n    ", AMBER_WITH, "\n    ", AMBER_WITHOUT, "\n\n")
} else {
  tree_with    <- read.tree(AMBER_WITH)
  tree_without <- read.tree(AMBER_WITHOUT)

  ages_with    <- match_node_ages(primary_tree, list(tree_with))[, 1]
  ages_without <- match_node_ages(primary_tree, list(tree_without))[, 1]

  amber_df <- data.frame(
    node_label         = names(primary_ages_vec),
    primary_age_Ma     = primary_ages_vec,
    with_amber_Ma      = ages_with,
    without_amber_Ma   = ages_without,
    delta_Ma           = ages_without - ages_with,
    pct_change         = 100 * (ages_without - ages_with) / primary_ages_vec,
    stringsAsFactors   = FALSE
  )
  amber_df <- amber_df[order(abs(amber_df$delta_Ma), decreasing = TRUE), ]

  write.csv(amber_df, file.path(SUMMARY, "amber_sensitivity.csv"), row.names = FALSE)
  cat("  Written:", file.path(SUMMARY, "amber_sensitivity.csv"), "\n")

  # Print top 10 most-affected nodes
  cat("\n  Top 10 nodes most affected by removing Burmese amber:\n")
  print(head(amber_df[, c("node_label", "primary_age_Ma", "with_amber_Ma",
                           "without_amber_Ma", "delta_Ma", "pct_change")], 10),
        row.names = FALSE)
  cat("\n")
}

# =============================================================================
# DONE
# =============================================================================

cat("=============================================================\n")
cat("Summary outputs in:", SUMMARY, "\n")
cat("  tob_dated_hpd.tre                      -- HPD-annotated dated tree\n")
cat("  node_ages_bootstrap.csv                -- full bootstrap age table\n")
cat("  node_sensitivity.csv                   -- jackknife sensitivity (all nodes)\n")
cat("  most_influential_fossil_per_node.csv   -- top fossil per node\n")
cat("  amber_sensitivity.csv                  -- amber on/off comparison\n")
cat("=============================================================\n")
cat("Finished:", format(Sys.time()), "\n")
