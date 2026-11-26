# ElevenLabs raw audio generator

This standalone Python 3 standard-library tool generates **one** raw MP3 and
its `<output>.mp3.json` metadata sidecar. By default it does not modify app
resources, manifests, or project files. All calls are opt-in and consume ElevenLabs
credits; check current pricing and licensing before use.
[Current API pricing](https://elevenlabs.io/pricing/api).

Default execution and `--dry-run` are offline: no API request, environment key
read, `.env` loading, or output files. `--dry-run` takes precedence even with
`--confirm-billing`. To generate, set `ELEVENLABS_API_KEY` in the process
environment and explicitly add `--confirm-billing`. No project files are
uploaded; only the supplied text and request parameters are sent.
Do not put secrets or personal data in prompts: prompts are sent to ElevenLabs
and saved verbatim in the sidecar. The tool does not log the key or API error
bodies. Check ElevenLabs' data retention terms before sending text.

```sh
python3 Tools/Audio/generate.py voice --id vl.pelle.praise.047 \
  --voice-id VOICE_ID --text 'Du hast gut gezählt!' \
  --output vo_de_vl.pelle.praise.047.mp3
python3 Tools/Audio/generate.py sfx --id sfx.cow.moo.1 \
  --text 'A gentle friendly moo' --duration-seconds 2 --output sfx.cow.moo.1.mp3
python3 Tools/Audio/generate.py music --id music.season.winter \
  --text 'Gentle winter farm music' --music-length-ms 30000 --output music.season.winter.mp3
```

These examples are dry runs. Add `--confirm-billing` to one command to generate.
The output directory must already exist and neither output nor sidecar may
exist. IDs use the project's `vl.*`, `sfx.*`, and `music.*` conventions;
voice raw filenames can follow `vo_<lang>_<id>.mp3`. The documented `.m4a`
voice convention is for post-processed release assets; this tool does not
transcode or perform QA. Music requests force instrumental output.
Optional `--duration-seconds` accepts 0.5–30 for SFX; `--music-length-ms`
accepts 3000–600000 for music. Without these flags the API chooses the duration.

## Optional manifest registration

Add `--register` to write the generated file inside `App/Resources/Audio` and
add or replace the matching ID in `App/Resources/Audio/manifest.json`.
Output paths must stay inside that directory, without parent traversal or
symlinks, and the parent directory must already exist. Existing files are never
overwritten. A conflicting ID kind, duplicate matching IDs, or a path used by
another ID is rejected before the request. Voice entries use `de-DE` and the
provided text as subtitle. Music and SFX entries default to `loop: false`;
add `--loop` to set it to `true`. This is a manifest playback flag, not an
instruction to generate seamlessly looping audio.

Registration is still a dry run unless `--confirm-billing` is supplied; a
registration dry run reads and validates the manifest but writes nothing.
For example:

```sh
python3 Tools/Audio/generate.py music --id music.season.winter \
  --text 'Gentle winter farm music' --music-length-ms 30000 --loop --register \
  --output App/Resources/Audio/music/season.winter.generated.mp3
```

Add `--confirm-billing` only when ready to consume credits. If manifest writing
fails after generation, the audio and sidecar are retained and the command
reports failure. Do not edit the manifest concurrently with registration.

The sidecar records the exact request URL, method, model, and JSON body, not
the authentication header. It may contain sensitive prompt text. Models and
API behavior can change; consult the official [TTS](https://elevenlabs.io/docs/api-reference/text-to-speech/convert),
[SFX](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert),
and [music](https://elevenlabs.io/docs/api-reference/music/compose) references.

Run offline tests with `python3 -m unittest discover -s Tools/Audio -p 'test_*.py'`.

## Asset provenance and distribution

The checked-in WAV prototypes are generated locally by `generate_audio.py` from
deterministic synthesis; they use no downloaded samples or ElevenLabs output.
They are quiet placeholders for integration and still need listening and
accessibility QA before release.

## Pinned local German voice production

The bundled German voice recordings are generated locally from the
[Thorsten Piper CC0 model](https://huggingface.co/Thorsten-Voice/Piper-Thorsten-CC0),
pinned to revision `9beb8542b91ec176ad58adbf9f6085f96b6caa17`. The renderer
checks the ONNX model and configuration SHA-256 values before use, runs Piper
with ONNX Runtime and no remote code, and encodes mono 22.05 kHz MP3 files at
48 kbit/s. Exact transcript-to-ID mappings and per-file hashes, durations,
peaks, model revision, and license provenance are kept in
`voice-catalog.json` and `piper-provenance.json`; the model and tooling are not
included in the app target.

Install the pinned renderer dependencies in an isolated Python 3.12
environment and provide `ffmpeg` with `libmp3lame`, then generate and verify
assets:

```sh
python3.12 -m venv /tmp/minifarm-piper
/tmp/minifarm-piper/bin/python -m pip install -r Tools/Audio/requirements-piper.txt
/tmp/minifarm-piper/bin/python Tools/Audio/render_piper.py
/tmp/minifarm-piper/bin/python Tools/Audio/render_piper.py --verify-only
/tmp/minifarm-piper/bin/python Tools/Audio/generate_audio.py --verify-only
```

The renderer downloads only the model and config from the pinned Hugging Face
revision when they are not already cached, verifies their hashes, and performs
all speech synthesis locally. It does not send text or credentials to a
service. Recorded voice rows include the CC0 license, exact model revision,
and revision-specific model-card URL. At runtime, a recording plays only when
both its cue ID and supplied text exactly match; other text uses an installed
German device voice as a local fallback, resolved off the main thread.

Treat ElevenLabs prototype output separately from release assets. ElevenLabs
states that the Free plan has no commercial license, that content created
outside a paid subscription cannot be used commercially, and that Beta
Services output cannot be used commercially or in production. Paid-plan
commercial rights remain subject to the applicable terms and service-specific
conditions:
[Can I publish the content I generate?](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform).
No ElevenLabs content was generated for these offline voice assets.
