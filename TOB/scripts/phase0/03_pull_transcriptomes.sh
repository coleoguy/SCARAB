#!/bin/bash
# TOB Phase 0 / Step 3 — pull 4 verified Tier-2 transcriptomes via NCBI efetch.
# Run on Grace LOGIN NODE.
#
# TSA "master" accessions (e.g. GACO00000000.1) are metadata stubs that
# return zero sequence via efetch fasta. The actual contigs live at
# accessions like GACO01000001..GACO01018752 (range listed in the
# master record's COMMENT field). Strategy:
#   1. fetch the GenBank text for the master, regex out the contig range
#   2. batch-fetch FASTA in chunks of 200 contigs via efetch POST
#   3. gzip the concatenated result
#
# Earlier WGS-FTP attempt failed: NCBI restructured the FTP layout and the
# /genbank/wgs/wgs_aux/<prefix>/ pattern returns 404 for these projects.
set -euo pipefail

TOB_ROOT="/scratch/user/blackmon/tob"
TR_DIR="$TOB_ROOT/transcriptomes"
LOG="$TOB_ROOT/logs/03_pull_transcriptomes_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$TR_DIR" "$TOB_ROOT/logs"

python3 - "$TR_DIR" "$LOG" <<'PY'
import urllib.request, urllib.parse, re, gzip, time, sys, os

TR_DIR, LOG = sys.argv[1], sys.argv[2]
EUTILS = 'https://eutils.ncbi.nlm.nih.gov/entrez/eutils'
BATCH = 200      # NCBI accepts up to ~500/POST; 200 keeps responses small
SLEEP = 0.35     # 3 req/sec without API key; stay under

# (species_safe_name, master_accession, family, suborder)
TSAS = [
    ('Priacma_serrata',      'GACO00000000.1', 'Cupedidae',      'Archostemata'),
    ('Micromalthus_debilis', 'GDOQ00000000.1', 'Micromalthidae', 'Archostemata'),
    ('Hydroscapha_redfordi', 'GDMJ00000000.1', 'Hydroscaphidae', 'Myxophaga'),
    ('Lepicerus_sp',         'GAZB00000000.2', 'Lepiceridae',    'Myxophaga'),
]


def log(msg):
    line = '[%s] %s' % (time.strftime('%T'), msg)
    print(line, flush=True)
    with open(LOG, 'a') as f:
        f.write(line + '\n')


def get_contig_range(master_acc):
    url = '%s/efetch.fcgi?db=nuccore&id=%s&rettype=gb&retmode=text' % (EUTILS, master_acc)
    txt = urllib.request.urlopen(url, timeout=60).read().decode('utf-8', errors='replace')
    # GenBank text wraps long lines; "consists of" and "sequences" can be on
    # separate physical lines (e.g. Priacma serrata GACO master record).
    # Use \s+ between every word and re.S so . matches newlines.
    m = re.search(r'consists\s+of\s+sequences\s+(\w+\d+)\s*-\s*(\w+\d+)', txt, re.S)
    if not m:
        return None, None
    return m.group(1), m.group(2)


def gen_accessions(start, end):
    m1 = re.match(r'(\D+)(\d+)$', start)
    m2 = re.match(r'(\D+)(\d+)$', end)
    if not m1 or not m2 or m1.group(1) != m2.group(1):
        return []
    prefix = m1.group(1)
    n1, n2 = int(m1.group(2)), int(m2.group(2))
    pad = len(m1.group(2))
    return [prefix + str(i).zfill(pad) for i in range(n1, n2 + 1)]


def fetch_batch_fasta(accs, retries=3):
    for attempt in range(1, retries + 1):
        try:
            data = urllib.parse.urlencode({
                'db': 'nuccore',
                'id': ','.join(accs),
                'rettype': 'fasta',
                'retmode': 'text',
            }).encode('utf-8')
            req = urllib.request.Request('%s/efetch.fcgi' % EUTILS, data=data)
            return urllib.request.urlopen(req, timeout=180).read().decode('utf-8', errors='replace')
        except Exception as e:
            if attempt == retries:
                raise
            time.sleep(5 * attempt)


for name, master, family, suborder in TSAS:
    log('%s/%s — %s (%s)' % (suborder, family, name, master))
    try:
        start, end = get_contig_range(master)
    except Exception as e:
        log('  ERROR fetching master: %s' % e)
        continue
    if not start:
        log('  ERROR: could not parse contig range from master record')
        continue
    accs = gen_accessions(start, end)
    log('  Range: %s ... %s (%d contigs)' % (start, end, len(accs)))

    out_path = os.path.join(TR_DIR, '%s_%s.fasta.gz' % (name, master))
    n_done = 0
    with gzip.open(out_path, 'wt') as out:
        for i in range(0, len(accs), BATCH):
            chunk = accs[i:i + BATCH]
            try:
                fasta = fetch_batch_fasta(chunk)
                out.write(fasta)
                n_done += len(chunk)
            except Exception as e:
                log('  Batch %d-%d FAILED after retries: %s' % (i, i + len(chunk) - 1, e))
            time.sleep(SLEEP)
    size_mb = os.path.getsize(out_path) / 1e6
    log('  Wrote %s (%.2f MB), %d/%d contigs OK' % (out_path, size_mb, n_done, len(accs)))
PY

echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 3 complete." | tee -a "$LOG"
ls -lh "$TR_DIR" | tee -a "$LOG"
