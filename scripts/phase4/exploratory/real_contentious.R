library(ape)
library(phangorn)

tree <- read.tree("/tmp/wastral_species_tree_rooted.nwk")
tmap <- read.csv("data/genomes/tree_tip_mapping.csv", stringsAsFactors=FALSE)
smap <- read.delim("/tmp/busco_tribolium_stevens_map.tsv", stringsAsFactors=FALSE)

tip_family <- setNames(tmap$family, tmap$tip_label)

tree_files <- list.files("/tmp/gene_trees", pattern="[.]treefile$", full.names=TRUE)
locus_element <- setNames(smap$stevens_element, smap$busco_id)
locus_start <- setNames(smap$tcas_start, smap$busco_id)
locus_end <- setNames(smap$tcas_end, smap$busco_id)

element_order <- c("A","B","C","D","E","F","G","H","X")
element_sizes <- c(A=40, B=27, C=27, D=18, E=22, F=13, G=13, H=19, X=10)
element_offsets <- cumsum(c(0, element_sizes[-length(element_sizes)]))
names(element_offsets) <- element_order

# ========================================================================
# CONTENTIOUS NODE 3: Lampyridae/Elateridae boundary
# Are fireflies (Lampyridae) nested WITHIN click beetles (Elateridae)?
# Or are they sister groups?
# This is one of the hottest debates in beetle systematics.
# Quartet: Lampyridae, Elateridae s.s. (Agriotes/Melanotus clade),
#          Cantharidae, outgroup=Buprestidae
# T1: (Lamp+Elat) | Canth  -- Lampyridae sister to Elateridae (traditional)
# T2: (Lamp+Canth) | Elat  -- Lampyridae sister to Cantharidae
# T3: (Elat+Canth) | Lamp  -- Lampyridae separate
# ========================================================================

cat("=== NODE 3: Lampyridae-Elateridae relationship ===\n")

# Define groups more carefully
# Elateridae s.s.: Agriotes, Melanotus, Dalopius, Ampedus
# Lampyridae: Photinus, Lampyris, Luciola, Aquatica, Abscondita, Pyrocoelia
# Cantharidae: Cantharis, Rhagonycha, Podabrus, Malthodes
# Outgroup: Buprestidae (Agrilus, Sambus)

elat_genera <- c("Agriotes", "Melanotus", "Dalopius", "Ampedus", "Hemicrepidius",
                  "Denticollis", "Actenicerus", "Aplotarsus", "Ctenicera", "Limonius")
lamp_genera <- c("Photinus", "Lampyris", "Luciola", "Aquatica", "Abscondita",
                  "Pyrocoelia", "Lamprigera", "Vesta", "Rhagophthalmus", "Sinopyrophorus")
canth_genera <- c("Cantharis", "Rhagonycha", "Podabrus", "Malthodes", "Malthinus",
                   "Ichthyurus", "Crudosilis", "Lycocerus")
bupr_genera <- c("Agrilus", "Sambus")

get_genus <- function(tip) sub("_.*", "", tip)

node3_results <- data.frame(locus=character(), element=character(),
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

    genera <- get_genus(gt$tip.label)
    elat_tips <- gt$tip.label[genera %in% elat_genera]
    lamp_tips <- gt$tip.label[genera %in% lamp_genera]
    canth_tips <- gt$tip.label[genera %in% canth_genera]
    bupr_tips <- gt$tip.label[genera %in% bupr_genera]

    if (length(elat_tips) == 0 || length(lamp_tips) == 0 ||
        length(canth_tips) == 0 || length(bupr_tips) == 0) next

    n_reps <- 5
    topo_votes <- c(T1=0, T2=0, T3=0)

    for (rep in 1:n_reps) {
        picks <- c(E=sample(elat_tips, 1), L=sample(lamp_tips, 1),
                   C=sample(canth_tips, 1), O=sample(bupr_tips, 1))
        gt_p <- tryCatch(drop.tip(gt, setdiff(gt$tip.label, picks)), error=function(e) NULL)
        if (is.null(gt_p) || Ntip(gt_p) != 4) next

        # Rooted by Buprestidae
        t1 <- read.tree(text=paste0("((", picks["L"], ",", picks["E"], "),", picks["C"], ",", picks["O"], ");"))
        t2 <- read.tree(text=paste0("((", picks["L"], ",", picks["C"], "),", picks["E"], ",", picks["O"], ");"))
        t3 <- read.tree(text=paste0("((", picks["E"], ",", picks["C"], "),", picks["L"], ",", picks["O"], ");"))

        rf1 <- RF.dist(gt_p, t1, normalize=TRUE)
        rf2 <- RF.dist(gt_p, t2, normalize=TRUE)
        rf3 <- RF.dist(gt_p, t3, normalize=TRUE)

        min_rf <- min(rf1, rf2, rf3)
        if (min_rf == rf1) topo_votes["T1"] <- topo_votes["T1"] + 1
        else if (min_rf == rf2) topo_votes["T2"] <- topo_votes["T2"] + 1
        else topo_votes["T3"] <- topo_votes["T3"] + 1
    }

    if (sum(topo_votes) == 0) next
    best <- names(which.max(topo_votes))
    mid <- (locus_start[locus] + locus_end[locus]) / 2e6
    genome_x <- element_offsets[elem] + mid

    node3_results <- rbind(node3_results, data.frame(
        locus=locus, element=elem, genome_pos=genome_x,
        topology=best, stringsAsFactors=FALSE
    ))
}

cat("Node 3 results:", nrow(node3_results), "loci\n")
cat("Topology counts:\n")
print(table(node3_results$topology))
cat("Proportions:\n")
print(round(prop.table(table(node3_results$topology)), 3))

# ========================================================================
# CONTENTIOUS NODE 4: Staphylinidae + Silphidae
# Are Silphidae nested within Staphylinidae? Recent genomic work says yes.
# Quartet: Staphylininae (Philonthus, Ocypus), Silphidae (Nicrophorus, Thanatophilus),
#          Tachyporinae (Tachyporus, Lordithon), outgroup=Scarabaeidae
# T1: (Staph+Silph) | Tach  -- Silphidae within Staphylinidae
# T2: (Staph+Tach) | Silph  -- Silphidae sister to Staphylinidae
# T3: (Silph+Tach) | Staph  -- Staphylininae separate
# ========================================================================

cat("\n=== NODE 4: Silphidae position (within or sister to Staphylinidae?) ===\n")

staph_genera <- c("Philonthus", "Staphylinus", "Ocypus", "Platydracus",
                   "Ontholestes", "Quedius", "Othius", "Xantholinus")
silph_genera <- c("Nicrophorus", "Thanatophilus", "Phosphuga")
tachy_genera <- c("Tachyporus", "Tachinus", "Lordithon")
scarab_outg <- c("Onthophagus", "Catharsius", "Canthon", "Phanaeus")

node4_results <- data.frame(locus=character(), element=character(),
                             genome_pos=numeric(), topology=character(),
                             stringsAsFactors=FALSE)

for (fi in seq_along(tree_files)) {
    f <- tree_files[fi]
    locus <- sub("[.]treefile$", "", basename(f))
    elem <- locus_element[locus]
    if (is.na(elem) || elem == "none") next

    gt <- tryCatch(read.tree(f), error=function(e) NULL)
    if (is.null(gt)) next

    genera <- get_genus(gt$tip.label)
    staph_tips <- gt$tip.label[genera %in% staph_genera]
    silph_tips <- gt$tip.label[genera %in% silph_genera]
    tachy_tips <- gt$tip.label[genera %in% tachy_genera]
    outg_tips <- gt$tip.label[genera %in% scarab_outg]

    if (length(staph_tips) == 0 || length(silph_tips) == 0 ||
        length(tachy_tips) == 0 || length(outg_tips) == 0) next

    n_reps <- 5
    topo_votes <- c(T1=0, T2=0, T3=0)

    for (rep in 1:n_reps) {
        picks <- c(S=sample(staph_tips, 1), Si=sample(silph_tips, 1),
                   T=sample(tachy_tips, 1), O=sample(outg_tips, 1))
        gt_p <- tryCatch(drop.tip(gt, setdiff(gt$tip.label, picks)), error=function(e) NULL)
        if (is.null(gt_p) || Ntip(gt_p) != 4) next

        t1 <- read.tree(text=paste0("((", picks["S"], ",", picks["Si"], "),", picks["T"], ",", picks["O"], ");"))
        t2 <- read.tree(text=paste0("((", picks["S"], ",", picks["T"], "),", picks["Si"], ",", picks["O"], ");"))
        t3 <- read.tree(text=paste0("((", picks["Si"], ",", picks["T"], "),", picks["S"], ",", picks["O"], ");"))

        rf1 <- RF.dist(gt_p, t1, normalize=TRUE)
        rf2 <- RF.dist(gt_p, t2, normalize=TRUE)
        rf3 <- RF.dist(gt_p, t3, normalize=TRUE)

        min_rf <- min(rf1, rf2, rf3)
        if (min_rf == rf1) topo_votes["T1"] <- topo_votes["T1"] + 1
        else if (min_rf == rf2) topo_votes["T2"] <- topo_votes["T2"] + 1
        else topo_votes["T3"] <- topo_votes["T3"] + 1
    }

    if (sum(topo_votes) == 0) next
    best <- names(which.max(topo_votes))
    mid <- (locus_start[locus] + locus_end[locus]) / 2e6
    genome_x <- element_offsets[elem] + mid

    node4_results <- rbind(node4_results, data.frame(
        locus=locus, element=elem, genome_pos=genome_x,
        topology=best, stringsAsFactors=FALSE
    ))
}

cat("Node 4 results:", nrow(node4_results), "loci\n")
cat("Topology counts:\n")
print(table(node4_results$topology))
cat("Proportions:\n")
print(round(prop.table(table(node4_results$topology)), 3))

# ========================================================================
# CONTENTIOUS NODE 5: Scarabaeidae paraphyly
# Lucanidae (stag beetles) position relative to Scarabaeidae subfamilies
# Are Lucanidae sister to Scarabaeidae, or nested within?
# Quartet: Scarabaeinae (dung beetles), Dynastinae (rhinoceros beetles),
#          Lucanidae, outgroup = Geotrupidae
# T1: (Scarab+Dyn) | Luc  -- Scarabaeidae monophyletic, Lucanidae sister
# T2: (Scarab+Luc) | Dyn  -- Lucanidae within Scarabaeidae
# T3: (Dyn+Luc) | Scarab  -- Lucanidae within Scarabaeidae (other way)
# ========================================================================

cat("\n=== NODE 5: Lucanidae position relative to Scarabaeidae ===\n")

scarab_genera2 <- c("Onthophagus", "Catharsius", "Canthon", "Phanaeus",
                     "Digitonthophagus", "Sisyphus", "Aphodius", "Melinopterus", "Aegialia")
dyn_genera <- c("Dynastes", "Oryctes", "Trypoxylus", "Marronus")
luc_genera <- c("Lucanus", "Dorcus", "Serrognathus", "Prosopocoilus", "Odontolabis")
geotrup_genera <- c("Geotrupes", "Lethrus")

node5_results <- data.frame(locus=character(), element=character(),
                             genome_pos=numeric(), topology=character(),
                             stringsAsFactors=FALSE)

for (fi in seq_along(tree_files)) {
    f <- tree_files[fi]
    locus <- sub("[.]treefile$", "", basename(f))
    elem <- locus_element[locus]
    if (is.na(elem) || elem == "none") next

    gt <- tryCatch(read.tree(f), error=function(e) NULL)
    if (is.null(gt)) next

    genera <- get_genus(gt$tip.label)
    scarab_tips2 <- gt$tip.label[genera %in% scarab_genera2]
    dyn_tips <- gt$tip.label[genera %in% dyn_genera]
    luc_tips <- gt$tip.label[genera %in% luc_genera]
    geotrup_tips <- gt$tip.label[genera %in% geotrup_genera]

    if (length(scarab_tips2) == 0 || length(dyn_tips) == 0 ||
        length(luc_tips) == 0 || length(geotrup_tips) == 0) next

    n_reps <- 5
    topo_votes <- c(T1=0, T2=0, T3=0)

    for (rep in 1:n_reps) {
        picks <- c(Sc=sample(scarab_tips2, 1), Dy=sample(dyn_tips, 1),
                   Lu=sample(luc_tips, 1), O=sample(geotrup_tips, 1))
        gt_p <- tryCatch(drop.tip(gt, setdiff(gt$tip.label, picks)), error=function(e) NULL)
        if (is.null(gt_p) || Ntip(gt_p) != 4) next

        t1 <- read.tree(text=paste0("((", picks["Sc"], ",", picks["Dy"], "),", picks["Lu"], ",", picks["O"], ");"))
        t2 <- read.tree(text=paste0("((", picks["Sc"], ",", picks["Lu"], "),", picks["Dy"], ",", picks["O"], ");"))
        t3 <- read.tree(text=paste0("((", picks["Dy"], ",", picks["Lu"], "),", picks["Sc"], ",", picks["O"], ");"))

        rf1 <- RF.dist(gt_p, t1, normalize=TRUE)
        rf2 <- RF.dist(gt_p, t2, normalize=TRUE)
        rf3 <- RF.dist(gt_p, t3, normalize=TRUE)

        min_rf <- min(rf1, rf2, rf3)
        if (min_rf == rf1) topo_votes["T1"] <- topo_votes["T1"] + 1
        else if (min_rf == rf2) topo_votes["T2"] <- topo_votes["T2"] + 1
        else topo_votes["T3"] <- topo_votes["T3"] + 1
    }

    if (sum(topo_votes) == 0) next
    best <- names(which.max(topo_votes))
    mid <- (locus_start[locus] + locus_end[locus]) / 2e6
    genome_x <- element_offsets[elem] + mid

    node5_results <- rbind(node5_results, data.frame(
        locus=locus, element=elem, genome_pos=genome_x,
        topology=best, stringsAsFactors=FALSE
    ))
}

cat("Node 5 results:", nrow(node5_results), "loci\n")
cat("Topology counts:\n")
print(table(node5_results$topology))
cat("Proportions:\n")
print(round(prop.table(table(node5_results$topology)), 3))

# Per-element for all nodes
cat("\n\n=== PER-ELEMENT SUMMARIES ===\n")
for (node_name in c("Node3_Lamp_Elat", "Node4_Silph_Staph", "Node5_Luc_Scarab")) {
    res <- switch(node_name,
        Node3_Lamp_Elat = node3_results,
        Node4_Silph_Staph = node4_results,
        Node5_Luc_Scarab = node5_results
    )
    cat(sprintf("\n%s by element:\n", node_name))
    for (e in element_order) {
        sub <- res[res$element == e, ]
        if (nrow(sub) < 5) next
        props <- round(prop.table(table(sub$topology)), 3)
        cat(sprintf("  %s (n=%3d): T1=%.3f T2=%.3f T3=%.3f\n",
            e, nrow(sub),
            ifelse("T1" %in% names(props), props["T1"], 0),
            ifelse("T2" %in% names(props), props["T2"], 0),
            ifelse("T3" %in% names(props), props["T3"], 0)))
    }
}

write.csv(node3_results, "/tmp/node3_quartet_results.csv", row.names=FALSE)
write.csv(node4_results, "/tmp/node4_quartet_results.csv", row.names=FALSE)
write.csv(node5_results, "/tmp/node5_quartet_results.csv", row.names=FALSE)
