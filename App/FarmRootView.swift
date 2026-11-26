import SwiftUI
import AVFoundation

struct FarmRootView: View {
    @State private var family = FamilyStore.live()
    @State private var preview = MiniFarmAudioController()
    @State private var endPreview: Task<Void, Never>?
    @State private var soundError: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        FamilyRootView(store: family) { session in
            FarmSessionView(family: family, session: session)
        }
        .environment(\.familyAvatarArtwork, FamilyAvatarArtwork { AnyView(FarmPictogram(id: $0.rawValue)) })
        .onAppear { [family] in
            family.learningSummary = { [weak family] id in
                guard let family, family.isParentAreaUnlocked else { return [] }
                switch family.storage.saves(for: id).load(slot: "Farm", decode: FarmSavedGame.decode) {
                case .loaded(let saved), .recovered(let saved, _):
                    let labels = ["mathCount": "Zählen", "cogSequence": "Reihenfolgen erkennen",
                                  "cogMatching": "Zuordnen", "cogMemory": "Sich erinnern",
                                  "percShape": "Formen erkennen", "langVocab": "Wörter entdecken",
                                  "worldTime": "Den Hoftag erleben", "moTap": "Ziele antippen",
                                  "moDrag": "Dinge bewegen", "moSteer": "Fahrzeuge lenken"]
                    return saved.state.skills.confidence.filter { $0.value > 0 }
                        .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                        .compactMap { labels[$0.key] }.prefix(3).map { "Auf dem Hof geübt: \($0)." }
                case .empty: return []
                case .unavailable, .unrecoverable: return ["Der Lernstand ist gerade nicht lesbar."]
                }
            }
            family.previewSound = playPreview
        }
        .onChange(of: family.isParentAreaUnlocked) { _, unlocked in if !unlocked { stopPreview() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stopPreview() } }
        .alert("Tonprobe nicht verfügbar", isPresented: Binding(get: { soundError != nil }, set: { if !$0 { soundError = nil } })) {
            Button("OK") { soundError = nil }
        } message: { Text(soundError ?? "") }
    }

    private func playPreview(_ id: ProfileID, _ bus: AudioBus) {
        guard family.isParentAreaUnlocked, scenePhase == .active, let profile = family.profile(id) else { return }
        stopPreview()
        let settings = FamilyRuntimeSettings(profile: profile, system: family.systemAccessibility)
        do {
            try preview.start()
            preview.updateProfileSettings(settings.farmAudio)
            switch bus {
            case .voice: preview.playVoiceCue(id: "vl.pelle.greet.morning", priority: .normal, text: "Hallo! Schön, dass du da bist!")
            case .music: preview.playMusic(season: .spring)
            case .ambience: preview.playAmbient(id: "ambience.farm.day")
            case .sfx: preview.playSoundEffect(id: "sfx.ui.success")
            }
            endPreview = Task {
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                preview.stop()
            }
        } catch { soundError = error.localizedDescription }
    }

    private func stopPreview() {
        endPreview?.cancel()
        guard endPreview != nil else { return }
        endPreview = nil
        preview.stop()
    }
}

struct FarmSavedGame {
    let state: FarmState
    let date: Date

    static func decode(_ payload: StoredPayload) throws -> Self {
        guard payload.schemaVersion == 1 else { throw SaveDataUnsupported() }
        return try Self(state: JSONDecoder().decode(FarmState.self, from: payload.data), date: payload.savedAt)
    }
}

extension FamilyRuntimeSettings {
    var farmAudio: MiniFarmAudioProfileSettings {
        .init(levels: .init(voice: Float(voiceVolume), soundEffects: Float(sfxVolume),
                            music: Float(musicVolume), ambient: Float(ambienceVolume * idleSoundScale)),
              subtitlesEnabled: subtitles,
              speechRate: AVSpeechUtteranceDefaultSpeechRate * (slowSpeech ? 0.75 : 0.9))
    }
}
