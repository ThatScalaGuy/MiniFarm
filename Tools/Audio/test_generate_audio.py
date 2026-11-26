import unittest
import json
import struct
import tempfile
from pathlib import Path
from unittest.mock import patch

import generate_audio
from generate_audio import ROOT, resolve_asset_path


class ResolveAssetPathTests(unittest.TestCase):
    def test_rejects_absolute_and_traversal_paths(self):
        for invalid_path in (
            str(ROOT / "README.md"),
            "C:\\outside.wav",
            "../README.md",
            "subdir/../../README.md",
            r"..\README.md",
        ):
            with self.subTest(path=invalid_path), self.assertRaises(ValueError):
                resolve_asset_path(invalid_path)

    def test_rejects_symlink_escaping_audio_root(self):
        test_root = Path(__file__).resolve().parent
        outside_target = ROOT / "README.md"
        link = test_root / ".path-validation-escape"
        self.assertFalse(link.exists() or link.is_symlink())
        try:
            link.symlink_to(outside_target)
            with self.assertRaises(ValueError):
                resolve_asset_path(link.name, test_root)
        finally:
            link.unlink(missing_ok=True)


class AudioGenerationTests(unittest.TestCase):
    def test_tractor_horn_is_short_soft_and_deterministic(self):
        first = generate_audio.generate_tractor_horn()
        second = generate_audio.generate_tractor_horn()
        peak = max(abs(sample[0]) for sample in struct.iter_unpack("<h", first)) / 32768
        duration = len(first) / 2 / generate_audio.SAMPLE_RATE
        self.assertEqual(first, second)
        self.assertLessEqual(
            peak, generate_audio.TRACTOR_HORN_PEAK + 1 / 32768
        )
        self.assertGreater(peak, 0)
        self.assertLess(duration, 0.5)

    def test_manifest_generation_preserves_recorded_and_pathless_voices(self):
        with tempfile.TemporaryDirectory() as directory:
            audio_dir = Path(directory)
            voice_assets = [
                {"id": "vl.test.recorded", "kind": "voice", "path": "voice/clip.mp3",
                 "subtitle": "Guten Morgen", "locale": "de-DE"},
                {"id": "vl.test.fallback", "kind": "voice", "path": None, "locale": "de-DE"},
            ]
            (audio_dir / "manifest.json").write_text(
                json.dumps({"schemaVersion": 1, "assets": voice_assets}), encoding="utf-8"
            )
            with patch.object(generate_audio, "AUDIO_DIR", audio_dir), \
                    patch.object(generate_audio, "wav_peak", return_value=0.1):
                result = generate_audio.manifest_data()
            preserved = [asset for asset in result["assets"] if asset["kind"] == "voice"]
            self.assertEqual(preserved, voice_assets)
            self.assertIn("sfx.tractor.horn", {asset["id"] for asset in result["assets"]})


if __name__ == "__main__":
    unittest.main()
