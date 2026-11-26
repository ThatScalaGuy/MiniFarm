#!/usr/bin/env python3
"""Generate and validate MiniFarm's license-clear, offline audio fallbacks."""

import argparse
import json
import math
import random
import struct
import wave
from pathlib import Path
from pathlib import PureWindowsPath


ROOT = Path(__file__).resolve().parents[2]
AUDIO_DIR = ROOT / "App" / "Resources" / "Audio"
SAMPLE_RATE = 22050
MAX_PEAK = 0.45
MUSIC_PEAK = 0.105
SFX_PEAK = 0.18
AMBIENCE_PEAK = 0.05
ANIMAL_PROTOTYPE_PEAK = 0.11
TRACTOR_HORN_PEAK = 0.095
BEAT_SECONDS = 60.0 / 78.0
BEATS = 16
DURATION = BEAT_SECONDS * BEATS
AMBIENCE_DURATION = 16.0

SEASONS = {
    "spring": {
        "scale": [0, 2, 4, 7, 9],
        "chords": [0, 3, 4, 0],
        "melody": [2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 1, 0, 1, 2, 3],
        "timbre": (1.0, 0.28, 0.1),
    },
    "summer": {
        "scale": [0, 2, 4, 7, 9],
        "chords": [0, 4, 3, 4],
        "melody": [0, 1, 2, 3, 2, 1, 2, 3, 4, 3, 2, 1, 2, 1, 0, 1],
        "timbre": (1.0, 0.18, 0.04),
    },
    "autumn": {
        "scale": [0, 2, 3, 7, 9],
        "chords": [0, 3, 4, 0],
        "melody": [2, 1, 0, 1, 2, 3, 2, 4, 2, 1, 0, 1, 2, 0, 1, 2],
        "timbre": (1.0, 0.33, 0.13),
    },
    "winter": {
        "scale": [0, 2, 4, 7, 9],
        "chords": [0, 4, 0, 3],
        "melody": [3, 2, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 1, 0, 1, 0],
        "timbre": (1.0, 0.38, 0.16),
    },
}

ANIMAL_SOUND_PROFILES = {
    "sfx.chicken.cluck": (0.56, 470, 330, (1.0, 0.48, 0.18), 0.02, 0, 0, 0,
                          ((0.02, 0.16, 0.75), (0.22, 0.12, 0.8), (0.39, 0.13, 0.65))),
    "sfx.chicken.peep": (0.48, 1550, 1980, (1.0, 0.35, 0.1), 0.01, 0, 0, 0,
                         ((0.02, 0.2, 0.8), (0.26, 0.17, 0.62))),
    "sfx.cat.meow": (0.78, 520, 285, (1.0, 0.42, 0.22, 0.08), 0.01, 5, 0.035, 0,
                     ((0.02, 0.7, 0.82),)),
    "sfx.cat.purr": (0.82, 92, 82, (1.0, 0.5, 0.24, 0.1), 0.04, 0, 0, 24,
                     ((0.02, 0.76, 0.72),)),
    "sfx.dog.woof": (0.48, 155, 112, (1.0, 0.5, 0.25, 0.12), 0.08, 0, 0, 0,
                     ((0.02, 0.19, 0.8), (0.26, 0.16, 0.52))),
    "sfx.dog.sniff": (0.4, 280, 390, (0.5, 0.24, 0.1), 0.55, 0, 0, 0,
                      ((0.03, 0.28, 0.75),)),
    "sfx.cow.moo.1": (0.92, 118, 88, (1.0, 0.46, 0.21, 0.08), 0.04, 3.2, 0.035, 0,
                      ((0.02, 0.82, 0.82),)),
    "sfx.cow.moo.2": (0.84, 101, 112, (1.0, 0.4, 0.2, 0.08), 0.03, 4.1, 0.04, 0,
                      ((0.02, 0.74, 0.78),)),
    "sfx.cow.hum": (0.76, 94, 98, (1.0, 0.32, 0.12, 0.04), 0.01, 2.8, 0.02, 0,
                    ((0.02, 0.68, 0.7),)),
    "sfx.sheep.bleat": (0.66, 265, 205, (1.0, 0.48, 0.2, 0.08), 0.02, 6.5, 0.07, 0,
                        ((0.02, 0.58, 0.78),)),
    "sfx.pig.grunt": (0.52, 148, 106, (1.0, 0.52, 0.3, 0.12), 0.16, 0, 0, 0,
                      ((0.02, 0.18, 0.72), (0.26, 0.16, 0.5))),
    "sfx.duck.quack": (0.58, 365, 225, (1.0, 0.68, 0.3, 0.12), 0.04, 9.5, 0.075, 0,
                       ((0.02, 0.48, 0.78),)),
    "sfx.goat.bleat": (0.64, 285, 325, (1.0, 0.45, 0.2, 0.08), 0.02, 7.2, 0.065, 0,
                       ((0.02, 0.56, 0.76),)),
    "sfx.horse.neigh": (0.96, 310, 660, (1.0, 0.45, 0.2, 0.08), 0.03, 5.2, 0.045, 0,
                        ((0.02, 0.86, 0.75),)),
    "sfx.horse.snort": (0.48, 175, 125, (0.48, 0.24, 0.1), 0.62, 0, 0, 0,
                        ((0.02, 0.32, 0.78),)),
    "sfx.rabbit.hop": (0.36, 420, 325, (1.0, 0.34, 0.12), 0.02, 0, 0, 0,
                       ((0.02, 0.11, 0.66), (0.19, 0.1, 0.48))),
    "sfx.bee.buzz": (0.82, 208, 222, (1.0, 0.62, 0.32, 0.14), 0.08, 0, 0, 48,
                     ((0.02, 0.74, 0.65),)),
}


def midi_hz(note):
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def add_pluck(samples, start, duration, frequency, volume, timbre, release=0.1):
    first = max(0, int(start * SAMPLE_RATE))
    count = min(int(duration * SAMPLE_RATE), len(samples) - first)
    if count <= 0:
        return
    partials = timbre
    for offset in range(count):
        t = offset / SAMPLE_RATE
        attack = min(1.0, t / 0.012)
        decay = math.exp(-4.2 * t / max(duration, 0.1))
        tail = min(1.0, (duration - t) / release) if release else 1.0
        envelope = attack * decay * max(0.0, tail)
        phase = 2.0 * math.pi * frequency * t
        tone = sum(weight * math.sin(phase * harmonic)
                   for harmonic, weight in enumerate(partials, 1))
        samples[first + offset] += volume * envelope * tone


def generate_music(season):
    config = SEASONS[season]
    samples = [0.0] * int(round(DURATION * SAMPLE_RATE))
    scale = config["scale"]
    # A quiet, four-bar pentatonic phrase with a gently repeating bass pattern.
    for beat in range(BEATS):
        bar = beat // 4
        chord_degree = config["chords"][bar]
        root = 60 + scale[chord_degree]
        if beat % 2 == 0:
            add_pluck(samples, beat * BEAT_SECONDS, 1.5 * BEAT_SECONDS,
                      midi_hz(root - 12), 0.18, (1.0, 0.22, 0.05), 0.2)

        # Soft broken-chord notes add a warm, acoustic-guitar/harp quality.
        chord_tones = (root, root + scale[2], root + scale[4])
        if beat % 2 == 0:
            note = chord_tones[(beat // 2 + bar) % len(chord_tones)]
            add_pluck(samples, beat * BEAT_SECONDS + 0.025, 1.05 * BEAT_SECONDS,
                      midi_hz(note), 0.12, config["timbre"], 0.16)

        degree = config["melody"][beat]
        octave = 12 if beat in (3, 7, 11, 15) else 0
        melody_note = 72 + scale[degree] + octave
        if beat % 2 == 0 or beat in (3, 7, 11, 15):
            add_pluck(samples, beat * BEAT_SECONDS + 0.045, 0.72 * BEAT_SECONDS,
                      midi_hz(melody_note), 0.09, config["timbre"], 0.14)

    return shape_and_encode(samples, MUSIC_PEAK, fade_in=0.08, fade_out=0.12)


def shape_and_encode(samples, target_peak, fade_in=0.008, fade_out=0.04):
    peak = max((abs(value) for value in samples), default=0.0)
    if peak == 0:
        raise ValueError("Generated silent audio")
    gain = target_peak / peak
    encoded = bytearray()
    total = len(samples)
    for index, value in enumerate(samples):
        t = index / SAMPLE_RATE
        remaining = (total - 1 - index) / SAMPLE_RATE
        envelope = min(1.0, t / fade_in, remaining / fade_out)
        value = max(-0.95, min(0.95, value * gain * max(0.0, envelope)))
        encoded.extend(struct.pack("<h", int(round(value * 32767))))
    return bytes(encoded)


def generate_tap():
    duration = 0.16
    samples = []
    for index in range(int(duration * SAMPLE_RATE)):
        t = index / SAMPLE_RATE
        env = math.sin(math.pi * min(1.0, t / duration)) ** 2
        freq = 560 - 130 * (t / duration)
        samples.append(0.45 * env * math.sin(2 * math.pi * freq * t))
    return shape_and_encode(samples, 0.13)


def generate_success():
    duration = 1.18
    samples = [0.0] * int(duration * SAMPLE_RATE)
    notes = (72, 76, 79, 84)
    for index, note in enumerate(notes):
        add_pluck(samples, 0.08 + index * 0.22, 0.72, midi_hz(note),
                  0.48 / (1 + index * 0.12), (1.0, 0.42, 0.14, 0.04), 0.18)
    return shape_and_encode(samples, 0.16, fade_in=0.008, fade_out=0.08)


def generate_tractor_horn():
    duration = 0.46
    samples = [0.0] * int(duration * SAMPLE_RATE)
    for start, frequency in ((0.035, 440.0), (0.25, 523.25)):
        pulse_duration = 0.16
        first = int(start * SAMPLE_RATE)
        count = int(pulse_duration * SAMPLE_RATE)
        for offset in range(count):
            t = offset / SAMPLE_RATE
            envelope = math.sin(math.pi * t / pulse_duration) ** 2
            phase = 2 * math.pi * frequency * t
            tone = 0.86 * math.sin(phase) + 0.14 * math.sin(2 * phase)
            samples[first + offset] += 0.45 * envelope * tone
    return shape_and_encode(samples, TRACTOR_HORN_PEAK, fade_in=0.012, fade_out=0.04)


def generate_moo():
    duration = 1.25
    samples = []
    for index in range(int(duration * SAMPLE_RATE)):
        t = index / SAMPLE_RATE
        progress = t / duration
        attack = min(1.0, t / 0.12)
        release = min(1.0, (duration - t) / 0.18)
        envelope = attack * release * (0.76 + 0.24 * math.sin(math.pi * progress))
        fundamental = 112 - 18 * progress + 3 * math.sin(2 * math.pi * 2.1 * t)
        phase = 2 * math.pi * fundamental * t
        # Rounded, cartoon-stylized formants; no recorded voice or sample source.
        tone = (math.sin(phase) + 0.42 * math.sin(2 * phase + 0.2)
                + 0.19 * math.sin(3 * phase + 0.4)
                + 0.06 * math.sin(5 * phase))
        samples.append(0.34 * envelope * tone)
    return shape_and_encode(samples, 0.17, fade_in=0.01, fade_out=0.08)


def generate_animal_prototype(sound_id):
    duration, start_hz, end_hz, harmonics, noise_level, vibrato_hz, vibrato_depth, flutter_hz, pulses = (
        ANIMAL_SOUND_PROFILES[sound_id]
    )
    count = int(duration * SAMPLE_RATE)
    seed = int.from_bytes(sound_id.encode("utf-8"), "little")
    rng = random.Random(seed)
    noise = []
    filtered_noise = 0.0
    for _ in range(count):
        filtered_noise = 0.9 * filtered_noise + 0.1 * (rng.random() * 2 - 1)
        noise.append(filtered_noise)

    samples = [0.0] * count
    for index in range(count):
        t = index / SAMPLE_RATE
        progress = t / duration
        envelope = 0.0
        for pulse_start, pulse_duration, pulse_level in pulses:
            local = (t - pulse_start) / pulse_duration
            if 0 < local < 1:
                envelope += pulse_level * (math.sin(math.pi * local) ** 0.7)
        envelope = min(1.0, envelope)
        frequency = start_hz + (end_hz - start_hz) * progress
        if vibrato_hz:
            frequency *= 1 + vibrato_depth * math.sin(2 * math.pi * vibrato_hz * t)
        phase = 2 * math.pi * frequency * t
        tone = sum(weight * math.sin(phase * harmonic)
                   for harmonic, weight in enumerate(harmonics, 1))
        if flutter_hz:
            tone *= 0.76 + 0.24 * (0.5 + 0.5 * math.sin(2 * math.pi * flutter_hz * t))
        samples[index] = envelope * (tone + noise_level * noise[index])
    return shape_and_encode(
        samples, ANIMAL_PROTOTYPE_PEAK, fade_in=0.008, fade_out=0.035
    )


def generate_farm_ambience():
    count = int(AMBIENCE_DURATION * SAMPLE_RATE)
    samples = [0.0] * count
    for index in range(count):
        t = index / SAMPLE_RATE
        # Integer-cycle tones make the soft breeze bed periodic at the loop point.
        wind = (
            0.36 * math.sin(2 * math.pi * 0.1875 * t)
            + 0.23 * math.sin(2 * math.pi * 0.3125 * t + 0.7)
            + 0.13 * math.sin(2 * math.pi * 0.5 * t + 1.4)
        )
        air = (
            0.25 * math.sin(2 * math.pi * 43.0625 * t)
            + 0.14 * math.sin(2 * math.pi * 67.125 * t + 0.3)
            + 0.09 * math.sin(2 * math.pi * 91.1875 * t + 1.1)
            + 0.05 * math.sin(2 * math.pi * 127.25 * t + 2.0)
        )
        samples[index] = 0.25 * wind + 0.12 * air

    # Sparse, softly enveloped bird chirps recur within each loop without a
    # transient at the boundary.
    for start in (2.0, 6.7, 11.4):
        chirp_duration = 0.42
        first = int(start * SAMPLE_RATE)
        length = int(chirp_duration * SAMPLE_RATE)
        for offset in range(length):
            t = offset / SAMPLE_RATE
            progress = t / chirp_duration
            envelope = math.sin(math.pi * progress) ** 2
            frequency = 1850 + 500 * progress
            samples[first + offset] += (
                0.11 * envelope * math.sin(2 * math.pi * frequency * t)
            )

    return shape_and_encode(
        samples, AMBIENCE_PEAK,
        fade_in=0.08, fade_out=0.12,
    )


def write_wav(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(data)


def wav_peak(relative_path):
    with wave.open(str(AUDIO_DIR / relative_path), "rb") as source:
        if source.getsampwidth() != 2:
            raise ValueError(f"Expected PCM16 audio: {relative_path}")
        frames = source.readframes(source.getnframes())
    return max(abs(value[0]) for value in struct.iter_unpack("<h", frames)) / 32768


def manifest_data():
    assets = [
        {"id": f"music.season.{season}", "kind": "music",
         "path": f"music/season.{season}.wav", "loop": True,
         "peak": wav_peak(f"music/season.{season}.wav")}
        for season in SEASONS
    ]
    assets.append({
        "id": "ambience.farm.day", "kind": "ambient",
        "path": "ambience/farm.day.wav", "loop": True,
        "peak": wav_peak("ambience/farm.day.wav"),
    })
    assets += [
        {"id": "sfx.ui.tap", "kind": "sfx", "path": "sfx/ui.tap.wav",
         "peak": wav_peak("sfx/ui.tap.wav")},
        {"id": "sfx.ui.success", "kind": "sfx", "path": "sfx/ui.success.wav",
         "peak": wav_peak("sfx/ui.success.wav")},
        {"id": "sfx.animal.cow.moo", "kind": "sfx",
         "path": "sfx/animal.cow.moo.wav", "peak": wav_peak("sfx/animal.cow.moo.wav")},
        {"id": "sfx.tractor.horn", "kind": "sfx", "path": "sfx/tractor.horn.wav",
         "peak": wav_peak("sfx/tractor.horn.wav")},
    ]
    assets.extend(
        {
            "id": sound_id,
            "kind": "sfx",
            "path": f"sfx/prototype/animals/{sound_id.removeprefix('sfx.')}.wav",
            "peak": wav_peak(f"sfx/prototype/animals/{sound_id.removeprefix('sfx.')}.wav"),
        }
        for sound_id in ANIMAL_SOUND_PROFILES
    )
    existing_manifest = AUDIO_DIR / "manifest.json"
    if existing_manifest.exists():
        existing_assets = json.loads(existing_manifest.read_text(encoding="utf-8")).get("assets", [])
        voice_assets = [asset for asset in existing_assets if asset.get("kind") == "voice"]
    else:
        voice_assets = [
            {"id": voice_id, "kind": "voice", "path": None, "locale": "de-DE"}
            for voice_id in (
                "vl.pelle.greet.morning", "vl.ritual.sleep", "vl.pelle.wish.prepare",
                "vl.pelle.home", "vl.pelle.greet.explore", "vl.hint.animal.feed",
                "vl.praise.animal.feed", "vl.praise.field.harvest",
                "vl.pelle.field.sow.seed", "vl.pelle.field.sow.field",
                "vl.pelle.field.water.use.can", "vl.pelle.field.water.field",
                "vl.pelle.shop.order.pack.radish", "vl.pelle.shop.order.ring",
                "vl.season.spring.greet", "vl.season.summer.greet",
                "vl.season.autumn.greet", "vl.season.winter.greet",
            )
        ]
    assets.extend(voice_assets)
    return {"schemaVersion": 1, "assets": assets}


def resolve_asset_path(relative_path, audio_root=AUDIO_DIR):
    if not isinstance(relative_path, str) or not relative_path:
        raise ValueError("Audio asset path must be a non-empty relative path")
    windows_path = PureWindowsPath(relative_path)
    if (Path(relative_path).is_absolute() or windows_path.is_absolute()
            or windows_path.drive):
        raise ValueError(f"Audio asset path must be relative: {relative_path}")
    parts = relative_path.replace("\\", "/").split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise ValueError(f"Invalid audio asset path: {relative_path}")

    root = Path(audio_root).resolve(strict=True)
    resolved = (root / Path(*parts)).resolve(strict=True)
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise ValueError(
            f"Audio asset resolves outside the audio directory: {relative_path}"
        ) from error
    return resolved


def generate():
    for season in SEASONS:
        write_wav(AUDIO_DIR / "music" / f"season.{season}.wav",
                  generate_music(season))
    write_wav(AUDIO_DIR / "sfx" / "ui.tap.wav", generate_tap())
    write_wav(AUDIO_DIR / "sfx" / "ui.success.wav", generate_success())
    write_wav(AUDIO_DIR / "sfx" / "tractor.horn.wav", generate_tractor_horn())
    write_wav(AUDIO_DIR / "sfx" / "animal.cow.moo.wav", generate_moo())
    write_wav(AUDIO_DIR / "ambience" / "farm.day.wav", generate_farm_ambience())
    for sound_id in ANIMAL_SOUND_PROFILES:
        filename = f"{sound_id.removeprefix('sfx.')}.wav"
        write_wav(
            AUDIO_DIR / "sfx" / "prototype" / "animals" / filename,
            generate_animal_prototype(sound_id),
        )
    (AUDIO_DIR / "manifest.json").write_text(
        json.dumps(manifest_data(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def verify():
    manifest_path = AUDIO_DIR / "manifest.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert set(data) == {"schemaVersion", "assets"} and data["schemaVersion"] == 1
    assets = data["assets"]
    ids = [asset["id"] for asset in assets]
    assert len(ids) == len(set(ids)), "Duplicate asset IDs"
    expected_music = {f"music.season.{season}" for season in SEASONS}
    expected_ambient = {"ambience.farm.day"}
    expected_sfx = {
        "sfx.ui.tap", "sfx.ui.success", "sfx.animal.cow.moo", "sfx.tractor.horn",
        *ANIMAL_SOUND_PROFILES,
    }
    required_voice = {
        "vl.pelle.greet.morning", "vl.ritual.sleep", "vl.pelle.wish.prepare",
        "vl.pelle.home", "vl.pelle.greet.explore", "vl.season.spring.greet",
        "vl.season.summer.greet", "vl.season.autumn.greet", "vl.season.winter.greet",
    }
    assert {a["id"] for a in assets if a["kind"] == "music"} == expected_music
    assert {a["id"] for a in assets if a["kind"] == "ambient"} == expected_ambient
    assert {a["id"] for a in assets if a["kind"] == "sfx"} == expected_sfx
    voice_assets = {a["id"]: a for a in assets if a["kind"] == "voice"}
    assert required_voice <= set(voice_assets)
    reports = []
    mix_peaks = {"music": [], "ambient": [], "sfx": [], "voice": []}
    for asset in assets:
        if asset["kind"] == "voice":
            assert asset["id"].startswith("vl.") and asset["locale"] == "de-DE"
            variants = asset.get("variants")
            recordings = variants if variants is not None else ([asset] if asset.get("path") else [])
            if variants is not None:
                assert asset.get("path") is None and variants
                texts = [variant.get("text") for variant in variants]
                assert all(isinstance(text, str) and text.strip() for text in texts)
                assert len(texts) == len(set(texts))
            for recording in recordings:
                if variants is None:
                    assert isinstance(asset.get("subtitle"), str) and asset["subtitle"].strip()
                assert recording.get("license") == "CC0-1.0"
                assert recording.get("modelRevision") == "9beb8542b91ec176ad58adbf9f6085f96b6caa17"
                assert recording.get("licenseSource", "").endswith(
                    "/raw/9beb8542b91ec176ad58adbf9f6085f96b6caa17/README.md"
                )
                assert recording.get("peak", 0) > 0
                assert recording["peak"] <= 0.40
                path = recording["path"]
                assert path.startswith("voice/") and path.endswith(".mp3")
                media = resolve_asset_path(path)
                assert media.is_file() and media.stat().st_size > 0
                mix_peaks["voice"].append(recording["peak"])
            continue
        if asset["kind"] in ("music", "ambient"):
            assert asset.get("loop") is True
        if asset["id"] in ANIMAL_SOUND_PROFILES:
            assert asset["path"].startswith("sfx/prototype/animals/")
        path = resolve_asset_path(asset["path"])
        assert path.is_file(), f"Missing audio file: {asset['path']}"
        with wave.open(str(path), "rb") as source:
            assert source.getnchannels() == 1
            assert source.getsampwidth() == 2
            assert source.getframerate() == SAMPLE_RATE
            frames = source.readframes(source.getnframes())
            peak = max(abs(value[0]) for value in struct.iter_unpack("<h", frames)) / 32768
            assert peak <= MAX_PEAK, f"Peak too high in {asset['path']}: {peak:.3f}"
            assert peak > 0, f"Silent audio: {asset['path']}"
            assert abs(asset.get("peak", 0) - peak) <= 1 / 32768, f"Stale peak in {asset['path']}"
            mix_kind = {"music": "music", "ambient": "ambient", "sfx": "sfx"}.get(asset["kind"])
            if mix_kind:
                mix_peaks[mix_kind].append(peak)
            reports.append((path, source.getnframes() / SAMPLE_RATE, peak))
    max_music = max(mix_peaks["music"])
    max_ambient = max(mix_peaks["ambient"])
    largest_sfx = sorted(mix_peaks["sfx"], reverse=True)[:3]
    dry_mix_peak = max_music + max_ambient + sum(largest_sfx)
    spoken_background = max_music * 0.25 + max_ambient * 0.5
    max_voice = max(max(mix_peaks["voice"], default=0), 0.65)
    spoken_mix_peak = max_voice + spoken_background + min(
        sum(largest_sfx), max(0, 0.9 - max_voice - spoken_background)
    )
    assert dry_mix_peak <= 0.9, f"Unbounded non-voice mix peak: {dry_mix_peak:.3f}"
    assert spoken_mix_peak <= 0.9, f"Unbounded spoken mix peak: {spoken_mix_peak:.3f}"
    reports.append(("mix bound (3 SFX)", 0, dry_mix_peak))
    reports.append(("spoken mix bound (3 SFX)", 0, spoken_mix_peak))
    return reports


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true",
                        help="validate existing manifest and WAV assets without generating")
    args = parser.parse_args()
    if not args.verify_only:
        generate()
    reports = verify()
    for path, duration, peak in reports:
        relative = path.relative_to(ROOT) if isinstance(path, Path) else path
        print(f"{relative}: {path.stat().st_size:,} bytes, WAV PCM16 mono "
              f"{SAMPLE_RATE} Hz, {duration:.2f}s, peak {peak:.3f}"
              if isinstance(path, Path) else f"{relative}: peak {peak:.3f}")
    print("Animal SFX are synthetic procedural prototypes, not recordings.")
    print("Combined worst-case mix peaks (linear):")
    for path, _, peak in reports[-2:]:
        print(f"{path}: {peak:.3f} (limit 0.900)")
    print("Manifest, voice provenance, combined mix bounds, and audio assets validated.")


if __name__ == "__main__":
    main()
