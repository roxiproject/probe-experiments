#!/usr/bin/env bash
# Portable mkdir-based mutex. macOS ships without flock(1), so appends to a
# shared results file are serialized with an atomic `mkdir` spin-lock
# instead. Source this file, then wrap the critical section:
#
#   source lib/lock.sh
#   with_lock "$results_file.lock" append_result "$line"
set -euo pipefail

# with_lock LOCKDIR CMD [ARGS...]
# Acquires LOCKDIR as a mutex (mkdir is atomic even on network filesystems),
# runs CMD with ARGS, then always releases the lock.
with_lock() {
  local lockdir=$1
  shift
  local waited=0
  local max_wait=30
  while ! mkdir "$lockdir" 2>/dev/null; do
    sleep 0.05
    waited=$((waited + 1))
    if [ "$waited" -gt $((max_wait * 20)) ]; then
      echo "with_lock: timed out waiting for $lockdir" >&2
      return 1
    fi
  done
  # shellcheck disable=SC2064
  trap "rmdir '$lockdir' 2>/dev/null || true" RETURN
  "$@"
}
