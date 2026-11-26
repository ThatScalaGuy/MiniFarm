import SwiftUI

/// Settings of one profile (doc 11 §9, doc 17 §2, doc 18 §4).
struct ProfileDetailView: View {
    let store: FamilyStore
    let profileID: ProfileID
    let onRemoved: () -> Void

    @State private var pending = PendingSliders()
    @State private var confirmReset = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        if let profile = store.profile(profileID) {
            form(profile)
        } else {
            Text("Dieses Profil gibt es nicht mehr.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func form(_ profile: FamilyProfile) -> some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    ProfileAvatarFrame(avatar: profile.avatar, size: 72)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text("Profil \(profile.avatar.displayName)")
                            .font(.title3.bold())
                        Text("Angelegt am \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            learningSection(profile)
            companionSection
            sessionSection(profile)
            audioSection(profile)
            comfortSection(profile)
            dataSection
        }
        .navigationTitle(profile.avatar.displayName)
        .onAppear { store.noteParentActivity() }
        .onDisappear { commitPending() }
        .task(id: pending) {
            guard !pending.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            commitPending()
        }
        .confirmationDialog("Fortschritt zurücksetzen?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Hof neu beginnen", role: .destructive) {
                perform { try store.resetProgress(profileID) }
                if errorMessage == nil { infoMessage = "Der Hof beginnt beim nächsten Spielen neu. Die Einstellungen bleiben." }
            }
            .accessibilityIdentifier("family.confirm.reset")
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Hof, Hofbuch und Lernstand dieses Profils werden gelöscht. Die Einstellungen bleiben.")
        }
        .confirmationDialog("Profil löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Profil löschen", role: .destructive) {
                perform { try store.deleteProfile(profileID) }
                if errorMessage == nil { onRemoved() }
            }
            .accessibilityIdentifier("family.confirm.delete")
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Das Profil und sein Hof werden von diesem Gerät gelöscht. Das kann nicht rückgängig gemacht werden.")
        }
        .alert("Das hat nicht geklappt", isPresented: present($errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Erledigt", isPresented: present($infoMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
    }

    // MARK: Sections

    private func learningSection(_ profile: FamilyProfile) -> some View {
        Section {
            Picker("Startniveau", selection: stageBinding) {
                ForEach(ProfileStage.allCases) { stage in
                    Text(stage.parentLabel).tag(stage)
                }
            }
            .accessibilityIdentifier("family.profile.stage")
            Toggle("Stufe automatisch anpassen", isOn: setting(\.learning.adaptivityEnabled))
                .accessibilityIdentifier("family.profile.adaptivity")
            Toggle("Merk-Modus erlauben", isOn: setting(\.learning.memoryMode))
            Picker("Hilfen", selection: setting(\.learning.helpTiming)) {
                ForEach(HelpTiming.allCases) { timing in
                    Text(timing.parentLabel).tag(timing)
                }
            }
        } header: {
            Text("Lernen")
        } footer: {
            Text("Ohne automatische Anpassung bleibt Ihr Kind auf dem Startniveau. Im Merk-Modus verschwindet die Bilderblase nach drei Sekunden, ein Tippen zeigt sie wieder. Hilfen kommen früher oder später, sie werden nie zur Strafe.")
        }
    }

    private var companionSection: some View {
        Section("Lernbegleitung") {
            let lines = store.learningSummary?(profileID) ?? []
            if lines.isEmpty {
                Text("Noch keine Hinweise. Sie erscheinen, wenn Ihr Kind gespielt hat.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                }
            }
            Text("Tipp: Fragen Sie nach dem Spielen, welches Tier heute Hilfe brauchte, und zählen Sie gemeinsam Dinge im Alltag.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func sessionSection(_ profile: FamilyProfile) -> some View {
        Section {
            Picker("Spielzeit", selection: setting(\.session.timerMinutes)) {
                Text("Aus").tag(Int?.none)
                ForEach(SessionSettings.timerOptions, id: \.self) { minutes in
                    Text("\(minutes) Min").tag(Int?.some(minutes))
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("family.profile.timer")
        } header: {
            Text("Spielzeit")
        } footer: {
            Text("Kurz vor Ende wird der Hof müde. Dann folgt ein Abendritual mit Ihrem Kind, ohne harten Abbruch. Wenn es länger dauert, schläft der Hof nach drei Minuten sanft ein.")
        }
    }

    private func audioSection(_ profile: FamilyProfile) -> some View {
        Section {
            ForEach(AudioBus.allCases) { bus in
                HStack(spacing: 12) {
                    Text(bus.parentLabel)
                        .frame(minWidth: 96, alignment: .leading)
                    Slider(value: volumeBinding(bus), in: 0...1) { editing in
                        if !editing {
                            commitPending()
                            store.previewSound?(profileID, bus)
                        }
                    }
                    .accessibilityLabel("Lautstärke \(bus.parentLabel)")
                    .accessibilityIdentifier("family.profile.volume.\(bus.rawValue)")
                    if store.previewSound != nil {
                        Button {
                            commitPending()
                            store.previewSound?(profileID, bus)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(bus.parentLabel) anhören")
                    }
                }
            }
            Toggle("Leises Spiel", isOn: setting(\.audio.quietGame))
            Toggle("Langsamere Sprache", isOn: setting(\.audio.slowSpeech))
            Toggle("Untertitel", isOn: setting(\.audio.subtitles))
            Toggle("Mono-Audio", isOn: setting(\.audio.monoAudio))
        } header: {
            Text("Ton")
        } footer: {
            Text("„Leises Spiel“ schaltet Musik und Umgebung aus. Sprache und wichtige Klänge bleiben, denn das Spiel erklärt sich über Bilder und Stimme.")
        }
    }

    private func comfortSection(_ profile: FamilyProfile) -> some View {
        Section {
            Picker("Ruhe", selection: setting(\.comfort.calmMode)) {
                ForEach(CalmMode.allCases) { mode in
                    Text(mode.parentLabel).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("family.profile.calmMode")
            Toggle("Weniger Bewegung", isOn: setting(\.comfort.reduceMotion))
            HStack(spacing: 12) {
                Text("Effekte")
                    .frame(minWidth: 96, alignment: .leading)
                Slider(value: effectsBinding, in: 0...1) { editing in
                    if !editing { commitPending() }
                }
                .accessibilityLabel("Stärke der Effekte")
            }
            Toggle("Hoher Kontrast", isOn: setting(\.comfort.highContrast))
            Toggle("Größere Symbole", isOn: setting(\.comfort.largeSymbols))
            Toggle("Vibration", isOn: setting(\.comfort.hapticsEnabled))
            ForEach(ComfortPreset.allCases) { preset in
                Button(preset.parentLabel) {
                    commitPending()
                    perform { try store.updateSettings(profileID) { $0.apply(preset) } }
                }
            }
        } header: {
            Text("Ruhe und Sehen")
        } footer: {
            Text("„Ruhig“ dämpft Musik, Partikel und Wetter. „Sehr ruhig“ lässt nur das Nötigste. Einstellungen des Geräts wie „Bewegung reduzieren“ gelten immer zusätzlich.")
        }
    }

    private var dataSection: some View {
        Section {
            Button("Fortschritt zurücksetzen", role: .destructive) { confirmReset = true }
                .accessibilityIdentifier("family.profile.reset")
            Button("Profil löschen", role: .destructive) { confirmDelete = true }
                .accessibilityIdentifier("family.profile.delete")
        } header: {
            Text("Daten")
        } footer: {
            Text("Beim Zurücksetzen bleiben Tierbild und Einstellungen erhalten.")
        }
    }

    // MARK: Bindings

    private var currentSettings: ProfileSettings {
        store.profile(profileID)?.settings ?? ProfileSettings()
    }

    private var stageBinding: Binding<ProfileStage> {
        Binding(
            get: { store.profile(profileID)?.stage ?? .sprout },
            set: { stage in perform { try store.updateProfile(profileID) { $0.stage = stage } } }
        )
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<ProfileSettings, Value>) -> Binding<Value> {
        Binding(
            get: { currentSettings[keyPath: keyPath] },
            set: { value in
                commitPending()
                perform { try store.updateSettings(profileID) { $0[keyPath: keyPath] = value } }
            }
        )
    }

    private func volumeBinding(_ bus: AudioBus) -> Binding<Double> {
        Binding(
            get: { pending.volumes[bus] ?? currentSettings.audio[bus] },
            set: { pending.volumes[bus] = $0 }
        )
    }

    private var effectsBinding: Binding<Double> {
        Binding(
            get: { pending.effects ?? currentSettings.comfort.effectsIntensity },
            set: { pending.effects = $0 }
        )
    }

    private func commitPending() {
        guard !pending.isEmpty else { return }
        let values = pending
        pending = PendingSliders()
        guard store.isParentAreaUnlocked else { return }
        perform {
            try store.updateSettings(profileID) { settings in
                for (bus, volume) in values.volumes { settings.audio[bus] = volume }
                if let effects = values.effects { settings.comfort.effectsIntensity = min(max(effects, 0), 1) }
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        store.noteParentActivity()
        do {
            try action()
        } catch {
            errorMessage = FamilyErrorText.message(for: error)
        }
    }

    private func present(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
    }
}

/// Slider values that are not saved yet. Saved after a short pause or when the finger lifts.
private struct PendingSliders: Equatable {
    var volumes: [AudioBus: Double] = [:]
    var effects: Double?

    var isEmpty: Bool { volumes.isEmpty && effects == nil }
}
