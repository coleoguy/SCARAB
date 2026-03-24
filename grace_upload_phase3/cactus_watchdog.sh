#!/bin/bash
# ============================================================================
# cactus_watchdog.sh — Auto-resubmit Cactus when it hits wall time
# ============================================================================
# Run this in a tmux session on the Grace login node. It watches the
# current Cactus job and resubmits automatically when it ends.
#
# Usage:
#   tmux new -s cactus_watch
#   cd $SCRATCH/scarab
#   bash grace_upload_phase3/cactus_watchdog.sh
#
# To stop:  Ctrl+C (or kill the tmux session)
# To check: tmux attach -t cactus_watch
# ============================================================================

SLURM_SCRIPT="${SCRATCH}/scarab/grace_upload_phase3/run_full_alignment.slurm"
LOG_DIR="${SCRATCH}/scarab/work/logs"
MAX_CYCLES=6           # safety limit: stop after this many auto-resubmissions
POLL_INTERVAL=300      # check every 5 minutes

mkdir -p "${LOG_DIR}"

cycle=0

echo "============================================================"
echo "Cactus watchdog started: $(date)"
echo "Script: ${SLURM_SCRIPT}"
echo "Max cycles: ${MAX_CYCLES}"
echo "============================================================"
echo ""

# Submit the first job if nothing is running
RUNNING_JOBS=$(squeue -u "$USER" --name=scarab_cactus -h | wc -l)
if [ "$RUNNING_JOBS" -eq 0 ]; then
  echo "No job running. Submitting first cycle..."
  JOBID=$(sbatch "${SLURM_SCRIPT}" | awk '{print $NF}')
  echo "Submitted job ${JOBID} at $(date)"
  echo "CYCLE_START cycle=1 job=${JOBID} $(date)" >> "${LOG_DIR}/alignment_status.log"
  cycle=1
else
  echo "Job already running. Watchdog will monitor it."
  CURRENT=$(squeue -u "$USER" --name=scarab_cactus -h -o "%i" | head -1)
  echo "Active job: ${CURRENT}"
  cycle=1
fi

while true; do
  sleep "${POLL_INTERVAL}"

  RUNNING=$(squeue -u "$USER" --name=scarab_cactus -h | wc -l)

  if [ "$RUNNING" -eq 0 ]; then
    # Job ended — check if it succeeded
    LAST_LOG=$(ls -t "${SCRATCH}"/scarab/scarab_cactus_*.log 2>/dev/null | head -1)
    if [ -n "$LAST_LOG" ] && grep -q "ALIGNMENT COMPLETE" "$LAST_LOG"; then
      echo "============================================================"
      echo "ALIGNMENT COMPLETE at $(date)"
      echo "============================================================"
      echo "All done. Watchdog exiting."
      exit 0
    fi

    # Not complete — resubmit
    cycle=$((cycle + 1))
    if [ "${cycle}" -gt "${MAX_CYCLES}" ]; then
      echo "Reached max cycles (${MAX_CYCLES}). Stopping watchdog."
      echo "Submit manually if more cycles are needed:"
      echo "  sbatch ${SLURM_SCRIPT}"
      exit 1
    fi

    echo ""
    echo "Job ended (not complete). Starting cycle ${cycle} at $(date)..."
    JOBID=$(sbatch "${SLURM_SCRIPT}" | awk '{print $NF}')
    echo "Submitted job ${JOBID}"
    echo "CYCLE_START cycle=${cycle} job=${JOBID} $(date)" >> "${LOG_DIR}/alignment_status.log"

  else
    # Still running
    CURRENT=$(squeue -u "$USER" --name=scarab_cactus -h -o "%i %.10M %.6D %T" | head -1)
    echo "[$(date '+%H:%M')] Cactus running: ${CURRENT}"
  fi
done
