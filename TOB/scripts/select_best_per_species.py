#!/usr/bin/env python3
"""
TOB winner-per-species selector.

Reads the NCBI inventory refresh CSV and decides which assembly to use
for each Coleoptera/Strepsiptera/Neuropterida species, applying:

  1. Bleed-through filter: drop suborder in {Apocrita, Pulicomorpha}
     (Hymenoptera and Siphonaptera misclassified by NCBI taxonomy expansion).

  2. Size filter: drop assemblies with total_length_mb < 50.
     Catches mitogenomes registered as full assemblies and the
     Wellcome Sanger 1-2 Mb Staphylinidae deposits (likely endosymbiont
     contamination).

  3. Per-species best-pick: for each organism, rank by
     (assembly_level rank, contig_N50). Keep the single best assembly.
     Per Heath 2026-05-03: option B — pull only what's actually used.

Inputs:
  TOB/data/ncbi_inventory_refresh_2026-05.csv

Outputs:
  TOB/data/best_assembly_per_species.csv
      One row per species; designates the assembly TOB will use.
  TOB/data/accessions_to_pull.txt
      Subset of winner accessions where source == new_pull.
      Read directly by Phase 0 / 02_pull_new_genomes.sh on Grace.

Run locally on Mac:
  python3 TOB/scripts/select_best_per_species.py
"""
import csv
import collections
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/..'
INVENTORY = os.path.normpath(os.path.join(REPO, 'TOB/data/ncbi_inventory_refresh_2026-05.csv'))
OUT_WINNERS = os.path.normpath(os.path.join(REPO, 'TOB/data/best_assembly_per_species.csv'))
OUT_PULL = os.path.normpath(os.path.join(REPO, 'TOB/data/accessions_to_pull.txt'))

EXCLUDE_SUBORDERS = {'apocrita', 'pulicomorpha'}
MIN_SIZE_MB = 50.0


def is_pull_eligible(row):
    """True if this NEW assembly passes the bleed-through + size filter.

    SCARAB-existing rows are exempt — they're already on Grace, BUSCO
    will catch any junk. The filter only restricts what we PULL.
    """
    if (row.get('in_scarab_catalog') or '').strip().lower() == 'yes':
        return True
    sub = (row.get('suborder') or '').strip().lower()
    if sub in EXCLUDE_SUBORDERS:
        return False
    try:
        if float(row['total_length_mb']) < MIN_SIZE_MB:
            return False
    except (ValueError, TypeError, KeyError):
        return False
    return True


def quality_key(row):
    """Higher tuple = better assembly. Prefers chromosome > scaffold > contig,
    breaks ties on contig N50."""
    level = {'Chromosome': 3, 'Scaffold': 2, 'Contig': 1}.get(
        (row.get('assembly_level') or '').strip(), 0)
    try:
        n50 = int(row['contig_N50'])
    except (ValueError, TypeError, KeyError):
        n50 = 0
    return (level, n50)


def main():
    rows = list(csv.DictReader(open(INVENTORY)))

    by_org = collections.defaultdict(list)
    for r in rows:
        org = (r.get('organism') or '').strip()
        if org:
            by_org[org].append(r)

    winners = {}
    n_species_skipped = 0
    for org, rs in by_org.items():
        eligible = [r for r in rs if is_pull_eligible(r)]
        if not eligible:
            n_species_skipped += 1
            continue
        winners[org] = max(eligible, key=quality_key)

    n_scarab = sum(1 for w in winners.values()
                   if (w.get('in_scarab_catalog') or '').lower() == 'yes')
    n_new = len(winners) - n_scarab

    fieldnames = ['organism', 'family', 'suborder', 'winner_accession',
                  'winner_source', 'winner_level', 'winner_contig_n50',
                  'winner_total_mb', 'n_assemblies_considered']
    with open(OUT_WINNERS, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for org in sorted(winners.keys()):
            best = winners[org]
            w.writerow({
                'organism': org,
                'family': best.get('family', ''),
                'suborder': best.get('suborder', ''),
                'winner_accession': best.get('accession', ''),
                'winner_source': ('scarab'
                                  if (best.get('in_scarab_catalog') or '').lower() == 'yes'
                                  else 'new_pull'),
                'winner_level': best.get('assembly_level', ''),
                'winner_contig_n50': best.get('contig_N50', ''),
                'winner_total_mb': best.get('total_length_mb', ''),
                'n_assemblies_considered': len(by_org[org]),
            })

    to_pull = sorted(
        w['accession'] for w in winners.values()
        if (w.get('in_scarab_catalog') or '').lower() == 'no'
    )
    with open(OUT_PULL, 'w') as f:
        for acc in to_pull:
            f.write(acc + '\n')

    print('=== TOB winner selection ===')
    print('Total inventory rows                : %d' % len(rows))
    print('Unique organisms                    : %d' % len(by_org))
    print('Species fully filtered out          : %d' % n_species_skipped)
    print('Species with a winning assembly     : %d' % len(winners))
    print('  - winner is SCARAB-existing       : %d' % n_scarab)
    print('  - winner is NEW (must pull)       : %d' % n_new)
    print()
    print('Pull list written to                : %s' % OUT_PULL)
    print('Winners CSV written to              : %s' % OUT_WINNERS)
    print()

    sub_counts = collections.Counter(w['suborder'] for w in winners.values())
    print('Winners by suborder:')
    for sub, c in sub_counts.most_common():
        print('  %-22s %d' % (sub or '(blank)', c))
    print()

    src_by_sub = collections.defaultdict(lambda: {'scarab': 0, 'new_pull': 0})
    for w in winners.values():
        src = ('scarab'
               if (w.get('in_scarab_catalog') or '').lower() == 'yes'
               else 'new_pull')
        src_by_sub[w['suborder']][src] += 1
    print('Winner source × suborder:')
    print('  %-22s %8s %8s' % ('suborder', 'scarab', 'new_pull'))
    for sub in sorted(src_by_sub.keys()):
        d = src_by_sub[sub]
        print('  %-22s %8d %8d' % (sub or '(blank)', d['scarab'], d['new_pull']))


if __name__ == '__main__':
    main()
