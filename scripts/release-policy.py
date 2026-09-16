#!/usr/bin/env python3
"""Compare numeric stable versions; prereleases never control stable aliases."""
import re
import sys


def version(tag):
    match = re.fullmatch(r"v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    return tuple(map(int, match.groups())) if match else None


def policy(current, tags):
    selected = version(current)
    if selected is None:
        raise ValueError("Expected a stable X.Y.Z version")
    versions = [v for tag in tags if (v := version(tag)) is not None]
    previous = [v for v in versions if v < selected]
    return selected >= max(versions, default=selected), ".".join(map(str, max(previous))) if previous else ""


if __name__ == "__main__":
    promote, previous = policy(sys.argv[1], sys.stdin.read().splitlines())
    print(f"publish_aliases={str(promote).lower()}")
    print(f"previous_version={previous}")
