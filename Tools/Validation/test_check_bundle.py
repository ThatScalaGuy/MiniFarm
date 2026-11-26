import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import check_bundle as gate


class BundleTests(unittest.TestCase):
    def setUp(self):
        work = tempfile.TemporaryDirectory()
        self.addCleanup(work.cleanup)
        self.app = Path(work.name, "MiniFarm.app")
        for name in gate.REQUIRED:
            path = self.app / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"{}")
        self.model = self.app / "Models/model.crop.carrot.ripe.usdz"
        with zipfile.ZipFile(self.model, "w") as package:
            package.writestr("root.usda", b"not a USD layer")
        self.write_manifest("Models", [{"id": "crop.carrot.ripe", "file": self.model.name,
                                        "bytes": self.model.stat().st_size}])
        self.voice = {"id": "vl.pelle.greet.morning", "kind": "voice", "locale": "de-DE", "subtitle": "Guten Morgen!"}
        self.write_manifest("Audio", [self.voice])

    def write_manifest(self, folder, rows):
        (self.app / folder / "manifest.json").write_text(json.dumps({"schemaVersion": 1, "assets": rows}))

    def test_only_explicit_local_speech_may_omit_audio(self):
        files = gate.inventory(self.app)
        self.assertEqual(gate.asset_paths(self.app, files), ({"model.crop.carrot.ripe"}, set(), 1))
        self.write_manifest("Audio", [{"id": "vl.pelle.greet.morning", "kind": "voice", "locale": "de-DE", "path": None}])
        self.assertEqual(gate.asset_paths(self.app, files)[2], 1)
        for invalid in (dict(self.voice, kind="sfx"), dict(self.voice, subtitle=" "),
                        dict(self.voice, path="voice/missing.m4a"), dict(self.voice, path="../.env")):
            with self.subTest(row=invalid), self.assertRaises(gate.BundleError):
                self.write_manifest("Audio", [invalid])
                gate.asset_paths(self.app, files)

    def test_missing_misnamed_or_unlisted_resource_fails(self):
        self.model.rename(self.model.with_name("model.crop.carrot.seed.usdz"))
        with self.assertRaisesRegex(gate.BundleError, "missing Models/model.crop.carrot.ripe.usdz"):
            gate.asset_paths(self.app, gate.inventory(self.app))
        self.model.with_name("model.crop.carrot.seed.usdz").rename(self.model)
        (self.app / "Audio/extra.wav").write_bytes(b"not playable")
        with self.assertRaisesRegex(gate.BundleError, "unlisted media"):
            gate.asset_paths(self.app, gate.inventory(self.app))
        (self.app / "Content/items.json").rename(self.app / "Content/Items.json")
        with self.assertRaises(gate.BundleError):
            gate.inventory(self.app)

    def test_unknown_files_links_and_build_tools_are_not_opened(self):
        for filename in ("Content/credentials.json", ".env.local", "Tools/build.sh", "Audio/key.pem"):
            with self.subTest(filename=filename):
                path = self.app / filename
                path.parent.mkdir(exist_ok=True)
                path.write_text("sentinel must remain private")
                with patch.object(Path, "read_bytes", side_effect=AssertionError("payload opened")):
                    with self.assertRaises(gate.BundleError) as error:
                        gate.check(self.app)
                self.assertNotIn("sentinel", str(error.exception))
                path.unlink()
                if path.parent.name == "Tools":
                    path.parent.rmdir()
        self.model.unlink()
        self.model.symlink_to(self.app.parent / "external")
        with self.assertRaisesRegex(gate.BundleError, "linked"):
            gate.inventory(self.app)

    def test_catalog_references_must_match_the_corresponding_manifest_kind(self):
        refs = {"models": ["model.crop.carrot.ripe"], "sfx": ["sfx.cow.hum"]}
        gate.check_references(refs, {"model.crop.carrot.ripe"}, {"sfx.cow.hum"})
        for models, sounds in (({"crop.carrot.ripe"}, {"sfx.cow.hum"}), ({"model.crop.carrot.ripe"}, set())):
            with self.assertRaisesRegex(gate.BundleError, "unresolved"):
                gate.check_references(refs, models, sounds)

    def test_damaged_archive_and_unwanted_members_fail_before_payload_reads(self):
        self.model.write_bytes(b"not a zip")
        with self.assertRaisesRegex(gate.BundleError, "invalid USDZ"):
            gate.archive_inventory(self.model)
        for member in ("../outside.usdc", "notes/.env", "authoring.py"):
            with self.subTest(member=member):
                with zipfile.ZipFile(self.model, "w") as package:
                    package.writestr("root.usdc", b"placeholder")
                    package.writestr(member, b"sentinel must remain private")
                with patch.object(zipfile.ZipFile, "open", side_effect=AssertionError("member opened")):
                    with self.assertRaisesRegex(gate.BundleError, "forbidden USDZ member"):
                        gate.archive_inventory(self.model)

    @unittest.skipUnless(shutil.which("usdchecker"), "requires Apple's USD tools")
    def test_crc_clean_zip_with_invalid_usd_is_not_a_playable_model(self):
        gate.archive_inventory(self.model)
        with zipfile.ZipFile(self.model) as package:
            self.assertIsNone(package.testzip())
        with self.assertRaises(gate.BundleError):
            gate.probe(["usdchecker", "--arkit", "--strict", self.model], "invalid model")

    def test_cli_returns_failure_without_echoing_suspicious_names_or_values(self):
        (self.app / ".env.unexpected-marker").write_text("private-marker")
        result = subprocess.run([sys.executable, gate.__file__, self.app], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected file", result.stderr)
        self.assertNotIn("marker", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
