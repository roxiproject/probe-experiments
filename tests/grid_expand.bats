#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "expands a 2x2 grid into 4 combinations" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2], "b": [3, 4]}}
EOF
  run python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 4 ]
}

@test "expands a 3x2x2 grid into 12 combinations" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"lr": [0.1, 0.2, 0.3], "steps": [5, 10], "seed": [1, 2]}}
EOF
  run python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 12 ]
}

@test "a single-value param does not multiply the combination count" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2, 3], "fixed": ["only-value"]}}
EOF
  run python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 3 ]
}

@test "every output line is valid JSON with params and param_hash" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2]}}
EOF
  run python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json"
  [ "$status" -eq 0 ]
  while IFS= read -r line; do
    echo "$line" | jq -e '.params and .param_hash' >/dev/null
  done <<<"$output"
}

@test "param_hash is stable regardless of key order in the source config" {
  cat >"$SCRATCH/ab.json" <<'EOF'
{"params": {"a": [1], "b": [2]}}
EOF
  cat >"$SCRATCH/ba.json" <<'EOF'
{"params": {"b": [2], "a": [1]}}
EOF
  hash_ab=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/ab.json" | jq -r '.param_hash')
  hash_ba=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/ba.json" | jq -r '.param_hash')
  [ "$hash_ab" = "$hash_ba" ]
}

@test "different param values produce different hashes" {
  cat >"$SCRATCH/one.json" <<'EOF'
{"params": {"a": [1]}}
EOF
  cat >"$SCRATCH/two.json" <<'EOF'
{"params": {"a": [2]}}
EOF
  hash_one=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/one.json" | jq -r '.param_hash')
  hash_two=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/two.json" | jq -r '.param_hash')
  [ "$hash_one" != "$hash_two" ]
}

@test "hashes within one expansion are all unique" {
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2, 3], "b": [1, 2, 3]}}
EOF
  count=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json" | jq -r '.param_hash' | sort -u | wc -l | tr -d ' ')
  [ "$count" -eq 9 ]
}

@test "YAML and JSON configs with equivalent grids expand identically" {
  cat >"$SCRATCH/grid.yaml" <<'EOF'
params:
  a:
    - 1
    - 2
  b:
    - x
    - y
EOF
  cat >"$SCRATCH/grid.json" <<'EOF'
{"params": {"a": [1, 2], "b": ["x", "y"]}}
EOF
  yaml_hashes=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.yaml" | jq -r '.param_hash' | sort)
  json_hashes=$(python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/grid.json" | jq -r '.param_hash' | sort)
  [ "$yaml_hashes" = "$json_hashes" ]
}

@test "missing params key fails with a clear error" {
  cat >"$SCRATCH/bad.json" <<'EOF'
{"not_params": {"a": [1]}}
EOF
  run python3 "$REPO_ROOT/lib/grid_expand.py" "$SCRATCH/bad.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"params"* ]]
}

@test "missing config argument fails with usage message" {
  run python3 "$REPO_ROOT/lib/grid_expand.py"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage"* ]]
}
