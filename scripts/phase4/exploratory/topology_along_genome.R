library(ape)
library(phangorn)
library(ggplot2)

tree <- read.tree("/tmp/wastral_species_tree_rooted.nwk")
tmap <- read.csv("data/genomes/tree_tip_mapping.csv", stringsAsFactors=FALSE)
smap <- read.delim("/tmp/busco_tribolium_stevens_map.tsv", stringsAsFactors=FALSE)

# Build clade lookup including recovery taxa via family
clade_lookup <- setNames(tmap$clade, tmap$tip_label)

# For recovery taxa (NA in tmap), assign clade by family
family_to_clade <- c(
    Carabidae="Adephaga", Dytiscidae="Adephaga", Gyrinidae="Adephaga",
    Chrysomelidae="Cucujiformia", Cerambycidae="Cucujiformia", Curculionidae="Cucujiformia",
    Coccinellidae="Cucujiformia", Tenebrionidae="Cucujiformia", Meloidae="Cucujiformia",
    Anthribidae="Cucujiformia", Attelabidae="Cucujiformia", Brentidae="Cucujiformia",
    Nitidulidae="Cucujiformia", Silvanidae="Cucujiformia", Cryptophagidae="Cucujiformia",
    Mycetophagidae="Cucujiformia", Latridiidae="Cucujiformia", Endomychidae="Cucujiformia",
    Cleridae="Cucujiformia", Melyridae="Cucujiformia", Ptinidae="Cucujiformia",
    Dermestidae="Cucujiformia", Bostrichidae="Cucujiformia", Bothrideridae="Cucujiformia",
    Ciidae="Cucujiformia", Mordellidae="Cucujiformia", Pyrochroidae="Cucujiformia",
    Salpingidae="Cucujiformia", Oedemeridae="Cucujiformia", Aderidae="Cucujiformia",
    Ripiphoridae="Cucujiformia", Cerylonidae="Cucujiformia", Monotomidae="Cucujiformia",
    Glaphyridae="Scarabaeiformia",
    Scarabaeidae="Scarabaeiformia", Lucanidae="Scarabaeiformia", Geotrupidae="Scarabaeiformia",
    Staphylinidae="Staphyliniformia", Silphidae="Staphyliniformia",
    Hydrophilidae="Staphyliniformia", Histeridae="Staphyliniformia",
    Leiodidae="Staphyliniformia",
    Elateridae="Elateriformia", Lampyridae="Elateriformia", Cantharidae="Elateriformia",
    Buprestidae="Elateriformia", Eucnemidae="Elateriformia", Drilidae="Elateriformia",
    Rhagophthalmidae="Elateriformia", Lycidae="Elateriformia",
    Byrrhidae="Elateriformia", Elmidae="Elateriformia",
    Scirtidae="Scirtoidea", Dascillidae="Scirtoidea",
    Corydalidae="Megaloptera", Sialidae="Megaloptera",
    Chrysopidae="Neuroptera", Hemerobiidae="Neuroptera", Myrmeleontidae="Neuroptera",
    Osmylidae="Neuroptera", Sisyridae="Neuroptera",
    Raphidiidae="Raphidioptera", Inocelliidae="Raphidioptera"
)

# Assign clades to all tips
all_tips <- tree$tip.label
tip_clades <- character(length(all_tips))
for (i in seq_along(all_tips)) {
    t <- all_tips[i]
    if (!is.na(clade_lookup[t])) {
        tip_clades[i] <- clade_lookup[t]
    } else {
        # Try family from tmap
        fam <- tmap$family[tmap$tip_label == t]
        if (length(fam) > 0 && fam[1] %in% names(family_to_clade)) {
            tip_clades[i] <- family_to_clade[fam[1]]
        } else {
            tip_clades[i] <- "unknown"
        }
    }
}
names(tip_clades) <- all_tips

cat("Clade assignments:\n")
print(table(tip_clades))

# Element -> position lookup
locus_element <- setNames(smap$stevens_element, smap$busco_id)
locus_start <- setNames(smap$tcas_start, smap$busco_id)
locus_end <- setNames(smap$tcas_end, smap$busco_id)

# Element sizes for genome-wide x-axis (using Tribolium chr sizes approximately)
element_order <- c("A","B","C","D","E","F","G","H","X")
# Approximate chromosome sizes in Mb from the data
element_sizes <- c(A=40, B=27, C=27, D=18, E=22, F=13, G=13, H=19, X=10)
element_offsets <- cumsum(c(0, element_sizes[-length(element_sizes)]))
names(element_offsets) <- element_order

# ========================================================================
# NODE 1: Polyphaga series backbone
# 4-taxon problem: Cucuj, Elat, Scarab, Staph (with Scirtoidea as outgroup)
# 3 possible unrooted quartets:
#   T1: (Cucuj,Elat) | (Scarab,Staph)  -- "Haplogastra"
#   T2: (Cucuj,Scarab) | (Elat,Staph)
#   T3: (Cucuj,Staph) | (Elat,Scarab)
# ========================================================================

cat("\n=== NODE 1: Series-level backbone ===\n")

# For each gene tree, pick 1 tip per series and test quartet topology
series_list <- c("Cucujiformia", "Elateriformia", "Scarabaeiformia", "Staphyliniformia")

tree_files <- list.files("/tmp/gene_trees", pattern="[.]treefile$", full.names=TRUE)

node1_results <- data.frame(locus=character(), element=character(),
                             genome_pos=numeric(), topology=character(),
                             stringsAsFactors=FALSE)

set.seed(42)

for (fi in seq_along(tree_files)) {
    f <- tree_files[fi]
    locus <- sub("[.]treefile$", "", basename(f))
    elem <- locus_element[locus]
    if (is.na(elem) || elem == "none") next

    gt <- tryCatch(read.tree(f), error=function(e) NULL)
    if (is.null(gt)) next

    # Get tips per series in this gene tree
    gt_clades <- tip_clades[gt$tip.label]
    series_tips <- list()
    for (s in series_list) {
        available <- gt$tip.label[gt_clades == s & !is.na(gt_clades)]
        if (length(available) == 0) { series_tips <- NULL; break }
        series_tips[[s]] <- available
    }
    if (is.null(series_tips)) next

    # Sample 3 tips per series for more robust quartet scoring
    n_reps <- 5
    topo_votes <- c(T1=0, T2=0, T3=0, ambig=0)

    for (rep in 1:n_reps) {
        picks <- sapply(series_tips, function(x) sample(x, 1))
        gt_pruned <- tryCatch(drop.tip(gt, setdiff(gt$tip.label, picks)), error=function(e) NULL)
        if (is.null(gt_pruned) || Ntip(gt_pruned) != 4) { topo_votes["ambig"] <- topo_votes["ambig"] + 1; next }

        # Determine quartet topology
        # The 4-tip unrooted tree has one internal edge separating 2 pairs
        # Find which pair is on each side of the internal edge
        if (length(gt_pruned$edge.length) < 4) { topo_votes["ambig"] <- topo_votes["ambig"] + 1; next }

        # Use RF distance to the 3 possible quartets
        t1 <- read.tree(text=paste0("((", picks["Cucujiformia"], ",", picks["Elateriformia"],
                                     "),(", picks["Scarabaeiformia"], ",", picks["Staphyliniformia"], "));"))
        t2 <- read.tree(text=paste0("((", picks["Cucujiformia"], ",", picks["Scarabaeiformia"],
                                     "),(", picks["Elateriformia"], ",", picks["Staphyliniformia"], "));"))
        t3 <- read.tree(text=paste0("((", picks["Cucujiformia"], ",", picks["Staphyliniformia"],
                                     "),(", picks["Elateriformia"], ",", picks["Scarabaeiformia"], "));"))

        rf1 <- RF.dist(gt_pruned, t1, normalize=TRUE)
        rf2 <- RF.dist(gt_pruned, t2, normalize=TRUE)
        rf3 <- RF.dist(gt_pruned, t3, normalize=TRUE)

        min_rf <- min(rf1, rf2, rf3)
        if (min_rf == rf1) topo_votes["T1"] <- topo_votes["T1"] + 1
        else if (min_rf == rf2) topo_votes["T2"] <- topo_votes["T2"] + 1
        else topo_votes["T3"] <- topo_votes["T3"] + 1
    }

    # Majority vote
    best <- names(which.max(topo_votes[1:3]))

    mid <- (locus_start[locus] + locus_end[locus]) / 2e6
    genome_x <- element_offsets[elem] + mid

    node1_results <- rbind(node1_results, data.frame(
        locus=locus, element=elem, genome_pos=genome_x,
        topology=best, stringsAsFactors=FALSE
    ))

    if (fi %% 200 == 0) cat("  Node1 processed", fi, "/", length(tree_files), "\n")
}

cat("Node 1 results:", nrow(node1_results), "loci\n")
cat("Topology counts:\n")
print(table(node1_results$topology))

# ========================================================================
# NODE 2: Elateriformia internal - Buprestoidea position
# Is Buprestidae sister to (Elateridae+Lampyridae+Cantharidae)?
# Or does Cantharidae break Elateroidea?
# 3-taxon rooted problem: Bupr, Elat sensu stricto, Cantharidae
# with outgroup = any Cucujiformia
#   T1: (Bupr, (Elat, Canth))  -- Buprestoidea sister to Elateroidea
#   T2: (Canth, (Bupr, Elat))  -- Cantharidae sister, breaks Elateroidea
#   T3: (Elat, (Bupr, Canth))  -- Elateridae sister
# ========================================================================

cat("\n=== NODE 2: Buprestoidea position ===\n")

# Families for the test
bupr_fams <- c("Buprestidae")
elat_fams <- c("Elateridae")
canth_fams <- c("Cantharidae", "Lycidae")  # soft-bodied Elateroidea

# Get family for each tip
tip_family <- setNames(tmap$family, tmap$tip_label)

node2_results <- data.frame(locus=character(), element=character(),
                             genome_pos=numeric(), topology=character(),
                             stringsAsFactors=FALSE)

for (fi in seq_along(tree_files)) {
    f <- tree_files[fi]
    locus <- sub("[.]treefile$", "", basename(f))
    elem <- locus_element[locus]
    if (is.na(elem) || elem == "none") next

    gt <- tryCatch(read.tree(f), error=function(e) NULL)
    if (is.null(gt)) next

    gt_fams <- tip_family[gt$tip.label]

    bupr_tips <- gt$tip.label[!is.na(gt_fams) & gt_fams %in% bupr_fams]
    elat_tips <- gt$tip.label[!is.na(gt_fams) & gt_fams %in% elat_fams]
    canth_tips <- gt$tip.label[!is.na(gt_fams) & gt_fams %in% canth_fams]
    outg_tips <- gt$tip.label[!is.na(tip_clades[gt$tip.label]) & tip_clades[gt$tip.label] == "Cucujiformia"]

    if (length(bupr_tips) == 0 || length(elat_tips) == 0 ||
        length(canth_tips) == 0 || length(outg_tips) == 0) next

    n_reps <- 5
    topo_votes <- c(T1=0, T2=0, T3=0)

    for (rep in 1:n_reps) {
        picks <- c(B=sample(bupr_tips, 1), E=sample(elat_tips, 1),
                   C=sample(canth_tips, 1), O=sample(outg_tips, 1))
        gt_pruned <- tryCatch(drop.tip(gt, setdiff(gt$tip.label, picks)), error=function(e) NULL)
        if (is.null(gt_pruned) || Ntip(gt_pruned) != 4) next

        # 3 rooted topologies (outgroup = O)
        t1 <- read.tree(text=paste0("((", picks["E"], ",", picks["C"], "),", picks["B"], ",", picks["O"], ");"))
        t2 <- read.tree(text=paste0("((", picks["B"], ",", picks["E"], "),", picks["C"], ",", picks["O"], ");"))
        t3 <- read.tree(text=paste0("((", picks["B"], ",", picks["C"], "),", picks["E"], ",", picks["O"], ");"))

        rf1 <- RF.dist(gt_pruned, t1, normalize=TRUE)
        rf2 <- RF.dist(gt_pruned, t2, normalize=TRUE)
        rf3 <- RF.dist(gt_pruned, t3, normalize=TRUE)

        min_rf <- min(rf1, rf2, rf3)
        if (min_rf == rf1) topo_votes["T1"] <- topo_votes["T1"] + 1
        else if (min_rf == rf2) topo_votes["T2"] <- topo_votes["T2"] + 1
        else topo_votes["T3"] <- topo_votes["T3"] + 1
    }

    if (sum(topo_votes) == 0) next
    best <- names(which.max(topo_votes))

    mid <- (locus_start[locus] + locus_end[locus]) / 2e6
    genome_x <- element_offsets[elem] + mid

    node2_results <- rbind(node2_results, data.frame(
        locus=locus, element=elem, genome_pos=genome_x,
        topology=best, stringsAsFactors=FALSE
    ))

    if (fi %% 200 == 0) cat("  Node2 processed", fi, "/", length(tree_files), "\n")
}

cat("Node 2 results:", nrow(node2_results), "loci\n")
cat("Topology counts:\n")
print(table(node2_results$topology))

# ========================================================================
# PLOTTING
# ========================================================================

# Element boundary lines and labels
elem_mids <- element_offsets + element_sizes / 2
elem_breaks <- data.frame(x=cumsum(element_sizes[-length(element_sizes)]))

# ---- Node 1 plot ----
# Convert topology to a numeric for smoothing: compute running proportion
# Use sliding window approach

make_topo_smooth_data <- function(results, window_mb=15) {
    topos <- sort(unique(results$topology))
    results <- results[order(results$genome_pos), ]

    smooth_data <- data.frame()
    positions <- seq(min(results$genome_pos), max(results$genome_pos), by=1)

    for (pos in positions) {
        in_window <- results[abs(results$genome_pos - pos) <= window_mb/2, ]
        if (nrow(in_window) < 10) next
        for (topo in topos) {
            prop <- mean(in_window$topology == topo)
            smooth_data <- rbind(smooth_data, data.frame(pos=pos, topology=topo, proportion=prop))
        }
    }
    return(smooth_data)
}

cat("\nComputing smoothed topology proportions for Node 1...\n")
smooth1 <- make_topo_smooth_data(node1_results, window_mb=20)

topo1_labels <- c(
    T1="(Cucuj+Elat)|(Scarab+Staph)\n\"Haplogastra\"",
    T2="(Cucuj+Scarab)|(Elat+Staph)",
    T3="(Cucuj+Staph)|(Elat+Scarab)"
)
smooth1$topo_label <- topo1_labels[smooth1$topology]

p1 <- ggplot(smooth1, aes(x=pos, y=proportion, color=topo_label)) +
    geom_line(linewidth=1.2) +
    geom_vline(data=elem_breaks, aes(xintercept=x), linetype="dashed", alpha=0.3) +
    annotate("text", x=elem_mids, y=rep(1.02, length(elem_mids)),
             label=element_order, fontface="bold", size=4) +
    scale_color_manual(values=c("#E41A1C", "#377EB8", "#4DAF4A")) +
    scale_y_continuous(limits=c(0, 1.05), breaks=seq(0, 1, 0.25)) +
    labs(x="Genome position (Mb, concatenated Stevens elements)",
         y="Proportion of gene trees",
         title="Node 1: Polyphaga series backbone topology across the genome",
         subtitle="Sliding window (20 Mb) | Which pairs of infraorders are sister?",
         color="Quartet topology") +
    theme_minimal(base_size=12) +
    theme(legend.position="bottom",
          legend.text=element_text(size=9),
          panel.grid.minor=element_blank())

ggsave("/tmp/node1_topology_along_genome.pdf", p1, width=14, height=6)
cat("Saved: /tmp/node1_topology_along_genome.pdf\n")

# ---- Node 2 plot ----
cat("Computing smoothed topology proportions for Node 2...\n")
smooth2 <- make_topo_smooth_data(node2_results, window_mb=20)

topo2_labels <- c(
    T1="(Elat+Canth),Bupr\nBuprestoidea sister",
    T2="(Bupr+Elat),Canth\nCantharidae sister",
    T3="(Bupr+Canth),Elat\nElateridae sister"
)
smooth2$topo_label <- topo2_labels[smooth2$topology]

p2 <- ggplot(smooth2, aes(x=pos, y=proportion, color=topo_label)) +
    geom_line(linewidth=1.2) +
    geom_vline(data=elem_breaks, aes(xintercept=x), linetype="dashed", alpha=0.3) +
    annotate("text", x=elem_mids, y=rep(1.02, length(elem_mids)),
             label=element_order, fontface="bold", size=4) +
    scale_color_manual(values=c("#E41A1C", "#377EB8", "#4DAF4A")) +
    scale_y_continuous(limits=c(0, 1.05), breaks=seq(0, 1, 0.25)) +
    labs(x="Genome position (Mb, concatenated Stevens elements)",
         y="Proportion of gene trees",
         title="Node 2: Buprestoidea position within Elateriformia across the genome",
         subtitle="Sliding window (20 Mb) | Rooted quartet with Cucujiformia outgroup",
         color="Topology") +
    theme_minimal(base_size=12) +
    theme(legend.position="bottom",
          legend.text=element_text(size=9),
          panel.grid.minor=element_blank())

ggsave("/tmp/node2_topology_along_genome.pdf", p2, width=14, height=6)
cat("Saved: /tmp/node2_topology_along_genome.pdf\n")

# Summary stats
cat("\n=== SUMMARY ===\n")
cat("\nNode 1 (Series backbone) genome-wide proportions:\n")
print(round(prop.table(table(node1_results$topology)), 3))
cat("\nNode 2 (Buprestoidea position) genome-wide proportions:\n")
print(round(prop.table(table(node2_results$topology)), 3))

# Per-element breakdown
cat("\nNode 1 by element:\n")
for (e in element_order) {
    sub <- node1_results[node1_results$element == e, ]
    if (nrow(sub) < 5) next
    props <- round(prop.table(table(sub$topology)), 3)
    cat(sprintf("  %s (n=%3d): T1=%.3f T2=%.3f T3=%.3f\n",
        e, nrow(sub),
        ifelse("T1" %in% names(props), props["T1"], 0),
        ifelse("T2" %in% names(props), props["T2"], 0),
        ifelse("T3" %in% names(props), props["T3"], 0)))
}

cat("\nNode 2 by element:\n")
for (e in element_order) {
    sub <- node2_results[node2_results$element == e, ]
    if (nrow(sub) < 5) next
    props <- round(prop.table(table(sub$topology)), 3)
    cat(sprintf("  %s (n=%3d): T1=%.3f T2=%.3f T3=%.3f\n",
        e, nrow(sub),
        ifelse("T1" %in% names(props), props["T1"], 0),
        ifelse("T2" %in% names(props), props["T2"], 0),
        ifelse("T3" %in% names(props), props["T3"], 0)))
}

# Save raw data
write.csv(node1_results, "/tmp/node1_quartet_results.csv", row.names=FALSE)
write.csv(node2_results, "/tmp/node2_quartet_results.csv", row.names=FALSE)
