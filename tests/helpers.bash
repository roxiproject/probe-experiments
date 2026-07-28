#!/usr/bin/env bash
# Shared setup for bats test files: resolves the repo root and gives each
# test a private scratch directory that is removed on teardown.
# shellcheck disable=SC2034  # consumed by the .bats files that source this
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"

make_scratch_dir() {
  mktemp -d "${TMPDIR:-/tmp}/probe-experiments-test.XXXXXX"
}
