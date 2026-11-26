# MiniFarm audio integration

Add `MiniFarmAudioController.swift` to the app target and copy `App/Resources/Audio`
as a **folder reference** so the bundle contains `Audio/manifest.json` and the
referenced files at their unchanged relative paths. The manifest must have
`schemaVersion: 1` and an `assets` array with `id`, `kind` (`voice`, `sfx`,
`music`, or `ambient`), and optional `path`, `subtitle`, `locale`, `loop`,
`peak`, and `variants`. A recorded voice either has a `path` plus exact
`subtitle`, or a null/missing row `path` and `variants` entries with exact
`text`, `path`, and `peak`; each recording entry includes its pinned license
provenance.
Duplicate IDs use the first entry. Missing or invalid manifests produce an empty catalog.
Paths must stay inside the Audio folder. No files are fetched at runtime.

The public API is main-actor isolated:

```swift
let audio = MiniFarmAudioController() // optionally init(bundle:)
audio.onSubtitleChange = { text in /* show text, or clear on nil */ }
audio.onVoiceCueEvent = { event in /* event.id and event.state */ }
audio.onAudioError = { error in /* handle manifest or asset error */ }
try audio.start()
audio.updateProfileSettings(.init(
    levels: .applyingUserMultipliers(),
    subtitlesEnabled: true,
    speechRate: 0.45
))
audio.playVoiceCue(
    id: "vl.pelle.greet.morning",
    priority: .normal,
    text: "Guten Morgen! Schön, dass du da bist."
)
audio.playSoundEffect(id: "sfx.ui.tap")
audio.playMusic(season: .spring)
audio.playAmbient(id: "ambience.farm.day")
audio.pause()
audio.resume()
audio.clearVoiceCues()
audio.stop()
```

`playVoice(id:priority:)` is an alias for `playVoiceCue`; `setLevels(_:)`
updates just the levels. Persisted family settings are user multipliers, so map
them with `MiniFarmAudioLevels.applyingUserMultipliers(voice:soundEffects:music:ambient:)`
to preserve the designed mix base levels. Priorities are `.low`, `.normal`, `.high`: higher
priority interrupts the active cue; otherwise normal and high cues queue by
priority, FIFO within a priority. Low cues are dropped while busy. Cue states
are `.queued`, `.started`, `.finished`, `.interrupted`, `.dropped`, and
`.failed`, plus `.unavailable` when no German system voice is installed or voice output is muted.
The event's optional `source` is `.recording` or `.localSynthesized` for
playback; it is nil when no source was selected, including `.unavailable`.
Callbacks run on the main actor. Bundled recordings and invalid requests can
produce callbacks synchronously; device-voice fallback is resolved
asynchronously.
Requests made before start or while paused are dropped (unknown voice IDs
without supplied text fail).
Stop interrupts the active cue and drops queued cues.
`clearVoiceCues()` does the same for voice only: it cancels the active line,
drops queued lines, and clears the subtitle while leaving music, ambience, and
sound effects running.

An exact-text bundled recording is preferred. The optional `text` argument
takes precedence over the manifest subtitle for display and fallback, and
enables fallback even when the manifest or ID is missing. If the file is absent
or unplayable, nonempty text is spoken using an already installed German voice,
preferring German (Germany) and higher-quality voices. Voice discovery runs
off the main actor at most once per controller; subtitles update immediately,
muted voice output skips discovery, and a slow system lookup times out after two
seconds. Paused, cleared, or interrupted cues are never played when a lookup
finishes later. The optional manifest locale is metadata; fallback is
intentionally German. Without an available German voice, `.unavailable` is
emitted and the subtitle remains visible until another cue replaces it or
`stop()` is called. The profile's subtitle setting still applies. Without a
file or text, the cue fails. Voice playback ducks music by about 12 dB and
ambience by about 6 dB; SFX are independent. Levels are clamped to 0...1;
changes affect file playback immediately, while synthesized speech takes its
volume when a cue starts. `speechRate` is clamped to the platform's supported
range; it affects newly started synthesized cues and adjusts recordings with
pitch-preserving time stretch. Music and ambience loop only when the manifest's
`loop` is true. `playAmbient(id:)` replaces the current ambient track; a
missing or unplayable replacement leaves it playing.

Set `onAudioError` before calling `start()`: `.manifestMissing` or
`.manifestInvalid` is delivered at each start for a missing, unreadable,
malformed, or unsupported manifest. `.assetUnavailable(id:kind:)` reports a
missing ID, wrong kind, or missing/invalid path for SFX, music, or ambience;
`.playbackFailed(id:kind:)` reports an unplayable file or playback failure.
`.soundEffectLimitReached(id:limit:)` reports a dropped SFX request when three
effects are already playing.
Requests made while stopped or paused do not report asset errors. Voice cue
errors continue to use `onVoiceCueEvent`, preserving the text fallback.

The host should pass the actual `FarmFeedback.voiceID` unchanged and include
the catalog's full text on every cue. Activity-step IDs follow
`vl.pelle.` + the activity ID without its `act.` prefix + `.` + the step ID,
for example `vl.pelle.field.sow.seed` and
`vl.pelle.field.water.use.can`. Success IDs are
`vl.praise.` + the activity ID without `act.` (for example
`vl.praise.animal.feed`); explicit hints use `vl.hint.` + the activity ID
without `act.` (for example `vl.hint.animal.feed`). Other catalog IDs include
`vl.pelle.greet.morning`, `vl.ritual.sleep`, `vl.pelle.wish.prepare`,
`vl.pelle.home`, and `vl.pelle.greet.explore`. Pass the catalog text even
when a manifest entry exists: dynamic quantities, animal names, and item names
must use the exact local text rather than a generic subtitle. The runtime
accepts catalog IDs not present in the manifest and locally speaks the supplied
text when a recording is missing.

`MiniFarmSeason` has raw values `spring`, `summer`, `autumn`, and `winter`;
`playMusic(season:)` resolves `music.season.<rawValue>`. Seasonal voice
greetings use `vl.season.spring.greet`, `vl.season.summer.greet`,
`vl.season.autumn.greet`, and `vl.season.winter.greet`, with the host's
supplied text.

The gameplay animal catalog uses these sound IDs and they must be passed
unchanged to `playSoundEffect(id:)`: `sfx.chicken.cluck`,
`sfx.chicken.peep`, `sfx.cat.meow`, `sfx.cat.purr`, `sfx.dog.woof`,
`sfx.dog.sniff`, `sfx.cow.moo.1`, `sfx.cow.moo.2`, `sfx.cow.hum`,
`sfx.sheep.bleat`, `sfx.pig.grunt`, `sfx.duck.quack`, `sfx.goat.bleat`,
`sfx.horse.neigh`, `sfx.horse.snort`, `sfx.rabbit.hop`, and `sfx.bee.buzz`.

`start()` configures and activates an ambient `AVAudioSession` and can throw.
The host owns session interruptions, route changes and lifecycle: call pause,
resume, or stop as appropriate, and deactivate/reconfigure the shared audio
session itself when needed. This component does not install an interruption observer or implement spatial
audio, asset prefetch, or downloads. It caps simultaneous SFX at three and
reduces their gain to keep the manifest-peak estimate of the combined mix below
its configured ceiling.

The standalone macOS smoke test in `Tools/Audio/Tests/` is not part of the app target:

```sh
swiftc -swift-version 6 App/Audio/MiniFarmAudioController.swift \
  Tools/Audio/Tests/AudioSmokeTests.swift -o /tmp/minifarm-audio-smoke
/tmp/minifarm-audio-smoke
rm /tmp/minifarm-audio-smoke
```
