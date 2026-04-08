library(ape)
library(phangorn)
library(ggplot2)

# Load results from previous analysis
results <- read.csv("/tmp/gene_tree_rf_by_element.csv", stringsAsFactors=FALSE)

# Load Stevens map for chromosomal positions
smap <- read.delim("/tmp/busco_tribolium_stevens_map.tsv", stringsAsFactors=FALSE)

# Merge: add chromosomal position to RF results
# Use busco_id as key
merged <- merge(results, smap[, c("busco_id", "tcas_scaffold", "tcas_start", "tcas_end",
                                   "icTriCast1_chr", "tcas52_LG", "stevens_element")],
                by.x="locus", by.y="busco_id", all.x=TRUE)

merged$midpoint <- (merged$tcas_start + merged$tcas_end) / 2
merged$midpoint_mb <- merged$midpoint / 1e6

# Drop unmapped
mapped <- merged[!is.na(merged$icTriCast1_chr) & merged$element != "none", ]
cat("Mapped loci with positions:", nrow(mapped), "\n")

# Order chromosomes by element name
mapped$element <- factor(mapped$element, levels=c("A","B","C","D","E","F","G","H","X"))

# Use icTriCast1 chromosome names for facets
cat("\nChromosomes:\n")
print(table(mapped$icTriCast1_chr, mapped$element))

# Plot: nRF along each Stevens element/chromosome
p <- ggplot(mapped, aes(x=midpoint_mb, y=nRF)) +
    geom_point(alpha=0.25, size=0.8, color="grey30") +
    geom_smooth(method="loess", span=0.3, se=TRUE, color="firebrick", linewidth=0.8) +
    geom_hline(yintercept=mean(mapped$nRF), linetype="dashed", color="blue", alpha=0.5) +
    facet_wrap(~element, scales="free_x", ncol=3) +
    labs(x="Position on Tribolium chromosome (Mb)",
         y="Normalized RF distance to species tree",
         title="Gene tree discordance along Stevens elements",
         subtitle=paste0("1,203 BUSCO loci mapped to Tribolium coordinates | ",
                         "Blue dashed = genome-wide mean | Red = loess smooth")) +
    theme_minimal(base_size=11) +
    theme(strip.text=element_text(face="bold", size=12),
          panel.grid.minor=element_blank())

ggsave("/tmp/discordance_along_chromosomes.pdf", p, width=12, height=10)
cat("Saved: /tmp/discordance_along_chromosomes.pdf\n")

# Also make a version colored by whether above/below mean
mapped$above_mean <- ifelse(mapped$nRF > mean(mapped$nRF), "above", "below")

p2 <- ggplot(mapped, aes(x=midpoint_mb, y=nRF)) +
    geom_point(aes(color=above_mean), alpha=0.35, size=1) +
    scale_color_manual(values=c("above"="firebrick", "below"="steelblue"), guide="none") +
    geom_smooth(method="loess", span=0.3, se=TRUE, color="black", linewidth=0.8) +
    facet_wrap(~element, scales="free_x", ncol=3) +
    labs(x="Position on Tribolium chromosome (Mb)",
         y="Normalized RF distance to species tree",
         title="Gene tree discordance along Stevens elements",
         subtitle="Red = above genome-wide mean discordance | Blue = below") +
    theme_minimal(base_size=11) +
    theme(strip.text=element_text(face="bold", size=12),
          panel.grid.minor=element_blank())

ggsave("/tmp/discordance_along_chromosomes_colored.pdf", p2, width=12, height=10)
cat("Saved: /tmp/discordance_along_chromosomes_colored.pdf\n")

# Print any regional hotspots (loess residuals)
cat("\n=== Regions with highest discordance (top 20 loci) ===\n")
top <- mapped[order(-mapped$nRF), c("locus", "element", "midpoint_mb", "nRF", "ntips")]
print(head(top, 20), row.names=FALSE)

cat("\n=== Regions with lowest discordance (top 20 loci) ===\n")
bot <- mapped[order(mapped$nRF), c("locus", "element", "midpoint_mb", "nRF", "ntips")]
print(head(bot, 20), row.names=FALSE)
