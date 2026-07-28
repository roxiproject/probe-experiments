#!/usr/bin/env bash
# Append a single line to a JSONL file under a mutex so concurrent sweep
# workers never interleave partial writes.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
# shellcheck source=lib/lock.sh
source "$SCRIPT_DIR/lock.sh"

# append_jsonl FILE LINE
append_jsonl() {
  local file=$1
  local line=$2
  printf '%s\n' "$line" >>"$file"
}

# append_jsonl_locked FILE LINE
append_jsonl_locked() {
  local file=$1
  local line=$2
  with_lock "${file}.lock" append_jsonl "$file" "$line"
}
