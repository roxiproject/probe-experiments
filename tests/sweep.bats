#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "sweep runs one result per grid combination" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2, 3]}}
EOF
  run "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 2 -- true
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$SCRATCH/out/results.jsonl" | tr -d ' ')" -eq 3 ]
}

@test "sweep with a 2x3 grid produces exactly 6 results" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2], "b": [1, 2, 3]}}
EOF
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 3 -- true
  [ "$(wc -l <"$SCRATCH/out/results.jsonl" | tr -d ' ')" -eq 6 ]
}

@test "sweep results cover every distinct param_hash from the grid" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2, 3, 4]}}
EOF
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 2 -- true
  expected=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json" | jq -r '.param_hash' | sort)
  actual=$(jq -r '.param_hash' "$SCRATCH/out/results.jsonl" | sort)
  [ "$expected" = "$actual" ]
}

@test "sweep rejects a non-positive --jobs value" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1]}}
EOF
  run "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 0 -- true
  [ "$status" -ne 0 ]
}

@test "sweep requires --config, --results, and a command" {
  run "$REPO_ROOT/bin/sweep" --results "$SCRATCH/out" -- true
  [ "$status" -ne 0 ]
}

@test "--jobs 2 bounds real concurrency to at most 2 simultaneous workers" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2, 3, 4, 5, 6, 7, 8]}}
EOF
  mkdir -p "$SCRATCH/markers"
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 2 -- \
    bash -c "id=\$\$; touch '$SCRATCH/markers/'\$id; n=\$(ls '$SCRATCH/markers' | wc -l | tr -d ' '); echo \$n >> '$SCRATCH/counts.log'; sleep 0.25; rm '$SCRATCH/markers/'\$id"
  max=$(sort -n "$SCRATCH/counts.log" | tail -1)
  [ "$max" -le 2 ]
}

@test "--jobs 2 concurrency is not silently serial (max observed > 1)" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2, 3, 4, 5, 6]}}
EOF
  mkdir -p "$SCRATCH/markers"
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 2 -- \
    bash -c "id=\$\$; touch '$SCRATCH/markers/'\$id; n=\$(ls '$SCRATCH/markers' | wc -l | tr -d ' '); echo \$n >> '$SCRATCH/counts.log'; sleep 0.25; rm '$SCRATCH/markers/'\$id"
  max=$(sort -n "$SCRATCH/counts.log" | tail -1)
  [ "$max" -gt 1 ]
}

@test "--jobs 4 allows up to 4 simultaneous workers, more than --jobs 2" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2, 3, 4, 5, 6, 7, 8]}}
EOF
  mkdir -p "$SCRATCH/markers"
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 4 -- \
    bash -c "id=\$\$; touch '$SCRATCH/markers/'\$id; n=\$(ls '$SCRATCH/markers' | wc -l | tr -d ' '); echo \$n >> '$SCRATCH/counts.log'; sleep 0.25; rm '$SCRATCH/markers/'\$id"
  max=$(sort -n "$SCRATCH/counts.log" | tail -1)
  [ "$max" -le 4 ]
  [ "$max" -gt 2 ]
}

@test "resume skips combinations already marked completed" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2, 3, 4]}}
EOF
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 1 -- \
    bash -c 'if [ "$PARAM_I" = "3" ]; then exit 1; fi; echo ok'
  completed_before=$(jq -r 'select(.status == "completed") | .param_hash' "$SCRATCH/out/results.jsonl" | sort -u | wc -l | tr -d ' ')
  [ "$completed_before" -eq 3 ]

  run "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 1 --resume -- echo second-pass
  [[ "$output" == *"launched=1 skipped=3"* ]]
}

@test "resume retries a previously failed combination and it can now succeed" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2]}}
EOF
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 1 -- \
    bash -c 'if [ "$PARAM_I" = "2" ]; then exit 1; fi; echo ok'
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 1 --resume -- echo ok
  all_hashes_completed=$(jq -s '
    group_by(.param_hash)
    | map(any(.[]; .status == "completed"))
    | all
  ' "$SCRATCH/out/results.jsonl")
  [ "$all_hashes_completed" = "true" ]
}

@test "resume without --resume reruns everything, appending duplicate records" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2]}}
EOF
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 1 -- echo ok
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 1 -- echo ok
  [ "$(wc -l <"$SCRATCH/out/results.jsonl" | tr -d ' ')" -eq 4 ]
}

@test "resume with nothing completed yet runs the full grid" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"i": [1, 2, 3]}}
EOF
  run "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 2 --resume -- echo ok
  [[ "$output" == *"launched=3 skipped=0"* ]]
}

@test "worker logs directory contains a stdout file per run" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2]}}
EOF
  "$REPO_ROOT/bin/sweep" --config "$SCRATCH/grid.json" --results "$SCRATCH/out" --jobs 2 -- echo hi
  count=$(find "$SCRATCH/out/logs" -name '*.out' | wc -l | tr -d ' ')
  [ "$count" -eq 2 ]
}

@test "end-to-end: toy experiment sweep produces plausible metrics" {
  "$REPO_ROOT/bin/sweep" --config "$REPO_ROOT/examples/grid.json" --results "$SCRATCH/out" --jobs 4 \
    -- python3 "$REPO_ROOT/examples/toy_experiment.py"
  [ "$(wc -l <"$SCRATCH/out/results.jsonl" | tr -d ' ')" -eq 12 ]
  all_completed=$(jq -s 'all(.[]; .status == "completed")' "$SCRATCH/out/results.jsonl")
  [ "$all_completed" = "true" ]
  # Every stdout log should carry a JSON object with a numeric metric field.
  while IFS= read -r stdout_path; do
    jq -e '.metric | numbers' "$stdout_path" >/dev/null
  done < <(jq -r '.stdout_path' "$SCRATCH/out/results.jsonl")
}
