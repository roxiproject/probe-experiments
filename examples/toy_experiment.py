#!/usr/bin/env python3
"""Toy experiment command used to exercise the sweep runner end to end.

Reads lr and steps from the environment (as PARAM_LR / PARAM_STEPS, the
convention bin/sweep-worker uses) and prints a JSON line with a computed
metric, matching the shape bin/aggregate expects.
"""
import json
import os
import sys


def main() -> int:
    lr = float(os.environ.get("PARAM_LR", "0.1"))
    steps = int(os.environ.get("PARAM_STEPS", "10"))
    # A deterministic toy "loss": decays with steps, scaled by lr, so the
    # sweep produces a real, distinguishable metric per combination.
    loss = round(1.0 / (1.0 + lr * steps), 6)
    print(json.dumps({"metric": loss, "lr": lr, "steps": steps}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
