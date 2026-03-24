#!/usr/bin/env Rscript
#===============================================================================
# Integrate 39 recovery genomes into SCARAB pipeline
#===============================================================================
# This script:
#   1. Reads the existing seqfile and guide tree (439 taxa)
#   2. Adds 39 recovery genomes to the seqfile
#   3. Grafts recovery taxa onto the guide tree using taxonomic placement
#   4. Outputs updated seqfile (478 taxa) and guide tree
#
# Run on Grace login node after download_recovery_genomes.sh completes.
# Requires: ape
#
# Usage: Rscript integrate_recovery_genomes.R [--scratch /path/to/scratch]
#===============================================================================

library(ape)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
scratch_idx <- which(args == "--scratch")
if (length(scratch_idx) > 0 && scratch_idx < length(args)) {
  SCRATCH <- args[scratch_idx + 1]
} else {
  SCRATCH <- Sys.getenv("SCRATCH", unset = "/scratch/user/blackmon")
}

SCARAB     <- file.path(SCRATCH, "scarab")
GENOME_DIR <- file.path(SCARAB, "genomes")
SEQFILE    <- file.path(SCARAB, "cactus_seqfile.txt")
TREE_FILE  <- file.path(SCARAB, "nuclear_markers", "nuclear_guide_tree_439_rooted.nwk")
CATALOG    <- file.path(SCARAB, "genome_catalog.csv")  # copy on Grace

# Recovery genome metadata (species, accession, family, contig_N50)
# Hardcoded to avoid dependency on local catalog copy
recovery <- data.frame(
  species = c(
    "Abscondita cerata", "Agriotes pubescens", "Araecerus fasciculatus",
    "Asbolus verrucosus", "Astagobius angustatus", "Batocera rufomaculata",
    "Calosoma relictum", "Carabus depressus", "Cosmopolites sordidus",
    "Cynegetis impunctata", "Dermolepida albohirtum", "Diaprepes abbreviatus",
    "Epicauta chinensis", "Exocentrus adspersus",
    "Henosepilachna vigintioctopunctata", "Kuschelorhynchus macadamiae",
    "Lamprigera yunnana", "Lampyris noctiluca", "Lethrus scoparius",
    "Lycocerus yunnanus", "Meloe dianella", "Micraspis discolor",
    "Molorchus minor", "Mylabris phalerata", "Nebria ingens riversi",
    "Neoclytus acuminatus acuminatus", "Novius pumilus",
    "Platerodrilus igneus", "Rhagophthalmus giganteus",
    "Rhamnusium bicolor", "Rosalia funebris", "Sinelater perroti",
    "Sinopyrophorus schimmeli", "Sternochetus mangiferae",
    "Troglocharinus ferreri", "Trypodendron lineatum",
    "Venustoraphidia nigricollis", "Vesta saturnalis",
    "Zygogramma bicolorata"
  ),
  accession = c(
    "GCA_030710515.1", "GCA_044115395.2", "GCA_050578095.1",
    "GCA_047676225.1", "GCA_965278915.1", "GCA_050941775.1",
    "GCA_055275695.1", "GCA_048127345.1", "GCA_031761425.1",
    "GCA_030704885.1", "GCA_031893035.2", "GCA_034092305.1",
    "GCA_021725515.1", "GCA_029955175.1",
    "GCA_030704895.1", "GCA_030620095.1",
    "GCA_013368075.1", "GCA_050947525.1", "GCA_052696345.1",
    "GCA_036346125.1", "GCA_028455855.1", "GCA_030674115.1",
    "GCA_029963825.1", "GCA_020740385.1", "GCA_018344505.1",
    "GCA_047371185.1", "GCA_020654155.1",
    "GCA_036346225.1", "GCA_036326145.1",
    "GCA_029963845.1", "GCA_037954035.1", "GCA_036346155.1",
    "GCA_036325965.1", "GCA_051294475.1",
    "GCA_982185335.1", "GCA_055532135.1",
    "GCA_034508555.1", "GCA_036346205.1",
    "GCA_032362365.1"
  ),
  family = c(
    "Lampyridae", "Elateridae", "Anthribidae",
    "Tenebrionidae", "Leiodidae", "Cerambycidae",
    "Carabidae", "Carabidae", "Curculionidae",
    "Coccinellidae", "Scarabaeidae", "Curculionidae",
    "Meloidae", "Cerambycidae",
    "Coccinellidae", "Curculionidae",
    "Lampyridae", "Lampyridae", "Geotrupidae",
    "Cantharidae", "Meloidae", "Coccinellidae",
    "Cerambycidae", "Meloidae", "Carabidae",
    "Cerambycidae", "Coccinellidae",
    "Lycidae", "Rhagophthalmidae",
    "Cerambycidae", "Cerambycidae", "Elateridae",
    "Elateridae", "Curculionidae",
    "Leiodidae", "Curculionidae",
    "Raphidiidae", "Lampyridae",
    "Chrysomelidae"
  ),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# Step 1: Find downloaded genome files and update seqfile
# ---------------------------------------------------------------------------
cat("Step 1: Updating seqfile with recovery genomes\n")

# Read existing seqfile
seqfile_lines <- readLines(SEQFILE)
cat("  Existing seqfile:", length(seqfile_lines), "lines\n")

# The first line is the Newick tree; remaining lines are name\tpath
tree_line <- seqfile_lines[1]
genome_lines <- seqfile_lines[-1]

new_lines <- character(0)
found <- 0
missing <- character(0)

for (i in seq_len(nrow(recovery))) {
  sp  <- recovery$species[i]
  acc <- recovery$accession[i]
  tip <- gsub(" ", "_", sp)

  # Find the genome file
  pattern <- paste0(acc, ".*_genomic.fna.gz")
  hits <- list.files(GENOME_DIR, pattern = pattern, full.names = TRUE)

  if (length(hits) > 0) {
    new_lines <- c(new_lines, paste0(tip, "\t", hits[1]))
    found <- found + 1
  } else {
    missing <- c(missing, paste(sp, acc))
    cat("  WARNING: genome not found for", sp, "(", acc, ")\n")
  }
}

cat("  Found:", found, "/ 39 recovery genomes\n")
if (length(missing) > 0) {
  cat("  Missing:", length(missing), "genomes:\n")
  for (m in missing) cat("    ", m, "\n")
}

# ---------------------------------------------------------------------------
# Step 2: Graft recovery taxa onto guide tree
# ---------------------------------------------------------------------------
cat("\nStep 2: Grafting recovery taxa onto guide tree\n")

tree <- read.tree(TREE_FILE)
cat("  Original tree:", Ntip(tree), "tips\n")

# Strategy: for each recovery species, find the closest congeneric or
# confamilial taxon already in the tree, and graft as sister with a
# short branch length (median branch length of the tree).
median_bl <- median(tree$edge.length, na.rm = TRUE)

for (i in seq_len(nrow(recovery))) {
  sp  <- recovery$species[i]
  fam <- recovery$family[i]
  tip <- gsub(" ", "_", sp)

  # Skip if already in tree
  if (tip %in% tree$tip.label) {
    cat("  ", tip, "already in tree, skipping\n")
    next
  }

  # Try congeneric first
  genus <- strsplit(sp, " ")[[1]][1]
  congenerics <- grep(paste0("^", genus, "_"), tree$tip.label, value = TRUE)

  if (length(congenerics) > 0) {
    # Graft as sister to first congeneric
    sister <- congenerics[1]
    cat("  Grafting", tip, "as sister to", sister, "(congeneric)\n")
  } else {
    # Find any confamilial taxon -- need the existing 439 catalog
    # Use the genome_lines from seqfile to get existing species names
    existing_tips <- sapply(strsplit(genome_lines, "\t"), `[`, 1)

    # Match family: check all existing tips against recovery family
    # We'll use a simple heuristic -- for well-known beetle families,
    # find a known representative genus
    family_reps <- list(
      Lampyridae    = "Photinus|Lampyris|Pyrocoelia|Aquatica|Luciola",
      Elateridae    = "Agriotes|Melanotus|Limonius|Elater",
      Anthribidae   = "Anthribus|Euparius",
      Tenebrionidae = "Tribolium|Tenebrio|Zophobas|Asbolus",
      Leiodidae     = "Catops|Leiodes|Choleva",
      Cerambycidae  = "Anoplophora|Monochamus|Batocera|Rosalia",
      Carabidae     = "Carabus|Calosoma|Nebria|Pterostichus|Bembidion",
      Curculionidae = "Sitophilus|Dendroctonus|Hypothenemus|Ips",
      Coccinellidae = "Harmonia|Coccinella|Hippodamia|Adalia",
      Scarabaeidae  = "Onthophagus|Copris|Oryctes|Dynastes",
      Meloidae      = "Epicauta|Lytta|Meloe",
      Geotrupidae   = "Geotrupes|Lethrus|Nicrophorus",
      Cantharidae   = "Chauliognathus|Rhagonycha|Lycocerus",
      Chrysomelidae = "Leptinotarsa|Chrysomela|Diabrotica|Callosobruchus",
      Lycidae       = "Plateros|Calopteron",
      Rhagophthalmidae = "Rhagophthalmus",
      Raphidiidae   = "Raphidia|Venustoraphidia"
    )

    sister <- NULL
    if (fam %in% names(family_reps)) {
      pattern <- family_reps[[fam]]
      matches <- grep(pattern, tree$tip.label, value = TRUE)
      if (length(matches) > 0) {
        sister <- matches[1]
      }
    }

    if (is.null(sister)) {
      # Last resort: just find any existing tip with same family
      # This requires the catalog -- if not available, pick a random tip
      # from the same suborder
      cat("  WARNING: no confamilial match for", tip, "(", fam, "),",
          "grafting to a random Polyphaga tip\n")
      # Pick any Curculionidae as a safe Polyphaga representative
      poly_match <- grep("Sitophilus|Tribolium|Harmonia", tree$tip.label,
                         value = TRUE)
      sister <- if (length(poly_match) > 0) poly_match[1] else tree$tip.label[1]
    } else {
      cat("  Grafting", tip, "as sister to", sister, "(confamilial)\n")
    }
  }

  # Perform the grafting
  # Add new tip as sister to 'sister' with branch length = median_bl
  sister_idx <- which(tree$tip.label == sister)
  if (length(sister_idx) == 0) {
    cat("  ERROR: sister tip", sister, "not found in tree. Skipping", tip, "\n")
    next
  }

  # Use bind.tip from ape
  # Position: at the midpoint of the sister's terminal branch
  sister_edge_idx <- which(tree$edge[, 2] == sister_idx)
  sister_bl <- tree$edge.length[sister_edge_idx]
  where <- sister_idx
  position <- sister_bl / 2

  tree <- bind.tip(tree, tip,
                   where = where,
                   position = position,
                   edge.length = position)
}

cat("  Updated tree:", Ntip(tree), "tips\n")

# ---------------------------------------------------------------------------
# Step 3: Write outputs
# ---------------------------------------------------------------------------
cat("\nStep 3: Writing outputs\n")

# Write updated tree
out_tree <- file.path(SCARAB, "nuclear_markers",
                      "nuclear_guide_tree_478_rooted.nwk")
write.tree(tree, out_tree)
cat("  Tree:", out_tree, "\n")

# Write updated seqfile with new tree line
all_genome_lines <- c(genome_lines, new_lines)
new_tree_string <- write.tree(tree)
out_seqfile <- file.path(SCARAB, "cactus_seqfile_478.txt")
writeLines(c(new_tree_string, all_genome_lines), out_seqfile)
cat("  Seqfile:", out_seqfile, "(", length(all_genome_lines), "genomes )\n")

# Write a manifest of what was added
manifest <- file.path(SCARAB, "recovery_manifest.txt")
writeLines(c(
  paste("# Recovery genome integration:", Sys.time()),
  paste("# Original taxa:", length(genome_lines)),
  paste("# Recovery taxa found:", found),
  paste("# Recovery taxa missing:", length(missing)),
  paste("# Updated tree tips:", Ntip(tree)),
  "",
  "# Added genomes:",
  new_lines,
  "",
  if (length(missing) > 0) c("# Missing genomes:", missing) else "# No missing genomes"
), manifest)
cat("  Manifest:", manifest, "\n")

cat("\n========================================\n")
cat("DONE. Next steps:\n")
cat("  1. Review the 478-taxa tree for grafting sanity\n")
cat("  2. Run filter_genomes_for_alignment.R on cactus_seqfile_478.txt\n")
cat("  3. Run supplemental P3 BLAST for the recovery taxa\n")
cat("========================================\n")
