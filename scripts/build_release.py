#!/usr/bin/env python3
"""Build the one installable WoW Forever archive for ElvUI_CharNotes."""

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import List, Optional


ROOT = Path(__file__).resolve().parents[1]
ADDON_FOLDER = "ElvUI_CharNotes"
ADDON_DIR = ROOT / "CharNotes"
TOC = ADDON_DIR / f"{ADDON_FOLDER}.toc"
RUNTIME_SUFFIXES = {".lua", ".xml", ".blp", ".tga", ".png", ".jpg", ".jpeg", ".ttf", ".otf", ".wav", ".mp3"}
SEMVER_TAG = re.compile(r"v(\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)")


def toc_version() -> str:
    if not TOC.is_file():
        raise ValueError(f"Missing addon manifest: {TOC.relative_to(ROOT)}")
    for line in TOC.read_text(encoding="utf-8-sig").splitlines():
        match = re.match(r"^##\s*Version:\s*(\S+)\s*$", line)
        if match:
            version = match.group(1)
            if not SEMVER_TAG.fullmatch(f"v{version}"):
                raise ValueError(f"Invalid ## Version in {TOC.relative_to(ROOT)}: {version}")
            return version
    raise ValueError(f"No ## Version metadata in {TOC.relative_to(ROOT)}")


def validate_tag(tag: Optional[str], version: str) -> None:
    if tag is None:
        return
    match = SEMVER_TAG.fullmatch(tag)
    if not match:
        raise ValueError("Tag must use vMAJOR.MINOR.PATCH with an optional prerelease suffix")
    if match.group(1) != version:
        raise ValueError(f"Tag version {match.group(1)!r} does not match TOC version {version!r}")


def runtime_files() -> List[Path]:
    files: List[Path] = []
    for path in ADDON_DIR.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(ADDON_DIR)
        if path == TOC or path.suffix.lower() in RUNTIME_SUFFIXES:
            if path.is_symlink():
                raise ValueError(f"Release source is a symbolic link: {relative}")
            files.append(relative)

    references = set()
    for raw in TOC.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        relative = PurePosixPath(line.replace("\\", "/"))
        if relative.is_absolute() or ".." in relative.parts or ":" in line:
            raise ValueError(f"Invalid TOC file path: {line}")
        references.add(Path(*relative.parts))
    if not references:
        raise ValueError("The TOC does not list any runtime files")
    missing = references.difference(files)
    if missing:
        raise ValueError("TOC files missing from the archive: " + ", ".join(sorted(map(str, missing))))
    return sorted(files, key=lambda item: item.as_posix())


def verify_archive(archive: Path, expected_names: List[str]) -> None:
    with zipfile.ZipFile(archive) as package:
        if package.namelist() != expected_names or package.testzip() is not None:
            raise ValueError("Release ZIP failed the file list or integrity check")


def build(output: Path, tag: Optional[str]) -> Path:
    version = toc_version()
    validate_tag(tag, version)
    files = runtime_files()
    names = [f"{ADDON_FOLDER}/{relative.as_posix()}" for relative in files]
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w") as package:
        for relative, name in zip(files, names):
            info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            package.writestr(info, (ADDON_DIR / relative).read_bytes(), zipfile.ZIP_DEFLATED, compresslevel=9)
    verify_archive(output, names)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_name(output.name + ".sha256").write_text(f"{digest}  {output.name}\n", encoding="ascii")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Release tag to validate against ## Version")
    parser.add_argument("--output", type=Path, help="Destination ZIP path")
    args = parser.parse_args()
    try:
        version = toc_version()
        output = args.output or ROOT / "dist" / f"Character-Notes_v{version}_Forever.zip"
        built = build(output.resolve(), args.tag)
        print(built.relative_to(ROOT) if ROOT in built.parents else built)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"build_release.py: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
