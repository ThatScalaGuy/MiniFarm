import SwiftUI

enum ParentRoute: Hashable {
    case profile(ProfileID)
    case newProfile
    case data
    case info(FamilyInfoTopic)
}

/// Parent area: plain adult UI, Dynamic Type, full VoiceOver (doc 17 §2).
struct ParentAreaView: View {
    let store: FamilyStore

    @State private var path: [ParentRoute] = []
    @State private var confirmDeleteAll = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !store.notices.isEmpty || store.hasUnavailableProfiles {
                    Section("Hinweise") {
                        if store.hasUnavailableProfiles {
                            Text("Ein Profil kann gerade nicht gelesen werden. Seine Daten bleiben erhalten. Entsperren Sie das Gerät oder aktualisieren Sie MiniFarm.")
                                .accessibilityIdentifier("family.parent.unavailableHint")
                        }
                        ForEach(store.notices) { notice in
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                                    .accessibilityHidden(true)
                                Text(notice.message)
                                Spacer()
                                Button("OK") { store.dismissNotice(notice.id) }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                profilesSection
                Section {
                    NavigationLink(value: ParentRoute.data) {
                        Label("Was ist gespeichert?", systemImage: "internaldrive")
                    }
                    .accessibilityIdentifier("family.parent.data")
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Alle Daten löschen", systemImage: "trash")
                    }
                    .disabled(store.profiles.isEmpty)
                    .accessibilityIdentifier("family.parent.deleteAll")
                } header: {
                    Text("Daten")
                } footer: {
                    Text("Alles bleibt auf diesem Gerät. \(FamilyInfo.offlineNote)")
                }
                Section("Info") {
                    ForEach(FamilyInfoTopic.allCases) { topic in
                        NavigationLink(value: ParentRoute.info(topic)) {
                            Label(topic.title, systemImage: topic.systemImage)
                        }
                        .accessibilityIdentifier("family.parent.info.\(topic.rawValue)")
                    }
                }
            }
            .navigationTitle("Elternbereich")
            .keepsParentAreaAwake(store)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { store.closeParentArea() }
                        .accessibilityIdentifier("family.parent.done")
                }
            }
            .navigationDestination(for: ParentRoute.self) { route in
                destination(route)
            }
            .confirmationDialog(
                "Alle Profile und Spielstände auf diesem Gerät löschen?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Alle Daten löschen", role: .destructive) {
                    perform { try store.deleteAllData() }
                    path = []
                }
                .accessibilityIdentifier("family.confirm.deleteAll")
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das kann nicht rückgängig gemacht werden.")
            }
            .alert("Das hat nicht geklappt", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onChange(of: path) { _, _ in store.noteParentActivity() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("family.parent")
        .accessibilityAddTraits(.isModal)
    }

    private var profilesSection: some View {
        Section {
            ForEach(store.profiles) { profile in
                NavigationLink(value: ParentRoute.profile(profile.id)) {
                    HStack(spacing: 14) {
                        ProfileAvatarFrame(avatar: profile.avatar, size: 48)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(profile.avatar.displayName)
                                .font(.headline)
                            Text(profile.stage.parentLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("family.parent.profile.\(profile.avatar.rawValue)")
            }
            if store.canAddProfile {
                NavigationLink(value: ParentRoute.newProfile) {
                    Label("Profil hinzufügen", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("family.parent.addProfile")
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Bis zu \(FamilyStore.maxProfiles) Profile, jedes mit eigenem Hof. Gespeichert werden nur Tierbild, Stufe und Einstellungen, kein Name und kein Foto.")
        }
    }

    @ViewBuilder
    private func destination(_ route: ParentRoute) -> some View {
        destinationContent(route)
            .keepsParentAreaAwake(store)
    }

    @ViewBuilder
    private func destinationContent(_ route: ParentRoute) -> some View {
        switch route {
        case .profile(let id):
            ProfileDetailView(store: store, profileID: id) { path = [] }
        case .newProfile:
            NewProfileView(store: store) { created in
                path = [.profile(created.id)]
            }
        case .data:
            DataOverviewView(store: store)
        case .info(let topic):
            FamilyInfoView(topic: topic)
                .onAppear { store.noteParentActivity() }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = FamilyErrorText.message(for: error)
        }
    }
}

extension View {
    /// Scrolling counts as parent activity, so reading long texts does not lock the area.
    /// It only observes the scroll view. Never add a tap gesture here: it blocks `NavigationLink` taps.
    func keepsParentAreaAwake(_ store: FamilyStore) -> some View {
        onScrollPhaseChange { _, phase in
            if phase == .interacting { store.noteParentActivity() }
        }
    }
}

enum FamilyErrorText {
    static func message(for error: Error) -> String {
        switch error {
        case FamilyStoreError.parentAreaLocked:
            "Der Elternbereich wurde aus Sicherheitsgründen gesperrt. Bitte erneut öffnen."
        case FamilyStoreError.tooManyProfiles:
            "Es sind schon \(FamilyStore.maxProfiles) Profile angelegt."
        case FamilyStoreError.avatarInUse:
            "Dieses Tier gehört schon zu einem anderen Profil."
        case FamilyStoreError.unknownProfile, FamilyStorageError.profileMissing:
            "Dieses Profil gibt es nicht mehr."
        case FamilyStorageError.existingDataUnavailable:
            "Die Daten sind gerade nicht lesbar. Bitte das Gerät entsperren und es später noch einmal versuchen."
        default:
            "Die Daten konnten nicht gespeichert werden. Bitte später noch einmal versuchen."
        }
    }
}

/// New profile: pick a free animal and a start stage.
struct NewProfileView: View {
    let store: FamilyStore
    let onCreated: (FamilyProfile) -> Void

    @State private var avatar: ProfileAvatar?
    @State private var stage = ProfileStage.sprout
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 16)], spacing: 16) {
                    ForEach(store.freeAvatars) { option in
                        Button {
                            avatar = option
                            store.noteParentActivity()
                        } label: {
                            VStack(spacing: 6) {
                                ProfileAvatarFrame(avatar: option, size: 80, highContrast: avatar == option)
                                    .overlay(alignment: .topTrailing) {
                                        if avatar == option {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.white, .green)
                                                .offset(x: 6, y: -6)
                                        }
                                    }
                                Text(option.displayName)
                                    .font(.footnote)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(option.displayName)
                        .accessibilityAddTraits(avatar == option ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("family.newProfile.avatar.\(option.rawValue)")
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Tierbild")
            } footer: {
                Text("Ihr Kind erkennt sein Profil an diesem Tier.")
            }
            Section {
                ForEach(ProfileStage.allCases) { option in
                    Button {
                        stage = option
                        store.noteParentActivity()
                    } label: {
                        HStack {
                            Text(option.parentLabel)
                                .foregroundStyle(.primary)
                            Spacer()
                            if stage == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityAddTraits(stage == option ? .isSelected : [])
                    .accessibilityIdentifier("family.newProfile.stage.\(option.rawValue)")
                }
            } header: {
                Text("Startniveau")
            } footer: {
                Text("Das Spiel passt sich danach behutsam an. Sie können das jederzeit ändern.")
            }
        }
        .navigationTitle("Neues Profil")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Profil anlegen") { create() }
                    .disabled(avatar == nil)
                    .accessibilityIdentifier("family.newProfile.create")
            }
        }
        .onAppear {
            store.noteParentActivity()
            if avatar == nil { avatar = store.freeAvatars.first }
        }
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func create() {
        guard let avatar else { return }
        do {
            let profile = try store.createProfile(avatar: avatar, stage: stage)
            onCreated(profile)
        } catch {
            errorMessage = FamilyErrorText.message(for: error)
        }
    }
}

/// "Was ist gespeichert?" (doc 17 §2).
struct DataOverviewView: View {
    let store: FamilyStore

    var body: some View {
        List {
            Section {
                Text("Alle Daten liegen nur auf diesem Gerät im geschützten Speicher der App. Es gibt keinen Namen, kein Foto, keine Sprachaufnahme und kein Konto. Nichts wird gesendet.")
            }
            ForEach(store.profiles) { profile in
                let info = store.storedInfo(for: profile.id)
                Section {
                    ForEach(info.slots) { slot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Self.label(for: slot.slot))
                            Text(details(slot))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if info.quarantinedFiles > 0 {
                        Text("\(info.quarantinedFiles) beschädigte Dateien wurden zur Sicherheit beiseitegelegt. Sie werden mit dem Profil gelöscht.")
                            .font(.footnote)
                    }
                } header: {
                    Text("Profil \(profile.avatar.displayName), zusammen \(Self.bytes(info.totalBytes))")
                }
            }
        }
        .navigationTitle("Was ist gespeichert?")
        .onAppear { store.noteParentActivity() }
    }

    static func label(for slot: SaveSlot) -> String {
        switch slot.name {
        case SaveSlot.profile.name: "Tierbild, Stufe und Einstellungen"
        case "Farm": "Hof, Hofbuch und Lernstand"
        default: slot.name
        }
    }

    private func details(_ slot: StoredSlotInfo) -> String {
        var parts = [Self.bytes(slot.bytes)]
        if let savedAt = slot.savedAt {
            parts.append("gespeichert \(savedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if slot.hasBackup {
            parts.append("mit Sicherungskopie")
        }
        return parts.joined(separator: ", ")
    }

    static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

struct FamilyInfoView: View {
    let topic: FamilyInfoTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
        }
        .navigationTitle(topic.title)
        .accessibilityIdentifier("family.info.\(topic.rawValue)")
    }
}
