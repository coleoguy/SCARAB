#!/usr/bin/env Rscript
# ============================================================================
# filter_genomes_for_alignment.R
# ============================================================================
# Run on Grace BEFORE submitting the full Cactus alignment.
# Applies pre-defined assembly quality thresholds to the genome set
# (439 original or 478 with recovery genomes) and produces a filtered
# seqfile + pruned guide tree.
#
# CRITICAL: These thresholds reflect ASSEMBLY QUALITY, not alignment quality.
# They must be applied BEFORE any alignment output is inspected.
# Do not adjust thresholds based on alignment results.
#
# Usage (Grace login node):
#   module load R
#   Rscript filter_genomes_for_alignment.R \
#     --seqfile   $SCRATCH/scarab/cactus_seqfile_478.txt \
#     --tree      $SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_478_rooted.nwk \
#     --catalog   /path/to/genome_catalog.csv \
#     --outseq    $SCRATCH/scarab/cactus_seqfile_filtered.txt \
#     --outtree   $SCRATCH/scarab/guide_tree_filtered.nwk \
#     --outreport $SCRATCH/scarab/genome_filter_report.csv
#
# Thresholds (adjust only with biological justification, before running):
#   CONTIG_N50_MIN   : 100,000 bp  (minimum for reliable multi-gene synteny)
#   MAX_SCAFFOLDS    : 10,000      (maximum scaffold count)
#   MANDATORY_KEEP   : species that cannot be excluded regardless of metrics
# ============================================================================

library(optparse)
suppressPackageStartupMessages(library(ape))

# ============================================================================
# ARGUMENTS
# ============================================================================

option_list <- list(
  make_option("--seqfile",   type = "character", help = "Cactus seqfile (tree + genome paths)"),
  make_option("--tree",      type = "character", help = "Newick guide tree (rooted)"),
  make_option("--catalog",   type = "character", help = "genome_catalog.csv"),
  make_option("--outseq",    type = "character", help = "Output: filtered seqfile"),
  make_option("--outtree",   type = "character", help = "Output: pruned Newick tree"),
  make_option("--outreport", type = "character", help = "Output: per-genome filter report CSV")
)
opt <- parse_args(OptionParser(option_list = option_list))

# ============================================================================
# THRESHOLDS — established prior to alignment inspection
# ============================================================================

CONTIG_N50_MIN <- 100000   # 100 kb
MAX_SCAFFOLDS  <- 10000    # scaffolds

# Species that must remain in the alignment regardless of assembly metrics.
# Tribolium castaneum is the Stevens element reference genome.
MANDATORY_KEEP <- c(
  "Tribolium_castaneum",
  "Tribolium castaneum"
)

cat("============================================================\n")
cat("SCARAB Genome Quality Filter\n")
cat(sprintf("Run: %s\n", Sys.time()))
cat(sprintf("Thresholds:\n"))
cat(sprintf("  Contig N50 >= %d bp (%d kb)\n", CONTIG_N50_MIN, CONTIG_N50_MIN / 1000))
cat(sprintf("  Scaffold count <= %d\n", MAX_SCAFFOLDS))
cat(sprintf("  Mandatory keeps: %s\n", paste(MANDATORY_KEEP, collapse = ", ")))
cat("============================================================\n\n")

# ============================================================================
# READ SEQFILE
# ============================================================================

cat("Reading seqfile:", opt$seqfile, "\n")
seqlines <- readLines(opt$seqfile)
tree_line <- seqlines[1]  # first line is the Newick tree

# Parse genome lines: "TipLabel  /path/to/genome.fna"
genome_lines <- seqlines[-1]
genome_lines <- genome_lines[nchar(trimws(genome_lines)) > 0]

seqfile_df <- do.call(rbind, lapply(genome_lines, function(ln) {
  parts <- strsplit(trimws(ln), "\\s+")[[1]]
  data.frame(tip_label = parts[1], fasta_path = parts[2], stringsAsFactors = FALSE)
}))

cat(sprintf("Genomes in seqfile: %d\n\n", nrow(seqfile_df)))

# ============================================================================
# READ CATALOG
# ============================================================================

cat("Reading catalog:", opt$catalog, "\n")
cat_df <- read.csv(opt$catalog, stringsAsFactors = FALSE)

# Extract assembly accession from fasta path (handles both ncbi_dataset and flat formats)
# e.g. "genomes/GCA_964197645.1/ncbi_dataset/.../GCA_964197645.1_*.fna" -> "GCA_964197645.1"
# e.g. "genomes/GCA_044115395.1_icAgrPube1_p1.1_genomic.fna.gz"         -> "GCA_044115395.1"
# Also handles GCF_ RefSeq accessions.
acc_pat <- "G[A-Z]{2}_[0-9]+\\.[0-9]+"
m <- regexpr(acc_pat, seqfile_df$fasta_path)
seqfile_df$accession <- ifelse(m > 0, regmatches(seqfile_df$fasta_path, m), NA_character_)

# Join on accession (one catalog row per assembly, no duplicates)
joined <- merge(seqfile_df,
                cat_df[, c("assembly_accession", "species_name", "contig_N50",
                            "scaffold_N50", "number_of_scaffolds",
                            "assembly_level", "genome_size_mb")],
                by.x = "accession", by.y = "assembly_accession", all.x = TRUE)

# Handle unmatched (catalog info missing)
n_unmatched <- sum(is.na(joined$contig_N50))
if (n_unmatched > 0) {
  cat(sprintf("WARNING: %d genomes have no catalog match — will be KEPT by default.\n", n_unmatched))
  cat("  Unmatched tips:\n")
  cat(paste0("    ", joined$tip_label[is.na(joined$contig_N50)], collapse = "\n"), "\n\n")
}

# ============================================================================
# APPLY FILTERS
# ============================================================================

joined$fail_contig_n50 <- !is.na(joined$contig_N50) & joined$contig_N50 < CONTIG_N50_MIN
joined$fail_scaffold_count <- !is.na(joined$number_of_scaffolds) &
                               joined$number_of_scaffolds > MAX_SCAFFOLDS
joined$mandatory_keep <- joined$tip_label %in% MANDATORY_KEEP |
                          joined$species_name %in% MANDATORY_KEEP

joined$exclude <- (joined$fail_contig_n50 | joined$fail_scaffold_count) &
                   !joined$mandatory_keep

# Summarize
n_fail_cn50 <- sum(joined$fail_contig_n50 & !joined$mandatory_keep, na.rm = TRUE)
n_fail_sc   <- sum(joined$fail_scaffold_count & !joined$mandatory_keep, na.rm = TRUE)
n_mandatory_override <- sum(joined$mandatory_keep & (joined$fail_contig_n50 | joined$fail_scaffold_count), na.rm = TRUE)
n_exclude   <- sum(joined$exclude)
n_keep      <- nrow(joined) - n_exclude

cat("============================================================\n")
cat("FILTER RESULTS\n")
cat(sprintf("  Total genomes in seqfile:  %d\n", nrow(joined)))
cat(sprintf("  Fail contig N50 < %d kb:   %d\n", CONTIG_N50_MIN/1000, n_fail_cn50))
cat(sprintf("  Fail scaffold count > %d: %d\n", MAX_SCAFFOLDS, n_fail_sc))
cat(sprintf("  Mandatory keep (override): %d\n", n_mandatory_override))
cat(sprintf("  Total excluded:            %d\n", n_exclude))
cat(sprintf("  Retained for alignment:    %d\n", n_keep))
cat("============================================================\n\n")

if (n_exclude > 0) {
  cat("EXCLUDED genomes:\n")
  excl <- joined[joined$exclude, c("tip_label", "contig_N50", "number_of_scaffolds",
                                    "assembly_level", "fail_contig_n50", "fail_scaffold_count")]
  excl <- excl[order(-excl$number_of_scaffolds), ]
  for (i in seq_len(nrow(excl))) {
    reasons <- c()
    if (excl$fail_contig_n50[i]) reasons <- c(reasons, sprintf("contig_N50=%.1f kb", excl$contig_N50[i]/1000))
    if (excl$fail_scaffold_count[i]) reasons <- c(reasons, sprintf("scaffolds=%s", format(excl$number_of_scaffolds[i], big.mark=",")))
    cat(sprintf("  %s [%s]: %s\n", excl$tip_label[i], excl$assembly_level[i], paste(reasons, collapse = ", ")))
  }
  cat("\n")
}

if (n_mandatory_override > 0) {
  cat("MANDATORY KEEP (would have failed thresholds but retained):\n")
  mand <- joined[joined$mandatory_keep & (joined$fail_contig_n50 | joined$fail_scaffold_count), ]
  for (i in seq_len(nrow(mand))) {
    cat(sprintf("  %s: contig_N50=%.1f kb, scaffolds=%s\n",
                mand$tip_label[i],
                mand$contig_N50[i] / 1000,
                format(mand$number_of_scaffolds[i], big.mark = ",")))
  }
  cat("\n")
}

# ============================================================================
# PRUNE GUIDE TREE
# ============================================================================

cat("Pruning guide tree:", opt$tree, "\n")
tree_raw <- readLines(opt$tree)
tree <- read.tree(text = tree_raw)

tips_to_exclude <- joined$tip_label[joined$exclude]
tips_in_tree    <- tree$tip.label

# Check for any excluded tips not in tree
not_in_tree <- tips_to_exclude[!tips_to_exclude %in% tips_in_tree]
if (length(not_in_tree) > 0) {
  cat("WARNING: These excluded tips were not found in the guide tree:\n")
  cat(paste0("  ", not_in_tree, collapse = "\n"), "\n")
}

# Drop excluded tips
tips_to_drop <- tips_to_exclude[tips_to_exclude %in% tips_in_tree]
if (length(tips_to_drop) > 0) {
  pruned_tree <- drop.tip(tree, tips_to_drop)
  cat(sprintf("  Tree tips: %d -> %d (dropped %d)\n",
              length(tree$tip.label), length(pruned_tree$tip.label), length(tips_to_drop)))
} else {
  pruned_tree <- tree
  cat("  No tree tips to prune.\n")
}

# ============================================================================
# WRITE OUTPUTS
# ============================================================================

# Filtered seqfile
cat(sprintf("\nWriting filtered seqfile: %s\n", opt$outseq))
kept_rows <- joined[!joined$exclude, ]
pruned_newick <- write.tree(pruned_tree)
out_lines <- c(pruned_newick,
               paste(kept_rows$tip_label, kept_rows$fasta_path))
writeLines(out_lines, opt$outseq)
cat(sprintf("  Written %d genome lines\n", nrow(kept_rows)))

# Pruned tree
cat(sprintf("Writing pruned tree: %s\n", opt$outtree))
write.tree(pruned_tree, file = opt$outtree)

# Report CSV
cat(sprintf("Writing filter report: %s\n", opt$outreport))
report <- joined[, c("tip_label", "species_name", "assembly_accession",
                      "contig_N50", "scaffold_N50", "number_of_scaffolds",
                      "assembly_level", "genome_size_mb",
                      "fail_contig_n50", "fail_scaffold_count",
                      "mandatory_keep", "exclude")]
report <- report[order(report$exclude, report$tip_label), ]
write.csv(report, opt$outreport, row.names = FALSE)

cat("\n============================================================\n")
cat("DONE\n")
cat(sprintf("  Filtered seqfile: %s\n", opt$outseq))
cat(sprintf("  Pruned tree:      %s\n", opt$outtree))
cat(sprintf("  Filter report:    %s\n", opt$outreport))
cat("\nNEXT STEPS:\n")
cat("  1. Review the filter report and exclusion list with Heath\n")
cat("  2. If approved, update the seqfile in the full alignment script:\n")
cat(sprintf("     SEQFILE=%s\n", opt$outseq))
cat("  3. Update cactus_seqfile.txt with the filtered version\n")
cat("  4. Submit the full alignment: sbatch run_full_alignment.slurm\n")
cat("============================================================\n")
