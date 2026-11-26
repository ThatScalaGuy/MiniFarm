import CoreGraphics
import Foundation
import ImageIO

struct ExportedTest: Decodable {
    struct Attachment: Decodable { let suggestedHumanReadableName, exportedFileName: String }
    let attachments: [Attachment]
}

struct EvidenceError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

func verify(_ directory: URL) throws {
    let manifest = try JSONDecoder().decode([ExportedTest].self, from: Data(contentsOf: directory.appendingPathComponent("manifest.json")))
    let images = manifest.flatMap(\.attachments)
    for name in ["Hofplatz-Hochformat", "Hofplatz-Querformat", "Saat-nach-Neustart",
                 "Gegossenes-Radieschen", "Tagesbild-nach-dem-Schlafen", "Reife-Radieschen", "Nach-Verkauf-an-Tilda"] {
        let matches = images.filter { $0.suggestedHumanReadableName.hasPrefix(name + "_") }
        guard matches.count == 1, let file = matches.first?.exportedFileName, !file.contains("/"),
              let source = CGImageSourceCreateWithURL(directory.appendingPathComponent(file) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw EvidenceError("Bild fehlt: \(name)") }
        guard (name == "Hofplatz-Hochformat") == (image.height > image.width) else {
            throw EvidenceError("Falsche Orientierung: \(name) (\(image.width) × \(image.height))")
        }
        let side = 100
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw EvidenceError("Bilddaten nicht lesbar: \(name)")
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        var black = 0, grass = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
            if max(r, max(g, b)) < 10 { black += 1 }
            if g > r && r > 70 && b * 100 < g * 75 { grass += 1 }
        }
        guard black < side * side / 10 else { throw EvidenceError("Überwiegend schwarzer Bildausschnitt: \(name)") }
        if name.hasPrefix("Hofplatz"), grass < 80 { throw EvidenceError("Kein sichtbarer grüner Hofboden: \(name)") }
        print("\(name): \(image.width) × \(image.height); Schwarz \(black)/10000, Grasfarben \(grass)/10000")
    }
}

do {
    guard CommandLine.arguments.count == 2 else { throw EvidenceError("Aufruf: swift Tools/verify_journey_images.swift BILDORDNER") }
    try verify(URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
} catch {
    FileHandle.standardError.write(Data("Bildprüfung fehlgeschlagen: \(error.localizedDescription)\n".utf8))
    exit(1)
}
