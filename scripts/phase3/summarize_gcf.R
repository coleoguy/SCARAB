#!/usr/bin/env Rscript
# summarize_gcf.R — Summarize gene concordance factor results from IQ-TREE
# Input: results/species_tree/concordance_gcf.cf.stat
# Output: results/species_tree/gcf_summary.txt

gcf <- read.table("results/species_tree/concordance_gcf.cf.stat",
                   header = TRUE, sep = "\t", comment.char = "#")

# Drop root/NA branches
gcf <- gcf[!is.na(gcf$gCF), ]

cat("=== Gene Concordance Factor Summary ===\n\n")
cat(sprintf("Total internal branches scored: %d\n", nrow(gcf)))
cat(sprintf("Mean gCF: %.1f%%\n", mean(gcf$gCF)))
cat(sprintf("Median gCF: %.1f%%\n", median(gcf$gCF)))
cat(sprintf("SD gCF: %.1f%%\n", sd(gcf$gCF)))
cat(sprintf("Range: %.1f%% - %.1f%%\n\n", min(gcf$gCF), max(gcf$gCF)))

cat("--- Distribution ---\n")
cat(sprintf("gCF >= 50%% (majority gene tree support): %d (%.1f%%)\n",
            sum(gcf$gCF >= 50), sum(gcf$gCF >= 50) / nrow(gcf) * 100))
cat(sprintf("gCF >= 33%% (plurality support): %d (%.1f%%)\n",
            sum(gcf$gCF >= 33), sum(gcf$gCF >= 33) / nrow(gcf) * 100))
cat(sprintf("gCF 20-33%%: %d (%.1f%%)\n",
            sum(gcf$gCF >= 20 & gcf$gCF < 33),
            sum(gcf$gCF >= 20 & gcf$gCF < 33) / nrow(gcf) * 100))
cat(sprintf("gCF 10-20%%: %d (%.1f%%)\n",
            sum(gcf$gCF >= 10 & gcf$gCF < 20),
            sum(gcf$gCF >= 10 & gcf$gCF < 20) / nrow(gcf) * 100))
cat(sprintf("gCF < 10%% (essentially unresolved): %d (%.1f%%)\n\n",
            sum(gcf$gCF < 10), sum(gcf$gCF < 10) / nrow(gcf) * 100))

cat("--- Discordance Pattern ---\n")
cat(sprintf("Mean gDF1: %.1f%%\n", mean(gcf$gDF1)))
cat(sprintf("Mean gDF2: %.1f%%\n", mean(gcf$gDF2)))
cat(sprintf("Mean gDFP (polyphyly): %.1f%%\n\n", mean(gcf$gDFP)))

# Test for asymmetric discordance (introgression signal)
# Only consider branches with >100 decisive gene trees
decisive <- gcf[gcf$gN > 100, ]
cat(sprintf("Branches with >100 decisive gene trees: %d\n", nrow(decisive)))

# Asymmetry: |gDF1 - gDF2| > 10 and max/min > 2
asym <- decisive[decisive$gDF1 > 0 & decisive$gDF2 > 0, ]
asym$diff <- abs(asym$gDF1 - asym$gDF2)
asym$ratio <- ifelse(asym$gDF1 > asym$gDF2,
                     asym$gDF1 / asym$gDF2,
                     asym$gDF2 / asym$gDF1)
n_asym <- sum(asym$diff > 10 & asym$ratio > 2, na.rm = TRUE)
cat(sprintf("Branches with asymmetric discordance (|gDF1-gDF2|>10%%, ratio>2x): %d (%.1f%%)\n",
            n_asym, n_asym / nrow(decisive) * 100))
cat("  (Symmetric discordance = consistent with ILS; asymmetry may indicate introgression)\n\n")

# Top 10 highest gCF
cat("--- Top 10 Highest gCF Branches ---\n")
top <- gcf[order(-gcf$gCF), ][1:10, ]
for (i in seq_len(nrow(top))) {
  cat(sprintf("  Branch %d: gCF=%.1f%%, gDF1=%.1f%%, gDF2=%.1f%%, gDFP=%.1f%%, N=%d\n",
              top$ID[i], top$gCF[i], top$gDF1[i], top$gDF2[i], top$gDFP[i], top$gN[i]))
}

cat("\n--- Bottom 10 Lowest gCF Branches ---\n")
bot <- gcf[order(gcf$gCF), ][1:10, ]
for (i in seq_len(nrow(bot))) {
  cat(sprintf("  Branch %d: gCF=%.1f%%, gDF1=%.1f%%, gDF2=%.1f%%, gDFP=%.1f%%, N=%d\n",
              bot$ID[i], bot$gCF[i], bot$gDF1[i], bot$gDF2[i], bot$gDFP[i], bot$gN[i]))
}

# Quintile breakdown
cat("\n--- gCF Quintiles ---\n")
q <- quantile(gcf$gCF, probs = seq(0, 1, 0.2))
cat(sprintf("  0%%: %.1f\n  20%%: %.1f\n  40%%: %.1f\n  60%%: %.1f\n  80%%: %.1f\n  100%%: %.1f\n",
            q[1], q[2], q[3], q[4], q[5], q[6]))
