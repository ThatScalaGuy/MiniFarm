import AppKit
import SwiftUI

enum ProofError: Error {
    case invalidAlias(String)
    case missing(String)
}

/// Built in a temporary macOS app bundle by proof.py, not linked into MiniFarm.
@main
struct RenderProof {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for (id, destination) in FarmPictogramIndex.aliases {
            guard let entry = FarmPictogram.entry(for: id),
                  entry.asset == FarmPictogram.entry(for: destination)?.asset else {
                throw ProofError.invalidAlias(id)
            }
        }
        guard FarmPictogram.entry(for: "animal.cow.17")?.asset == FarmPictogram.entry(for: "animal.cow")?.asset,
              FarmPictogram.entry(for: "animal.unknown") == nil else {
            throw ProofError.invalidAlias("animal instance or unknown ID")
        }
        for (id, entry) in FarmPictogramIndex.entries {
            guard NSImage(named: entry.asset) != nil else { throw ProofError.missing(id) }
            for size in [64, 88] {
                let side = CGFloat(size)
                let image = ImageRenderer(content: FarmPictogram(id: id).frame(width: side, height: side))
                image.scale = 1
                guard let cgImage = image.cgImage,
                      cgImage.width == size, cgImage.height == size,
                      let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
                    throw ProofError.missing(id)
                }
                try data.write(to: directory.appendingPathComponent("\(id)-\(size).png"))
            }
        }
        print("Rendered \(FarmPictogramIndex.entries.count) cards via SwiftUI at 64 and 88 pt.")
    }
}
