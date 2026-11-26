import OSLog
import SwiftUI

/// A text-free, scalable Doc 21 picture. The enclosing control supplies its
/// touch target and action label; this view supplies the picture's spoken name.
/// Example: `FarmPictogram(id: "act.field.sow").frame(width: 72, height: 72)`.
struct FarmPictogram: View {
    let id: String

    var body: some View {
        if let entry = Self.entry(for: id) {
            picture(entry)
        } else {
            // Saved discoveries from a newer catalog remain visible as a book.
            Image("farm-pic-hofbook-cover", label: Text("Hofbuch"))
                .resizable()
                .scaledToFit()
                .onAppear {
                    Logger(subsystem: "MiniFarm", category: "Pictograms")
                        .notice("No picture registered for content ID: \(id, privacy: .private)")
                }
        }
    }

    private func picture(_ entry: FarmPictogramIndex.Entry) -> some View {
        Image(entry.asset, label: Text(verbatim: entry.label))
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
    }

    static func entry(for id: String) -> FarmPictogramIndex.Entry? {
        var key = id
        if key.hasPrefix("animal."), let lastDot = key.lastIndex(of: "."),
           Int(key[key.index(after: lastDot)...]) != nil {
            key = String(key[..<lastDot])
        }
        return FarmPictogramIndex.entries[FarmPictogramIndex.aliases[key] ?? key]
    }
}
