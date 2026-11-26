import Foundation

/// Parent information pages. All text is in the app; there are no external links.
enum FamilyInfoTopic: String, CaseIterable, Hashable, Sendable, Identifiable {
    case privacy
    case coPlay
    case familySharing
    case listening
    case credits
    case provider

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "Datenschutz"
        case .coPlay: "Gemeinsam spielen"
        case .familySharing: "Familienfreigabe"
        case .listening: "Hören und Lautstärke"
        case .credits: "Mitwirkende und KI-Hinweis"
        case .provider: "Anbieter und Kontakt"
        }
    }

    var systemImage: String {
        switch self {
        case .privacy: "lock.shield"
        case .coPlay: "person.2"
        case .familySharing: "person.3"
        case .listening: "headphones"
        case .credits: "music.note.list"
        case .provider: "building.2"
        }
    }

    var paragraphs: [String] {
        switch self {
        case .privacy:
            [
                "MiniFarm braucht keine Internetverbindung. Das Spiel sendet keine Daten, zeigt keine Werbung und nutzt kein Tracking und keine Analyse.",
                "Auf diesem Gerät gespeichert werden nur: das Tierbild und die Stufe jedes Profils, Ihre Einstellungen und der Spielstand mit Hof, Hofbuch und Lernstand. Es gibt keine Namen, keine Fotos, keine Sprachaufnahmen und keine Konten.",
                "Die Dateien liegen im geschützten Speicher der App. Ein Geräte-Backup von Apple kann sie enthalten, wenn Sie Backups nutzen.",
                "Unter Daten sehen Sie, was gespeichert ist. Dort können Sie den Fortschritt zurücksetzen, ein Profil löschen oder alle Daten löschen. Wenn Sie die App löschen, sind alle Daten entfernt.",
                "Absturzberichte sendet nur Apple, und nur wenn Sie das in den iOS-Einstellungen erlauben.",
            ]
        case .coPlay:
            [
                "Spielen Sie ab und zu mit. Fragen Sie zum Beispiel: Wie viele Äpfel sind das? Welches Tier hat Hunger?",
                "Lassen Sie Ihr Kind selbst tippen. Pelle hilft von allein, wenn etwas nicht klappt. Lob für das Tun wirkt besser als Lob für das Ergebnis.",
                "Am Ende eines Hoftags geht der Hof schlafen. Das ist ein guter Moment für eine Pause.",
            ]
        case .familySharing:
            [
                "Mit der Familienfreigabe von Apple können Sie einen Kauf mit Ihrer Familie teilen. Sie richten das in den iOS-Einstellungen unter Ihrem Namen ein.",
                "Jedes Gerät speichert seine Profile getrennt. Spielstände werden nicht zwischen Geräten übertragen.",
            ]
        case .listening:
            [
                "Stellen Sie die Lautstärke gemeinsam mit Ihrem Kind ein. Bei Kopfhörern lieber leiser beginnen.",
                "Mit „Leises Spiel“ schweigen Musik und Umgebung. Sprache und wichtige Klänge bleiben.",
                "Mono-Audio und weitere Hörhilfen finden Sie auch in den iOS-Einstellungen unter Bedienungshilfen.",
            ]
        case .credits:
            [
                "Musik, Umgebungsklänge und Tierlaute wurden für MiniFarm mit einem Klangprogramm erzeugt. Die fertigen Tondateien sind in der App enthalten.",
                "Wenn für einen Satz keine Sprachdatei vorliegt, spricht die Sprachausgabe dieses Geräts. Sie funktioniert ohne Internet.",
                "Figuren, Tiere und Bildsymbole wurden eigens für MiniFarm gestaltet, die Figuren in Blender.",
                "Bei der Entwicklung von MiniFarm wurden KI-Werkzeuge eingesetzt.",
            ] + (FamilyInfo.creditLines.isEmpty ? ["Namen und Lizenzen folgen vor der Veröffentlichung."] : FamilyInfo.creditLines)
        case .provider:
            FamilyInfo.providerLines + [
                "Die App öffnet keine Webseiten und keine E-Mail. Kontaktdaten stehen hier nur als Text.",
            ]
        }
    }
}

enum FamilyInfo {
    /// Release blocker: provider name, address and contact must be filled in before publishing.
    static let providerLines = [
        "Anbieter: Angaben folgen vor der Veröffentlichung.",
    ]

    /// Release blocker: names of contributors, the licensed offline voice and licenses. Filled in by the release owner.
    static let creditLines: [String] = []

    static let offlineNote = "Dieses Spiel braucht keine Internetverbindung."
}
