#!/usr/bin/env python3
"""Generate one raw ElevenLabs audio asset; offline unless billing is confirmed."""

import argparse
import json
import os
from pathlib import Path
import re
import sys
import unicodedata
import urllib.error
import urllib.request
import uuid


BASE = "https://api.elevenlabs.io"
AUDIO_ROOT = Path(__file__).resolve().parents[2] / "App" / "Resources" / "Audio"
OUTPUT_FORMAT = "mp3_44100_128"
MODELS = {
    "voice": "eleven_multilingual_v2",
    "sfx": "eleven_text_to_sound_v3",
    "music": "music_v2_5",
}
ID_PREFIXES = {"voice": "vl", "sfx": "sfx", "music": "music"}
ID_RE = re.compile(r"[a-z0-9]+(?:[._-][a-z0-9]+)*\Z")
VOICE_RE = re.compile(r"[A-Za-z0-9_-]{1,128}\Z")


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse's message can include arbitrary user-supplied values.
        self.print_usage(sys.stderr)
        self.exit(2, "error: invalid or missing arguments; see --help\n")


def parser():
    p = SafeParser(
        description="Generate one raw MP3 from text. OFFLINE by default; "
                    "--confirm-billing makes a credit-consuming API request."
    )
    p.add_argument("kind", choices=("voice", "sfx", "music"))
    p.add_argument("--id", required=True, help="Stable dotted asset ID: vl.*, sfx.*, or music.*")
    p.add_argument("--text", required=True, help="Plain text to speak or prompt (not a file)")
    p.add_argument("--output", required=True, type=Path, help="New .mp3 output path")
    p.add_argument("--voice-id", help="ElevenLabs voice ID (required for voice only)")
    p.add_argument("--duration-seconds", type=float, help="SFX duration in seconds (0.5–30)")
    p.add_argument("--music-length-ms", type=int, help="Music duration in milliseconds (3000–600000)")
    p.add_argument("--register", action="store_true", help="Register generated file in the runtime audio manifest")
    p.add_argument("--loop", action="store_true", help="Set manifest loop for registered SFX or music")
    p.add_argument("--confirm-billing", action="store_true", help="Actually call ElevenLabs; consumes credits")
    p.add_argument("--dry-run", action="store_true", help="Stay offline even with --confirm-billing")
    return p


def validate(args):
    if not ID_RE.fullmatch(args.id) or not args.id.startswith(ID_PREFIXES[args.kind] + "."):
        raise ValueError("invalid asset ID for kind")
    if not args.text.strip() or any(
        unicodedata.category(c) == "Cc" and c not in "\n\t" for c in args.text
    ):
        raise ValueError("text must be nonempty plain text without control characters")
    if len(args.text) > 5000:
        raise ValueError("text exceeds 5000 characters")
    if args.kind == "voice":
        if not args.voice_id or not VOICE_RE.fullmatch(args.voice_id):
            raise ValueError("voice requires a valid voice ID")
    elif args.voice_id is not None:
        raise ValueError("voice ID is only valid for voice")
    if args.duration_seconds is not None:
        if args.kind != "sfx" or not 0.5 <= args.duration_seconds <= 30:
            raise ValueError("duration-seconds is only valid for SFX and must be 0.5–30")
    if args.music_length_ms is not None:
        if args.kind != "music" or not 3000 <= args.music_length_ms <= 600000:
            raise ValueError("music-length-ms is only valid for music and must be 3000–600000")
    if args.output.suffix.lower() != ".mp3":
        raise ValueError("output must have an .mp3 extension")
    if args.loop and (not args.register or args.kind == "voice"):
        raise ValueError("loop requires registration of SFX or music")


def registration_details(args):
    root = AUDIO_ROOT.absolute()
    if root.resolve() != root or not root.is_dir():
        raise ValueError("audio directory must exist and must not be a symlink")
    if ".." in args.output.parts:
        raise ValueError("registered output must not contain parent traversal")
    output = Path(os.path.abspath(args.output))
    try:
        relative = output.relative_to(root)
    except ValueError:
        raise ValueError("registered output must be inside the audio directory") from None
    current = root
    for component in relative.parts:
        current = current / component
        if current.is_symlink():
            raise ValueError("registered output must not traverse symlinks")
    if not output.parent.is_dir():
        raise ValueError("output parent directory must exist")
    manifest_path = root / "manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError("audio manifest must be an existing regular file")
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (UnicodeError, json.JSONDecodeError):
        raise ValueError("audio manifest is invalid") from None
    if not isinstance(data, dict) or type(data.get("schemaVersion")) is not int \
            or data["schemaVersion"] != 1 or not isinstance(data.get("assets"), list):
        raise ValueError("audio manifest has an unsupported schema")
    assets = data["assets"]
    if any(not isinstance(asset, dict) or not isinstance(asset.get("id"), str)
           or not isinstance(asset.get("kind"), str)
           or any(asset.get(field) is not None and not isinstance(asset[field], str)
                  for field in ("path", "locale", "subtitle"))
           or (asset.get("loop") is not None and type(asset["loop"]) is not bool)
           for asset in assets):
        raise ValueError("audio manifest contains invalid assets")
    matches = [index for index, asset in enumerate(assets) if asset["id"] == args.id]
    if len(matches) > 1 or (matches and assets[matches[0]]["kind"] != args.kind):
        raise ValueError("audio manifest has a duplicate ID or a conflicting kind")
    path = relative.as_posix()
    if any(asset["id"] != args.id and asset.get("path") == path for asset in assets):
        raise ValueError("audio manifest path is already used by another asset")
    entry = {"id": args.id, "kind": args.kind, "path": path}
    if args.kind == "voice":
        entry.update(locale="de-DE", subtitle=args.text)
    else:
        entry["loop"] = args.loop
    if matches:
        assets[matches[0]] = entry
    else:
        assets.append(entry)
    return manifest_path, data


def register(args):
    manifest_path, data = registration_details(args)
    # Create the staging file alongside the manifest, not in a system temp directory.
    staging = manifest_path.with_name(".manifest." + uuid.uuid4().hex + ".tmp")
    created = False
    try:
        with staging.open("x", encoding="utf-8") as f:
            created = True
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        os.replace(staging, manifest_path)
    finally:
        if created:
            staging.unlink(missing_ok=True)


def request_details(args):
    body = {"model_id": MODELS[args.kind]}
    if args.kind == "voice":
        endpoint = "/v1/text-to-speech/" + args.voice_id
        body["text"] = args.text
    elif args.kind == "sfx":
        endpoint = "/v1/sound-generation"
        body["text"] = args.text
        if args.duration_seconds is not None:
            body["duration_seconds"] = args.duration_seconds
    else:
        endpoint = "/v1/music"
        body["prompt"] = args.text
        body["force_instrumental"] = True
        if args.music_length_ms is not None:
            body["music_length_ms"] = args.music_length_ms
    return BASE + endpoint + "?output_format=" + OUTPUT_FORMAT, body


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def api_key():
    return os.environ.get("ELEVENLABS_API_KEY")


def generate(url, body, key):
    request = urllib.request.Request(
        url, data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
        method="POST",
    )
    # Do not let proxy environment variables or redirects send the key elsewhere.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    with opener.open(request, timeout=180) as response:
        if response.headers.get_content_type() != "audio/mpeg":
            raise ValueError("API returned a non-MP3 response")
        audio = response.read()
        if not audio:
            raise ValueError("API returned empty audio")
        return audio


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        validate(args)
        if args.register:
            registration_details(args)
        url, body = request_details(args)
        if args.dry_run or not args.confirm_billing:
            print("Offline dry run: no request, credentials read, or files written. "
                  "Use --confirm-billing to consume credits.")
            return 0

        key = api_key()
        if not key:
            raise ValueError("ELEVENLABS_API_KEY is required for generation")
        metadata = {
            "asset_id": args.id,
            "kind": args.kind,
            "request": {"method": "POST", "url": url, "body": body},
        }
        serialized = json.dumps(metadata, ensure_ascii=False, indent=2) + "\n"
        if key in serialized or key in str(args.output):
            raise ValueError("credentials must not appear in request data or output path")
        sidecar = Path(str(args.output) + ".json")
        if args.output.exists() or sidecar.exists():
            raise ValueError("output or sidecar already exists; choose a new path")
        if not args.output.parent.is_dir():
            raise ValueError("output parent directory must exist")
        audio = generate(url, body, key)
        # Exclusive writes protect existing files, including in races.
        created_audio = False
        created_sidecar = False
        try:
            with args.output.open("xb") as f:
                created_audio = True
                f.write(audio)
            with sidecar.open("x", encoding="utf-8") as f:
                created_sidecar = True
                f.write(serialized)
        except OSError:
            if created_sidecar:
                sidecar.unlink(missing_ok=True)
            if created_audio:
                args.output.unlink(missing_ok=True)
            raise
        if args.register:
            try:
                register(args)
            except (OSError, ValueError):
                print("Generated audio and sidecar, but manifest registration failed; "
                      "files were retained.", file=sys.stderr)
                return 1
        print("Generated audio and request metadata sidecar" +
              (" and registered the manifest entry." if args.register else "."))
        return 0
    except urllib.error.HTTPError as e:
        print(f"Generation failed: HTTP {e.code}; no response body logged.", file=sys.stderr)
    except (urllib.error.URLError, OSError):
        print("Generation failed: network or filesystem error; details suppressed.", file=sys.stderr)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
