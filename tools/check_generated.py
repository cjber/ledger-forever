"""Regenerate Ledger's pinned lookup data and reject stale or unstable output."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from forever_tools import generated

ROOT = Path(__file__).resolve().parent.parent
DATA = (
    "Data/ZoneLevels.lua",
    "Data/Areas.lua",
    "Data/Territory.lua",
)
SOURCES = (
    DATA
    + tuple(f"tools/gen_{name}.py" for name in ("zonelevels", "areas", "territory"))
    + ("tools/check_generated.py",)
)


def copy_sources(root, scratch, copy_tracked=generated.copy_tracked):
    """Include this change's untracked generators while developing before the first commit."""
    copy_tracked(root, scratch)
    for name in SOURCES:
        source = root / name
        target = scratch / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def input_cache(root, cache="tools/.cache"):
    """Keep this worktree's cache local when its shared main checkout is read-only."""
    return root / cache


def run(root, *command):
    subprocess.run(command, cwd=root, check=True)


def outputs(root):
    return {name: (root / name).read_bytes() for name in DATA}


def regenerate(root, offline):
    for name in DATA:
        (root / name).unlink()
    mode = ["--offline"] if offline else []
    for generator in ("zonelevels", "areas", "territory"):
        run(root, sys.executable, f"tools/gen_{generator}.py", *mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="require cached inputs in tools/.cache")
    original_copy_tracked = generated.copy_tracked
    original_input_cache = generated.input_cache
    generated.copy_tracked = copy_sources
    generated.input_cache = input_cache
    try:
        generated.check_generated(
            ROOT,
            outputs=outputs,
            regenerate=regenerate,
            offline=parser.parse_args().offline,
            success="Generated lookup data is current and reproducible.",
            prefix="ledger-regenerate-",
        )
    finally:
        generated.copy_tracked = original_copy_tracked
        generated.input_cache = original_input_cache


if __name__ == "__main__":
    main()
