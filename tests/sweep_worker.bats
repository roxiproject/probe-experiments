#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "worker exports params as PARAM_* environment variables" {
  run "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash1 \
    '{"params":{"lr":0.5,"batch_size":8}}' \
    -- bash -c 'echo "$PARAM_LR $PARAM_BATCH_SIZE"'
  [ "$status" -eq 0 ]
  cat_out=$(cat "$SCRATCH/logs/hash1.out")
  [ "$cat_out" = "0.5 8" ]
}

@test "worker writes one JSONL record with the correct param_hash" {
  "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash2 \
    '{"params":{"a":1}}' -- true
  [ -f "$SCRATCH/results.jsonl" ]
  [ "$(wc -l <"$SCRATCH/results.jsonl" | tr -d ' ')" -eq 1 ]
  reported=$(jq -r '.param_hash' "$SCRATCH/results.jsonl")
  [ "$reported" = "hash2" ]
}

@test "worker records exit_code 0 and status completed on success" {
  "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash3 '{"params":{}}' -- true
  record=$(jq -c . "$SCRATCH/results.jsonl")
  [ "$(echo "$record" | jq -r '.exit_code')" = "0" ]
  [ "$(echo "$record" | jq -r '.status')" = "completed" ]
}

@test "worker records non-zero exit_code and status failed on failure" {
  run "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash4 '{"params":{}}' -- bash -c 'exit 7'
  [ "$status" -eq 7 ]
  record=$(jq -c . "$SCRATCH/results.jsonl")
  [ "$(echo "$record" | jq -r '.exit_code')" = "7" ]
  [ "$(echo "$record" | jq -r '.status')" = "failed" ]
}

@test "worker captures stderr separately from stdout" {
  "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash5 '{"params":{}}' \
    -- bash -c 'echo out-line; echo err-line >&2'
  [ "$(cat "$SCRATCH/logs/hash5.out")" = "out-line" ]
  [ "$(cat "$SCRATCH/logs/hash5.err")" = "err-line" ]
}

@test "worker records a positive wall_time_s" {
  "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash6 '{"params":{}}' -- sleep 0.05
  wall=$(jq -r '.wall_time_s' "$SCRATCH/results.jsonl")
  awk -v w="$wall" 'BEGIN { exit !(w > 0) }'
}

@test "worker output record is compact single-line JSON" {
  "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash7 '{"params":{"a":1}}' -- true
  # A pretty-printed record would span multiple lines, breaking JSONL.
  [ "$(wc -l <"$SCRATCH/results.jsonl" | tr -d ' ')" -eq 1 ]
}

@test "worker rejects missing -- separator" {
  run "$REPO_ROOT/bin/sweep-worker" "$SCRATCH" hash8 '{"params":{}}' true
  [ "$status" -ne 0 ]
}

@test "worker rejects too few arguments" {
  run "$REPO_ROOT/bin/sweep-worker" "$SCRATCH"
  [ "$status" -ne 0 ]
}
