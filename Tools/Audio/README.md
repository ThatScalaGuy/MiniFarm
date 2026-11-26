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

The app's German speech fallback uses `AVSpeechSynthesizer` with an already
installed device voice. It is local runtime synthesis, not an ElevenLabs
recording, and no system-voice WAV is exported or checked in. The macOS 27
Software License Agreement, section 2 (“System Voices”), permits System Voice
use while running Apple software and to create original content/projects for
personal, non-commercial use; it does not grant a commercial distribution
license for rendered voice files. Check the applicable OS license before any
commercial use:
[Apple macOS 27 SLA, §2](https://www.apple.com/legal/sla/docs/macOS27.pdf).

Treat ElevenLabs prototype output separately from release assets. ElevenLabs
states that the Free plan has no commercial license, that content created
outside a paid subscription cannot be used commercially, and that Beta
Services output cannot be used commercially or in production. Paid-plan
commercial rights remain subject to the applicable terms and service-specific
conditions:
[Can I publish the content I generate?](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform).
No ElevenLabs content was generated for these checked-in assets.
