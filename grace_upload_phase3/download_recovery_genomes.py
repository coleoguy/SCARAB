#!/usr/bin/env python3
"""
Download 39 SCARAB recovery genomes from NCBI FTP.
No datasets CLI required — constructs URLs directly from accession numbers.

Robust behavior:
  - Skips genomes already downloaded (checks file size > 1 MB)
  - Logs failures without dying
  - Resumes partial downloads via wget -c
  - Prints a summary at the end

Usage (Grace login node):
  python3 download_recovery_genomes.py \
      --outdir  $SCRATCH/scarab/genomes \
      --log     $SCRATCH/scarab/download_recovery.log

The genome files are written as {ACCESSION}_*_genomic.fna.gz in --outdir,
matching the naming convention expected by integrate_recovery_genomes.R and
P3_blast_recovery_taxa.slurm.
"""

import os
import sys
import argparse
import urllib.request
import urllib.error
import html.parser
import subprocess
import time

# ---------------------------------------------------------------------------
# Recovery genome manifest (accession -> tip label)
# ---------------------------------------------------------------------------
RECOVERY = {
    "GCA_030710515.1": "Abscondita_cerata",
    "GCA_044115395.2": "Agriotes_pubescens",
    "GCA_050578095.1": "Araecerus_fasciculatus",
    "GCA_047676225.1": "Asbolus_verrucosus",
    "GCA_965278915.1": "Astagobius_angustatus",
    "GCA_050941775.1": "Batocera_rufomaculata",
    "GCA_055275695.1": "Calosoma_relictum",
    "GCA_048127345.1": "Carabus_depressus",
    "GCA_031761425.1": "Cosmopolites_sordidus",
    "GCA_030704885.1": "Cynegetis_impunctata",
    "GCA_031893035.2": "Dermolepida_albohirtum",
    "GCA_034092305.1": "Diaprepes_abbreviatus",
    "GCA_021725515.1": "Epicauta_chinensis",
    "GCA_029955175.1": "Exocentrus_adspersus",
    "GCA_030704895.1": "Henosepilachna_vigintioctopunctata",
    "GCA_030620095.1": "Kuschelorhynchus_macadamiae",
    "GCA_013368075.1": "Lamprigera_yunnana",
    "GCA_050947525.1": "Lampyris_noctiluca",
    "GCA_052696345.1": "Lethrus_scoparius",
    "GCA_036346125.1": "Lycocerus_yunnanus",
    "GCA_028455855.1": "Meloe_dianella",
    "GCA_030674115.1": "Micraspis_discolor",
    "GCA_029963825.1": "Molorchus_minor",
    "GCA_020740385.1": "Mylabris_phalerata",
    "GCA_018344505.1": "Nebria_ingens_riversi",
    "GCA_047371185.1": "Neoclytus_acuminatus_acuminatus",
    "GCA_020654155.1": "Novius_pumilus",
    "GCA_036346225.1": "Platerodrilus_igneus",
    "GCA_036326145.1": "Rhagophthalmus_giganteus",
    "GCA_029963845.1": "Rhamnusium_bicolor",
    "GCA_037954035.1": "Rosalia_funebris",
    "GCA_036346155.1": "Sinelater_perroti",
    "GCA_036325965.1": "Sinopyrophorus_schimmeli",
    "GCA_051294475.1": "Sternochetus_mangiferae",
    "GCA_982185335.1": "Troglocharinus_ferreri",
    "GCA_055532135.1": "Trypodendron_lineatum",
    "GCA_034508555.1": "Venustoraphidia_nigricollis",
    "GCA_036346205.1": "Vesta_saturnalis",
    "GCA_032362365.1": "Zygogramma_bicolorata",
}

NCBI_FTP_BASE = "https://ftp.ncbi.nlm.nih.gov/genomes/all"


# ---------------------------------------------------------------------------
# URL helpers
# ---------------------------------------------------------------------------

def accession_to_dir_url(acc):
    """
    GCA_030710515.1 -> https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/030/710/515/
    Handles 9-digit and shorter digit strings by zero-padding to 9.
    """
    # Strip version: GCA_030710515
    acc_base = acc.split(".")[0]
    prefix, digits = acc_base.split("_")          # GCA, 030710515
    digits = digits.zfill(9)                       # ensure 9 digits
    path = "/".join([digits[0:3], digits[3:6], digits[6:9]])
    return f"{NCBI_FTP_BASE}/{prefix}/{path}/"


class _LinkParser(html.parser.HTMLParser):
    """Extract href values from an NCBI FTP HTML directory listing."""
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            for key, val in attrs:
                if key == "href" and val and not val.startswith("?") and val != "/":
                    self.links.append(val.rstrip("/"))


def list_dir(url, retries=3, delay=5):
    """Return list of names in an NCBI FTP HTML directory. Empty on failure."""
    headers = {"User-Agent": "SCARAB/1.0 (coleoguy@gmail.com)"}
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                content = resp.read().decode("utf-8", errors="replace")
            parser = _LinkParser()
            parser.feed(content)
            return parser.links
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(delay)
            else:
                return []
    return []


# ---------------------------------------------------------------------------
# Per-genome download
# ---------------------------------------------------------------------------

def download_one(acc, species, outdir, log_fh, min_size_bytes=1_000_000):
    """
    Download genomic.fna.gz for `acc` into `outdir`.
    Returns (status, outpath) where status is 'ok', 'skip', or 'fail'.
    """

    def log(msg):
        print(msg, flush=True)
        log_fh.write(msg + "\n")
        log_fh.flush()

    # ---- Locate assembly directory ----------------------------------------
    base_url = accession_to_dir_url(acc)
    entries = list_dir(base_url)

    # Find the versioned assembly directory: starts with the accession prefix
    acc_base = acc.split(".")[0]  # GCA_030710515
    asm_dirs = [e for e in entries if e.startswith(acc_base)]

    # Fallback: match on the full accession string anywhere in the name
    if not asm_dirs:
        asm_dirs = [e for e in entries if acc.replace(".", "_") in e or acc in e]

    if not asm_dirs:
        log(f"FAIL  {acc} ({species}): no assembly dir found at {base_url}")
        return "fail", None

    # Prefer the exact version match; otherwise take the first hit
    acc_nodot = acc.replace(".", "_")
    exact = [d for d in asm_dirs if d.startswith(acc_nodot)]
    asm_name = exact[0] if exact else asm_dirs[0]
    asm_url  = base_url + asm_name + "/"

    # ---- Locate the genomic FASTA file ------------------------------------
    files = list_dir(asm_url)
    # Want *_genomic.fna.gz but NOT rna_from_genomic or cds_from_genomic
    genomic = [
        f for f in files
        if f.endswith("_genomic.fna.gz")
        and "rna_from" not in f
        and "cds_from" not in f
    ]

    if not genomic:
        log(f"FAIL  {acc} ({species}): no *_genomic.fna.gz in {asm_url}")
        return "fail", None

    filename = genomic[0]
    file_url  = asm_url + filename
    outpath   = os.path.join(outdir, filename)

    # ---- Skip if already downloaded ---------------------------------------
    if os.path.exists(outpath) and os.path.getsize(outpath) >= min_size_bytes:
        size_mb = os.path.getsize(outpath) / 1e6
        log(f"SKIP  {acc} ({species}): already exists ({size_mb:.0f} MB)")
        return "skip", outpath

    # ---- Download via wget (supports resume, retries) ---------------------
    log(f"GET   {acc} ({species})")
    log(f"      {file_url}")

    cmd = [
        "wget", "-c",            # resume partial downloads
        "--quiet",
        "--timeout=120",
        "--tries=3",
        "--waitretry=10",
        "-O", outpath,
        file_url,
    ]

    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

    if result.returncode == 0 and os.path.exists(outpath) and \
            os.path.getsize(outpath) >= min_size_bytes:
        size_mb = os.path.getsize(outpath) / 1e6
        log(f"  OK  {species}: {size_mb:.0f} MB -> {os.path.basename(outpath)}")
        return "ok", outpath
    else:
        errmsg = result.stderr.strip()[:200] if result.stderr else "no stderr"
        log(f"  FAIL {species}: wget exit {result.returncode} — {errmsg}")
        # Remove partial file so resume works next run
        if os.path.exists(outpath):
            try:
                os.remove(outpath)
            except OSError:
                pass
        return "fail", None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--outdir", required=True,
                        help="Directory to write genome files (e.g. $SCRATCH/scarab/genomes)")
    parser.add_argument("--log",    required=True,
                        help="Path to write download log")
    parser.add_argument("--accessions", default=None,
                        help="Optional file with subset of accessions to download (one per line)")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    # Optional: restrict to a subset of accessions
    target = RECOVERY
    if args.accessions:
        with open(args.accessions) as fh:
            subset = {ln.strip() for ln in fh if ln.strip()}
        target = {k: v for k, v in RECOVERY.items() if k in subset}
        if not target:
            print(f"ERROR: --accessions file matched no known accessions", file=sys.stderr)
            sys.exit(1)

    total   = len(target)
    n_ok    = 0
    n_skip  = 0
    n_fail  = 0
    failed  = []

    with open(args.log, "a") as log_fh:
        log_fh.write(f"\n{'='*60}\n")
        log_fh.write(f"SCARAB recovery genome download  ({time.strftime('%Y-%m-%d %H:%M:%S')})\n")
        log_fh.write(f"Target: {total} accessions\n")
        log_fh.write(f"Outdir: {args.outdir}\n")
        log_fh.write(f"{'='*60}\n\n")

        for i, (acc, species) in enumerate(target.items(), 1):
            print(f"\n[{i}/{total}] {acc}  {species}", flush=True)
            log_fh.write(f"[{i}/{total}] {acc}  {species}\n")

            status, path = download_one(acc, species, args.outdir, log_fh)

            if status == "ok":
                n_ok += 1
            elif status == "skip":
                n_skip += 1
            else:
                n_fail += 1
                failed.append(f"{acc} ({species})")

        # ---- Summary -------------------------------------------------------
        summary = (
            f"\n{'='*60}\n"
            f"DONE  {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"  Downloaded : {n_ok}\n"
            f"  Skipped    : {n_skip}  (already present)\n"
            f"  Failed     : {n_fail}\n"
        )
        if failed:
            summary += "  Failed accessions:\n"
            for f in failed:
                summary += f"    {f}\n"
        summary += f"{'='*60}\n"

        print(summary, flush=True)
        log_fh.write(summary)

    if n_fail > 0:
        print(f"\nRe-run to retry failed downloads. They will be skipped once complete.",
              flush=True)
        sys.exit(1)   # non-zero exit so SLURM marks job as failed if needed
    else:
        print("\nAll genomes present. Run integrate_recovery_genomes.R next.", flush=True)


if __name__ == "__main__":
    main()
