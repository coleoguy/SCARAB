#!/usr/bin/env Rscript
##############################################################################
# PHASE_2.2_full_alignment/split_tree.R
#
# Purpose:
#   Decompose the full Coleoptera phylogenetic tree at major clade boundaries
#   Identifies clade boundaries and splits guide tree into N subtrees
#   Generates per-subtree seqFiles for parallel alignment
#   Creates a backbone tree for final merging
#
# Input:
#   - Full constraint tree (Newick format)
#   - Full seqFile with all genome paths
#   - Number of subtrees to create (configurable)
#
# Output:
#   - subtree_1.nwk, subtree_2.nwk, ..., subtree_N.nwk
#   - subtree_1.seqfile, subtree_2.seqfile, ..., subtree_N.seqfile
#   - backbone.nwk (root + outgroups)
#   - split_tree_report.txt (summary and diagnostics)
#
# Usage:
#   Rscript split_tree.R \
#     --tree /path/to/pruned_tree.nwk \
#     --seqfile /path/to/seqFile.txt \
#     --output-dir /path/to/output \
#     --num-subtrees 5 \
#     --min-subtree-size 3
#
# Dependencies:
#   - ape (for tree reading/manipulation)
#   - tidyverse (optional, for reporting)
##############################################################################

suppressPackageStartupMessages({
  library(optparse)
  library(stringr)
  library(ape)
})

# Command-line argument parsing
option_list <- list(
  make_option(
    c("-t", "--tree"),
    type = "character",
    default = NULL,
    help = "Path to constraint tree (Newick format) [REQUIRED]"
  ),
  make_option(
    c("-s", "--seqfile"),
    type = "character",
    default = NULL,
    help = "Path to cactus seqFile with genome paths [REQUIRED]"
  ),
  make_option(
    c("-o", "--output-dir"),
    type = "character",
    default = "./split_tree_output",
    help = "Output directory for subtrees and seqFiles [default: %default]"
  ),
  make_option(
    c("-n", "--num-subtrees"),
    type = "integer",
    default = 5,
    help = "Target number of subtrees [default: %default]"
  ),
  make_option(
    c("-m", "--min-subtree-size"),
    type = "integer",
    default = 3,
    help = "Minimum genomes per subtree [default: %default]"
  ),
  make_option(
    c("-v", "--verbose"),
    type = "logical",
    default = TRUE,
    help = "Verbose output [default: %default]"
  )
)

parser <- OptionParser(option_list = option_list)
args <- parse_args(parser, positional_arguments = 0)

# Validate required arguments
if (is.null(args$tree) || is.null(args$seqfile)) {
  print_help(parser)
  cat("\nERROR: --tree and --seqfile are required\n", file = stderr())
  quit(status = 1)
}

tree_file <- args$tree
seqfile_path <- args$seqfile
output_dir <- args$output_dir
num_subtrees <- args$num_subtrees
min_size <- args$min_subtree_size
verbose <- args$verbose

# Create output directory
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Helper function for verbose logging
vlog <- function(msg) {
  if (verbose) {
    cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
  }
}

vlog(sprintf("Tree splitting pipeline started"))
vlog(sprintf("Tree file: %s", tree_file))
vlog(sprintf("seqFile: %s", seqfile_path))
vlog(sprintf("Output directory: %s", output_dir))
vlog(sprintf("Target subtrees: %d", num_subtrees))
vlog(sprintf("Minimum subtree size: %d", min_size))
vlog("")

# ============================================================================
# 1. Read constraint tree
# ============================================================================
vlog("Reading constraint tree...")

if (!file.exists(tree_file)) {
  stop(sprintf("ERROR: Tree file not found: %s", tree_file))
}

tree <- read.tree(tree_file)
vlog(sprintf("  ✓ Tree read successfully")
vlog(sprintf("  Number of tips: %d", length(tree$tip.label)))
vlog(sprintf("  Tree size: %.1f Mb", object.size(tree) / (1024^2)))
vlog("")

# ============================================================================
# 2. Read seqFile and parse genome information
# ============================================================================
vlog("Reading seqFile...")

if (!file.exists(seqfile_path)) {
  stop(sprintf("ERROR: seqFile not found: %s", seqfile_path))
}

seqfile_data <- read.delim(
  seqfile_path,
  header = FALSE,
  sep = " ",
  col.names = c("genome", "path"),
  stringsAsFactors = FALSE,
  comment.char = "#"
)

# Remove any empty rows
seqfile_data <- seqfile_data[seqfile_data$genome != "", ]

vlog(sprintf("  ✓ seqFile read successfully")
vlog(sprintf("  Number of genomes: %d", nrow(seqfile_data)))
vlog("")

# Verify all tree tips are in seqFile
tips_in_seqfile <- tree$tip.label %in% seqfile_data$genome
if (!all(tips_in_seqfile)) {
  missing_tips <- tree$tip.label[!tips_in_seqfile]
  vlog(sprintf("  WARNING: %d tree tips not in seqFile: %s",
               length(missing_tips), paste(head(missing_tips, 3), collapse = ", ")))
}

# ============================================================================
# 3. Identify major clade boundaries (automated)
# ============================================================================
vlog("Identifying major clades...")

# Function to extract clades at a given depth
get_clades_at_depth <- function(tree, target_num_clades) {
  # Start from root and identify internal nodes
  # Return list of subtrees rooted at internal nodes
  # that divide the tree into approximately target_num_clades parts

  n_internal <- tree$Nnode
  n_tips <- length(tree$tip.label)

  # Identify good split nodes
  # A good split divides tips somewhat evenly
  clades <- list()

  # Recursive function to collect clades
  collect_clades <- function(node, current_depth = 0) {
    if (node <= n_tips) {
      # Leaf node
      return(1)  # 1 tip
    }

    descendants <- tree$tip.label[
      is.na(tree$edge[, 2][tree$edge[, 1] == node])
    ]
    if (length(descendants) == 0) {
      # Find descendants manually via edge table
      desc_nodes <- c()
      to_visit <- c(node)
      visited <- c()

      while (length(to_visit) > 0) {
        current <- to_visit[1]
        to_visit <- to_visit[-1]
        visited <- c(visited, current)

        children <- tree$edge[tree$edge[, 1] == current, 2]
        for (child in children) {
          if (child <= n_tips) {
            descendants <- c(descendants, tree$tip.label[child])
          } else {
            to_visit <- c(to_visit, child)
          }
        }
      }
    }

    return(length(descendants))
  }

  # Simplified approach: find internal nodes with ~balanced subtrees
  clade_nodes <- which(
    sapply(seq(n_tips + 1, n_tips + n_internal), function(node) {
      # Count descendants
      1  # Placeholder; replace with actual count
    }) > 2
  ) + n_tips

  return(clade_nodes)
}

## <<<STUDENT: Customize clade identification for Coleoptera>>>
## Known major clades (adjust based on your phylogeny):
## - Adephaga (carabid beetles, dytiscids) - ~100+ species
## - Cucujiformia (lady beetles, bark lice) - ~100+ species
## - Elateriformia (click beetles, death watch) - ~50+ species
## - Staphyliniformia (rove beetles, silvanids) - ~100+ species
## - Remaining Polyphaga - ~20+ species
## - Outgroups (Neuropterida) - ~10-20 species

vlog("Clade structure (based on Coleoptera phylogeny):")

# For this automated approach, we identify clades by:
# 1. Looking for deep internal nodes
# 2. Splitting the tree to achieve roughly num_subtrees groups

# Identify candidate split nodes
n_tips <- length(tree$tip.label)
split_nodes <- list()

# Use edge lengths and clade sizes to identify good split points
for (node in (n_tips + 1):(n_tips + tree$Nnode)) {
  # Find all descendants of this node
  descendants <- tips_in_clade(tree, node)
  n_desc <- length(descendants)

  # We want clades with at least min_size and not more than n_tips / num_subtrees * 2
  ideal_size <- n_tips / num_subtrees
  max_size <- ideal_size * 1.5

  if (n_desc >= min_size && n_desc <= max_size) {
    split_nodes[[length(split_nodes) + 1]] <- list(
      node = node,
      descendants = descendants,
      size = n_desc
    )
  }
}

# Helper function: extract tips in a clade rooted at node
tips_in_clade <- function(tree, node) {
  n_tips <- length(tree$tip.label)

  # Find all descendants
  descendants <- c()
  to_visit <- c(node)

  while (length(to_visit) > 0) {
    current <- to_visit[1]
    to_visit <- to_visit[-1]

    if (current <= n_tips) {
      descendants <- c(descendants, tree$tip.label[current])
    } else {
      children <- tree$edge[tree$edge[, 1] == current, 2]
      to_visit <- c(to_visit, children)
    }
  }

  return(unique(descendants))
}

vlog(sprintf("  Identified %d candidate clade boundaries", length(split_nodes)))

# ============================================================================
# 4. Extract subtrees and create per-subtree seqFiles
# ============================================================================
vlog("")
vlog("Extracting subtrees...")

subtrees <- list()
subtree_seqfiles <- list()
subtree_names <- list()

for (i in 1:min(num_subtrees, length(split_nodes))) {
  node <- split_nodes[[i]]$node
  clade_tips <- split_nodes[[i]]$descendants

  vlog(sprintf("  Subtree %d: %d genomes", i, length(clade_tips)))

  # Store subtree information
  subtree_names[[i]] <- sprintf("subtree_%d", i)
  subtrees[[i]] <- clade_tips

  # Create per-subtree seqFile
  seqfile_subset <- seqfile_data[seqfile_data$genome %in% clade_tips, ]

  subtree_seqfile_path <- file.path(output_dir, sprintf("subtree_%d.seqfile", i))
  write.table(
    seqfile_subset,
    file = subtree_seqfile_path,
    quote = FALSE,
    sep = " ",
    col.names = FALSE,
    row.names = FALSE
  )

  vlog(sprintf("    → seqFile: %s", subtree_seqfile_path))
  subtree_seqfiles[[i]] <- subtree_seqfile_path
}

# ============================================================================
# 5. Extract simplified guide trees for each subtree
# ============================================================================
vlog("")
vlog("Extracting per-subtree guide trees...")

for (i in 1:length(subtrees)) {
  clade_tips <- subtrees[[i]]

  # Extract subtree with only these tips
  subtree <- drop.tip(tree, tree$tip.label[!(tree$tip.label %in% clade_tips)])

  # Write Newick format
  subtree_file <- file.path(output_dir, sprintf("subtree_%d.nwk", i))
  write.tree(subtree, file = subtree_file)

  vlog(sprintf("  Subtree %d: %s", i, subtree_file))
}

# ============================================================================
# 6. Create backbone tree (for merging subtrees)
# ============================================================================
vlog("")
vlog("Creating backbone tree for merging...")

## <<<STUDENT: Customize backbone tree structure>>>
## The backbone tree should have one leaf per subtree + outgroups
## For example: (subtree_1:1.0,subtree_2:1.0,...,outgroups:1.0);

# Build backbone tree with placeholder nodes
backbone_leaves <- c(sprintf("subtree_%d", 1:length(subtrees)))

# Add outgroups (genomes not in any subtree)
all_subtree_genomes <- unique(unlist(subtrees))
outgroup_genomes <- seqfile_data$genome[!(seqfile_data$genome %in% all_subtree_genomes)]

if (length(outgroup_genomes) > 0) {
  vlog(sprintf("  Outgroups: %d genomes", length(outgroup_genomes)))
  backbone_leaves <- c(backbone_leaves, outgroup_genomes)
}

# Create simple star tree for backbone
backbone_str <- paste(backbone_leaves, collapse = ":1.0,")
backbone_str <- sprintf("(%s:1.0);", backbone_str)

backbone_file <- file.path(output_dir, "backbone.nwk")
write(backbone_str, file = backbone_file)

vlog(sprintf("  Backbone tree: %s", backbone_file))

# Create backbone seqFile
backbone_seqfile <- seqfile_data[seqfile_data$genome %in% c(backbone_leaves, outgroup_genomes), ]
backbone_seqfile_path <- file.path(output_dir, "backbone.seqfile")
write.table(
  backbone_seqfile,
  file = backbone_seqfile_path,
  quote = FALSE,
  sep = " ",
  col.names = FALSE,
  row.names = FALSE
)

vlog(sprintf("  Backbone seqFile: %s (%d genomes)", basename(backbone_seqfile_path), nrow(backbone_seqfile)))

# ============================================================================
# 7. Generate split tree report
# ============================================================================
vlog("")
vlog("Generating report...")

report_file <- file.path(output_dir, "split_tree_report.txt")

report_text <- sprintf(
  "COLEOPTERA TREE SPLITTING REPORT
================================================================================
Generated: %s

INPUT:
  Tree file:        %s
  seqFile:          %s
  Total genomes:    %d
  Tree tips:        %d

SPLITTING PARAMETERS:
  Target subtrees:  %d
  Min subtree size: %d genomes

RESULTS:
  Subtrees created: %d
  Total coverage:   %d genomes

SUBTREE SUMMARY:
%s

BACKBONE CONFIGURATION:
  Backbone leaves:  %d (subtrees + outgroups)
  Outgroup count:   %d genomes

OUTPUT FILES:
  - subtree_*.nwk:      Per-subtree guide trees
  - subtree_*.seqfile:  Per-subtree genome lists
  - backbone.nwk:       Root alignment guide tree
  - backbone.seqfile:   Root alignment genome list

NEXT STEPS:
  1. Review per-subtree sizes and genetic distances
  2. Submit parallel subtree alignment jobs via submit_subtree.slurm
  3. Submit backbone alignment via submit_backbone.slurm
  4. Merge results with merge_subtrees.slurm

================================================================================",
  Sys.time(),
  tree_file,
  seqfile_path,
  nrow(seqfile_data),
  length(tree$tip.label),
  length(subtrees),
  min_size,
  length(subtrees),
  sum(sapply(subtrees, length)),
  paste(sprintf(
    "  Subtree %d:  %3d genomes", 1:length(subtrees), sapply(subtrees, length)
  ), collapse = "\n"),
  length(backbone_leaves),
  length(outgroup_genomes)
)

write(report_text, file = report_file)

# ============================================================================
# 8. Final summary and output list
# ============================================================================
vlog("")
vlog("Split tree pipeline completed successfully!")
vlog("")
vlog("OUTPUT SUMMARY:")
vlog("")

for (i in 1:length(subtrees)) {
  vlog(sprintf("Subtree %d:", i))
  vlog(sprintf("  Genomes:  %d", length(subtrees[[i]])))
  vlog(sprintf("  Tree:     subtree_%d.nwk", i))
  vlog(sprintf("  seqFile:  subtree_%d.seqfile", i))
}

vlog("")
vlog("Backbone:")
vlog(sprintf("  Genomes:  %d", length(backbone_leaves)))
vlog(sprintf("  Tree:     backbone.nwk"))
vlog(sprintf("  seqFile:  backbone.seqfile"))
vlog("")
vlog(sprintf("Full report: %s", report_file))
vlog("")
vlog(sprintf("Output directory: %s", output_dir))
