import Foundation
import AVFoundation

// Standalone smoke test; compile with the controller as documented below.
actor VoiceLookupCounter {
    private var count = 0

    func increment() { count += 1 }
    func value() -> Int { count }
}

@main
struct AudioSmokeTests {
    @MainActor
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MiniFarm-AudioSmoke-\(UUID().uuidString).bundle", isDirectory: true)
        let resources = root.appendingPathComponent("Contents/Resources/Audio", isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: resources, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        try """
        {"schemaVersion":1,"assets":[
          {"id":"a","kind":"voice","path":"silence.wav","subtitle":"Hallo","peak":0.32},
          {"id":"b","kind":"voice","path":"silence.wav","subtitle":"Gut","peak":0.32},
          {"id":"c","kind":"voice","path":"silence.wav","subtitle":"Hier","peak":0.32},
          {"id":"variants","kind":"voice","path":null,"locale":"de-DE","variants":[
            {"text":"Variante Eins","path":"silence.wav","peak":0.32},
            {"text":"Variante Zwei","path":"silence.wav","peak":0.32}
          ]},
          {"id":"missing","kind":"voice","path":"missing.wav"},
          {"id":"sfx.tap","kind":"sfx","path":"silence.wav","peak":0.18},
          {"id":"sfx.broken","kind":"sfx","path":"broken.wav"},
          {"id":"music.season.spring","kind":"music","path":"silence.wav","loop":true,"peak":0.05},
          {"id":"music.season.summer","kind":"music","path":"absent.wav","peak":0.05},
          {"id":"ambient.farm","kind":"ambient","path":"silence.wav","loop":true,"peak":0.025},
          {"id":"ambient.once","kind":"ambient","path":"silence.wav","peak":0.025}
        ]}
        """.write(to: resources.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)

        // Half a second of silent 8 kHz, 16-bit mono PCM.
        var wav = Data()
        func bytes(_ text: String) { wav.append(contentsOf: text.utf8) }
        func int<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
        }
        bytes("RIFF"); int(UInt32(8_036)); bytes("WAVEfmt "); int(UInt32(16))
        int(UInt16(1)); int(UInt16(1)); int(UInt32(8_000)); int(UInt32(16_000))
        int(UInt16(2)); int(UInt16(16)); bytes("data"); int(UInt32(8_000))
        wav.append(Data(repeating: 0, count: 8_000))
        try wav.write(to: resources.appendingPathComponent("silence.wav"))
        try Data("invalid audio".utf8).write(to: resources.appendingPathComponent("broken.wav"))
        guard let bundle = Bundle(url: root) else { fatalError("Fixture bundle unavailable") }

        let audio = MiniFarmAudioController(bundle: bundle)
        var events: [(String, MiniFarmVoiceCueEvent.State, MiniFarmVoiceCueEvent.Source?)] = []
        var subtitles: [String?] = []
        var errors: [MiniFarmAudioError] = []
        audio.onVoiceCueEvent = { events.append(($0.id, $0.state, $0.source)) }
        audio.onSubtitleChange = { subtitles.append($0) }
        audio.onAudioError = { errors.append($0) }
        audio.playVoiceCue(id: "a")
        precondition(events.last?.1 == .dropped)
        try audio.start()
        precondition(errors.isEmpty)
        audio.playSoundEffect(id: "sfx.missing")
        guard case .assetUnavailable(id: "sfx.missing", kind: "sfx") = errors.last else {
            fatalError("Missing SFX was not reported")
        }
        audio.playMusic(season: .winter)
        guard case .assetUnavailable(id: "music.season.winter", kind: "music") = errors.last else {
            fatalError("Missing music was not reported")
        }
        audio.playAmbient(id: "ambient.missing")
        guard case .assetUnavailable(id: "ambient.missing", kind: "ambient") = errors.last else {
            fatalError("Missing ambience was not reported")
        }
        audio.playSoundEffect(id: "sfx.broken")
        guard case .playbackFailed(id: "sfx.broken", kind: "sfx") = errors.last else {
            fatalError("Invalid SFX was not reported")
        }
        for _ in 0..<3 { audio.playSoundEffect(id: "sfx.tap") }
        audio.playSoundEffect(id: "sfx.tap")
        guard case .soundEffectLimitReached(id: "sfx.tap", limit: 3) = errors.last else {
            fatalError("Concurrent SFX limit was not enforced")
        }
        try await Task.sleep(for: .milliseconds(600))
        audio.setLevels(.init(music: 0.8, ambient: 0.6))
        audio.playMusic(season: .spring)
        audio.playAmbient(id: "ambient.farm")
        precondition(audio.musicPlayer?.numberOfLoops == -1 && audio.ambientPlayer?.numberOfLoops == -1)
        precondition(abs((audio.musicPlayer?.volume ?? 0) - 0.8) < 0.001)
        precondition(abs((audio.ambientPlayer?.volume ?? 0) - 0.6) < 0.001)
        audio.playMusic(season: .summer)
        guard case .assetUnavailable(id: "music.season.summer", kind: "music") = errors.last else {
            fatalError("Missing music file was not reported")
        }
        precondition(audio.musicPlayer?.isPlaying == true)
        audio.playAmbient(id: "ambient.once")
        precondition(audio.ambientPlayer?.numberOfLoops == 0)
        audio.playAmbient(id: "ambient.farm")
        audio.playVoiceCue(id: "unknown")
        precondition(events.last?.1 == .failed)
        audio.playVoiceCue(id: "missing")
        precondition(events.last?.1 == .failed)
        audio.playVoiceCue(id: "a", priority: .normal, text: "Hallo")
        precondition(events.last?.1 == .started)
        precondition(events.last?.2 == .recording)
        precondition(subtitles.last! == "Hallo")
        precondition(abs((audio.musicPlayer?.volume ?? 0) - 0.2) < 0.001)
        precondition(abs((audio.ambientPlayer?.volume ?? 0) - 0.3) < 0.001)
        audio.setLevels(.init(music: 0.4, ambient: 0.8))
        precondition(abs((audio.musicPlayer?.volume ?? 0) - 0.1) < 0.001)
        precondition(abs((audio.ambientPlayer?.volume ?? 0) - 0.4) < 0.001)
        audio.playVoiceCue(id: "b", priority: .low)
        precondition(events.last?.1 == .dropped)
        audio.playVoiceCue(id: "b", priority: .normal)
        precondition(events.last?.1 == .queued)
        audio.playVoiceCue(id: "c", priority: .high)
        precondition(events.suffix(2).map(\.1) == [.interrupted, .started])
        audio.pause()
        precondition(audio.ambientPlayer?.isPlaying == false)
        audio.playVoiceCue(id: "a")
        precondition(events.last?.1 == .dropped)
        audio.resume()
        precondition(audio.ambientPlayer?.isPlaying == true)
        audio.stop()
        precondition(audio.ambientPlayer == nil)
        precondition(events.suffix(2).map(\.1) == [.interrupted, .dropped])
        precondition(subtitles.last! == nil)

        try audio.start()
        audio.setLevels(.init(music: 0.8, ambient: 0.6))
        audio.playMusic(season: .spring)
        audio.playAmbient(id: "ambient.farm")
        events.removeAll()
        audio.playVoiceCue(id: "a", priority: .high)
        audio.playVoiceCue(id: "b", priority: .normal)
        audio.playVoiceCue(id: "c", priority: .high)
        try await Task.sleep(for: .seconds(3))
        let startedIDs = events.filter { $0.1 == .started }.map(\.0)
        precondition(startedIDs == ["a", "c", "b"], "Wrong queued order: \(startedIDs)")
        precondition(events.filter { $0.1 == .finished }.count == 3)
        precondition(abs((audio.musicPlayer?.volume ?? 0) - 0.8) < 0.001)
        precondition(abs((audio.ambientPlayer?.volume ?? 0) - 0.6) < 0.001)
        let musicBeforeClear = audio.musicPlayer
        let ambientBeforeClear = audio.ambientPlayer
        audio.playVoiceCue(id: "a", priority: .normal)
        audio.playVoiceCue(id: "b", priority: .normal)
        audio.clearVoiceCues()
        precondition(events.suffix(4).map(\.1) == [.started, .queued, .interrupted, .dropped])
        precondition(subtitles.last! == nil)
        precondition(audio.musicPlayer === musicBeforeClear && audio.ambientPlayer === ambientBeforeClear)
        precondition(audio.musicPlayer?.isPlaying == true && audio.ambientPlayer?.isPlaying == true)
        precondition(abs((audio.musicPlayer?.volume ?? 0) - 0.8) < 0.001)
        precondition(abs((audio.ambientPlayer?.volume ?? 0) - 0.6) < 0.001)
        audio.stop()

        let variantAudio = MiniFarmAudioController(bundle: bundle)
        var variantEvent: MiniFarmVoiceCueEvent?
        variantAudio.onVoiceCueEvent = { variantEvent = $0 }
        try variantAudio.start()
        variantAudio.playVoiceCue(id: "variants", text: "Variante Zwei")
        precondition(variantEvent?.state == .started && variantEvent?.source == .recording)
        variantAudio.stop()

        let projectAudio = URL(fileURLWithPath: manager.currentDirectoryPath)
            .appendingPathComponent("App/Resources/Audio", isDirectory: true)
        let projectManifestData = try Data(contentsOf: projectAudio.appendingPathComponent("manifest.json"))
        guard let projectManifest = try JSONSerialization.jsonObject(with: projectManifestData) as? [String: Any],
              let projectAssets = projectManifest["assets"] as? [[String: Any]],
              let projectVoice = projectAssets.first(where: {
                  guard $0["kind"] as? String == "voice" else { return false }
                  return ($0["path"] as? String) != nil || (($0["variants"] as? [[String: Any]])?.isEmpty == false)
              }) else {
            fatalError("No recorded voice is available for bundled MP3 playback testing")
        }
        let recordedVariant: [String: Any]
        if projectVoice["path"] as? String != nil {
            recordedVariant = projectVoice
        } else if let variant = (projectVoice["variants"] as? [[String: Any]])?.first {
            recordedVariant = variant
        } else {
            fatalError("Recorded voice row has no playable path")
        }
        guard let sourcePath = recordedVariant["path"] as? String,
              let recordedText = recordedVariant["text"] as? String ?? projectVoice["subtitle"] as? String,
              let recordedPeakNumber = recordedVariant["peak"] as? NSNumber else {
            fatalError("Recorded voice row has incomplete playback metadata")
        }
        let recordedPeak = recordedPeakNumber.floatValue
        let recordedBundleRoot = root.appendingPathComponent("offline.bundle", isDirectory: true)
        let recordedResources = recordedBundleRoot
            .appendingPathComponent("Contents/Resources/Audio", isDirectory: true)
        try manager.createDirectory(at: recordedResources, withIntermediateDirectories: true)
        let recordedFile = recordedResources.appendingPathComponent("recording.mp3")
        try Data(contentsOf: projectAudio.appendingPathComponent(sourcePath)).write(to: recordedFile)
        let recordedManifest: [String: Any] = [
            "schemaVersion": 1,
            "assets": [[
                "id": "offline.recording", "kind": "voice", "path": "recording.mp3",
                "subtitle": recordedText, "locale": "de-DE", "peak": recordedPeak,
            ]],
        ]
        let recordedManifestData = try JSONSerialization.data(withJSONObject: recordedManifest)
        try recordedManifestData.write(to: recordedResources.appendingPathComponent("manifest.json"))
        guard let recordedBundle = Bundle(url: recordedBundleRoot) else {
            fatalError("Recorded voice fixture bundle unavailable")
        }
        let recordedAudioFile = try AVAudioFile(forReading: recordedFile)
        let recordedDuration = Double(recordedAudioFile.length) / recordedAudioFile.processingFormat.sampleRate
        let recordedAudio = MiniFarmAudioController(bundle: recordedBundle)
        var recordedEvent: MiniFarmVoiceCueEvent?
        recordedAudio.onVoiceCueEvent = { recordedEvent = $0 }
        try recordedAudio.start()
        recordedAudio.playVoiceCue(id: "offline.recording", text: recordedText)
        precondition(recordedEvent?.state == .started && recordedEvent?.source == .recording)
        try await Task.sleep(for: .seconds(recordedDuration + 1))
        precondition(recordedEvent?.state == .finished, "Bundled MP3 did not finish playing")
        recordedAudio.stop()

        let mismatchAudio = MiniFarmAudioController(bundle: bundle, germanVoiceLookupProvider: { nil })
        var mismatchEvent: MiniFarmVoiceCueEvent?
        var mismatchSubtitle: String?
        mismatchAudio.onVoiceCueEvent = { mismatchEvent = $0 }
        mismatchAudio.onSubtitleChange = { mismatchSubtitle = $0 }
        try mismatchAudio.start()
        mismatchAudio.playVoiceCue(id: "a", text: "Anderer Satz")
        for _ in 0..<100 where mismatchEvent == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        precondition(mismatchEvent?.state == .unavailable && mismatchEvent?.source == nil)
        precondition(mismatchSubtitle == "Anderer Satz")
        mismatchAudio.stop()

        try manager.removeItem(at: resources.appendingPathComponent("manifest.json"))
        let fallback = MiniFarmAudioController(bundle: bundle)
        var fallbackEvent: MiniFarmVoiceCueEvent?
        var fallbackSubtitle: String?
        var manifestError: MiniFarmAudioError?
        fallback.onVoiceCueEvent = { fallbackEvent = $0 }
        fallback.onSubtitleChange = { fallbackSubtitle = $0 }
        fallback.onAudioError = { manifestError = $0 }
        try fallback.start()
        guard case .manifestMissing = manifestError else { fatalError("Missing manifest was not reported") }
        fallback.playVoiceCue(id: "not-in-manifest", text: "Hallo vom Hof")
        precondition(fallbackSubtitle == "Hallo vom Hof")
        fallback.updateProfileSettings(.init(speechRate: 0.4))
        for _ in 0..<150 where fallbackEvent?.state != .started && fallbackEvent?.state != .unavailable {
            try await Task.sleep(for: .milliseconds(20))
        }
        precondition(fallbackEvent?.state == .started || fallbackEvent?.state == .unavailable)
        if fallbackEvent?.state == .started {
            precondition(fallbackEvent?.source == .localSynthesized)
        } else {
            precondition(fallbackEvent?.source == nil)
        }
        fallback.stop()

        let unavailable = MiniFarmAudioController(bundle: bundle, germanVoiceLookupProvider: { nil })
        var unavailableEvent: MiniFarmVoiceCueEvent?
        var unavailableSubtitle: String?
        unavailable.onVoiceCueEvent = { unavailableEvent = $0 }
        unavailable.onSubtitleChange = { unavailableSubtitle = $0 }
        try unavailable.start()
        unavailable.playVoiceCue(id: "no-voice", text: "Guten Morgen")
        for _ in 0..<100 where unavailableEvent == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        precondition(unavailableEvent?.state == .unavailable)
        precondition(unavailableEvent?.source == nil)
        precondition(unavailableSubtitle == "Guten Morgen")
        unavailable.updateProfileSettings(.init(subtitlesEnabled: false))
        precondition(unavailableSubtitle == nil)
        unavailable.updateProfileSettings(.init(subtitlesEnabled: true))
        precondition(unavailableSubtitle == "Guten Morgen")
        unavailable.stop()
        precondition(unavailableSubtitle == nil)

        let mutedLookupCount = VoiceLookupCounter()
        let muted = MiniFarmAudioController(bundle: bundle, germanVoiceLookupProvider: {
            await mutedLookupCount.increment()
            return nil
        })
        var mutedEvent: MiniFarmVoiceCueEvent?
        muted.onVoiceCueEvent = { mutedEvent = $0 }
        try muted.start()
        muted.updateProfileSettings(.init(levels: .init(voice: 0)))
        muted.playVoiceCue(id: "muted", text: "Leise bleiben")
        precondition(mutedEvent?.state == .unavailable)
        try await Task.sleep(for: .milliseconds(80))
        let mutedLookupCalls = await mutedLookupCount.value()
        precondition(mutedLookupCalls == 0)
        muted.stop()

        let slowLookupCount = VoiceLookupCounter()
        let slowLookup = MiniFarmAudioController(bundle: bundle, germanVoiceLookupProvider: {
            await slowLookupCount.increment()
            try? await Task.sleep(for: .milliseconds(350))
            return nil
        })
        var slowEvents: [MiniFarmVoiceCueEvent] = []
        var slowSubtitle: String?
        slowLookup.onVoiceCueEvent = { slowEvents.append($0) }
        slowLookup.onSubtitleChange = { slowSubtitle = $0 }
        try slowLookup.start()
        let lookupRequestStart = ContinuousClock.now
        slowLookup.playVoiceCue(id: "old-profile", text: "Alter Hof")
        precondition(slowSubtitle == "Alter Hof")
        slowLookup.updateProfileSettings(.init(speechRate: 0.5))
        precondition(lookupRequestStart.duration(to: .now) < .milliseconds(250))
        slowLookup.pause()
        precondition(slowEvents.last?.state == .interrupted)
        slowLookup.resume()
        slowLookup.playVoiceCue(id: "new-profile", text: "Neuer Hof")
        precondition(slowSubtitle == "Neuer Hof")
        try await Task.sleep(for: .milliseconds(450))
        precondition(!slowEvents.contains { $0.id == "old-profile" && $0.state == .started })
        precondition(slowEvents.contains { $0.id == "new-profile" && $0.state == .unavailable })
        let slowLookupCalls = await slowLookupCount.value()
        precondition(slowLookupCalls == 1)
        slowLookup.stop()

        let hangingLookup = MiniFarmAudioController(bundle: bundle, germanVoiceLookupProvider: {
            try? await Task.sleep(for: .seconds(3))
            return nil
        })
        var hangingEvent: MiniFarmVoiceCueEvent?
        var hangingSubtitle: String?
        hangingLookup.onVoiceCueEvent = { hangingEvent = $0 }
        hangingLookup.onSubtitleChange = { hangingSubtitle = $0 }
        try hangingLookup.start()
        hangingLookup.playVoiceCue(id: "slow-system", text: "Das bleibt verfügbar")
        precondition(hangingSubtitle == "Das bleibt verfügbar")
        hangingLookup.updateProfileSettings(.init(speechRate: 0.6))
        try await Task.sleep(for: .seconds(2.2))
        precondition(hangingEvent?.state == .unavailable)
        try await Task.sleep(for: .seconds(1))
        precondition(hangingEvent?.state == .unavailable)
        hangingLookup.stop()

        let clearedLookup = MiniFarmAudioController(bundle: bundle, germanVoiceLookupProvider: {
            try? await Task.sleep(for: .milliseconds(250))
            return nil
        })
        var clearedEvents: [MiniFarmVoiceCueEvent] = []
        clearedLookup.onVoiceCueEvent = { clearedEvents.append($0) }
        try clearedLookup.start()
        clearedLookup.playVoiceCue(id: "cleared-profile", text: "Verworfen")
        clearedLookup.clearVoiceCues()
        try await Task.sleep(for: .milliseconds(350))
        precondition(clearedEvents.map(\.state) == [.interrupted])
        clearedLookup.stop()

        try "invalid".write(to: resources.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        let invalid = MiniFarmAudioController(bundle: bundle)
        invalid.onAudioError = { manifestError = $0 }
        manifestError = nil
        try invalid.start()
        guard case .manifestInvalid = manifestError else { fatalError("Invalid manifest was not reported") }
        invalid.stop()

        var rateSettings = MiniFarmAudioProfileSettings(speechRate: -1)
        precondition(rateSettings.speechRate == AVSpeechUtteranceMinimumSpeechRate)
        rateSettings.speechRate = 100
        precondition(rateSettings.speechRate == AVSpeechUtteranceMaximumSpeechRate)
        rateSettings.speechRate = .nan
        precondition(rateSettings.speechRate == AVSpeechUtteranceDefaultSpeechRate * 0.9)
        let mappedLevels = MiniFarmAudioLevels.applyingUserMultipliers(
            voice: 0.7, soundEffects: 0.5, music: 2, ambient: .nan
        )
        precondition(mappedLevels.voice == 0.7)
        precondition(mappedLevels.soundEffects == 0.3)
        precondition(mappedLevels.music == 0.25 && mappedLevels.ambient == 0)
        print("Audio smoke tests passed")
    }
}
