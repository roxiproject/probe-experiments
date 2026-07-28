#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "with_lock runs the wrapped command and releases the lock directory" {
  run bash -c "source '$REPO_ROOT/lib/lock.sh'; with_lock '$SCRATCH/l.lock' true"
  [ "$status" -eq 0 ]
  [ ! -d "$SCRATCH/l.lock" ]
}

@test "with_lock passes arguments through to the wrapped command" {
  run bash -c "source '$REPO_ROOT/lib/lock.sh'; with_lock '$SCRATCH/l.lock' echo hello world"
  [ "$status" -eq 0 ]
  [ "$output" = "hello world" ]
}

@test "10 concurrent locked appends never interleave partial lines" {
  for i in $(seq 1 10); do
    bash -c "
      source '$REPO_ROOT/lib/append_jsonl.sh'
      append_jsonl_locked '$SCRATCH/out.jsonl' '{\"n\": $i, \"padding\": \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}'
    " &
  done
  wait
  # Every line must be valid, independently parseable JSON: if the lock
  # failed, two writers interleaving would corrupt at least one line.
  while IFS= read -r line; do
    echo "$line" | jq -e . >/dev/null
  done <"$SCRATCH/out.jsonl"
  [ "$(wc -l <"$SCRATCH/out.jsonl" | tr -d ' ')" -eq 10 ]
}

@test "append_jsonl_locked preserves all distinct values under contention" {
  for i in $(seq 1 10); do
    bash -c "
      source '$REPO_ROOT/lib/append_jsonl.sh'
      append_jsonl_locked '$SCRATCH/out2.jsonl' '{\"n\": $i}'
    " &
  done
  wait
  values=$(jq -r '.n' "$SCRATCH/out2.jsonl" | sort -n | tr '\n' ',')
  [ "$values" = "1,2,3,4,5,6,7,8,9,10," ]
}
