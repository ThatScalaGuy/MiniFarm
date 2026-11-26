#!/usr/bin/env python3
"""Render the pinned German CC0 voice catalog locally and validate its assets."""

import argparse
import hashlib
import importlib.metadata
import json
import os
import shutil
import struct
import subprocess
import tempfile
import urllib.request
import wave
from pathlib import Path, PureWindowsPath


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_AUDIO_DIR = ROOT / "App" / "Resources" / "Audio"
DEFAULT_CATALOG = Path(__file__).with_name("voice-catalog.json")
DEFAULT_PROVENANCE = Path(__file__).with_name("piper-provenance.json")
MODEL_REPOSITORY = "Thorsten-Voice/Piper-Thorsten-CC0"
MODEL_REVISION = "9beb8542b91ec176ad58adbf9f6085f96b6caa17"
MODEL_PATH = "onnx/de_DE-thorsten_cc0-medium.onnx"
CONFIG_PATH = "onnx/de_DE-thorsten_cc0-medium.onnx.json"
MODEL_SHA256 = "3fb6d89734bba7b995e398955722a1aae8ccd237bf64ed67f5256f79300fb62f"
CONFIG_SHA256 = "d5909431612ff35daa899ed89c26fffa0de037a64559a9e4aecd80c7fddb9c41"
MODEL_LICENSE = "CC0-1.0"
LICENSE_SOURCE = (
    "https://huggingface.co/Thorsten-Voice/Piper-Thorsten-CC0/raw/"
    f"{MODEL_REVISION}/README.md"
)
PIPER_VERSION = "1.8.0"
ONNXRUNTIME_VERSION = "1.32.0"
PROFILE_ID = "deterministic-soft-v1"
SAMPLE_RATE = 22050
RENDER_VOLUME = 0.32
PEAK_SAFETY_MARGIN = 1.10
MAX_VOICE_PEAK = 0.40


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_audio_path(relative_path, audio_dir, must_exist=True):
    if not isinstance(relative_path, str) or not relative_path:
        raise ValueError("Audio path must be a non-empty relative path")
    windows_path = PureWindowsPath(relative_path)
    if Path(relative_path).is_absolute() or windows_path.is_absolute() or windows_path.drive:
        raise ValueError(f"Audio path must be relative: {relative_path}")
    parts = relative_path.replace("\\", "/").split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise ValueError(f"Invalid audio path: {relative_path}")

    root = Path(audio_dir).resolve(strict=True)
    target = root.joinpath(*parts).resolve(strict=must_exist)
    try:
        target.relative_to(root)
    except ValueError as error:
        raise ValueError(f"Audio path escapes the Audio folder: {relative_path}") from error
    return target


def download_verified(url, target, expected_hash):
    target = Path(target)
    if target.exists():
        actual = sha256_file(target)
        if actual != expected_hash:
            raise ValueError(f"Unexpected SHA-256 for cached file {target}: {actual}")
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".piper-", delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "MiniFarm-offline-audio/1"})
        with urllib.request.urlopen(request, timeout=90) as response, temporary_path.open("wb") as output:
            shutil.copyfileobj(response, output)
        actual = sha256_file(temporary_path)
        if actual != expected_hash:
            raise ValueError(f"Unexpected SHA-256 from {url}: {actual}")
        temporary_path.replace(target)
        return target
    finally:
        temporary_path.unlink(missing_ok=True)


def model_files(model_dir):
    directory = Path(model_dir).expanduser()
    base_url = f"https://huggingface.co/{MODEL_REPOSITORY}/resolve/{MODEL_REVISION}"
    model = download_verified(f"{base_url}/{MODEL_PATH}", directory / Path(MODEL_PATH).name, MODEL_SHA256)
    config = download_verified(f"{base_url}/{CONFIG_PATH}", directory / Path(CONFIG_PATH).name, CONFIG_SHA256)
    return model, config


def model_cache_dir():
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return cache / "minifarm" / "piper" / MODEL_REVISION


def load_catalog(path):
    catalog = json.loads(Path(path).read_text(encoding="utf-8"))
    if catalog.get("schemaVersion") != 1 or catalog.get("locale") != "de-DE":
        raise ValueError("Unsupported German voice catalog")
    entries = catalog.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("Voice catalog is empty")
    seen = set()
    for entry in entries:
        voice_id, text = entry.get("id"), entry.get("text")
        if not isinstance(voice_id, str) or not voice_id.startswith("vl."):
            raise ValueError(f"Invalid voice ID: {voice_id!r}")
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f"Empty transcript for {voice_id}")
        key = (voice_id, text)
        if key in seen:
            raise ValueError(f"Duplicate transcript for {voice_id}")
        seen.add(key)
    return catalog


def probe_audio(path):
    result = subprocess.run(
        [
            "ffprobe", "-v", "error", "-show_entries",
            "stream=codec_name,sample_rate,channels:format=duration", "-of", "json", str(path),
        ],
        check=True, stdout=subprocess.PIPE, text=True,
    )
    document = json.loads(result.stdout)
    if len(document.get("streams", [])) != 1:
        raise ValueError(f"Expected one audio stream in {path}")
    stream = document["streams"][0]
    duration = float(document["format"]["duration"])
    if (stream.get("codec_name") != "mp3" or stream.get("sample_rate") != str(SAMPLE_RATE)
            or stream.get("channels") != 1 or not 0.1 < duration < 20.0):
        raise ValueError(f"Invalid voice media format or duration: {path}")
    return duration


def decoded_peak(path):
    result = subprocess.run(
        [
            "ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-f", "s16le",
            "-acodec", "pcm_s16le", "-ac", "1", "-ar", str(SAMPLE_RATE), "pipe:1",
        ],
        check=True, stdout=subprocess.PIPE,
    )
    if not result.stdout or len(result.stdout) % 2:
        raise ValueError(f"Could not decode audio samples: {path}")
    sample_peak = max(abs(sample[0]) for sample in struct.iter_unpack("<h", result.stdout)) / 32768
    if sample_peak == 0:
        raise ValueError(f"Silent voice asset: {path}")
    return min(1.0, sample_peak * PEAK_SAFETY_MARGIN)


def synthesize_wav(voice, text, target):
    from piper.config import SynthesisConfig

    config = SynthesisConfig(
        length_scale=1.0, noise_scale=0.0, noise_w_scale=0.0,
        normalize_audio=True, volume=RENDER_VOLUME,
    )
    with wave.open(str(target), "wb") as output:
        voice.synthesize_wav(text, output, syn_config=config)
    with wave.open(str(target), "rb") as audio:
        if audio.getframerate() != SAMPLE_RATE or audio.getnchannels() != 1 or audio.getsampwidth() != 2:
            raise ValueError(f"Piper returned an unexpected WAV format for: {text}")
        frames = audio.readframes(audio.getnframes())
        if not frames:
            raise ValueError(f"Piper returned empty audio for: {text}")


def encode_mp3(source_wav, target_mp3):
    subprocess.run(
        [
            "ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(source_wav),
            "-vn", "-ac", "1", "-ar", str(SAMPLE_RATE),
            "-codec:a", "libmp3lame", "-b:a", "48k", "-compression_level", "2",
            str(target_mp3),
        ],
        check=True,
    )


def asset_path(voice_id, text):
    identity = "\0".join((PROFILE_ID, MODEL_REVISION, voice_id, text)).encode("utf-8")
    digest = hashlib.sha256(identity).hexdigest()[:24]
    return f"voice/{digest}.mp3"


def voice_license_fields():
    return {
        "license": MODEL_LICENSE,
        "modelRevision": MODEL_REVISION,
        "licenseSource": LICENSE_SOURCE,
    }


def manifest_rows(catalog, rendered):
    grouped = {}
    for entry, metadata in zip(catalog["entries"], rendered):
        grouped.setdefault(entry["id"], []).append((entry, metadata))

    rows = []
    for voice_id in sorted(grouped):
        variants = grouped[voice_id]
        if len(variants) == 1:
            entry, metadata = variants[0]
            rows.append({
                "id": voice_id, "kind": "voice", "path": metadata["path"],
                "subtitle": entry["text"], "locale": "de-DE",
                "peak": metadata["peak"], **voice_license_fields(),
            })
        else:
            rows.append({
                "id": voice_id, "kind": "voice", "path": None, "locale": "de-DE",
                "variants": [
                    {
                        "text": entry["text"], "path": metadata["path"],
                        "peak": metadata["peak"], **voice_license_fields(),
                    }
                    for entry, metadata in variants
                ],
            })
    return rows


def validate_voice_rows(assets, audio_dir):
    ids = [asset.get("id") for asset in assets]
    if len(ids) != len(set(ids)):
        raise ValueError("Manifest contains duplicate IDs")
    for asset in assets:
        path = asset.get("path")
        if asset.get("kind") != "voice":
            if isinstance(path, str) and path.startswith("voice/"):
                raise ValueError(f"Non-voice asset is stored under voice/: {asset.get('id')}")
            continue
        if not isinstance(asset.get("id"), str) or not asset["id"].startswith("vl."):
            raise ValueError(f"Invalid voice manifest ID: {asset.get('id')!r}")
        if asset.get("locale") != "de-DE":
            raise ValueError(f"Voice asset has the wrong locale: {asset['id']}")

        variants = asset.get("variants")
        if variants is not None:
            if path not in (None, "") or not isinstance(variants, list) or not variants:
                raise ValueError(f"Invalid variants row: {asset['id']}")
            texts = set()
            for variant in variants:
                text = variant.get("text")
                if not isinstance(text, str) or not text.strip() or text in texts:
                    raise ValueError(f"Invalid or duplicate variant text: {asset['id']}")
                texts.add(text)
                validate_recording(asset["id"], variant, audio_dir)
        elif path:
            if not isinstance(asset.get("subtitle"), str) or not asset["subtitle"].strip():
                raise ValueError(f"Recorded voice has no subtitle: {asset['id']}")
            validate_recording(asset["id"], asset, audio_dir)
        elif asset.get("subtitle") not in (None, ""):
            raise ValueError(f"Pathless voice cannot declare a transcript: {asset['id']}")


def validate_recording(voice_id, recording, audio_dir):
    if (recording.get("license") != MODEL_LICENSE
            or recording.get("modelRevision") != MODEL_REVISION
            or recording.get("licenseSource") != LICENSE_SOURCE):
        raise ValueError(f"Missing pinned license provenance for {voice_id}")
    path = recording.get("path")
    if not isinstance(path, str) or not path.startswith("voice/") or not path.endswith(".mp3"):
        raise ValueError(f"Recorded voice must be an MP3 under voice/: {voice_id}")
    media = resolve_audio_path(path, audio_dir)
    if not media.is_file() or media.stat().st_size == 0:
        raise ValueError(f"Missing voice media for {voice_id}: {path}")
    peak = recording.get("peak")
    if not isinstance(peak, (int, float)) or not 0 < peak <= MAX_VOICE_PEAK:
        raise ValueError(f"Invalid recorded peak for {voice_id}: {peak}")


def load_existing_manifest(audio_dir):
    path = Path(audio_dir) / "manifest.json"
    if not path.exists():
        return {"schemaVersion": 1, "assets": []}
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schemaVersion") != 1 or not isinstance(manifest.get("assets"), list):
        raise ValueError(f"Invalid audio manifest: {path}")
    return manifest


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    content = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}-", delete=False,
    ) as temporary:
        temporary.write(content)
        temporary_path = Path(temporary.name)
    temporary_path.replace(path)


def render(catalog_path, audio_dir, provenance_path, model_dir):
    from piper import PiperVoice

    if importlib.metadata.version("piper-tts") != PIPER_VERSION:
        raise ValueError(f"Expected piper-tts {PIPER_VERSION}")
    if importlib.metadata.version("onnxruntime") != ONNXRUNTIME_VERSION:
        raise ValueError(f"Expected onnxruntime {ONNXRUNTIME_VERSION}")
    catalog = load_catalog(catalog_path)
    audio_dir = Path(audio_dir)
    audio_dir.mkdir(parents=True, exist_ok=True)
    model, config = model_files(model_dir)
    voice = PiperVoice.load(model, config, use_cuda=False)
    rendered = []

    with tempfile.TemporaryDirectory(prefix="MiniFarm-Piper-") as work:
        work = Path(work)
        for index, entry in enumerate(catalog["entries"], start=1):
            relative = asset_path(entry["id"], entry["text"])
            destination = resolve_audio_path(relative, audio_dir, must_exist=False)
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                wav_path = work / f"{index:04d}.wav"
                mp3_path = work / f"{index:04d}.mp3"
                synthesize_wav(voice, entry["text"], wav_path)
                encode_mp3(wav_path, mp3_path)
                temporary = work / f"{index:04d}.verified.mp3"
                shutil.copyfile(mp3_path, temporary)
                temporary.replace(destination)

            duration = probe_audio(destination)
            peak = decoded_peak(destination)
            if peak > MAX_VOICE_PEAK:
                raise ValueError(f"Voice peak exceeds {MAX_VOICE_PEAK:.2f}: {relative} ({peak:.3f})")
            rendered.append({
                "id": entry["id"], "textSha256": hashlib.sha256(entry["text"].encode("utf-8")).hexdigest(),
                "path": relative, "sha256": sha256_file(destination),
                "bytes": destination.stat().st_size, "durationSeconds": round(duration, 4),
                "peak": round(peak, 6),
            })
            if index % 50 == 0 or index == len(catalog["entries"]):
                print(f"Rendered or verified {index}/{len(catalog['entries'])} voice clips")

    new_voice_rows = manifest_rows(catalog, rendered)
    manifest = load_existing_manifest(audio_dir)
    replaced_ids = {row["id"] for row in new_voice_rows}
    retained = [
        asset for asset in manifest["assets"]
        if asset.get("kind") != "voice" or asset.get("id") not in replaced_ids
    ]
    manifest["assets"] = [asset for asset in retained if asset.get("kind") != "voice"] \
        + [asset for asset in retained if asset.get("kind") == "voice"] + new_voice_rows
    validate_voice_rows(manifest["assets"], audio_dir)
    write_json(audio_dir / "manifest.json", manifest)

    ffmpeg_version = subprocess.run(
        ["ffmpeg", "-version"], check=True, stdout=subprocess.PIPE, text=True,
    ).stdout.splitlines()[0]
    try:
        catalog_path_record = str(Path(catalog_path).resolve().relative_to(ROOT))
    except ValueError:
        catalog_path_record = Path(catalog_path).name
    provenance = {
        "schemaVersion": 1,
        "model": {
            "repository": MODEL_REPOSITORY, "revision": MODEL_REVISION,
            "license": MODEL_LICENSE, "licenseSource": LICENSE_SOURCE,
            "onnxSha256": sha256_file(model), "configSha256": sha256_file(config),
        },
        "generator": {
            "piperTTS": PIPER_VERSION, "onnxruntime": ONNXRUNTIME_VERSION,
            "python": os.sys.version.split()[0], "ffmpeg": ffmpeg_version,
            "profile": PROFILE_ID, "sampleRate": SAMPLE_RATE, "channels": 1,
            "bitrate": "48k", "lengthScale": 1.0, "noiseScale": 0.0,
            "noiseWScale": 0.0, "normalizedVolume": RENDER_VOLUME,
            "peakSafetyMargin": PEAK_SAFETY_MARGIN,
        },
        "catalog": {
            "path": catalog_path_record,
            "sha256": sha256_file(catalog_path),
            "sourceRevision": catalog["sourceRevision"],
            "entryCount": len(catalog["entries"]),
        },
        "files": rendered,
    }
    write_json(provenance_path, provenance)
    total_bytes = sum(item["bytes"] for item in rendered)
    print(f"Validated {len(rendered)} offline German voice clips ({total_bytes:,} bytes)")


def verify(catalog_path, audio_dir, provenance_path):
    catalog = load_catalog(catalog_path)
    manifest = load_existing_manifest(audio_dir)
    validate_voice_rows(manifest["assets"], audio_dir)
    provenance = json.loads(Path(provenance_path).read_text(encoding="utf-8"))
    files = {item["path"]: item for item in provenance.get("files", [])}
    expected = {}
    for entry in catalog["entries"]:
        expected.setdefault(entry["id"], {})[entry["text"]] = asset_path(entry["id"], entry["text"])
    actual = {}
    for asset in manifest["assets"]:
        recordings = asset.get("variants", []) if asset.get("kind") == "voice" else []
        if asset.get("kind") == "voice" and asset.get("path"):
            recordings = [asset]
        for recording in recordings:
            report = files.get(recording["path"])
            if report is None or sha256_file(resolve_audio_path(recording["path"], audio_dir)) != report["sha256"]:
                raise ValueError(f"Missing or changed provenance entry: {recording['path']}")
            if report["peak"] > MAX_VOICE_PEAK:
                raise ValueError(f"Voice peak exceeds limit: {recording['path']}")
            text = recording.get("text", asset.get("subtitle"))
            actual.setdefault(asset["id"], {})[text] = recording["path"]
    if expected != actual:
        raise ValueError("Manifest IDs, exact transcripts, and paths do not match the voice catalog")
    print(f"Verified {sum(map(len, expected.values()))} voice clips against the catalog and pinned provenance")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--audio-dir", type=Path, default=DEFAULT_AUDIO_DIR)
    parser.add_argument("--provenance", type=Path, default=DEFAULT_PROVENANCE)
    parser.add_argument("--model-dir", type=Path, default=model_cache_dir())
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only:
        verify(args.catalog, args.audio_dir, args.provenance)
    else:
        render(args.catalog, args.audio_dir, args.provenance, args.model_dir)


if __name__ == "__main__":
    main()
