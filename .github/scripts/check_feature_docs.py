#!/usr/bin/env python3
"""PR gate: do not modify Flutter feature code without a documentation diff.

This check intentionally does NOT claim semantic accuracy; reviewers must read
and validate the updated docs and tests. PR template requires that review.
"""
import os
import subprocess
import sys


def main() -> int:
    base = os.environ.get("DOCS_BASE_SHA", "")
    head = os.environ.get("DOCS_HEAD_SHA", "")
    if not base or not head:
        print("Documentation gate: not a pull_request; skipping.")
        return 0

    proc = subprocess.run(
        ["git", "diff", "--name-only", base, head],
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode:
        print("Unable to determine PR file changes:", proc.stderr, file=sys.stderr)
        return 1

    paths = set(proc.stdout.splitlines())
    flutter_code = sorted(
        path for path in paths if path.startswith("lib/") and path.endswith(".dart")
    )
    if not flutter_code:
        print("Documentation gate: no lib/*.dart changes.")
        return 0

    docs = sorted(
        path for path in paths if path.startswith("docs/") and path.endswith(".md")
    )
    if not docs:
        print("Documentation update required for changes to:")
        for path in flutter_code:
            print(" -", path)
        print(
            "Update the relevant docs/ feature reference, handover, "
            "implementation status or decision log in this PR."
        )
        return 1

    print("Documentation gate: feature code accompanied by docs changes.")
    for path in docs:
        print(" -", path)
    print("Note: reviewers still verify factual accuracy and updated status.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
