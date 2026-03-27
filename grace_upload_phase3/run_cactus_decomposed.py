#!/usr/bin/env python3
"""
run_cactus_decomposed.py -- Level-by-level Cactus alignment with quality gates.

Decomposes a Progressive Cactus alignment using cactus-prepare, then submits
each tree-depth level as a SLURM array job. Between levels, the user can
inspect sub-HAL quality and drop problematic taxa.

Python 3.6 compatible (Grace HPC constraint).

Usage:
    python3 run_cactus_decomposed.py setup
    python3 run_cactus_decomposed.py submit --level 0
    python3 run_cactus_decomposed.py submit --level 1
    python3 run_cactus_decomposed.py status
    python3 run_cactus_decomposed.py qc --level 1
    python3 run_cactus_decomposed.py merge
"""

from __future__ import print_function
import argparse
import json
import os
import re
import subprocess
import sys

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR = os.path.join(os.environ.get("SCRATCH", "/scratch/user/blackmon"), "scarab")
CONTAINER = os.path.join(PROJECT_DIR, "cactus_v2.9.3.sif")
SEQFILE = os.path.join(PROJECT_DIR, "cactus_seqfile_filtered.txt")
WORK_DIR = os.path.join(PROJECT_DIR, "work", "cactus_decomposed")
STATE_FILE = os.path.join(WORK_DIR, "pipeline_state.json")
COMMANDS_FILE = os.path.join(WORK_DIR, "cactus_commands.txt")

SING = "singularity exec --cleanenv -B {pd}:{pd} -B /tmp:/tmp {c}".format(
    pd=PROJECT_DIR, c=CONTAINER)

# Resource tiers by tree depth
RESOURCE_TIERS = [
    # (max_depth, cores, mem_gb, wall_time, partition)
    # Grace: short=2h, medium=1d, long=7d, xlong=21d
    (2,   8,   32,  "12:00:00",  "medium"),
    (4,  16,   64,  "12:00:00",  "medium"),
    (10, 32,  128,  "1-00:00:00", "long"),
    (20, 48,  192,  "2-00:00:00", "long"),
    (99, 48,  384,  "7-00:00:00", "long"),
]

PREPROCESS_WALL = "12:00:00"
PREPROCESS_PARTITION = "medium"
PREPROCESS_CORES = 48
PREPROCESS_MEM = 128

MAIL_USER = "coleoguy@gmail.com"


def get_resources(depth):
    """Return (cores, mem_gb, wall_time, partition) for a given tree depth."""
    for max_d, cores, mem, wall, part in RESOURCE_TIERS:
        if depth <= max_d:
            return cores, mem, wall, part
    return 48, 384, "7-00:00:00", "long"


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


# ============================================================================
# SETUP: run cactus-prepare, parse tree, save dependency graph
# ============================================================================

def parse_newick_depths(tree_str):
    """Parse newick tree to get depth (from leaves) for each Anc node."""
    nodes = {}
    stack = []
    current_children = []
    i = 0

    while i < len(tree_str):
        c = tree_str[i]
        if c == "(":
            stack.append(current_children)
            current_children = []
            i += 1
        elif c == ")":
            i += 1
            node_name = ""
            while i < len(tree_str) and tree_str[i] not in ":,);":
                node_name += tree_str[i]
                i += 1
            if i < len(tree_str) and tree_str[i] == ":":
                i += 1
                while i < len(tree_str) and tree_str[i] not in ",);":
                    i += 1
            children = current_children
            current_children = stack.pop()
            if node_name:
                nodes[node_name] = children
                current_children.append(node_name)
            else:
                current_children.extend(children)
        elif c == ",":
            i += 1
        elif c == ";":
            i += 1
        else:
            leaf_name = ""
            while i < len(tree_str) and tree_str[i] not in ":,);(":
                leaf_name += tree_str[i]
                i += 1
            if i < len(tree_str) and tree_str[i] == ":":
                i += 1
                while i < len(tree_str) and tree_str[i] not in ",);":
                    i += 1
            if leaf_name:
                current_children.append(leaf_name)

    anc_nodes = {k: v for k, v in nodes.items() if k.startswith("Anc")}

    depth_cache = {}

    def get_depth(name):
        if name in depth_cache:
            return depth_cache[name]
        if name not in anc_nodes:
            depth_cache[name] = 0
            return 0
        d = 1 + max(get_depth(c) for c in anc_nodes[name])
        depth_cache[name] = d
        return d

    for name in anc_nodes:
        get_depth(name)

    return {k: depth_cache[k] for k in anc_nodes}


def cmd_setup(args):
    """Run cactus-prepare, parse tree, build dependency graph."""
    os.makedirs(WORK_DIR, exist_ok=True)
    os.makedirs(os.path.join(WORK_DIR, "slurm_scripts"), exist_ok=True)
    os.makedirs(os.path.join(WORK_DIR, "logs"), exist_ok=True)

    steps_dir = os.path.join(WORK_DIR, "steps")
    steps_file = os.path.join(steps_dir, "steps.txt")
    out_hal = os.path.join(steps_dir, "scarab.hal")

    if os.path.exists(steps_dir):
        print("Removing old steps dir...")
        subprocess.call(["rm", "-rf", steps_dir])
    os.makedirs(os.path.join(steps_dir, "logs"), exist_ok=True)

    # Run cactus-prepare
    print("Running cactus-prepare...")
    cmd = (
        "{sing} cactus-prepare {seqfile} "
        "--outDir {steps_dir} "
        "--outSeqFile {steps_file} "
        "--outHal {out_hal} "
        "--defaultCores 48 --blastCores 48 --alignCores 48"
    ).format(
        sing=SING, seqfile=SEQFILE, steps_dir=steps_dir,
        steps_file=steps_file, out_hal=out_hal
    )

    proc = subprocess.Popen(
        cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True
    )
    stdout, stderr = proc.communicate()

    warnings = [l for l in stderr.strip().split("\n") if "WARNING" in l]
    if warnings:
        print("WARNINGS from cactus-prepare ({} total):".format(len(warnings)))
        for w in warnings[:5]:
            print("  " + w)
        if len(warnings) > 5:
            print("  ... and {} more".format(len(warnings) - 5))

    # Save commands
    with open(COMMANDS_FILE, "w") as f:
        f.write(stdout)
    print("Commands saved to: {}".format(COMMANDS_FILE))

    # Parse commands into categories
    preprocess_cmds = []
    blast_cmds = {}
    align_cmds = {}
    append_cmds = []

    for line in stdout.strip().split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "cactus-preprocess" in line:
            preprocess_cmds.append(line)
        elif "cactus-blast" in line:
            m = re.search(r"--root\s+(\S+)", line)
            if m:
                blast_cmds[m.group(1)] = line
        elif "cactus-align" in line:
            m = re.search(r"--root\s+(\S+)", line)
            if m:
                align_cmds[m.group(1)] = line
        elif "halAppendSubtree" in line:
            append_cmds.append(line)

    print("Parsed: {} preprocess, {} blast, {} align, {} halAppend".format(
        len(preprocess_cmds), len(blast_cmds), len(align_cmds), len(append_cmds)))

    # Parse tree from steps.txt to get depth levels
    print("Parsing tree for depth levels...")
    tree_line = open(steps_file).readline().strip()
    anc_depths = parse_newick_depths(tree_line)

    # Group by depth
    levels = {}
    for anc, depth in anc_depths.items():
        levels.setdefault(depth, []).append(anc)

    max_depth = max(levels.keys()) if levels else 0
    print("Depth levels: {} (max depth: {})".format(len(levels), max_depth))
    for d in sorted(levels.keys()):
        print("  Level {}: {} nodes".format(d, len(levels[d])))

    # Save state
    state = {
        "steps_dir": steps_dir,
        "steps_file": steps_file,
        "out_hal": out_hal,
        "preprocess_cmds": preprocess_cmds,
        "blast_cmds": blast_cmds,
        "align_cmds": align_cmds,
        "append_cmds": append_cmds,
        "anc_depths": anc_depths,
        "levels": {str(k): v for k, v in levels.items()},
        "max_depth": max_depth,
        "completed_levels": [],
        "job_ids": {},
    }
    save_state(state)
    print("\nSetup complete. State saved to: {}".format(STATE_FILE))
    print("\nNext: python3 run_cactus_decomposed.py submit --level 0")


# ============================================================================
# SUBMIT: submit one level as SLURM jobs
# ============================================================================

def cmd_submit(args):
    """Submit all jobs for a given depth level."""
    state = load_state()
    if not state:
        print("ERROR: Run setup first.")
        sys.exit(1)

    level = args.level

    if level == 0:
        submit_preprocess(state)
    else:
        submit_blast_align_level(state, level)


def submit_preprocess(state):
    """Submit preprocessing jobs as a SLURM array."""
    cmds = state["preprocess_cmds"]
    n = len(cmds)
    print("Submitting {} preprocess jobs...".format(n))

    # Write command list
    cmd_list = os.path.join(WORK_DIR, "preprocess_cmds.txt")
    with open(cmd_list, "w") as f:
        for c in cmds:
            f.write(c + "\n")

    # Write SLURM script
    slurm_script = os.path.join(WORK_DIR, "slurm_scripts", "preprocess.slurm")
    with open(slurm_script, "w") as f:
        f.write("""#!/bin/bash
#SBATCH --job-name=cactus_prep
#SBATCH --partition={partition}
#SBATCH --time={wall}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={cores}
#SBATCH --mem={mem}G
#SBATCH --array=1-{n}
#SBATCH --output={logdir}/preprocess_%a_%j.log
#SBATCH --error={logdir}/preprocess_%a_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user={mail}

set -euo pipefail
CMD=$(sed -n "${{SLURM_ARRAY_TASK_ID}}p" {cmd_list})
echo "Task $SLURM_ARRAY_TASK_ID: $CMD"
echo "Started: $(date)"
{sing} $CMD
echo "Completed: $(date)"
""".format(
            partition=PREPROCESS_PARTITION,
            wall=PREPROCESS_WALL,
            cores=PREPROCESS_CORES,
            mem=PREPROCESS_MEM,
            n=n,
            logdir=os.path.join(WORK_DIR, "logs"),
            mail=MAIL_USER,
            cmd_list=cmd_list,
            sing=SING,
        ))

    # Submit
    proc = subprocess.Popen(
        ["sbatch", slurm_script],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
    )
    out, err = proc.communicate()
    if proc.returncode != 0:
        print("ERROR submitting: {}".format(err))
        sys.exit(1)

    job_id = out.strip().split()[-1]
    print("Submitted preprocess array: job {}".format(job_id))
    state["job_ids"]["level_0"] = job_id
    save_state(state)
    print("\nNext: wait for completion, then:")
    print("  python3 run_cactus_decomposed.py submit --level 1")


def submit_blast_align_level(state, level):
    """Submit blast+align jobs for a given tree depth level."""
    level_key = str(level)
    if level_key not in state["levels"]:
        print("ERROR: No nodes at depth level {}".format(level))
        sys.exit(1)

    anc_nodes = state["levels"][level_key]
    blast_cmds = state["blast_cmds"]
    align_cmds = state["align_cmds"]

    # Build command pairs for this level
    pairs = []
    missing = []
    for anc in sorted(anc_nodes):
        if anc in blast_cmds and anc in align_cmds:
            pairs.append((anc, blast_cmds[anc], align_cmds[anc]))
        else:
            missing.append(anc)

    if missing:
        print("WARNING: {} nodes missing blast/align commands: {}".format(
            len(missing), ", ".join(missing[:5])))

    n = len(pairs)
    if n == 0:
        print("No jobs to submit for level {}".format(level))
        return

    cores, mem, wall, partition = get_resources(level)
    print("Level {}: {} blast+align jobs ({} cores, {} GB, {}, {})".format(
        level, n, cores, mem, wall, partition))

    # Write command pairs file (blast\talign per line)
    cmd_list = os.path.join(WORK_DIR, "level_{}_cmds.txt".format(level))
    with open(cmd_list, "w") as f:
        for anc, bcmd, acmd in pairs:
            f.write("{}\t{}\t{}\n".format(anc, bcmd, acmd))

    # Write SLURM script
    slurm_script = os.path.join(
        WORK_DIR, "slurm_scripts", "level_{}.slurm".format(level))
    with open(slurm_script, "w") as f:
        f.write("""#!/bin/bash
#SBATCH --job-name=cactus_L{level}
#SBATCH --partition={partition}
#SBATCH --time={wall}
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task={cores}
#SBATCH --mem={mem}G
#SBATCH --array=1-{n}
#SBATCH --output={logdir}/L{level}_%a_%j.log
#SBATCH --error={logdir}/L{level}_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user={mail}

set -euo pipefail
LINE=$(sed -n "${{SLURM_ARRAY_TASK_ID}}p" {cmd_list})
ANC=$(echo "$LINE" | cut -f1)
BLAST_CMD=$(echo "$LINE" | cut -f2)
ALIGN_CMD=$(echo "$LINE" | cut -f3)

echo "Level {level}, Task $SLURM_ARRAY_TASK_ID: $ANC"
echo "Started: $(date)"

# Override --maxCores to match SLURM allocation
BLAST_CMD=$(echo "$BLAST_CMD" | sed "s/--maxCores [0-9]*/--maxCores {cores}/")
ALIGN_CMD=$(echo "$ALIGN_CMD" | sed "s/--maxCores [0-9]*/--maxCores {cores}/")

echo "=== BLAST ==="
{sing} $BLAST_CMD
echo "=== ALIGN ==="
{sing} $ALIGN_CMD
echo "Completed: $(date)"
""".format(
            level=level,
            partition=partition,
            wall=wall,
            cores=cores,
            mem=mem,
            n=n,
            logdir=os.path.join(WORK_DIR, "logs"),
            mail=MAIL_USER,
            cmd_list=cmd_list,
            sing=SING,
        ))

    # Check for dependency on previous level
    dep_flag = ""
    prev_key = "level_{}".format(level - 1)
    if prev_key in state.get("job_ids", {}):
        prev_id = state["job_ids"][prev_key]
        dep_flag = "--dependency=afterok:{}".format(prev_id)
        print("  Dependency: afterok:{}".format(prev_id))

    # Submit
    sbatch_cmd = ["sbatch"]
    if dep_flag:
        sbatch_cmd.append(dep_flag)
    sbatch_cmd.append(slurm_script)

    proc = subprocess.Popen(
        sbatch_cmd,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
    )
    out, err = proc.communicate()
    if proc.returncode != 0:
        print("ERROR submitting: {}".format(err))
        sys.exit(1)

    job_id = out.strip().split()[-1]
    print("Submitted level {} array: job {}".format(level, job_id))
    state["job_ids"]["level_{}".format(level)] = job_id
    save_state(state)

    print("\nNext: wait for completion, then:")
    print("  python3 run_cactus_decomposed.py qc --level {}".format(level))


# ============================================================================
# STATUS: check pipeline progress
# ============================================================================

def cmd_status(args):
    """Show pipeline status."""
    state = load_state()
    if not state:
        print("No pipeline state. Run setup first.")
        return

    max_depth = state.get("max_depth", 0)
    job_ids = state.get("job_ids", {})

    print("=== CACTUS DECOMPOSED PIPELINE STATUS ===")
    print("Max depth: {}".format(max_depth))
    print("")

    for level in range(0, max_depth + 1):
        level_key = "level_{}".format(level)
        if level == 0:
            n = len(state.get("preprocess_cmds", []))
            label = "preprocess"
        else:
            lk = str(level)
            n = len(state.get("levels", {}).get(lk, []))
            label = "blast+align"

        job_id = job_ids.get(level_key, "not submitted")

        if job_id != "not submitted":
            # Check SLURM status
            proc = subprocess.Popen(
                ["sacct", "-j", str(job_id), "--format=State", "--noheader", "-P"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
            )
            out, _ = proc.communicate()
            states = [s.strip() for s in out.strip().split("\n") if s.strip()]
            if all(s == "COMPLETED" for s in states):
                status = "COMPLETED"
            elif any(s == "RUNNING" for s in states):
                running = sum(1 for s in states if s == "RUNNING")
                status = "RUNNING ({}/{})".format(running, n)
            elif any(s == "PENDING" for s in states):
                status = "PENDING"
            elif any(s == "FAILED" for s in states):
                failed = sum(1 for s in states if s == "FAILED")
                status = "FAILED ({}/{})".format(failed, n)
            else:
                status = ", ".join(set(states))[:40]
        else:
            status = "not submitted"

        print("  Level {:2d} ({:3d} {} jobs): {} [{}]".format(
            level, n, label, status, job_id))

    print("")
    print("Active SLURM jobs:")
    os.system("squeue -u $USER --name='cactus_*' -o '%.8i %.12j %.8T %.10M %.4D %R' 2>/dev/null || echo '  (none)'")


# ============================================================================
# QC: inspect sub-HAL files from a level
# ============================================================================

def cmd_qc(args):
    """Run quality check on sub-HALs from a completed level."""
    state = load_state()
    if not state:
        print("ERROR: Run setup first.")
        sys.exit(1)

    level = args.level
    level_key = str(level)
    if level_key not in state.get("levels", {}):
        print("ERROR: No nodes at level {}".format(level))
        sys.exit(1)

    anc_nodes = state["levels"][level_key]
    steps_dir = state["steps_dir"]

    print("=== QC for Level {} ({} nodes) ===".format(level, len(anc_nodes)))
    print("")

    problems = []
    for anc in sorted(anc_nodes):
        hal_path = os.path.join(steps_dir, "{}.hal".format(anc))
        if not os.path.exists(hal_path):
            print("  {}: HAL MISSING".format(anc))
            problems.append((anc, "HAL missing"))
            continue

        size_mb = os.path.getsize(hal_path) / (1024 * 1024)
        if size_mb < 0.01:
            print("  {}: HAL EMPTY ({:.1f} MB)".format(anc, size_mb))
            problems.append((anc, "HAL empty"))
            continue

        # Run halStats
        cmd = "{} halStats {} 2>&1".format(SING, hal_path)
        proc = subprocess.Popen(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True
        )
        out, err = proc.communicate()

        if proc.returncode != 0:
            print("  {}: halStats FAILED ({:.1f} MB)".format(anc, size_mb))
            problems.append((anc, "halStats failed"))
            continue

        # Parse halStats output
        lines = out.strip().split("\n")
        genomes = [l for l in lines if not l.startswith("hal") and l.strip()]
        n_genomes = len(genomes)
        print("  {}: {:.1f} MB, {} genomes".format(anc, size_mb, n_genomes))

    print("")
    if problems:
        print("PROBLEMS FOUND: {}".format(len(problems)))
        for anc, issue in problems:
            print("  {}: {}".format(anc, issue))
        print("\nTo drop problematic taxa, identify which leaf taxa are affected")
        print("and re-run setup with a pruned seqfile.")
    else:
        print("All {} sub-HALs OK.".format(len(anc_nodes)))
        print("\nNext: python3 run_cactus_decomposed.py submit --level {}".format(
            level + 1))


# ============================================================================
# MERGE: run halAppendSubtree to build final HAL
# ============================================================================

def cmd_merge(args):
    """Submit halAppendSubtree jobs to build final HAL."""
    state = load_state()
    if not state:
        print("ERROR: Run setup first.")
        sys.exit(1)

    append_cmds = state.get("append_cmds", [])
    n = len(append_cmds)
    print("Submitting {} halAppendSubtree jobs (sequential)...".format(n))

    # Write command list
    cmd_list = os.path.join(WORK_DIR, "merge_cmds.txt")
    with open(cmd_list, "w") as f:
        for c in append_cmds:
            f.write(c + "\n")

    # Single SLURM job that runs all merges sequentially
    slurm_script = os.path.join(WORK_DIR, "slurm_scripts", "merge.slurm")
    with open(slurm_script, "w") as f:
        f.write("""#!/bin/bash
#SBATCH --job-name=cactus_merge
#SBATCH --partition=long
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --output={logdir}/merge_%j.log
#SBATCH --error={logdir}/merge_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user={mail}

set -euo pipefail
echo "HAL merge started: $(date)"
echo "{n} halAppendSubtree commands"

i=0
while IFS= read -r CMD; do
    i=$((i+1))
    echo "[$i/{n}] $CMD"
    {sing} $CMD
done < {cmd_list}

echo ""
echo "Merge complete: $(date)"
echo "Final HAL: {out_hal}"
{sing} halStats {out_hal}
""".format(
            logdir=os.path.join(WORK_DIR, "logs"),
            mail=MAIL_USER,
            n=n,
            sing=SING,
            cmd_list=cmd_list,
            out_hal=state.get("out_hal", ""),
        ))

    proc = subprocess.Popen(
        ["sbatch", slurm_script],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True
    )
    out, err = proc.communicate()
    if proc.returncode != 0:
        print("ERROR submitting: {}".format(err))
        sys.exit(1)

    job_id = out.strip().split()[-1]
    print("Submitted merge job: {}".format(job_id))
    state["job_ids"]["merge"] = job_id
    save_state(state)


# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Decomposed Cactus alignment with quality gates")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("setup", help="Run cactus-prepare and parse dependency graph")

    p_submit = sub.add_parser("submit", help="Submit jobs for a depth level")
    p_submit.add_argument("--level", type=int, required=True,
                          help="Tree depth level (0=preprocess, 1+=blast+align)")

    sub.add_parser("status", help="Check pipeline progress")

    p_qc = sub.add_parser("qc", help="QC sub-HALs from a completed level")
    p_qc.add_argument("--level", type=int, required=True)

    sub.add_parser("merge", help="Submit halAppendSubtree merge jobs")

    args = parser.parse_args()

    if args.command == "setup":
        cmd_setup(args)
    elif args.command == "submit":
        cmd_submit(args)
    elif args.command == "status":
        cmd_status(args)
    elif args.command == "qc":
        cmd_qc(args)
    elif args.command == "merge":
        cmd_merge(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
