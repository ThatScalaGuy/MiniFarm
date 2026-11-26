import Foundation
import AVFoundation

// Standalone smoke test; compile with the controller as documented below.
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
          {"id":"a","kind":"voice","path":"silence.wav","subtitle":"Hallo"},
          {"id":"b","kind":"voice","path":"silence.wav","subtitle":"Gut"},
          {"id":"c","kind":"voice","path":"silence.wav","subtitle":"Hier"},
          {"id":"missing","kind":"voice","path":"missing.wav"},
          {"id":"sfx.tap","kind":"sfx","path":"silence.wav"},
          {"id":"sfx.broken","kind":"sfx","path":"broken.wav"},
          {"id":"music.season.spring","kind":"music","path":"silence.wav","loop":true},
          {"id":"music.season.summer","kind":"music","path":"absent.wav"},
          {"id":"ambient.farm","kind":"ambient","path":"silence.wav","loop":true},
          {"id":"ambient.once","kind":"ambient","path":"silence.wav"}
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
        var events: [(String, MiniFarmVoiceCueEvent.State)] = []
        var subtitles: [String?] = []
        var errors: [MiniFarmAudioError] = []
        audio.onVoiceCueEvent = { events.append(($0.id, $0.state)) }
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
        audio.playVoiceCue(id: "a", priority: .normal, text: "Katalogtext")
        precondition(events.last?.1 == .started)
        precondition(subtitles.last! == "Katalogtext")
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
        precondition(fallbackEvent?.state == .started || fallbackEvent?.state == .unavailable)
        if fallbackEvent?.state == .started {
            precondition(fallbackEvent?.source == .localSynthesized)
        } else {
            precondition(fallbackEvent?.source == nil)
        }
        fallback.stop()

        let unavailable = MiniFarmAudioController(bundle: bundle, germanVoiceProvider: { nil })
        var unavailableEvent: MiniFarmVoiceCueEvent?
        var unavailableSubtitle: String?
        unavailable.onVoiceCueEvent = { unavailableEvent = $0 }
        unavailable.onSubtitleChange = { unavailableSubtitle = $0 }
        try unavailable.start()
        unavailable.playVoiceCue(id: "no-voice", text: "Guten Morgen")
        precondition(unavailableEvent?.state == .unavailable)
        precondition(unavailableEvent?.source == nil)
        precondition(unavailableSubtitle == "Guten Morgen")
        unavailable.updateProfileSettings(.init(subtitlesEnabled: false))
        precondition(unavailableSubtitle == nil)
        unavailable.updateProfileSettings(.init(subtitlesEnabled: true))
        precondition(unavailableSubtitle == "Guten Morgen")
        unavailable.stop()
        precondition(unavailableSubtitle == nil)

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
        print("Audio smoke tests passed")
    }
}
