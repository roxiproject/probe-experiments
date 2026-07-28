#!/usr/bin/env bats
# Meta-test: every shell script this toolkit ships must be shellcheck-clean.
# Run with `shellcheck -x` so cross-file `source` warnings resolve instead
# of surfacing as SC1091 info notices.

load helpers.bash

setup() {
  if ! command -v shellcheck >/dev/null 2>&1; then
    skip "shellcheck not installed"
  fi
}

@test "bin/sweep is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/bin/sweep"
  [ "$status" -eq 0 ]
}

@test "bin/sweep-worker is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/bin/sweep-worker"
  [ "$status" -eq 0 ]
}

@test "bin/aggregate is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/bin/aggregate"
  [ "$status" -eq 0 ]
}

@test "bin/capture-env is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/bin/capture-env"
  [ "$status" -eq 0 ]
}

@test "lib/lock.sh is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/lib/lock.sh"
  [ "$status" -eq 0 ]
}

@test "lib/append_jsonl.sh is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/lib/append_jsonl.sh"
  [ "$status" -eq 0 ]
}

@test "tests/helpers.bash is shellcheck-clean" {
  run shellcheck -x "$REPO_ROOT/tests/helpers.bash"
  [ "$status" -eq 0 ]
}
