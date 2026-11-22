#!/usr/bin/env python3
"""Write public commit subjects and full bodies since the previous release tag."""

import argparse
import re
import subprocess
import sys


SECTIONS = {
    "feat": "New Features",
    "fix": "Bug Fixes",
    "perf": "Performance",
    "security": "Security",
    "revert": "Reverts",
}
PATTERN = re.compile(r"^([a-z]+)(?:\(([^)]+)\))?(!)?:\s+(.+)$", re.I)


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--product", required=True)
    args = parser.parse_args()

    head = git("rev-parse", "HEAD")
    tagged = git("rev-parse", f"refs/tags/{args.tag}^{{commit}}")
    if head != tagged:
        parser.error("HEAD must match the release tag")

    try:
        previous = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0", "--match", "v[0-9]*.[0-9]*.[0-9]*", "HEAD^"],
            text=True, stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        previous = None
    revision_range = f"refs/tags/{previous}..HEAD" if previous else "HEAD"
    # NUL separators preserve multiline bodies, blank lines, and tabs without
    # confusing prose with a new commit. Git commit messages cannot contain NUL.
    fields = git("log", "--no-merges", "-z", "--format=%h%x00%s%x00%b", revision_range).split("\0")
    if fields and fields[-1] == "":
        fields.pop()
    if len(fields) % 3:
        raise ValueError("Unexpected commit record format")
    groups = {name: [] for name in SECTIONS}
    for index in range(0, len(fields), 3):
        short_hash, subject, body = fields[index:index + 3]
        match = PATTERN.fullmatch(subject.strip())
        if match and match.group(1).lower() in SECTIONS:
            kind, scope, breaking, description = match.groups()
            label = f"{scope}: {description}" if scope else description
            if breaking:
                label = f"BREAKING: {label}"
            groups[kind.lower()].append((label, short_hash, body))

    print(f"# {args.product} {args.tag} — WoW Forever\n")
    for kind, title in SECTIONS.items():
        if groups[kind]:
            print(f"## {title}\n")
            for description, short_hash, body in groups[kind]:
                # Commit subjects are untrusted text; keep them on one Markdown line.
                description = description.replace("\\", "\\\\").replace("`", "\\`")
                print(f"- {description} (`{short_hash}`)")
                if body.strip():
                    print()
                    # Nest the original Markdown under its commit. Preserve
                    # lists, code blocks, paragraphs, and breaking-change notes.
                    for line in body.rstrip("\n").splitlines():
                        print("  " + line if line else "")
                    print()
            print()
    if not any(groups.values()):
        print("No player-facing changes since the previous release.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"generate_release_notes.py: {exc}", file=sys.stderr)
        sys.exit(1)
