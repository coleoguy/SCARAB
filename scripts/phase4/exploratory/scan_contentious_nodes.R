library(ape)
library(phangorn)

tree <- read.tree("/tmp/wastral_species_tree_rooted.nwk")
tmap <- read.csv("data/genomes/tree_tip_mapping.csv", stringsAsFactors=FALSE)

# Get family for each tip
tip_family <- setNames(tmap$family, tmap$tip_label)

# Assign families to recovery taxa too
all_tips <- tree$tip.label
for (t in all_tips) {
    if (is.na(tip_family[t])) {
        fam <- tmap$family[tmap$tip_label == t]
        if (length(fam) > 0) tip_family[t] <- fam[1]
    }
}

# Load gene trees
tree_files <- list.files("/tmp/gene_trees", pattern="[.]treefile$", full.names=TRUE)

cat("=== Scanning family-level monophyly across gene trees ===\n\n")

# For each family with >= 5 tips, test monophyly in each gene tree
families_in_tree <- table(tip_family[tree$tip.label])
big_families <- names(families_in_tree[families_in_tree >= 5])
cat("Families with >= 5 tips:", length(big_families), "\n")
cat(paste(big_families, families_in_tree[big_families], sep="=", collapse=", "), "\n\n")

# Test monophyly in species tree first
cat("=== Family monophyly in wASTRAL species tree ===\n")
for (fam in sort(big_families)) {
    tips <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == fam]
    tips <- tips[tips %in% tree$tip.label]
    if (length(tips) < 2) next
    mono <- is.monophyletic(tree, tips)
    if (!mono) {
        cat(sprintf("  %-25s NOT monophyletic (n=%d)\n", fam, length(tips)))
    }
}

cat("\n=== Family monophyly: % of gene trees supporting ===\n")

# For families NOT monophyletic in species tree, count gene tree support
mono_counts <- list()
for (fam in sort(big_families)) {
    tips <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == fam]
    if (length(tips) < 3) next
    mono_counts[[fam]] <- c(mono=0, not_mono=0, tested=0)
}

for (fi in seq_along(tree_files)) {
    f <- tree_files[fi]
    gt <- tryCatch(read.tree(f), error=function(e) NULL)
    if (is.null(gt)) next

    for (fam in names(mono_counts)) {
        tips <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == fam]
        tips_in <- tips[tips %in% gt$tip.label]
        if (length(tips_in) < 3) next
        mono_counts[[fam]]["tested"] <- mono_counts[[fam]]["tested"] + 1
        if (is.monophyletic(gt, tips_in)) {
            mono_counts[[fam]]["mono"] <- mono_counts[[fam]]["mono"] + 1
        } else {
            mono_counts[[fam]]["not_mono"] <- mono_counts[[fam]]["not_mono"] + 1
        }
    }
    if (fi %% 200 == 0) cat("  processed", fi, "/", length(tree_files), "\n")
}

cat("\nFamily monophyly support across gene trees:\n")
mono_df <- data.frame(family=character(), n_tips=integer(),
                       tested=integer(), pct_mono=numeric(),
                       sp_tree_mono=logical(), stringsAsFactors=FALSE)
for (fam in sort(names(mono_counts))) {
    mc <- mono_counts[[fam]]
    if (mc["tested"] < 100) next
    tips <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == fam]
    tips <- tips[tips %in% tree$tip.label]
    sp_mono <- is.monophyletic(tree, tips)
    pct <- 100 * mc["mono"] / mc["tested"]
    mono_df <- rbind(mono_df, data.frame(family=fam, n_tips=length(tips),
                                          tested=mc["tested"], pct_mono=round(pct, 1),
                                          sp_tree_mono=sp_mono, stringsAsFactors=FALSE))
}
mono_df <- mono_df[order(mono_df$pct_mono), ]
print(mono_df, row.names=FALSE)

# Now check some specific contentious relationships:
cat("\n\n=== SPECIFIC CONTENTIOUS NODES ===\n")

# 1. Chrysomelidae monophyly (some argue Cerambycidae nests within)
cat("\n--- Chrysomeloidea: Chrysomelidae + Cerambycidae sister? ---\n")
chryso <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Chrysomelidae"]
ceramb <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Cerambycidae"]
chryso <- chryso[chryso %in% tree$tip.label]
ceramb <- ceramb[ceramb %in% tree$tip.label]
cat("Chrysomelidae:", length(chryso), "tips\n")
cat("Cerambycidae:", length(ceramb), "tips\n")
cat("Chrysomeloidea (Chryso+Ceramb) monophyletic:", is.monophyletic(tree, c(chryso, ceramb)), "\n")

# 2. Curculionoidea: Curculionidae paraphyly is contentious
cat("\n--- Curculionidae monophyly ---\n")
curc <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Curculionidae"]
curc <- curc[curc %in% tree$tip.label]
cat("Curculionidae:", length(curc), "tips, monophyletic:", is.monophyletic(tree, curc), "\n")

# 3. Lampyridae (fireflies) - historically messy
cat("\n--- Lampyridae monophyly ---\n")
lamp <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Lampyridae"]
lamp <- lamp[lamp %in% tree$tip.label]
cat("Lampyridae:", length(lamp), "tips, monophyletic:", is.monophyletic(tree, lamp), "\n")

# 4. Scarabaeidae monophyly
cat("\n--- Scarabaeidae monophyly ---\n")
scarab <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Scarabaeidae"]
scarab <- scarab[scarab %in% tree$tip.label]
cat("Scarabaeidae:", length(scarab), "tips, monophyletic:", is.monophyletic(tree, scarab), "\n")

# 5. Staphylinidae monophyly
cat("\n--- Staphylinidae monophyly ---\n")
staph <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Staphylinidae"]
staph <- staph[staph %in% tree$tip.label]
cat("Staphylinidae:", length(staph), "tips, monophyletic:", is.monophyletic(tree, staph), "\n")

# 6. Coccinellidae
cat("\n--- Coccinellidae monophyly ---\n")
cocc <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == "Coccinellidae"]
cocc <- cocc[cocc %in% tree$tip.label]
cat("Coccinellidae:", length(cocc), "tips, monophyletic:", is.monophyletic(tree, cocc), "\n")

# 7. Dynastinae within Scarabaeidae - the Hercules beetles
cat("\n--- Dynastes monophyly (Hercules beetle complex) ---\n")
dynastes <- tree$tip.label[grepl("^Dynastes_", tree$tip.label)]
cat("Dynastes:", length(dynastes), "tips, monophyletic:", is.monophyletic(tree, dynastes), "\n")

# 8. Check which families are NOT monophyletic in species tree
# and what's intruding
cat("\n\n=== INTRUDERS breaking family monophyly ===\n")
for (fam in sort(big_families)) {
    tips <- all_tips[!is.na(tip_family[all_tips]) & tip_family[all_tips] == fam]
    tips <- tips[tips %in% tree$tip.label]
    if (length(tips) < 3) next
    if (is.monophyletic(tree, tips)) next

    mrca_node <- getMRCA(tree, tips)
    mrca_tips <- extract.clade(tree, mrca_node)$tip.label
    intruders <- mrca_tips[!(mrca_tips %in% tips)]
    intruder_fams <- tip_family[intruders]

    if (length(intruders) <= 15) {
        cat(sprintf("\n%s (n=%d) — intruders in MRCA:\n", fam, length(tips)))
        for (t in intruders) {
            cat(sprintf("  %s (%s)\n", t, tip_family[t]))
        }
    } else {
        cat(sprintf("\n%s (n=%d) — %d intruders: ", fam, length(tips), length(intruders)))
        cat(paste(paste0(names(table(intruder_fams)), "=", table(intruder_fams)), collapse=", "), "\n")
    }
}
