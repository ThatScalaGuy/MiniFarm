#!/usr/bin/env python3
"""Check MiniFarm's unsigned Release product. No extraction, playback or network."""

import argparse
import filecmp
import json
import plistlib
import re
import stat
import subprocess
import sys
import tempfile
import wave
import zipfile
from pathlib import Path
from xml.parsers.expat import ExpatError


ROOT = Path(__file__).resolve().parents[2]
CONTENT = {
    f"Content/{name}.json" for name in
    "activities adaptive animals crops decorations economy hofbook items locations machines recipes seasons".split()
}
MANIFESTS = {"Audio/manifest.json", "Models/manifest.json"}
REQUIRED = CONTENT | MANIFESTS | {"Info.plist", "MiniFarm", "PrivacyInfo.xcprivacy", "Assets.car"}
RESOURCE_DIRS = {"Content", "Audio", "Models"}
ID = r"[a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+"
MODEL = rf"Models/model\.{ID}\.usdz"
AUDIO = r"Audio/(?:[a-z0-9][a-z0-9_.-]*/)*[a-z0-9][a-z0-9_.-]*\.(?:wav|m4a|caf|mp3|aiff|aac)"


class BundleError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise BundleError(message)


def inventory(app):
    """Use directory entries, not path.exists(): case matters even on the default macOS volume."""
    require(not app.is_symlink() and app.is_dir(), "expected an actual .app directory")
    files = set()
    directories = set()

    def visit(directory, prefix):
        for entry in directory.iterdir():
            name = prefix + entry.name
            info = entry.lstat()
            if stat.S_ISDIR(info.st_mode):
                require(name in RESOURCE_DIRS or re.fullmatch(r"Audio/(?:[a-z0-9][a-z0-9_.-]*/)*[a-z0-9][a-z0-9_.-]*", name),
                        "unexpected directory in product (not opened)")
                directories.add(name)
                visit(entry, name + "/")
                continue
            require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1,
                    "linked or special file in product (not opened)")
            if name in {folder + "/.gitkeep" for folder in RESOURCE_DIRS}:
                require(info.st_size == 0, "nonempty resource placeholder (not opened)")
                continue
            require(name in REQUIRED or name == "PkgInfo"
                    or re.fullmatch(r"AppIcon[0-9]+x[0-9]+(?:@[23]x)?(?:~ipad)?\.png", name)
                    or re.fullmatch(MODEL, name) or re.fullmatch(AUDIO, name),
                    "unexpected file in product (not opened)")
            require(info.st_size > 0, f"empty file: {name}")
            files.add(name)

    visit(app, "")
    missing = sorted(REQUIRED - files)
    require(not missing, "missing from product: " + ", ".join(missing))
    parents = {parent.as_posix() for name in files for parent in Path(name).parents}
    require(directories <= parents, "unexpected empty directory in product")
    return files


def manifest_rows(app, group):
    name = f"{group}/manifest.json"
    try:
        manifest = json.loads((app / name).read_bytes())
    except (ValueError, RecursionError):
        raise BundleError(f"{name}: invalid JSON") from None
    require(isinstance(manifest, dict), f"{name}: expected manifest object")
    if group == "Audio":
        require(type(manifest.get("schemaVersion")) is int and manifest["schemaVersion"] == 1,
                f"{name}: unsupported schemaVersion")
    rows = manifest.get("assets")
    require(isinstance(rows, list) and rows, f"{name}: missing or empty assets")
    seen = set()
    for index, row in enumerate(rows):
        where = f"{name}: assets[{index}]"
        require(isinstance(row, dict) and isinstance(row.get("id"), str) and re.fullmatch(ID, row["id"]),
                f"{where}: invalid asset ID")
        require(row["id"] not in seen, f"{where}: duplicate ID {row['id']}")
        seen.add(row["id"])
        yield row, where


def asset_paths(app, files):
    model_ids, sound_ids, declared, speech = set(), set(), set(), 0
    for row, where in manifest_rows(app, "Models"):
        asset_id = "model." + row["id"]
        filename = asset_id + ".usdz"
        require(row.get("file") == filename,
                f"{where}: file does not match runtime basename for {asset_id}")
        name = "Models/" + filename
        require(name in files, f"{where}: missing {name}")
        require(type(row.get("bytes")) is int and row["bytes"] == (app / name).stat().st_size,
                f"{name}: size differs from manifest")
        model_ids.add(asset_id)
        declared.add(name)

    for row, where in manifest_rows(app, "Audio"):
        kind = row.get("kind")
        require(kind in ("sfx", "voice", "music", "ambient"), f"{where}: unknown audio kind")
        if kind == "sfx":
            sound_ids.add(row["id"])
        if row.get("path") is None:
            require(kind == "voice" and row["id"].startswith("vl.") and row.get("locale") == "de-DE",
                    f"{where}: only a declared German voice may omit its recording")
            # Dynamic cues get their text from FarmGame, not a stale manifest subtitle.
            subtitle = row.get("subtitle")
            require(subtitle is None or (isinstance(subtitle, str) and subtitle.strip()),
                    f"{where}: blank fallback subtitle")
            speech += 1
            continue
        path = row["path"]
        require(isinstance(path, str) and re.fullmatch(AUDIO, "Audio/" + path), f"{where}: invalid audio path")
        name = "Audio/" + path
        require(name in files, f"{where}: missing {name}")
        declared.add(name)

    media = {name for name in files if re.fullmatch(MODEL, name) or re.fullmatch(AUDIO, name)}
    require(not media - declared, "unlisted media in product (not opened)")
    return model_ids, sound_ids, speech


def archive_inventory(path):
    # Inspect all names/types before a USD or CRC reader can open any member.
    where = f"Models/{path.name}"
    require(path.stat().st_size <= 256 * 1024**2, f"{where}: archive too large")
    try:
        with zipfile.ZipFile(path) as archive:
            entries = archive.infolist()
            require(entries and len(entries) <= 4096 and sum(m.file_size for m in entries) <= 256 * 1024**2,
                    f"{where}: empty or oversized archive")
            seen = set()
            for entry in entries:
                name = entry.orig_filename
                require(re.fullmatch(r"(?:[A-Za-z0-9][A-Za-z0-9._-]*/)*[A-Za-z0-9][A-Za-z0-9._-]*"
                                     r"\.(?:usd[ac]?|png|jpe?g|exr)", name)
                        and stat.S_IFMT(entry.external_attr >> 16) in (0, stat.S_IFREG)
                        and not entry.flag_bits & 1 and entry.compress_type == zipfile.ZIP_STORED
                        and entry.file_size > 0 and name.casefold() not in seen,
                        f"{where}: forbidden USDZ member (not opened)")
                seen.add(name.casefold())
            require(entries[0].filename.endswith((".usd", ".usda", ".usdc")), f"{where}: no USD root layer")
    except zipfile.BadZipFile:
        raise BundleError(f"{where}: invalid USDZ archive") from None


def probe(command, error):
    # Native media tools can print file contents and arbitrary metadata on errors.
    result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    require(result.returncode == 0, error)


def check_references(refs, model_ids, sound_ids):
    for field, ids in (("models", model_ids), ("sfx", sound_ids)):
        for ref in refs[field]:
            require(re.fullmatch(ID, ref), f"Content: invalid {field} reference")
            require(ref in ids, f"Content: unresolved {field} reference {ref}")


def check(app):
    files = inventory(app)
    models, sounds, speech = asset_paths(app, files)
    archives = sorted(app / name for name in files if re.fullmatch(MODEL, name))
    for path in archives:
        archive_inventory(path)

    for name in sorted(files):
        if name.split("/", 1)[0] not in RESOURCE_DIRS:
            continue
        reference = ROOT / "App/Resources" / name
        require(reference.is_file() and not reference.is_symlink(), f"checkout missing resource: {name}")
        require(filecmp.cmp(reference, app / name, shallow=False), f"bundled {name} differs from checkout")
    try:
        privacy = plistlib.loads((app / "PrivacyInfo.xcprivacy").read_bytes())
    except (ValueError, ExpatError, plistlib.InvalidFileException):
        raise BundleError("PrivacyInfo.xcprivacy: invalid plist") from None
    require(isinstance(privacy, dict) and privacy.get("NSPrivacyTracking") is False
            and privacy.get("NSPrivacyTrackingDomains") == [] and privacy.get("NSPrivacyCollectedDataTypes") == [],
            "PrivacyInfo.xcprivacy: expected no tracking, tracking domains or collected data")
    probe([sys.executable, ROOT / "Tools/verify_bundle.py", app], "bundle metadata or resource/CRC check failed")

    with tempfile.TemporaryDirectory(prefix="MiniFarm-probe-") as work:
        checker = Path(work, "catalog-check")
        sources = sorted((ROOT / "App/Gameplay").glob("*.swift"))
        subprocess.run(["xcrun", "swiftc", "-swift-version", "6", *sources,
                        Path(__file__).with_name("CatalogReferences.swift"), "-o", checker], check=True)
        refs = subprocess.check_output([checker, app / "Content"])
        check_references(json.loads(refs), models, sounds)
        for path in archives:
            probe(["usdchecker", "--arkit", "--strict", path], f"Models/{path.name}: invalid USD for ARKit")
        audio = sorted(name for name in files if re.fullmatch(AUDIO, name))
        decoded = Path(work, "decoded.wav")
        for name in audio:
            probe(["afconvert", "-f", "WAVE", "-d", "LEI16", app / name, decoded], f"{name}: cannot decode audio")
            with wave.open(str(decoded)) as wav:
                require(wav.getnframes() > 0, f"{name}: no playable frames")
            decoded.unlink()
    print(f"MiniFarm.app OK: {len(CONTENT)} catalogs, {len(models)} USDZ, {len(audio)} audio files, "
          f"{speech} declared local speech fallbacks")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    try:
        check(parser.parse_args().app.absolute())
    except BundleError as error:
        sys.exit(f"FAIL: {error}")
    except FileNotFoundError as error:
        tool = error.filename if error.filename in ("xcrun", "usdchecker", "afconvert") else "required file"
        sys.exit(f"FAIL: {tool} not found")
    except (OSError, EOFError, ExpatError, plistlib.InvalidFileException, wave.Error, subprocess.CalledProcessError):
        sys.exit("FAIL: could not process bundle or run the catalog checker")
