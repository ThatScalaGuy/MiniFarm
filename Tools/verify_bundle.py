#!/usr/bin/env python3
"""Offline-Bestandsprobe für MiniFarm.app: Dateizählung und USDZ-ZIP-Prüfung, kein Hör- oder Rendertest."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path, PureWindowsPath
import plistlib
import re
import stat
import sys
import zipfile
import zlib
from xml.parsers.expat import ExpatError

BUNDLE_ID = "de.thatscalaguy.minifarm"
MEDIA = {"Content": set(), "Models": {".usdz", ".usd", ".usda", ".usdc", ".reality"},
         "Audio": {".m4a", ".caf", ".aac", ".wav", ".mp3", ".aiff", ".aif", ".aifc", ".flac"}}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def check_info(path):
    require(path.is_file() and not path.is_symlink(), "Info.plist fehlt oder ist verlinkt")
    info = plistlib.loads(path.read_bytes())
    require(isinstance(info, dict) and info.get("CFBundleIdentifier") == BUNDLE_ID,
            f"Info.plist: CFBundleIdentifier muss {BUNDLE_ID} sein")
    version = info.get("MinimumOSVersion")
    require(isinstance(version, str) and re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", version)
            and int(version.split(".")[0]) >= 18, "Info.plist: MinimumOSVersion muss ≥ 18 sein")
    family = info.get("UIDeviceFamily")
    require(isinstance(family, list) and all(type(x) is int for x in family) and {1, 2} <= set(family),
            "Info.plist: UIDeviceFamily muss iPhone (1) und iPad (2) enthalten")
    key = "UISupportedInterfaceOrientations"
    for device, extra in (("iphone", ()), ("ipad", ("PortraitUpsideDown",))):
        orientations = info.get(f"{key}~{device}", info.get(key))
        for mode in ("Portrait", "LandscapeLeft", "LandscapeRight") + extra:
            require(isinstance(orientations, list) and "UIInterfaceOrientation" + mode in orientations,
                    f"Info.plist: {device} fehlt Orientierung {mode}")
    for key, value in info.items():
        base = re.split("[-~]", key)[0]
        require(base != "NSUserTrackingUsageDescription", f"Info.plist: {key} vorhanden")
        if base == "NSAppTransportSecurity":
            require(isinstance(value, dict) and not value.get("NSExceptionDomains")
                    and not any(v for k, v in value.items() if k.startswith("NSAllows")),
                    f"Info.plist: ATS-Ausnahme oder ungültiges {key}")
    print(f"Info.plist: {BUNDLE_ID}, iOS {version}, iPhone/iPad, Hoch-/Querformate geprüft")


def check_usdz(path):
    require(path.stat().st_size <= 256 * 1024**2, "ZIP-Prüflimit überschritten (256 MiB)")
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        require(len(members) <= 4096 and sum(m.file_size for m in members) <= 256 * 1024**2,
                "ZIP-Prüflimit überschritten (4096 Einträge / 256 MiB entpackt)")
        seen, layer = set(), False
        for m in members:
            name = m.orig_filename.removesuffix("/")
            require(name not in seen and not PureWindowsPath(name).drive and "\\" not in name
                    and "\0" not in name and not {"", ".", ".."}.intersection(name.split("/"))
                    and stat.S_IFMT(m.external_attr >> 16) in (0, stat.S_IFREG, stat.S_IFDIR)
                    and not m.flag_bits & 1, f"unsicherer/doppelter ZIP-Eintrag: {name!r}")
            require(m.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), "nicht unterstützte ZIP-Kompression")
            seen.add(name)
            layer |= not m.is_dir() and m.file_size > 0 and Path(name).suffix.lower() in {".usd", ".usda", ".usdc"}
        require(layer, "keine nichtleere USD-Ebene im ZIP")
        bad = archive.testzip()  # Liest alle Member blockweise inkl. CRC, ohne zu extrahieren.
        require(bad is None, f"beschädigter ZIP-Eintrag: {bad!r}")


def check_catalog(path, content):
    data = json.loads(path.read_bytes())
    require(isinstance(data, (dict, list)), "erwarte JSON-Objekt oder -Liste")
    fields = data if isinstance(data, dict) else {"Einträge": data}
    version = fields.get("schemaVersion")
    if content or "schemaVersion" in fields:
        require(type(version) is int and version >= 1, "schemaVersion fehlt oder ist keine positive Ganzzahl")
    sets = ", ".join(f"{k}={len(v)}" for k, v in sorted(fields.items()) if isinstance(v, list))
    print(f"Katalog {path}: schemaVersion={version if version is not None else '–'}" + (f", {sets}" if sets else ""))


def check_resources(folder):
    require(folder.is_dir() and not folder.is_symlink(), f"{folder}/ fehlt oder ist verlinkt")
    counts = Counter()
    for path in sorted(folder.rglob("*")):
        if any(part.startswith(".") for part in path.parts):
            continue
        require(not path.is_symlink(), f"{path}: verlinkte Ressource")
        ext = path.suffix.lower()
        if not path.is_file() or (ext != ".json" and ext not in MEDIA[folder.name]):
            continue
        try:
            require(path.stat().st_size, "leere Datei")
            if ext == ".json":
                check_catalog(path, folder.name == "Content")
            elif ext == ".usdz":
                check_usdz(path)
        except (ValueError, OSError, zipfile.BadZipFile, EOFError, RuntimeError, zlib.error) as exc:
            raise ValueError(f"{path}: {exc}") from exc
        counts[ext] += 1
    catalogs = counts.pop(".json", 0)
    formats = ", ".join(f"{k}={n}" for k, n in sorted(counts.items()))
    media = f"; Mediendateien={sum(counts.values())}" if folder.name != "Content" else ""
    print(f"{folder}/: JSON-Kataloge={catalogs}{media}" + (f" ({formats})" if formats else ""))
    require(catalogs or counts, f"{folder}/: keine Katalog- oder Mediendateien")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", metavar="MiniFarm.app")
    try:
        os.chdir(parser.parse_args().app)
        check_info(Path("Info.plist"))
        for directory in MEDIA:
            check_resources(Path(directory))
    except (ValueError, OSError, plistlib.InvalidFileException, ExpatError) as error:
        sys.exit(f"FEHLER: {error or 'Info.plist nicht lesbar'}")
