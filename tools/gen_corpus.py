#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Build the ignored, test-only QuestieDB corpus from one pinned Forever release."""

import argparse
import hashlib
import io
import shutil
import sys
import urllib.error
import zipfile
from pathlib import Path

try:
    from tools.forever_tools import wago
    from tools.forever_tools.fsio import atomic_write
except ModuleNotFoundError:
    from forever_tools import wago
    from forever_tools.fsio import atomic_write

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
CORPUS = ROOT / "tests" / ".corpus"
CLIENT_BUILD = "1.60.1.70959"
USER_AGENT = "LedgerForever/1.0"
QUESTIEDB_TAG = "v1.1.0"
QUESTIEDB_ASSET = "QuestieDB-1.1.0-Forever.zip"
QUESTIEDB_SHA256 = "283779bc9b9b3e352be63cb665e86ccc1b29bd893186e03062bcff943f20995c"
QUESTIEDB_URL = f"https://github.com/Questie/QuestieDB/releases/download/{QUESTIEDB_TAG}/{QUESTIEDB_ASSET}"
ARCHIVE = CACHE / f"questiedb-{QUESTIEDB_TAG}.zip"
CACHE_ROOT = CACHE / f"questiedb-{QUESTIEDB_TAG}"
CORPUS_ROOT = CORPUS / "QuestieDB"


def verify(content):
    digest = hashlib.sha256(content).hexdigest()
    if digest != QUESTIEDB_SHA256:
        raise ValueError(f"QuestieDB {QUESTIEDB_TAG}: sha256 {digest} does not match the pin")


def archive_files(content):
    """Validate and return the archive's safe files below its QuestieDB root."""
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        names = []
        for info in archive.infolist():
            path = Path(info.filename)
            if info.is_dir():
                continue
            if path.is_absolute() or ".." in path.parts or path.parts[:1] != ("QuestieDB",):
                raise ValueError(f"QuestieDB archive has an unsafe path: {info.filename}")
            names.append(info.filename)
        required = "QuestieDB/QuestieDB_Forever.toc"
        if required not in names:
            raise ValueError(f"QuestieDB archive has no {required}")
        return sorted(names)


def validate_zip(content):
    """Reject a truncated or corrupt QuestieDB archive before it enters the cache."""
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        bad = archive.testzip()
    if bad is not None:
        raise ValueError(f"QuestieDB archive has a corrupt member: {bad}")


def unpack(content):
    """Extract the pinned release once under the ignored shared cache."""
    addon = CACHE_ROOT / "QuestieDB"
    if (addon / "QuestieDB_Forever.toc").is_file():
        return addon
    if CACHE_ROOT.exists():
        shutil.rmtree(CACHE_ROOT)
    CACHE_ROOT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        for name in archive_files(content):
            target = CACHE_ROOT / name
            target.parent.mkdir(parents=True, exist_ok=True)
            atomic_write(target, archive.read(name))
    return addon


def write_corpus(source):
    """Copy the pinned release into the ignored test corpus, with a human-readable pin file."""
    CORPUS.mkdir(parents=True, exist_ok=True)
    if CORPUS_ROOT.exists():
        shutil.rmtree(CORPUS_ROOT)
    shutil.copytree(source, CORPUS_ROOT)
    atomic_write(
        CORPUS / "pin.txt",
        (
            "Ledger Forever test-only QuestieDB corpus. Never shipped.\n"
            f"QuestieDB: {QUESTIEDB_URL}\n"
            f"sha256: {QUESTIEDB_SHA256}\n"
            f"Forever client build: {CLIENT_BUILD}\n"
        ).encode(),
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--refresh", action="store_true", help="Download the pinned QuestieDB release again")
    group.add_argument("--offline", action="store_true", help="Require the pinned release in tools/.cache")
    args = parser.parse_args()
    content = wago.fetch(
        QUESTIEDB_URL,
        ARCHIVE,
        user_agent=USER_AGENT,
        refresh=args.refresh,
        offline=args.offline,
        timeout=300,
        validate=validate_zip,
    )
    verify(content)
    source = unpack(content)
    write_corpus(source)
    files = sum(1 for path in CORPUS_ROOT.rglob("*") if path.is_file())
    print(f"wrote tests/.corpus/QuestieDB: {files} files from {QUESTIEDB_TAG}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, urllib.error.URLError, zipfile.BadZipFile) as error:
        sys.exit(f"gen_corpus: {error}")
