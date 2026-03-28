#!/usr/bin/env Rscript
# ============================================================================
# discordance_x_breakpoints.R
# ============================================================================
# Test whether gene tree discordance correlates with chromosomal breakpoints.
#
# Hypothesis: Genes near rearrangement breakpoints show higher discordance
# (lower gCF/sCF) than genes in conserved syntenic blocks, consistent with
# the chromosomal speciation model (Rieseberg/Noor/Navarro-Barton).
#
# Inputs:
#   1. Per-gene concordance factors (gCF/sCF from IQ-TREE, produced by P6/P7)
#   2. BUSCO-to-Stevens-element mapping (busco_tribolium_stevens_map.tsv)
#   3. Cactus-inferred breakpoints (from HAL, Phase 4 output)
#   4. Species tree (ASTRAL or IQ-TREE concatenation)
#
# Outputs:
#   - Per-gene discordance scores with chromosomal position
#   - Statistical tests: discordance ~ distance_to_breakpoint
#   - Per-Stevens-element concordance summaries
#   - Figures: discordance along chromosomes, breakpoint enrichment
#
# Analysis stages:
#   A. Gene-level concordance x chromosomal position
#   B. Breakpoint proximity test (requires Cactus output)
#   C. Per-node temporal analysis (at high-rearrangement nodes, does
#      discordance increase for breakpoint-proximal genes?)
#   D. Per-Stevens-element concordance factor summary
#
# Dependencies: ape, phytools, ggplot2, data.table
# ============================================================================

library(ape)
library(data.table)
library(ggplot2)

# ============================================================================
# CONFIGURATION — update paths after pipeline completes
# ============================================================================

# From P6 (ASTRAL) or P7 (concatenation IQ-TREE)
SPECIES_TREE    <- ""  # ASTRAL species tree
GCF_FILE        <- ""  # gCF/sCF output from IQ-TREE concordance analysis

# From BUSCO mapping (already exists)
STEVENS_MAP     <- "phylogenomics/busco_tribolium_stevens_map.tsv"

# From Cactus Phase 4 (future)
BREAKPOINTS_BED <- ""  # BED file of Cactus-inferred breakpoints on T. castaneum

# Output
OUT_DIR         <- "results/discordance_analysis/"

# ============================================================================
# STAGE A: Gene-level concordance x chromosomal position
# ============================================================================
# This stage can run as soon as P6/P7 produces concordance factors.
# It does NOT require Cactus output.

run_stage_A <- function(gcf_file, stevens_map_file, out_dir) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

    # Load Stevens element mapping with chromosomal positions
    smap <- fread(stevens_map_file)
    # Columns: busco_id, variant_id, protein_length, tcas_scaffold,
    #          tcas_start, tcas_end, strand, pident, evalue,
    #          icTriCast1_chr, tcas52_LG, stevens_element

    # Load concordance factors (format depends on IQ-TREE output)
    # Expected: gene_id, gCF, sCF, gDF1, gDF2, gN
    gcf <- fread(gcf_file)

    # Match gene IDs: the gCF file uses BUSCO IDs as gene names
    # Strip variant suffix (_0, _5, etc.) if present for matching
    smap[, busco_base := sub("_[0-9]+$", "", busco_id)]
    gcf[, busco_base := sub("_[0-9]+$", "", gene_id)]

    merged <- merge(gcf, smap, by = "busco_base", all.x = TRUE)

    # Midpoint position on T. castaneum chromosome
    merged[, tcas_midpoint := (tcas_start + tcas_end) / 2]

    # ---- Per-Stevens-element concordance summary ----
    element_summary <- merged[stevens_element != "NA" & stevens_element != "none",
        .(
            n_genes = .N,
            mean_gCF = mean(gCF, na.rm = TRUE),
            median_gCF = median(gCF, na.rm = TRUE),
            mean_sCF = mean(sCF, na.rm = TRUE),
            sd_gCF = sd(gCF, na.rm = TRUE)
        ),
        by = stevens_element
    ]
    cat("=== Per-Stevens-element concordance ===\n")
    print(element_summary[order(stevens_element)])

    fwrite(element_summary, file.path(out_dir, "stevens_element_concordance.csv"))

    # ---- Concordance along chromosomes ----
    # Plot gCF vs chromosomal position for each Stevens element
    plot_data <- merged[stevens_element != "NA" & stevens_element != "none"]

    p <- ggplot(plot_data, aes(x = tcas_midpoint / 1e6, y = gCF)) +
        geom_point(alpha = 0.3, size = 0.8) +
        geom_smooth(method = "loess", span = 0.3, se = TRUE, color = "red") +
        facet_wrap(~stevens_element, scales = "free_x", ncol = 3) +
        labs(
            x = "Position on T. castaneum chromosome (Mb)",
            y = "Gene concordance factor (gCF)",
            title = "Gene tree concordance across Stevens elements"
        ) +
        theme_minimal()

    ggsave(file.path(out_dir, "gCF_along_chromosomes.pdf"), p, width = 12, height = 10)
    cat("Saved: gCF_along_chromosomes.pdf\n")

    # ---- Test: does gCF vary among Stevens elements? ----
    if (nrow(plot_data) > 50) {
        kw <- kruskal.test(gCF ~ stevens_element, data = plot_data)
        cat(sprintf("\nKruskal-Wallis test (gCF ~ Stevens element): chi2=%.2f, p=%.2e\n",
                    kw$statistic, kw$p.value))
    }

    # ---- X chromosome enrichment ----
    # Test whether X-linked genes show different concordance
    merged[, is_X := stevens_element == "X"]
    if (sum(merged$is_X, na.rm = TRUE) > 10) {
        wt <- wilcox.test(gCF ~ is_X, data = merged[!is.na(is_X)])
        cat(sprintf("X vs autosome gCF: W=%.0f, p=%.4f\n", wt$statistic, wt$p.value))
        cat(sprintf("  X mean gCF: %.2f, Autosome mean gCF: %.2f\n",
                    mean(merged[is_X == TRUE]$gCF, na.rm = TRUE),
                    mean(merged[is_X == FALSE]$gCF, na.rm = TRUE)))
    }

    return(merged)
}


# ============================================================================
# STAGE B: Breakpoint proximity test (requires Cactus output)
# ============================================================================
# After Cactus alignment and breakpoint calling, test whether genes
# near breakpoints show elevated discordance.

run_stage_B <- function(merged, breakpoints_bed, out_dir) {
    # Load breakpoints (BED format: chrom, start, end, type, node)
    bp <- fread(breakpoints_bed)
    names(bp)[1:3] <- c("chrom", "bp_start", "bp_end")

    # For each gene, compute distance to nearest breakpoint on same chromosome
    merged[, min_dist_to_bp := {
        chr_bp <- bp[chrom == tcas_scaffold]
        if (nrow(chr_bp) == 0) return(NA_real_)
        min(abs(tcas_midpoint - (chr_bp$bp_start + chr_bp$bp_end) / 2))
    }, by = seq_len(nrow(merged))]

    # Bin genes by distance to nearest breakpoint
    merged[, bp_proximity := cut(min_dist_to_bp,
        breaks = c(0, 100000, 500000, 1000000, 5000000, Inf),
        labels = c("<100kb", "100-500kb", "0.5-1Mb", "1-5Mb", ">5Mb")
    )]

    # Test: discordance ~ proximity to breakpoint
    cat("=== gCF by distance to nearest breakpoint ===\n")
    prox_summary <- merged[!is.na(bp_proximity),
        .(n = .N, mean_gCF = mean(gCF, na.rm = TRUE), sd_gCF = sd(gCF, na.rm = TRUE)),
        by = bp_proximity
    ]
    print(prox_summary)

    # Correlation test
    cor_test <- cor.test(merged$min_dist_to_bp, merged$gCF,
                         method = "spearman", use = "complete.obs")
    cat(sprintf("\nSpearman correlation (distance_to_bp ~ gCF): rho=%.3f, p=%.2e\n",
                cor_test$estimate, cor_test$p.value))

    # Plot
    p <- ggplot(merged[!is.na(bp_proximity)], aes(x = bp_proximity, y = gCF)) +
        geom_boxplot(outlier.size = 0.5) +
        labs(
            x = "Distance to nearest Cactus breakpoint",
            y = "Gene concordance factor (gCF)",
            title = "Gene tree discordance vs breakpoint proximity"
        ) +
        theme_minimal()

    ggsave(file.path(out_dir, "gCF_vs_breakpoint_proximity.pdf"), p, width = 8, height = 6)

    fwrite(merged[, .(busco_id, stevens_element, tcas_midpoint, gCF, sCF,
                       min_dist_to_bp, bp_proximity)],
           file.path(out_dir, "gene_discordance_breakpoint_data.csv"))

    return(merged)
}


# ============================================================================
# STAGE C: Temporal analysis at rearrangement-rich nodes
# ============================================================================
# At phylogenetic nodes with high rearrangement rates (from Cactus),
# does discordance increase specifically for breakpoint-proximal genes?

run_stage_C <- function(merged, species_tree_file, gcf_per_node_file, out_dir) {
    # This analysis requires:
    # 1. Per-branch rearrangement rates from Cactus
    # 2. Per-gene, per-branch concordance (from IQ-TREE --gcf per internal node)
    #
    # For each internal node in the species tree:
    #   - Get rearrangement rate (fusions + fissions + inversions per My)
    #   - Get per-gene gCF at that node
    #   - Test: interaction between rearrangement rate and breakpoint proximity
    #
    # This is the strongest test of the chromosomal speciation model:
    # rearrangements should reduce gene flow specifically near breakpoints,
    # increasing discordance at those loci on the branches where rearrangements occur.

    cat("Stage C requires per-node rearrangement rates from Cactus.\n")
    cat("Placeholder: will implement after HAL analysis in Phase 4.\n")
}


# ============================================================================
# STAGE D: Per-Stevens-element summary for manuscript
# ============================================================================

run_stage_D <- function(merged, out_dir) {
    # Publication-ready summary table
    summary_table <- merged[stevens_element != "NA",
        .(
            n_loci = .N,
            mean_gCF = round(mean(gCF, na.rm = TRUE), 1),
            mean_sCF = round(mean(sCF, na.rm = TRUE), 1),
            pct_concordant = round(100 * mean(gCF > 50, na.rm = TRUE), 1),
            pct_high_discord = round(100 * mean(gCF < 20, na.rm = TRUE), 1)
        ),
        by = .(stevens_element)
    ][order(stevens_element)]

    cat("=== Stevens element concordance summary (manuscript table) ===\n")
    print(summary_table)

    fwrite(summary_table, file.path(out_dir, "Table_S_stevens_concordance.csv"))

    return(summary_table)
}


# ============================================================================
# MAIN — run stages as data becomes available
# ============================================================================

# Uncomment stages as inputs are ready:
#
# After P6/P7:
#   merged <- run_stage_A(GCF_FILE, STEVENS_MAP, OUT_DIR)
#   run_stage_D(merged, OUT_DIR)
#
# After Cactus Phase 4 breakpoint calling:
#   merged <- run_stage_B(merged, BREAKPOINTS_BED, OUT_DIR)
#
# After per-node rearrangement rates:
#   run_stage_C(merged, SPECIES_TREE, GCF_PER_NODE, OUT_DIR)

cat("discordance_x_breakpoints.R loaded.\n")
cat("Run stages individually as pipeline data becomes available.\n")
cat("See comments in MAIN section for usage.\n")
