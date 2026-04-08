library(ape)
library(phangorn)

# Load species tree
sp_tree <- read.tree("/tmp/wastral_species_tree_rooted.nwk")
cat("Species tree:", Ntip(sp_tree), "tips\n")

# Load Stevens element map
smap <- read.delim("/tmp/busco_tribolium_stevens_map.tsv", stringsAsFactors=FALSE)
cat("Stevens map:", nrow(smap), "rows,", length(unique(smap$stevens_element)), "elements\n")
cat("Elements:", paste(sort(unique(smap$stevens_element)), collapse=", "), "\n\n")

# Load gene trees
tree_files <- list.files("/tmp/gene_trees", pattern="[.]treefile$", full.names=TRUE)
cat("Gene tree files:", length(tree_files), "\n")

# Build locus -> element lookup
locus_element <- setNames(smap$stevens_element, smap$busco_id)

# Compute normalized RF distance from each gene tree to species tree
locus_vec <- character()
element_vec <- character()
nrf_vec <- numeric()
ntips_vec <- integer()

for (i in seq_along(tree_files)) {
    f <- tree_files[i]
    locus <- sub("[.]treefile$", "", basename(f))
    gt <- tryCatch(read.tree(f), error=function(e) NULL)
    if (is.null(gt)) next

    # Get element
    elem <- locus_element[locus]
    if (is.na(elem)) next

    # Prune species tree to gene tree taxa
    shared <- intersect(gt$tip.label, sp_tree$tip.label)
    if (length(shared) < 10) next

    sp_pruned <- drop.tip(sp_tree, setdiff(sp_tree$tip.label, shared))
    gt_pruned <- drop.tip(gt, setdiff(gt$tip.label, shared))

    # Normalized RF distance
    rf <- RF.dist(sp_pruned, gt_pruned, normalize=TRUE)

    locus_vec <- c(locus_vec, locus)
    element_vec <- c(element_vec, elem)
    nrf_vec <- c(nrf_vec, rf)
    ntips_vec <- c(ntips_vec, length(shared))

    if (i %% 200 == 0) cat("  processed", i, "/", length(tree_files), "\n")
}

results <- data.frame(locus=locus_vec, element=element_vec, nRF=nrf_vec,
                       ntips=ntips_vec, stringsAsFactors=FALSE)

cat("Computed RF for", nrow(results), "loci\n\n")

# Summary by element
cat("=== Normalized RF distance to species tree by Stevens element ===\n")
for (e in sort(unique(results$element))) {
    vals <- results$nRF[results$element == e]
    cat(sprintf("  %s: n=%4d  mean=%.4f  median=%.4f  sd=%.4f\n",
        sprintf("%-5s", e), length(vals), mean(vals), median(vals), sd(vals)))
}

cat("\n=== Kruskal-Wallis test: nRF ~ Stevens element ===\n")
kw <- kruskal.test(nRF ~ element, data=results)
print(kw)

# Exclude "none" for cleaner analysis
results_mapped <- results[results$element != "none", ]
cat("\n=== Kruskal-Wallis (excluding unmapped 'none') ===\n")
kw2 <- kruskal.test(nRF ~ element, data=results_mapped)
print(kw2)

cat("\n=== X chromosome comparison ===\n")
x_rf <- results_mapped$nRF[results_mapped$element == "X"]
auto_rf <- results_mapped$nRF[results_mapped$element != "X"]
cat(sprintf("X chromosome: n=%d, mean nRF=%.4f, median=%.4f\n",
    length(x_rf), mean(x_rf), median(x_rf)))
cat(sprintf("Autosomes:    n=%d, mean nRF=%.4f, median=%.4f\n",
    length(auto_rf), mean(auto_rf), median(auto_rf)))
wt <- wilcox.test(x_rf, auto_rf)
cat(sprintf("Wilcoxon X vs autosomes: W=%.0f, p=%.6f\n", wt$statistic, wt$p.value))

cat("\n=== Pairwise: each element vs all others ===\n")
for (e in sort(unique(results_mapped$element))) {
    this <- results_mapped$nRF[results_mapped$element == e]
    rest <- results_mapped$nRF[results_mapped$element != e]
    wt <- wilcox.test(this, rest)
    direction <- ifelse(mean(this) > mean(rest), "MORE discordant", "LESS discordant")
    cat(sprintf("  %s (n=%3d, mean=%.4f) vs rest (%.4f): p=%.4f  %s\n",
        sprintf("%-5s", e), length(this), mean(this), mean(rest), wt$p.value, direction))
}

# Save
write.csv(results, "/tmp/gene_tree_rf_by_element.csv", row.names=FALSE)
cat("\nResults saved to /tmp/gene_tree_rf_by_element.csv\n")
