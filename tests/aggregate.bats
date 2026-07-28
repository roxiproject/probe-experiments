#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
  mkdir -p "$SCRATCH/out/logs"
  # Three hand-built result records, in the exact shape bin/sweep-worker
  # would have written, so aggregate can be tested in isolation from the
  # runner.
  cat >"$SCRATCH/out/logs/h1.out" <<'EOF'
{"metric": 0.9}
EOF
  cat >"$SCRATCH/out/logs/h2.out" <<'EOF'
{"metric": 0.1}
EOF
  cat >"$SCRATCH/out/logs/h3.out" <<'EOF'
{"metric": 0.5}
EOF
  cat >"$SCRATCH/out/results.jsonl" <<EOF
{"param_hash":"h1","params":{"a":1},"exit_code":0,"wall_time_s":0.1,"stdout_path":"$SCRATCH/out/logs/h1.out","stderr_path":"$SCRATCH/out/logs/h1.err","status":"completed","finished_at":"2026-01-01T00:00:00Z"}
{"param_hash":"h2","params":{"a":2},"exit_code":0,"wall_time_s":0.2,"stdout_path":"$SCRATCH/out/logs/h2.out","stderr_path":"$SCRATCH/out/logs/h2.err","status":"completed","finished_at":"2026-01-01T00:00:01Z"}
{"param_hash":"h3","params":{"a":3},"exit_code":0,"wall_time_s":0.3,"stdout_path":"$SCRATCH/out/logs/h3.out","stderr_path":"$SCRATCH/out/logs/h3.err","status":"completed","finished_at":"2026-01-01T00:00:02Z"}
EOF
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "aggregate exits 0 against a well-formed results file" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric
  [ "$status" -eq 0 ]
}

@test "aggregate desc order lists the highest metric first" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --order desc
  [ "$status" -eq 0 ]
  first_data_line=$(echo "$output" | sed -n '2p')
  [[ "$first_data_line" == h1* ]]
}

@test "aggregate asc order lists the lowest metric first" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --order asc
  [ "$status" -eq 0 ]
  first_data_line=$(echo "$output" | sed -n '2p')
  [[ "$first_data_line" == h2* ]]
}

@test "aggregate --top limits the number of rows shown" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --order desc --top 1
  [ "$status" -eq 0 ]
  data_lines=$(echo "$output" | tail -n +2 | grep -c . )
  [ "$data_lines" -eq 1 ]
}

@test "aggregate --csv writes a header plus one row per run" {
  "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --csv "$SCRATCH/out.csv"
  [ -f "$SCRATCH/out.csv" ]
  [ "$(wc -l <"$SCRATCH/out.csv" | tr -d ' ')" -eq 4 ]
}

@test "aggregate --csv header names the expected columns" {
  "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --csv "$SCRATCH/out.csv"
  header=$(head -1 "$SCRATCH/out.csv")
  [ "$header" = "param_hash,params,metric,exit_code,wall_time_s,status,finished_at" ]
}

@test "aggregate reports the best run's true metric value in the CSV" {
  "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --order desc --top 1 --csv "$SCRATCH/out.csv"
  best_row=$(tail -1 "$SCRATCH/out.csv")
  [[ "$best_row" == '"h1"'* ]]
  [[ "$best_row" == *,0.9,* ]]
}

@test "aggregate rejects an invalid --order value" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --order sideways
  [ "$status" -ne 0 ]
}

@test "aggregate fails clearly when results file is missing" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/does-not-exist" --metric metric
  [ "$status" -ne 0 ]
}

@test "aggregate requires --results and --metric" {
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out"
  [ "$status" -ne 0 ]
}

@test "aggregate handles a missing metric key by sorting those runs last" {
  cat >"$SCRATCH/out/logs/h1.out" <<'EOF'
not json at all
EOF
  run "$REPO_ROOT/bin/aggregate" --results "$SCRATCH/out" --metric metric --order desc
  [ "$status" -eq 0 ]
  last_data_line=$(echo "$output" | tail -1)
  [[ "$last_data_line" == h1* ]]
}
