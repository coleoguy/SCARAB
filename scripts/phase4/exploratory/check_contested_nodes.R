library(ape)

tree <- read.tree("/tmp/wastral_species_tree_rooted.nwk")

# Load tip mapping for clade assignments
tmap <- read.csv("data/genomes/tree_tip_mapping.csv", stringsAsFactors=FALSE)
clade_lookup <- setNames(tmap$clade, tmap$tip_label)

# Key taxa for contested nodes
cat("=== Taxa present for key nodes ===\n\n")

# 1. Scirtoidea position - sister to rest of Polyphaga?
scirt <- c("Prionocyphon_serricornis", "Dascillus_cervinus")
cat("Scirtoidea:", paste(scirt[scirt %in% tree$tip.label], collapse=", "), "\n")

# 2. Check what's sister to what at deep Polyphaga nodes
# Get MRCA of each infraorder
adephaga_tips <- tmap$tip_label[tmap$clade == "Adephaga"]
cucuj_tips <- tmap$tip_label[tmap$clade == "Cucujiformia"]
elat_tips <- tmap$tip_label[tmap$clade == "Elateriformia"]
scarab_tips <- tmap$tip_label[tmap$clade == "Scarabaeiformia"]
staph_tips <- tmap$tip_label[tmap$clade == "Staphyliniformia"]
scirt_tips <- tmap$tip_label[tmap$clade == "Scirtoidea"]

# Outgroup
neuro_tips <- tmap$tip_label[tmap$clade %in% c("Neuroptera", "Megaloptera", "Raphidioptera")]

cat("\nClade sizes in tree:\n")
for (cl in c("Adephaga", "Cucujiformia", "Elateriformia", "Scarabaeiformia",
             "Staphyliniformia", "Scirtoidea", "Neuroptera", "Megaloptera", "Raphidioptera")) {
    tips <- tmap$tip_label[tmap$clade == cl]
    in_tree <- sum(tips %in% tree$tip.label)
    cat(sprintf("  %-20s %d\n", cl, in_tree))
}

# Extract the backbone topology by getting clade for each tip
# Then find what's sister to Scirtoidea
cat("\n=== Checking Scirtoidea position ===\n")
if (length(scirt_tips) > 0 && any(scirt_tips %in% tree$tip.label)) {
    scirt_in <- scirt_tips[scirt_tips %in% tree$tip.label]
    if (length(scirt_in) == 1) {
        # Find parent node, then sister clade
        node_idx <- which(tree$tip.label == scirt_in)
        parent <- tree$edge[tree$edge[,2] == node_idx, 1]
        # Get all descendants of parent
        siblings <- tree$edge[tree$edge[,1] == parent, 2]
        sister_node <- siblings[siblings != node_idx]
        if (sister_node <= Ntip(tree)) {
            cat("Scirtoidea sister taxon:", tree$tip.label[sister_node], "\n")
        } else {
            sister_tips <- extract.clade(tree, sister_node)$tip.label
            sister_clades <- table(clade_lookup[sister_tips])
            cat("Scirtoidea sister clade (", length(sister_tips), "tips):\n")
            print(sister_clades)
        }
    }
}

# Check monophyly of each infraorder
cat("\n=== Monophyly tests ===\n")
for (cl in c("Adephaga", "Cucujiformia", "Elateriformia", "Scarabaeiformia",
             "Staphyliniformia")) {
    tips <- tmap$tip_label[tmap$clade == cl]
    tips_in <- tips[tips %in% tree$tip.label]
    if (length(tips_in) >= 2) {
        mono <- is.monophyletic(tree, tips_in)
        cat(sprintf("  %-20s monophyletic: %s (n=%d)\n", cl, mono, length(tips_in)))
    }
}

# Check Neuropterida monophyly and internal arrangement
cat("\n=== Neuropterida (outgroup) arrangement ===\n")
mega_tips <- tmap$tip_label[tmap$clade == "Megaloptera"]
raph_tips <- tmap$tip_label[tmap$clade == "Raphidioptera"]
neuro_strict <- tmap$tip_label[tmap$clade == "Neuroptera"]

mega_in <- mega_tips[mega_tips %in% tree$tip.label]
raph_in <- raph_tips[raph_tips %in% tree$tip.label]
neuro_in <- neuro_strict[neuro_strict %in% tree$tip.label]

cat("Megaloptera monophyletic:", is.monophyletic(tree, mega_in), "(n=", length(mega_in), ")\n")
cat("Neuroptera monophyletic:", is.monophyletic(tree, neuro_in), "(n=", length(neuro_in), ")\n")
cat("Megaloptera+Neuroptera monophyletic:", is.monophyletic(tree, c(mega_in, neuro_in)), "\n")
cat("Megaloptera+Raphidioptera monophyletic:", is.monophyletic(tree, c(mega_in, raph_in)), "\n")

# Get the deep backbone: what's the sister to Adephaga among Polyphaga?
cat("\n=== Deep Polyphaga backbone ===\n")
# Find MRCA of all Polyphaga
poly_tips <- c(cucuj_tips, elat_tips, scarab_tips, staph_tips, scirt_tips)
poly_in <- poly_tips[poly_tips %in% tree$tip.label]
adeph_in <- adephaga_tips[adephaga_tips %in% tree$tip.label]

cat("Polyphaga monophyletic:", is.monophyletic(tree, poly_in), "(n=", length(poly_in), ")\n")
cat("Coleoptera monophyletic:", is.monophyletic(tree, c(poly_in, adeph_in)), "\n")

# Extract subtree for backbone analysis
# Get MRCA of Polyphaga, then check successive sisters
poly_mrca <- getMRCA(tree, poly_in)

# Walk up from Scirtoidea to find its placement
cat("\n=== Detailed backbone (walking from Scirtoidea) ===\n")
scirt_in <- scirt_tips[scirt_tips %in% tree$tip.label]
if (length(scirt_in) >= 1) {
    # Get the path from Scirtoidea MRCA to Polyphaga MRCA
    if (length(scirt_in) == 1) {
        current <- which(tree$tip.label == scirt_in[1])
    } else {
        current <- getMRCA(tree, scirt_in)
    }

    for (step in 1:10) {
        parent <- tree$edge[tree$edge[,2] == current, 1]
        if (length(parent) == 0) break
        children <- tree$edge[tree$edge[,1] == parent, 2]
        sister <- children[children != current]

        if (sister <= Ntip(tree)) {
            sister_tips_list <- tree$tip.label[sister]
        } else {
            sister_tips_list <- extract.clade(tree, sister)$tip.label
        }

        sister_clades <- table(clade_lookup[sister_tips_list])
        cat(sprintf("Step %d up: sister clade has %d tips: ", step, length(sister_tips_list)))
        cat(paste(paste0(names(sister_clades), "=", sister_clades), collapse=", "), "\n")

        current <- parent
        # Stop if we've reached the root or Coleoptera MRCA
        all_desc <- extract.clade(tree, current)$tip.label
        if (any(clade_lookup[all_desc] %in% c("Neuroptera", "Megaloptera", "Raphidioptera"), na.rm=TRUE)) break
    }
}

# Check Elateriformia: historically contentious for monophyly
cat("\n=== Elateriformia details ===\n")
elat_in <- elat_tips[elat_tips %in% tree$tip.label]
cat("Elateriformia tips:", length(elat_in), "\n")
# Check specific families
elat_families <- tmap$family[tmap$clade == "Elateriformia" & tmap$tip_label %in% tree$tip.label]
cat("Families:", paste(sort(unique(elat_families)), collapse=", "), "\n")

# Staphyliniformia + Scarabaeiformia sister? (= Haplogastra hypothesis)
cat("\n=== Haplogastra test (Staph + Scarab sister?) ===\n")
staph_in <- staph_tips[staph_tips %in% tree$tip.label]
scarab_in <- scarab_tips[scarab_tips %in% tree$tip.label]
haplo <- c(staph_in, scarab_in)
cat("Staphyliniformia+Scarabaeiformia monophyletic:", is.monophyletic(tree, haplo), "\n")
