#!/usr/bin/env python3
"""Build a transcript catalog from the pinned playable game content."""

import argparse
import io
import json
import subprocess
import tarfile
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = Path(__file__).with_name("voice-catalog.json")
GAMEPLAY_REVISION = "13adab768d5b4857d8cdee48d6ec0bb2068a8754"
CONTENT_FILES = (
    "activities", "adaptive", "animals", "crops", "decorations", "economy",
    "hofbook", "items", "locations", "machines", "recipes", "seasons",
)


def source_tree(temp_root):
    gameplay = ROOT / "App" / "Gameplay"
    content = ROOT / "App" / "Resources" / "Content"
    if gameplay.is_dir() and content.is_dir():
        return ROOT, content, "working-tree"

    archive = subprocess.run(
        ["git", "archive", "--format=tar", GAMEPLAY_REVISION, "App/Gameplay", "App/Resources/Content"],
        cwd=ROOT, check=True, stdout=subprocess.PIPE,
    ).stdout
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as source:
        source.extractall(temp_root, filter="data")
    return temp_root, temp_root / "App" / "Resources" / "Content", GAMEPLAY_REVISION


def load_rows(content, name):
    document = json.loads((content / f"{name}.json").read_text(encoding="utf-8"))
    if document.get("schemaVersion") != 1:
        raise ValueError(f"Unsupported {name}.json schema")
    values = document.get(name)
    if not isinstance(values, list):
        raise ValueError(f"Missing {name} rows")
    return values


def first_day_entries(source_root, content):
    with tempfile.NamedTemporaryFile(prefix="minifarm-first-day-", delete=False) as temporary_binary:
        binary = Path(temporary_binary.name)
    binary.unlink()
    sources = sorted((source_root / "App" / "Gameplay").glob("*.swift"))
    if not sources:
        raise ValueError("Gameplay Swift sources are unavailable")
    runner = Path(__file__).with_name("Tests") / "FirstDayVoiceDump.swift"
    try:
        subprocess.run(
            ["swiftc", "-swift-version", "6", *(str(path) for path in sources), str(runner), "-o", str(binary)],
            cwd=ROOT, check=True,
        )
        result = subprocess.run(
            [str(binary), str(content)], cwd=ROOT, check=True, text=True, capture_output=True,
        )
        return json.loads(result.stdout)
    finally:
        binary.unlink(missing_ok=True)


def build_catalog(source_root, content, source_revision):
    entries = {}

    def add(voice_id, text, source):
        if not isinstance(voice_id, str) or not voice_id.startswith("vl."):
            raise ValueError(f"Invalid voice ID: {voice_id!r}")
        if not isinstance(text, str) or not text.strip():
            return
        entries.setdefault((voice_id, text), source)

    activities = load_rows(content, "activities")
    for activity in activities:
        activity_id = activity["id"]
        short_id = activity_id.removeprefix("act.")
        for step in activity.get("steps", []):
            add(f"vl.pelle.{short_id}.{step['id']}", step.get("text", ""), "activity-step")
            for choice in step.get("choices", []):
                title = choice.get("title")
                if title:
                    add(f"vl.hint.{short_id}", f"Schau mal: {title}.", "activity-choice")

    for entry in load_rows(content, "hofbook"):
        add(f"vl.book.{entry['id'].removeprefix('hofbook.')}", entry["fact"], "hofbook")

    for location in load_rows(content, "locations"):
        add(f"vl.vocab.{location['id']}", location["title"], "location")

    for season in load_rows(content, "seasons"):
        add(f"vl.{season['id']}.greet", f"Schau, jetzt ist {season['title']}!", "season")
        add(
            f"vl.{season['id']}.greet",
            f"Jetzt ist {season['title']} auf dem Hof.",
            "season-greeting",
        )

    for text in (
        "Pelle schläft. Ganz still liegt unser Hof im Mondlicht. Bald geht die Sonne auf.",
        "Schau ins Beet. Radieschen! Über Nacht ist die Ernte reif geworden.",
        "Heute war ein ruhiger Hoftag. Guten Morgen, kleiner Hof!",
        "Säen",
        "Beete gießen",
        "Tiere füttern",
    ):
        add("vl.story.local", text, "host-night-story")

    for activity in activities:
        add(
            "vl.pelle.wish.prepare",
            f"Dein Wunsch wartet. Zuerst: {activity['title']}.",
            "wish-route",
        )

    for voice_id, texts in {
        "vl.pelle.greet.morning": [
            "Hallo! Schön, dass du da bist!",
            "Guten Morgen! Der Hof wacht auf.",
        ],
        "vl.pelle.home": ["Da ist unser Hofbaum.", "Komm, wir schauen bei Pelle nach."],
        "vl.pelle.greet.explore": ["Was möchtest du entdecken?", "Wir schauen, was gerade bereitliegt."],
        "vl.pelle.wish.season": ["Dein Wunsch bleibt hier. Komm, wir drehen am Jahreskreis."],
    }.items():
        for text in texts:
            add(voice_id, text, "game-feedback")

    for entry in first_day_entries(source_root, content):
        add(entry["id"], entry["text"], entry["source"])

    ordered = [
        {"id": voice_id, "text": text, "source": source}
        for (voice_id, text), source in sorted(entries.items())
    ]
    return {
        "schemaVersion": 1,
        "locale": "de-DE",
        "sourceRevision": source_revision,
        "entries": ordered,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="fail if the catalog differs from the saved file")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="MiniFarm-voice-catalog-") as directory:
        source_root, content, revision = source_tree(Path(directory))
        catalog = build_catalog(source_root, content, revision)

    rendered = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        existing = args.output.read_text(encoding="utf-8")
        if existing != rendered:
            raise SystemExit(f"Voice catalog differs: {args.output}")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(f"{len(catalog['entries'])} exact German voice variants in {args.output}")


if __name__ == "__main__":
    main()
