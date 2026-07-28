#!/usr/bin/env bats

load helpers.bash

setup() {
  SCRATCH=$(make_scratch_dir)
}

teardown() {
  rm -rf "$SCRATCH"
}

@test "capture-env exits 0 and produces valid JSON" {
  run "$REPO_ROOT/bin/capture-env" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
}

@test "capture-env reports the expected top-level fields" {
  run "$REPO_ROOT/bin/capture-env" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  for field in captured_at python_version pip_freeze git_commit git_dirty os hostname; do
    echo "$output" | jq -e "has(\"$field\")" >/dev/null
  done
}

@test "capture-env reports the real git HEAD of the target directory" {
  run "$REPO_ROOT/bin/capture-env" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  actual_head=$(git -C "$REPO_ROOT" rev-parse HEAD)
  reported=$(echo "$output" | jq -r '.git_commit')
  [ "$reported" = "$actual_head" ]
}

@test "capture-env reports os.arch matching uname -m" {
  run "$REPO_ROOT/bin/capture-env" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  reported=$(echo "$output" | jq -r '.os.arch')
  [ "$reported" = "$(uname -m)" ]
}

@test "capture-env against a clean git worktree reports git_dirty false" {
  git init -q "$SCRATCH/repo"
  git -C "$SCRATCH/repo" config user.email "t@example.com"
  git -C "$SCRATCH/repo" config user.name "t"
  echo hi >"$SCRATCH/repo/f.txt"
  git -C "$SCRATCH/repo" add f.txt
  git -C "$SCRATCH/repo" commit -q -m "init"
  run "$REPO_ROOT/bin/capture-env" "$SCRATCH/repo"
  [ "$status" -eq 0 ]
  reported=$(echo "$output" | jq -r '.git_dirty')
  [ "$reported" = "false" ]
}

@test "capture-env against a dirty git worktree reports git_dirty true" {
  git init -q "$SCRATCH/repo2"
  git -C "$SCRATCH/repo2" config user.email "t@example.com"
  git -C "$SCRATCH/repo2" config user.name "t"
  echo hi >"$SCRATCH/repo2/f.txt"
  git -C "$SCRATCH/repo2" add f.txt
  git -C "$SCRATCH/repo2" commit -q -m "init"
  echo "changed" >>"$SCRATCH/repo2/f.txt"
  run "$REPO_ROOT/bin/capture-env" "$SCRATCH/repo2"
  [ "$status" -eq 0 ]
  reported=$(echo "$output" | jq -r '.git_dirty')
  [ "$reported" = "true" ]
}

@test "capture-env pip_freeze field is a JSON array" {
  run "$REPO_ROOT/bin/capture-env" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  kind=$(echo "$output" | jq -r '.pip_freeze | type')
  [ "$kind" = "array" ]
}
