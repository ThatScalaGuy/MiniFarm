#!/usr/bin/env python3
"""Check MiniFarm's unsigned Release product. No extraction, playback or network."""

import argparse
import filecmp
import hashlib
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
MODEL = rf"Models/(?:model|anim)\.{ID}\.usdz"
AUDIO = r"Audio/(?:[a-z0-9][a-z0-9_.-]*/)*[a-z0-9][a-z0-9_.-]*\.(?:wav|m4a|caf|mp3|aiff|aac)"
VOICE = r"voice/[0-9a-f]{24}\.mp3"
LICENSES = {"CC0-1.0"}
PROVENANCE = ROOT / "Tools/Audio/piper-provenance.json"


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


def recording(item, where, files, recordings, cue, text):
    # Speech files are pinned to an allowed licence and the exact voice-model revision.
    path, revision, source = item.get("path"), item.get("modelRevision"), item.get("licenseSource")
    require(isinstance(path, str) and re.fullmatch(VOICE, path), f"{where}: voice recording must be voice/<24 hex>.mp3")
    require(item.get("license") in LICENSES and isinstance(revision, str) and re.fullmatch(r"[0-9a-f]{40}", revision)
            and isinstance(source, str) and source.startswith("https://") and revision in source,
            f"{where}: voice recording needs an allowed license, pinned licenseSource and modelRevision")
    require("Audio/" + path in files, f"{where}: missing Audio/{path}")
    require(path not in recordings, f"{where}: voice recording is used for more than one text")
    recordings[path] = {"id": cue, "text": text, "license": item["license"], "revision": revision,
                        "source": source, "where": where}
    return "Audio/" + path


def check_provenance(app, recordings, provenance=PROVENANCE):
    """Every bundled voice file must be the exact Piper render of its manifest text."""
    if not recordings:
        return 0
    name = "Tools/Audio/piper-provenance.json"
    try:
        record = json.loads(provenance.read_bytes())
    except FileNotFoundError:
        raise BundleError(f"{name}: missing for bundled voice recordings") from None
    except (ValueError, RecursionError):
        raise BundleError(f"{name}: invalid JSON") from None
    model = record.get("model") if isinstance(record, dict) else None
    files = record.get("files") if isinstance(record, dict) else None
    require(isinstance(model, dict) and record.get("schemaVersion") == 1 and isinstance(files, list)
            and model.get("license") in LICENSES and isinstance(model.get("repository"), str)
            and isinstance(model.get("revision"), str) and re.fullmatch(r"[0-9a-f]{40}", model["revision"]),
            f"{name}: expected schemaVersion 1, an allowed model license, repository and pinned revision")
    rendered = {}
    for index, entry in enumerate(files):
        require(isinstance(entry, dict) and isinstance(entry.get("path"), str)
                and entry["path"] not in rendered, f"{name}: files[{index}] has no unique path")
        rendered[entry["path"]] = entry
    missing, stale = len(recordings.keys() - rendered.keys()), len(rendered.keys() - recordings.keys())
    require(not missing and not stale,
            f"{name}: {missing} bundled recordings without provenance, {stale} provenance files not bundled")
    for path, clip in recordings.items():
        entry, where = rendered[path], clip["where"]
        require(clip["license"] == model["license"] and clip["revision"] == model["revision"]
                and f"/{model['repository']}/" in clip["source"],
                f"{where}: license, licenseSource or modelRevision differs from the rendered voice model")
        require(entry.get("id") == clip["id"]
                and entry.get("textSha256") == hashlib.sha256(clip["text"].encode()).hexdigest(),
                f"{where}: Audio/{path} was rendered for a different cue or text")
        data = (app / "Audio" / path).read_bytes()
        require(entry.get("bytes") == len(data) and entry.get("sha256") == hashlib.sha256(data).hexdigest(),
                f"{where}: Audio/{path} differs from its recorded render")
    return len(recordings)


def asset_paths(app, files):
    model_ids, sound_ids, declared, speech, variants, recordings = set(), set(), set(), 0, [], {}
    for row, where in manifest_rows(app, "Models"):
        # Animation variants keep their full "anim." ID; they are never catalog model references.
        variant = row["id"].startswith("anim.")
        asset_id = row["id"] if variant else "model." + row["id"]
        filename = asset_id + ".usdz"
        require(row.get("file") == filename,
                f"{where}: file does not match runtime basename for {asset_id}")
        name = "Models/" + filename
        require(name in files, f"{where}: missing {name}")
        require(type(row.get("bytes")) is int and row["bytes"] == (app / name).stat().st_size,
                f"{name}: size differs from manifest")
        if variant:
            base, motion = asset_id[len("anim."):].rsplit(".", 1)
            require(row.get("kind") == "animationVariant" and row.get("variantOf") == base
                    and row.get("motion") == motion,
                    f"{where}: animation variant must declare kind, variantOf {base} and motion {motion}")
            variants.append(("model." + base, where))
        else:
            require(row.get("kind", "model") == "model" and row.get("variantOf") is None
                    and row.get("motion") is None, f"{where}: model row declares variant fields")
            model_ids.add(asset_id)
        declared.add(name)
    for base, where in variants:
        require(base in model_ids, f"{where}: animation variant has no base model {base}")

    for row, where in manifest_rows(app, "Audio"):
        kind = row.get("kind")
        require(kind in ("sfx", "voice", "music", "ambient"), f"{where}: unknown audio kind")
        if kind == "sfx":
            sound_ids.add(row["id"])
        voice = kind == "voice"
        require(not voice or (row["id"].startswith("vl.") and row.get("locale") == "de-DE"),
                f"{where}: voice must be a German vl.* cue")
        if "variants" in row:
            items = row["variants"]
            require(voice and row.get("path") is None and isinstance(items, list) and items,
                    f"{where}: variants need a voice row without path")
            texts = set()
            for index, item in enumerate(items):
                at = f"{where}.variants[{index}]"
                require(isinstance(item, dict) and isinstance(item.get("text"), str) and item["text"].strip()
                        and item["text"] not in texts, f"{at}: missing or duplicate text")
                texts.add(item["text"])
                declared.add(recording(item, at, files, recordings, row["id"], item["text"]))
            continue
        if row.get("path") is None:
            require(voice, f"{where}: only a declared German voice may omit its recording")
            # Dynamic cues get their text from FarmGame, not a stale manifest subtitle.
            subtitle = row.get("subtitle")
            require(subtitle is None or (isinstance(subtitle, str) and subtitle.strip()),
                    f"{where}: blank fallback subtitle")
            speech += 1
            continue
        if voice:
            require(isinstance(row.get("subtitle"), str) and row["subtitle"].strip(),
                    f"{where}: recorded voice needs its exact subtitle")
            declared.add(recording(row, where, files, recordings, row["id"], row["subtitle"]))
            continue
        path = row["path"]
        require(isinstance(path, str) and re.fullmatch(AUDIO, "Audio/" + path) and not path.startswith("voice/"),
                f"{where}: invalid audio path")
        name = "Audio/" + path
        require(name in files, f"{where}: missing {name}")
        declared.add(name)

    media = {name for name in files if re.fullmatch(MODEL, name) or re.fullmatch(AUDIO, name)}
    require(not media - declared, "unlisted media in product (not opened)")
    return model_ids, sound_ids, speech, len(variants), recordings


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
    models, sounds, speech, variants, recordings = asset_paths(app, files)
    voices = check_provenance(app, recordings)
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
    print(f"MiniFarm.app OK: {len(CONTENT)} catalogs, {len(models)} USDZ models, "
          f"{variants} USDZ animation variants, {len(audio)} audio files "
          f"({voices} CC0 voice recordings matching their Piper provenance), "
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
