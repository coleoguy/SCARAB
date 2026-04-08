library(ape)

tree <- read.tree("/tmp/wastral_species_tree_rooted.nwk")
tmap <- read.csv("data/genomes/tree_tip_mapping.csv", stringsAsFactors=FALSE)
clade_lookup <- setNames(tmap$clade, tmap$tip_label)

# Polyphaga is NOT monophyletic - something is breaking in
# Let's find what's intruding
poly_clades <- c("Cucujiformia", "Elateriformia", "Scarabaeiformia", "Staphyliniformia", "Scirtoidea")
poly_tips <- tmap$tip_label[tmap$clade %in% poly_clades & tmap$tip_label %in% tree$tip.label]
poly_mrca <- getMRCA(tree, poly_tips)
poly_subtree_tips <- extract.clade(tree, poly_mrca)$tip.label

# What non-Polyphaga tips are in the Polyphaga MRCA subtree?
intruders <- poly_subtree_tips[!(clade_lookup[poly_subtree_tips] %in% poly_clades)]
cat("=== Non-Polyphaga taxa within Polyphaga MRCA ===\n")
for (t in intruders) {
    cat(sprintf("  %s (%s)\n", t, clade_lookup[t]))
}

# Similarly check Adephaga
adeph_tips <- tmap$tip_label[tmap$clade == "Adephaga" & tmap$tip_label %in% tree$tip.label]
adeph_mrca <- getMRCA(tree, adeph_tips)
adeph_subtree_tips <- extract.clade(tree, adeph_mrca)$tip.label
adeph_intruders <- adeph_subtree_tips[clade_lookup[adeph_subtree_tips] != "Adephaga"]
cat("\n=== Non-Adephaga taxa within Adephaga MRCA ===\n")
for (t in adeph_intruders) {
    cat(sprintf("  %s (%s)\n", t, clade_lookup[t]))
}

# Check what breaks Cucujiformia monophyly
cat("\n=== Checking what breaks each series ===\n")
for (cl in c("Cucujiformia", "Elateriformia", "Scarabaeiformia", "Staphyliniformia")) {
    cl_tips <- tmap$tip_label[tmap$clade == cl & tmap$tip_label %in% tree$tip.label]
    if (length(cl_tips) < 2) next
    cl_mrca <- getMRCA(tree, cl_tips)
    cl_subtree <- extract.clade(tree, cl_mrca)$tip.label
    intruders <- cl_subtree[!(clade_lookup[cl_subtree] %in% cl)]
    if (length(intruders) > 0) {
        cat(sprintf("\n%s (n=%d) has %d intruders:\n", cl, length(cl_tips), length(intruders)))
        intruder_clades <- table(clade_lookup[intruders])
        print(intruder_clades)
        if (length(intruders) <= 10) {
            for (t in intruders) cat(sprintf("  %s (%s, %s)\n", t, clade_lookup[t],
                                             tmap$family[tmap$tip_label == t]))
        }
    }
}

# Now check the actual series-level topology
# Reduce to a backbone by picking 1 representative per infraorder
cat("\n=== Series-level backbone from wASTRAL ===\n")
# Use Tribolium for Cucujiformia reference
# Check where series interleave

# Get the path from Scirtoidea to root, noting what we pass
cat("\nPolyphaga infraordinal arrangement:\n")
# Scirtoidea is sister to the rest of Polyphaga (series)
# What's the arrangement of the 4 remaining series?
# Get the node that is (Cucuj + Elat + Scarab + Staph)
non_scirt_poly <- tmap$tip_label[tmap$clade %in% c("Cucujiformia", "Elateriformia",
                                                      "Scarabaeiformia", "Staphyliniformia") &
                                   tmap$tip_label %in% tree$tip.label]
ns_mrca <- getMRCA(tree, non_scirt_poly)
ns_subtree <- extract.clade(tree, ns_mrca)

# Walk the deep backbone of this subtree
cat("Walking the deep backbone of non-Scirtoidea Polyphaga...\n")
# Find which series pair is sister
for (cl1 in c("Cucujiformia", "Elateriformia", "Scarabaeiformia", "Staphyliniformia")) {
    for (cl2 in c("Cucujiformia", "Elateriformia", "Scarabaeiformia", "Staphyliniformia")) {
        if (cl1 >= cl2) next
        tips1 <- tmap$tip_label[tmap$clade == cl1 & tmap$tip_label %in% ns_subtree$tip.label]
        tips2 <- tmap$tip_label[tmap$clade == cl2 & tmap$tip_label %in% ns_subtree$tip.label]
        combined <- c(tips1, tips2)
        mono <- is.monophyletic(ns_subtree, combined)
        if (mono) cat(sprintf("  %s + %s = MONOPHYLETIC\n", cl1, cl2))
    }
}

# Neuropterida arrangement
cat("\n=== Neuropterida internal arrangement ===\n")
neuro_tips <- tmap$tip_label[tmap$clade == "Neuroptera" & tmap$tip_label %in% tree$tip.label]
mega_tips <- tmap$tip_label[tmap$clade == "Megaloptera" & tmap$tip_label %in% tree$tip.label]
raph_tips <- tmap$tip_label[tmap$clade == "Raphidioptera" & tmap$tip_label %in% tree$tip.label]

all_neuropterida <- c(neuro_tips, mega_tips, raph_tips)
neuro_subtree <- extract.clade(tree, getMRCA(tree, all_neuropterida))

cat("Neuroptera s.s. monophyletic:", is.monophyletic(neuro_subtree, neuro_tips), "\n")
cat("Mega+Neuro monophyletic:", is.monophyletic(neuro_subtree, c(mega_tips, neuro_tips)), "\n")
cat("Mega+Raph monophyletic:", is.monophyletic(neuro_subtree, c(mega_tips, raph_tips)), "\n")
cat("Neuro+Raph monophyletic:", is.monophyletic(neuro_subtree, c(neuro_tips, raph_tips)), "\n")

# What's the Neuropterida topology?
neuro_backbone <- drop.tip(neuro_subtree,
    neuro_subtree$tip.label[!(neuro_subtree$tip.label %in% c(neuro_tips[1], mega_tips[1], raph_tips[1]))])
cat("\nNeuropterida backbone (1 rep each):\n")
cat(write.tree(neuro_backbone), "\n")
