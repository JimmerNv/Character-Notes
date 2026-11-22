#!/usr/bin/env python3
"""Write release notes from every commit since the previous release tag."""

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
    "docs": "Documentation",
    "refactor": "Refactoring",
    "test": "Tests",
    "build": "Build",
    "ci": "CI",
    "chore": "Maintenance",
    "style": "Style",
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
    subjects = git("log", "--no-merges", "--format=%h%x09%s", revision_range).splitlines()
    groups = {name: [] for name in SECTIONS}
    groups["other"] = []
    for entry in subjects:
        if not entry:
            continue
        short_hash, subject = entry.split("\t", 1)
        match = PATTERN.fullmatch(subject.strip())
        if match and match.group(1).lower() in SECTIONS:
            kind, scope, breaking, description = match.groups()
            label = f"{scope}: {description}" if scope else description
            if breaking:
                label = f"BREAKING: {label}"
            groups[kind.lower()].append((label, short_hash))
        else:
            groups["other"].append((subject, short_hash))

    print(f"# {args.product} {args.tag} — WoW Forever\n")
    for kind, title in (*SECTIONS.items(), ("other", "Other Changes")):
        if groups[kind]:
            print(f"## {title}\n")
            for description, short_hash in groups[kind]:
                # Commit subjects are untrusted text; keep them on one Markdown line.
                description = description.replace("\\", "\\\\").replace("`", "\\`")
                print(f"- {description} (`{short_hash}`)")
            print()
    if not subjects:
        print("No changes since the previous release.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"generate_release_notes.py: {exc}", file=sys.stderr)
        sys.exit(1)
