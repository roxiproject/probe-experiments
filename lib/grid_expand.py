#!/usr/bin/env python3
"""Expand a parameter-grid config into one JSON object per combination.

Input config (JSON or YAML) has the shape:

    {
      "params": {
        "lr": [0.01, 0.1],
        "batch_size": [16, 32]
      }
    }

Each output line on stdout is a JSON object like:

    {"params": {"lr": 0.01, "batch_size": 16}, "param_hash": "a1b2c3..."}

param_hash is a stable sha256 of the params, sorted by key, so the same
combination always hashes to the same value regardless of key order in
the source config. This hash is the resume/dedupe key used by bin/sweep.
"""
from __future__ import annotations

import hashlib
import itertools
import json
import sys


def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    if path.endswith((".yaml", ".yml")):
        import yaml  # local import: only required for YAML configs

        return yaml.safe_load(text)
    return json.loads(text)


def param_hash(params: dict) -> str:
    canonical = json.dumps(params, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16]


def expand(grid: dict) -> list[dict]:
    keys = sorted(grid.keys())
    value_lists = [grid[k] if isinstance(grid[k], list) else [grid[k]] for k in keys]
    combos = []
    for values in itertools.product(*value_lists):
        combos.append(dict(zip(keys, values)))
    return combos


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: grid_expand.py <config.json|config.yaml>", file=sys.stderr)
        return 2
    config = load_config(argv[1])
    grid = config.get("params")
    if not isinstance(grid, dict) or not grid:
        print("config must contain a non-empty 'params' object", file=sys.stderr)
        return 2
    for combo in expand(grid):
        record = {"params": combo, "param_hash": param_hash(combo)}
        print(json.dumps(record, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
