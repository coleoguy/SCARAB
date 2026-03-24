# ============================================================================
# calibrate_tree.R
# Assign approximate divergence-time branch lengths to the SCARAB constraint tree
# using McKenna et al. (2019) and other calibrated beetle phylogeny estimates.
# ============================================================================

library(ape)

## <<<STUDENT: Set to your SCARAB project root directory>>>
base_dir <- Sys.getenv("SCARAB_ROOT", unset = normalizePath(file.path(dirname(sys.frame(1)$ofile), "..", ".."), mustWork = FALSE))

tree <- read.tree(file.path(base_dir, "data/genomes/constraint_tree.nwk"))
tip_map <- read.csv(file.path(base_dir, "data/genomes/tree_tip_mapping.csv"),
                    stringsAsFactors = FALSE)

cat("Tree tips:", Ntip(tree), "\n")
cat("Internal nodes:", Nnode(tree), "\n")
cat("Tip mapping rows:", nrow(tip_map), "\n")

# Verify all tips are in mapping
missing <- setdiff(tree$tip.label, tip_map$tip_label)
cat("Tips missing from mapping:", length(missing), "\n")

# Build lookup: tip_label -> clade, family, role
tip_info <- tip_map[match(tree$tip.label, tip_map$tip_label), ]

# Helper: find MRCA of all tips belonging to a group
find_clade_mrca <- function(tree, tip_info, column, value) {
  tips <- tip_info$tip_label[tip_info[[column]] == value]
  tips <- tips[tips %in% tree$tip.label]
  if (length(tips) < 2) return(NULL)
  mrca_node <- getMRCA(tree, tips)
  return(mrca_node)
}

# -------------------------------------------------------------------
# Node age assignments (Ma from present)
# McKenna et al. (2019) Syst. Entomol. + Zhang et al. (2018) Curr. Biol.
# -------------------------------------------------------------------

node_ages <- rep(NA, Ntip(tree) + Nnode(tree))
node_ages[1:Ntip(tree)] <- 0  # tips at present

# Root: Coleoptera + Neuropterida split
root <- Ntip(tree) + 1
node_ages[root] <- 320

# Calibration points
clade_ages <- list(
  list(col = "clade", val = "Adephaga", age = 215),
  list(col = "clade", val = "Cucujiformia", age = 195),
  list(col = "clade", val = "Scarabaeiformia", age = 175),
  list(col = "clade", val = "Staphyliniformia", age = 185),
  list(col = "clade", val = "Elateriformia", age = 190),
  list(col = "role", val = "outgroup", age = 300),
  list(col = "family", val = "Carabidae", age = 160),
  list(col = "family", val = "Chrysomelidae", age = 100),
  list(col = "family", val = "Cerambycidae", age = 120),
  list(col = "family", val = "Curculionidae", age = 115),
  list(col = "family", val = "Coccinellidae", age = 80),
  list(col = "family", val = "Scarabaeidae", age = 120),
  list(col = "family", val = "Lucanidae", age = 90),
  list(col = "family", val = "Staphylinidae", age = 140),
  list(col = "family", val = "Tenebrionidae", age = 130),
  list(col = "family", val = "Cantharidae", age = 110),
  list(col = "family", val = "Elateridae", age = 130),
  list(col = "family", val = "Lampyridae", age = 100),
  list(col = "family", val = "Geotrupidae", age = 130),
  list(col = "family", val = "Silphidae", age = 120),
  list(col = "family", val = "Corydalidae", age = 180),
  list(col = "family", val = "Chrysopidae", age = 150)
)

assigned <- 0
for (ca in clade_ages) {
  mrca <- find_clade_mrca(tree, tip_info, ca$col, ca$val)
  if (!is.null(mrca)) {
    node_ages[mrca] <- ca$age
    assigned <- assigned + 1
  }
}
cat("Assigned calibration ages to", assigned, "nodes\n")

# Coleoptera crown
coleoptera_tips <- tip_info$tip_label[tip_info$role == "ingroup"]
coleoptera_mrca <- getMRCA(tree, coleoptera_tips)
if (!is.na(coleoptera_mrca)) {
  node_ages[coleoptera_mrca] <- 268
  cat("Coleoptera MRCA node:", coleoptera_mrca, "age: 268 Ma\n")
}

# -------------------------------------------------------------------
# Interpolate missing internal node ages
# -------------------------------------------------------------------

# Get parent of each node
parent_vec <- integer(Ntip(tree) + Nnode(tree))
for (i in seq_len(nrow(tree$edge))) {
  parent_vec[tree$edge[i, 2]] <- tree$edge[i, 1]
}

# Preorder traversal
visited <- logical(Ntip(tree) + Nnode(tree))
queue <- root
preorder <- integer(0)
while (length(queue) > 0) {
  current <- queue[1]
  queue <- queue[-1]
  if (visited[current]) next
  visited[current] <- TRUE
  preorder <- c(preorder, current)
  children <- tree$edge[tree$edge[, 1] == current, 2]
  queue <- c(children, queue)
}

# First pass: interpolate
for (node in preorder) {
  if (node <= Ntip(tree)) next
  if (!is.na(node_ages[node])) next

  parent_age <- node_ages[parent_vec[node]]
  if (is.na(parent_age)) parent_age <- 320

  children <- tree$edge[tree$edge[, 1] == node, 2]
  child_ages <- node_ages[children]
  child_ages <- child_ages[!is.na(child_ages)]
  max_child_age <- if (length(child_ages) > 0) max(child_ages) else 0

  node_ages[node] <- (parent_age + max_child_age) / 2
}

# Second pass: enforce monotonicity
for (node in preorder) {
  if (node == root) next
  parent <- parent_vec[node]
  if (!is.na(node_ages[parent]) && !is.na(node_ages[node])) {
    if (node_ages[node] >= node_ages[parent]) {
      node_ages[node] <- node_ages[parent] * 0.95
    }
  }
}

# -------------------------------------------------------------------
# Convert to branch lengths
# -------------------------------------------------------------------
new_edge_lengths <- numeric(nrow(tree$edge))
for (i in seq_len(nrow(tree$edge))) {
  parent <- tree$edge[i, 1]
  child <- tree$edge[i, 2]
  bl <- node_ages[parent] - node_ages[child]
  new_edge_lengths[i] <- max(bl, 0.1)
}
tree$edge.length <- new_edge_lengths

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
cat("\n=== Calibrated Tree Summary ===\n")
cat("Tips:", Ntip(tree), "\n")
cat("Internal nodes:", Nnode(tree), "\n")
cat("Branch length range:", round(min(tree$edge.length), 2), "-",
    round(max(tree$edge.length), 2), "Ma\n")
cat("Mean branch length:", round(mean(tree$edge.length), 2), "Ma\n")
cat("Median branch length:", round(median(tree$edge.length), 2), "Ma\n")
cat("Root age:", round(node_ages[root], 2), "Ma\n")

depths <- node.depth.edgelength(tree)
cat("Max root-to-tip:", round(max(depths), 2), "Ma\n")

# Spot checks
for (sp in c("Tribolium_castaneum", "Dendroctonus_ponderosae", "Chrysopa_pallens")) {
  idx <- which(tree$tip.label == sp)
  if (length(idx) > 0) cat("  ", sp, ":", round(depths[idx], 1), "Ma from root\n")
}

# Write output
out_path <- file.path(base_dir, "data/genomes/constraint_tree_calibrated.nwk")
write.tree(tree, file = out_path)
cat("\nCalibrated tree written to:", out_path, "\n")

# Verify
test <- read.tree(out_path)
cat("Verification:", Ntip(test), "tips,", Nnode(test), "nodes\n")
cat("Branch lengths:", round(min(test$edge.length), 2), "-", round(max(test$edge.length), 2), "\n")
