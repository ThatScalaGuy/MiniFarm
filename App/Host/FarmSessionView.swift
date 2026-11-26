import AVFoundation
import SwiftUI

@MainActor
struct FarmSessionView: View {
    let family: FamilyStore
    let session: FamilySession
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: FarmGame?
    @State private var pauseMenu = false
    @State private var showPlaza = false
    @State private var decorationBox = false
    @State private var nightStory: FarmNightStory?
    @State private var parcel: FarmLevelParcel?
    @State private var album: FarmFestivalAlbum?
    @State private var caption: String?
    @State private var failure: String?
    @State private var audio = MiniFarmAudioController()
    @State private var audioStarted = false
    @State private var audioInterrupted = false
    @State private var musicSeason: MiniFarmSeason?
    @State private var accountedSeconds = 0

    var body: some View {
        ZStack {
            if let failure {
                ContentUnavailableView {
                    Label("Der Hof macht eine Pause", systemImage: "house.fill")
                } description: {
                    Text(failure)
                } actions: {
                    Button("Erneut öffnen", action: open)
                    Button("Zur Profilwahl") { family.endSession() }
                }
            } else if let game, let settings = family.runtimeSettings {
                FarmPlayView(state: game.worldSnapshot(settings: settings, caption: caption, showPlaza: showPlaza,
                                                       timer: family.sessionTimer.phase, story: nightStory,
                                                       paused: covered || family.isParentFlowActive || scenePhase != .active), send: receive)
                    .contrast(settings.highContrast ? 1.18 : 1)
                    .allowsHitTesting(!covered)
                    .accessibilityHidden(covered)
                if decorationBox {
                    FarmDecorationView(game: game, send: decorate, close: { decorationBox = false })
                }
                if let parcel {
                    FarmLevelParcelView(parcel: parcel, reduceMotion: settings.reduceMotion || settings.essentialSFXOnly,
                                        speak: readStory, close: { self.parcel = nil })
                }
                if let album {
                    FarmFestivalAlbumView(album: album, speak: readStory, close: { self.album = nil })
                }
            } else {
                ProgressView("Der Hof wacht auf")
            }
            if pauseMenu {
                FarmPauseMenu(
                    onContinue: { setPaused(false) },
                    onSleep: { setPaused(false); receive(.endDay) },
                    onProfiles: { family.endSession() },
                    onParents: { family.requestParentArea(); setPaused(false) }
                )
            }
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .onAppear(perform: open)
        .onDisappear {
            audio.stop()
            audio.onSubtitleChange = nil
            audio.onAudioError = nil
            audio.onVoiceCueEvent = nil
            audioStarted = false
            musicSeason = nil
        }
        .onChange(of: scenePhase) { _, _ in updateAudio() }
        .onChange(of: family.isParentFlowActive) { _, _ in updateAudio() }
        .onChange(of: pauseMenu) { _, _ in updateAudio() }
        .onChange(of: failure) { _, _ in updateAudio() }
        .onChange(of: game?.season) { _, _ in updateAudio() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            audioInterrupted = type == .began
            if type == .ended {
                let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if !AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    setPaused(true)
                }
            }
            updateAudio()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { note in
            if let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                setPaused(true)
                audio.pause()
            }
        }
        .onChange(of: family.runtimeSettings) { _, value in
            guard let value, var updated = game else { return }
            apply(value, to: &updated)
            store(updated)
            updateAudio()
        }
    }

    private var covered: Bool { pauseMenu || decorationBox || parcel != nil || album != nil }

    private func notifyParents(_ message: String) {
        if !family.notices.contains(where: { $0.message == message }) { family.addNotice(message) }
    }

    private func readStory(_ text: String) {
        audio.clearVoiceCues()
        caption = text
        audio.playVoiceCue(id: "vl.story.local", priority: .high, text: text)
    }

    private func open() {
        do {
            let catalog = try FarmCatalog.load(from: Bundle.main.bundleURL.appendingPathComponent("Content", isDirectory: true))
            let outcome = session.saves.load(slot: "Farm", decode: FarmSavedGame.decode)
            let opening: FarmGame
            var daysAway = 0
            switch outcome {
            case .empty:
                opening = FarmGame(catalog: catalog, stage: stage(session.profile.stage))
            case .loaded(let saved), .recovered(let saved, _):
                if case .recovered = outcome { notifyParents("Der Hof wurde aus seiner Sicherungskopie wiederhergestellt.") }
                opening = FarmGame(catalog: catalog, state: saved.state)
                let calendar = Calendar.current
                daysAway = calendar.dateComponents([.day], from: calendar.startOfDay(for: saved.date),
                                                    to: calendar.startOfDay(for: .now)).day ?? 0
            case .unavailable:
                failure = "Der Spielstand ist gerade nicht lesbar oder braucht eine neuere App. Er wurde nicht ersetzt."
                return
            case .unrecoverable:
                failure = "Beide Kopien des Spielstands sind beschädigt. Sie wurden gesichert. Erneutes Öffnen startet einen neuen Hof."
                return
            }
            var configured = opening
            if let settings = family.runtimeSettings { apply(settings, to: &configured) }
            configured.resume(afterDays: daysAway)
            guard store(configured) else { return }
            failure = nil
            audio.onSubtitleChange = { caption = $0 }
            audio.onVoiceCueEvent = { event in
                if event.state == .unavailable {
                    notifyParents("Für diesen Satz ist keine deutsche Stimme verfügbar. Die Bildzeichen bleiben nutzbar.")
                }
            }
            audio.onAudioError = { error in
                switch error {
                case .manifestMissing, .manifestInvalid: notifyParents("Der Tonkatalog ist nicht verfügbar.")
                case .assetUnavailable, .playbackFailed: notifyParents("Ein lokaler Ton konnte nicht abgespielt werden.")
                }
            }
            updateAudio()
            if let prompt = configured.prompt {
                audio.playVoiceCue(id: prompt.voiceID, priority: .high, text: prompt.text)
            } else {
                audio.playVoiceCue(id: "vl.pelle.greet.morning", priority: .high, text: "Hallo! Schön, dass du da bist!")
            }
        } catch {
            failure = "Die Hofinhalte konnten nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    private func stage(_ stage: ProfileStage) -> FarmStage {
        switch stage {
        case .sprout: .sprout
        case .shoot: .shoot
        case .bloom: .bloom
        }
    }

    private func apply(_ settings: FamilyRuntimeSettings, to game: inout FarmGame) {
        game.configure(stage: nil, adaptive: settings.adaptivityEnabled,
                       memory: settings.memoryMode, hintDelayScale: settings.hintDelayScale)
        game.applyProfileStage(stage(settings.startStage), revision: settings.stageRevision, locked: settings.stageLocked)
    }

    private func setPaused(_ paused: Bool) {
        pauseMenu = paused
        family.setGamePaused(paused)
    }

    private func updateAudio() {
        guard scenePhase == .active, !audioInterrupted, !family.isParentFlowActive, !pauseMenu, failure == nil,
              let game, let settings = family.runtimeSettings else {
            if audioStarted { audio.pause() }
            return
        }
        do {
            if !audioStarted {
                try audio.start()
                audioStarted = true
            } else {
                audio.resume()
            }
            audio.updateProfileSettings(settings.farmAudio)
            if let season = MiniFarmSeason(rawValue: String(game.season.dropFirst("season.".count))),
               season != musicSeason {
                audio.playMusic(season: season)
                if musicSeason == nil { audio.playAmbient(id: "ambience.farm.day") }
                musicSeason = season
            }
        } catch {
            notifyParents("Sprachausgabe momentan nicht verfügbar: \(error.localizedDescription)")
        }
    }

    private func receive(_ input: FarmWorldIntent) {
        guard scenePhase == .active, !family.isParentFlowActive, !covered, let before = game else { return }
        var updated = before
        let seconds = Int(family.sessionTimer.elapsed)
        updated.recordPlay(seconds: max(0, seconds - accountedSeconds))
        switch input {
        case .horn:
            audio.playSoundEffect(id: "sfx.tractor.horn")
        case .closeNightStory:
            nightStory = nil
            audio.clearVoiceCues()
            if case .windDown = family.sessionTimer.phase { family.windDownFinished() }
        case .readStory(let text): readStory(text)
        case .decorationBox:
            audio.clearVoiceCues()
            decorationBox = true
        case .pause:
            setPaused(true)
        case .readSticker(let id):
            guard updated.state.book.contains(id), let entry = updated.catalog.hofbook.first(where: { $0.id == id }) else { return }
            audio.clearVoiceCues()
            if let festival = FarmFestivalAlbum(entryID: id, game: updated) {
                album = festival
                return
            }
            caption = entry.fact
            audio.playVoiceCue(id: "vl.book." + id.dropFirst("hofbook.".count), priority: .high, text: entry.fact)
        default:
            guard let intent = updated.gameIntent(for: input) else { return }
            let previousTurn = updated.state.active
            let giver = previousTurn?.wishID.flatMap { id in updated.state.outstanding.first(where: { $0.id == id })?.giver }
            let feedback = updated.send(intent)
            guard store(updated) else { return }
            accountedSeconds = seconds
            switch input {
            case .visit(let id): showPlaza = id == "loc.plaza"
            case .leaveActivity, .endDay: showPlaza = false
            default: break
            }
            if case .idleHint = input, previousTurn?.assist == updated.state.active?.assist { return }
            audio.clearVoiceCues()
            caption = feedback.text
            if feedback.completed {
                if previousTurn?.activityID.hasPrefix("act.animal.") == true,
                   let giver, let species = updated.catalog.animals.first(where: { giver.hasPrefix($0.id) }),
                   let sound = species.sounds.first {
                    audio.playSoundEffect(id: sound)
                } else {
                    audio.playSoundEffect(id: "sfx.ui.success")
                }
            }
            audio.playVoiceCue(id: feedback.voiceID, priority: .high, text: feedback.text)
            if updated.season != before.season, let greeting = updated.catalog.seasons.first(where: { $0.id == updated.season }) {
                audio.playVoiceCue(id: "vl.\(greeting.id).greet", priority: .normal,
                                   text: "Jetzt ist \(greeting.title) auf dem Hof.")
            }
            if input == .endDay { nightStory = FarmNightStory(before: before, after: updated) }
            parcel = FarmLevelParcel(before: before, after: updated)
        }
    }

    private func decorate(_ intent: FarmIntent) {
        guard scenePhase == .active, !family.isParentFlowActive, !pauseMenu, decorationBox, var updated = game else { return }
        let feedback = updated.send(intent)
        guard store(updated) else { return }
        audio.clearVoiceCues()
        audio.playVoiceCue(id: feedback.voiceID, priority: .normal, text: feedback.text)
    }

    @discardableResult
    private func store(_ updated: FarmGame) -> Bool {
        do {
            try session.saves.save(updated.state, slot: "Farm", schemaVersion: 1)
            game = updated
            return true
        } catch let error as FamilyStorageError where error.isDiscardable {
            return false
        } catch {
            failure = "Dein letzter Schritt konnte nicht gesichert werden. Der vorherige Spielstand bleibt erhalten: \(error.localizedDescription)"
            return false
        }
    }
}
