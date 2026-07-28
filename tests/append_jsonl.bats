#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "append_jsonl writes exactly one line per call" {
  run bash -c "source '$REPO_ROOT/lib/append_jsonl.sh'; append_jsonl '$SCRATCH/f.jsonl' '{\"a\":1}'"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$SCRATCH/f.jsonl" | tr -d ' ')" -eq 1 ]
}

@test "append_jsonl preserves content exactly" {
  bash -c "source '$REPO_ROOT/lib/append_jsonl.sh'; append_jsonl '$SCRATCH/f.jsonl' '{\"a\":1}'"
  content=$(cat "$SCRATCH/f.jsonl")
  [ "$content" = '{"a":1}' ]
}

@test "append_jsonl_locked creates the file if it does not exist" {
  [ ! -e "$SCRATCH/new.jsonl" ]
  bash -c "source '$REPO_ROOT/lib/append_jsonl.sh'; append_jsonl_locked '$SCRATCH/new.jsonl' '{\"a\":1}'"
  [ -f "$SCRATCH/new.jsonl" ]
}

@test "append_jsonl_locked cleans up its lock directory after each call" {
  bash -c "source '$REPO_ROOT/lib/append_jsonl.sh'; append_jsonl_locked '$SCRATCH/f.jsonl' '{\"a\":1}'"
  [ ! -d "$SCRATCH/f.jsonl.lock" ]
}
