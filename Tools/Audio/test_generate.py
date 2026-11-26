import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import urllib.error

import generate


class GenerateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.directory.cleanup)
        self.output = Path(self.directory.name) / "asset.mp3"

    def args(self, kind="voice"):
        ids = {"voice": "vl.pelle.praise.047", "sfx": "sfx.cow.moo.1", "music": "music.season.winter"}
        args = [kind, "--id", ids[kind], "--text", "Hello!", "--output", str(self.output)]
        if kind == "voice":
            args += ["--voice-id", "Voice123"]
        return args

    def run_main(self, args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            result = generate.main(args)
        return result, out.getvalue() + err.getvalue()

    def test_offline_never_reads_key_or_calls_network(self):
        cases = [
            ("voice", []), ("voice", ["--dry-run"]),
            ("sfx", ["--duration-seconds", "2"]),
            ("music", ["--music-length-ms", "3000", "--dry-run", "--confirm-billing"]),
        ]
        for kind, extra in cases:
            with self.subTest(kind=kind, extra=extra), mock.patch.object(generate, "api_key", side_effect=AssertionError), \
                    mock.patch.object(generate, "generate", side_effect=AssertionError):
                result, message = self.run_main(self.args(kind) + extra)
                self.assertEqual(result, 0)
                self.assertIn("Offline", message)
                self.assertFalse(self.output.exists())

    def test_help_is_offline_and_mentions_billing(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), mock.patch.object(generate, "api_key", side_effect=AssertionError), \
                mock.patch.object(generate.urllib.request, "build_opener", side_effect=AssertionError):
            with self.assertRaises(SystemExit) as result:
                generate.main(["--help"])
        self.assertEqual(result.exception.code, 0)
        self.assertIn("--confirm-billing", output.getvalue())
        self.assertIn("credit", output.getvalue())

    def test_requests_and_metadata_for_all_kinds(self):
        for kind, endpoint, model, field in (
            ("voice", "/v1/text-to-speech/Voice123", "eleven_multilingual_v2", "text"),
            ("sfx", "/v1/sound-generation", "eleven_text_to_sound_v3", "text"),
            ("music", "/v1/music", "music_v2_5", "prompt"),
        ):
            with self.subTest(kind=kind), mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}), \
                    mock.patch.object(generate, "generate", return_value=b"audio") as call:
                result, message = self.run_main(self.args(kind) + ["--confirm-billing"])
                self.assertEqual(result, 0, message)
                url, body, key = call.call_args.args
                self.assertEqual(url, "https://api.elevenlabs.io" + endpoint + "?output_format=mp3_44100_128")
                self.assertEqual(body["model_id"], model)
                self.assertEqual(body[field], "Hello!")
                self.assertNotIn("duration_seconds", body)
                self.assertNotIn("music_length_ms", body)
                self.assertEqual(key, "private-key")
                if kind == "music":
                    self.assertTrue(body["force_instrumental"])
                self.assertEqual(self.output.read_bytes(), b"audio")
                sidecar = Path(str(self.output) + ".json")
                raw = sidecar.read_text(encoding="utf-8")
                self.assertNotIn(key, raw + message)
                self.assertEqual(json.loads(raw)["request"], {"method": "POST", "url": url, "body": body})
                self.output.unlink()
                sidecar.unlink()

    def test_duration_bounds_and_request_metadata(self):
        cases = [
            ("sfx", "--duration-seconds", "0.5", "duration_seconds", 0.5),
            ("sfx", "--duration-seconds", "30", "duration_seconds", 30.0),
            ("music", "--music-length-ms", "3000", "music_length_ms", 3000),
            ("music", "--music-length-ms", "600000", "music_length_ms", 600000),
        ]
        with mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}), \
                mock.patch.object(generate, "generate", return_value=b"audio") as call:
            for kind, flag, value, field, expected in cases:
                with self.subTest(kind=kind, value=value):
                    result, message = self.run_main(self.args(kind) + [flag, value, "--confirm-billing"])
                    self.assertEqual(result, 0, message)
                    body = call.call_args.args[1]
                    self.assertEqual(body[field], expected)
                    sidecar = Path(str(self.output) + ".json")
                    self.assertEqual(json.loads(sidecar.read_text())["request"]["body"], body)
                    self.output.unlink()
                    sidecar.unlink()

    def test_invalid_durations_and_old_music_id_are_rejected_offline(self):
        cases = [
            ("sfx", ["--duration-seconds", "0.49"]),
            ("sfx", ["--duration-seconds", "30.1"]),
            ("sfx", ["--duration-seconds", "nan"]),
            ("sfx", ["--duration-seconds", "inf"]),
            ("music", ["--music-length-ms", "2999"]),
            ("music", ["--music-length-ms", "600001"]),
            ("voice", ["--duration-seconds", "1"]),
            ("music", ["--duration-seconds", "1"]),
            ("sfx", ["--music-length-ms", "3000"]),
            ("voice", ["--music-length-ms", "3000"]),
        ]
        with mock.patch.object(generate, "api_key", side_effect=AssertionError), \
                mock.patch.object(generate, "generate", side_effect=AssertionError):
            for kind, extra in cases:
                with self.subTest(kind=kind, extra=extra):
                    self.assertEqual(self.run_main(self.args(kind) + extra + ["--confirm-billing"])[0], 1)
            args = self.args("music")
            args[args.index("--id") + 1] = "mus.winter"
            self.assertEqual(self.run_main(args + ["--confirm-billing"])[0], 1)
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as result:
                generate.main(self.args("music") + ["--music-length-ms", "3000.5", "--confirm-billing"])
            self.assertEqual(result.exception.code, 2)

    def test_invalid_inputs_and_existing_output_do_not_call(self):
        invalid = [
            ["voice", "--id", "vl../oops", "--text", "test", "--voice-id", "ok", "--output", str(self.output)],
            ["voice", "--id", "vl.ok", "--text", "  ", "--voice-id", "ok", "--output", str(self.output)],
            ["voice", "--id", "vl.ok", "--text", "x", "--voice-id", "../x", "--output", str(self.output)],
            ["sfx", "--id", "sfx.ok", "--text", "x\x7f", "--output", str(self.output)],
        ]
        with mock.patch.object(generate, "generate", side_effect=AssertionError), \
                mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}):
            for args in invalid:
                self.assertEqual(self.run_main(args + ["--confirm-billing"])[0], 1)
            self.output.write_bytes(b"existing")
            self.assertEqual(self.run_main(self.args() + ["--confirm-billing"])[0], 1)
            self.assertEqual(self.output.read_bytes(), b"existing")
            self.output.unlink()
            sidecar = Path(str(self.output) + ".json")
            sidecar.write_text("existing")
            self.assertEqual(self.run_main(self.args() + ["--confirm-billing"])[0], 1)
            self.assertEqual(sidecar.read_text(), "existing")

    def test_missing_key_and_secret_in_prompt(self):
        with mock.patch.object(generate, "generate", side_effect=AssertionError):
            with mock.patch.dict(os.environ, {}, clear=True):
                self.assertEqual(self.run_main(self.args() + ["--confirm-billing"])[0], 1)
            with mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}):
                args = self.args()
                args[args.index("--text") + 1] = "private-key"
                result, message = self.run_main(args + ["--confirm-billing"])
                self.assertEqual(result, 1)
                self.assertNotIn("private-key", message)

    def test_http_errors_do_not_log_response_body(self):
        error = urllib.error.HTTPError("url", 401, "private-key", {}, None)
        with mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}), \
                mock.patch.object(generate, "generate", side_effect=error):
            result, message = self.run_main(self.args() + ["--confirm-billing"])
        error.close()
        self.assertEqual(result, 1)
        self.assertIn("401", message)
        self.assertNotIn("private-key", message)
        self.assertFalse(self.output.exists())

    def test_transport_disables_proxy_redirects_and_sends_only_json(self):
        response = mock.MagicMock()
        response.__enter__.return_value = response
        response.headers.get_content_type.return_value = "audio/mpeg"
        response.read.return_value = b"audio"
        opener = mock.Mock()
        opener.open.return_value = response
        with mock.patch.object(generate.urllib.request, "build_opener", return_value=opener) as build:
            self.assertEqual(generate.generate("https://api.elevenlabs.io/v1/music", {"prompt": "Hi"}, "secret"), b"audio")
        self.assertEqual(build.call_args.args[0].proxies, {})
        self.assertIsInstance(build.call_args.args[1], generate.NoRedirect)
        req = opener.open.call_args.args[0]
        self.assertEqual(json.loads(req.data), {"prompt": "Hi"})
        self.assertEqual(req.get_header("Xi-api-key"), "secret")
        self.assertIsNone(build.call_args.args[1].redirect_request(req, None, 302, "", {}, "https://other.invalid"))

    def make_audio_root(self, assets=None):
        root = Path(self.directory.name).resolve() / "Audio"
        root.mkdir()
        for folder in ("voice", "music", "sfx"):
            (root / folder).mkdir()
        manifest = root / "manifest.json"
        manifest.write_text(json.dumps({"schemaVersion": 1, "assets": assets or []}), encoding="utf-8")
        return root, manifest

    def test_registration_adds_and_replaces_assets(self):
        root, manifest = self.make_audio_root([
            {"id": "music.season.winter", "kind": "music", "path": "music/old.wav", "loop": True},
            {"id": "sfx.other", "kind": "sfx", "path": "sfx/other.wav"},
        ])
        cases = [
            ("voice", "voice/greeting.mp3", [],
             {"id": "vl.pelle.praise.047", "kind": "voice", "path": "voice/greeting.mp3",
              "locale": "de-DE", "subtitle": "Hello!"}),
            ("music", "music/new.mp3", ["--loop"],
             {"id": "music.season.winter", "kind": "music", "path": "music/new.mp3", "loop": True}),
            ("sfx", "sfx/new.mp3", [],
             {"id": "sfx.cow.moo.1", "kind": "sfx", "path": "sfx/new.mp3", "loop": False}),
        ]
        with mock.patch.object(generate, "AUDIO_ROOT", root), \
                mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}), \
                mock.patch.object(generate, "generate", return_value=b"audio"):
            for kind, path, extra, expected in cases:
                with self.subTest(kind=kind):
                    self.output = root / path
                    result, message = self.run_main(self.args(kind) + ["--register", "--confirm-billing"] + extra)
                    self.assertEqual(result, 0, message)
                    data = json.loads(manifest.read_text())
                    matching = [asset for asset in data["assets"] if asset["id"] == expected["id"]]
                    self.assertEqual(matching, [expected])
                    self.assertTrue((root / expected["path"]).is_file())
                    self.assertTrue(Path(str(self.output) + ".json").is_file())
        self.assertIn({"id": "sfx.other", "kind": "sfx", "path": "sfx/other.wav"},
                      json.loads(manifest.read_text())["assets"])

    def test_registration_dry_run_and_rejections_never_generate(self):
        root, manifest = self.make_audio_root([
            {"id": "sfx.cow.moo.1", "kind": "music", "path": "music/old.wav"},
        ])
        original = manifest.read_bytes()
        external = Path(self.directory.name).resolve() / "outside"
        external.mkdir()
        (root / "link").symlink_to(external, target_is_directory=True)
        with mock.patch.object(generate, "AUDIO_ROOT", root), \
                mock.patch.object(generate, "api_key", side_effect=AssertionError), \
                mock.patch.object(generate, "generate", side_effect=AssertionError):
            self.output = root / "music" / "new.mp3"
            self.assertEqual(self.run_main(self.args("music") + ["--register"])[0], 0)
            self.assertEqual(manifest.read_bytes(), original)
            self.assertFalse(self.output.exists())
            for output in (external / "outside.mp3", root / "link" / "outside.mp3",
                           root / "music" / ".." / "music" / "new.mp3"):
                with self.subTest(output=output):
                    self.output = output
                    self.assertEqual(self.run_main(self.args("music") + ["--register", "--confirm-billing"])[0], 1)
            self.output = root / "sfx" / "new.mp3"
            self.assertEqual(self.run_main(self.args("sfx") + ["--register", "--confirm-billing"])[0], 1)
            self.output = root / "voice" / "new.mp3"
            self.assertEqual(self.run_main(self.args("voice") + ["--register", "--loop"])[0], 1)
            self.assertEqual(manifest.read_bytes(), original)

    def test_registration_failure_retains_generated_files(self):
        root, manifest = self.make_audio_root()
        self.output = root / "music" / "new.mp3"
        original = manifest.read_bytes()
        with mock.patch.object(generate, "AUDIO_ROOT", root), \
                mock.patch.dict(os.environ, {"ELEVENLABS_API_KEY": "private-key"}), \
                mock.patch.object(generate, "generate", return_value=b"audio"), \
                mock.patch.object(generate, "register", side_effect=OSError):
            result, message = self.run_main(self.args("music") + ["--register", "--confirm-billing"])
        self.assertEqual(result, 1)
        self.assertIn("retained", message)
        self.assertEqual(self.output.read_bytes(), b"audio")
        self.assertTrue(Path(str(self.output) + ".json").is_file())
        self.assertEqual(manifest.read_bytes(), original)

    def test_registration_rejects_bad_manifest_and_path_conflicts(self):
        root, manifest = self.make_audio_root()
        self.output = root / "music" / "new.mp3"
        cases = [
            {"schemaVersion": 2, "assets": []},
            {"schemaVersion": 1, "assets": [{"id": "other", "kind": "music", "loop": "yes"}]},
            {"schemaVersion": 1, "assets": [
                {"id": "music.season.winter", "kind": "music"},
                {"id": "music.season.winter", "kind": "music"},
            ]},
            {"schemaVersion": 1, "assets": [
                {"id": "music.other", "kind": "music", "path": "music/new.mp3"},
            ]},
        ]
        with mock.patch.object(generate, "AUDIO_ROOT", root), \
                mock.patch.object(generate, "api_key", side_effect=AssertionError), \
                mock.patch.object(generate, "generate", side_effect=AssertionError):
            for data in cases:
                with self.subTest(data=data):
                    manifest.write_text(json.dumps(data))
                    original = manifest.read_bytes()
                    self.assertEqual(self.run_main(self.args("music") + ["--register", "--confirm-billing"])[0], 1)
                    self.assertEqual(manifest.read_bytes(), original)
                    self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
