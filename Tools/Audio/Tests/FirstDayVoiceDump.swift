import Foundation

private struct VoiceEntry: Encodable {
    let id: String
    let text: String
    let source: String
}

@main
struct FirstDayVoiceDump {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "FirstDayVoiceDump", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Expected the content directory path"])
        }
        let contentURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let catalog = try FarmCatalog.load(from: contentURL)
        var game = FarmGame(catalog: catalog)
        var entries: [VoiceEntry] = []

        func append(_ id: String, _ text: String, _ source: String) {
            entries.append(VoiceEntry(id: id, text: text, source: source))
        }

        func completeIntroduction(_ index: Int) throws {
            guard let wish = game.wishes.first(where: { $0.introduction == index }) else {
                throw FarmContentError.invalid("Einladung \(index) fehlt am ersten Spieltag")
            }
            _ = game.send(.startWish(wish.id))
            for _ in 0..<100 {
                guard let prompt = game.prompt else { break }
                append(prompt.voiceID, prompt.text, "first-day-prompt")

                var hintGame = game
                let hint = hintGame.send(.askPelle)
                if hint.voiceID.hasPrefix("vl.hint.") {
                    append(hint.voiceID, hint.text, "first-day-hint")
                }

                let result = game.send(.choose(prompt.targetID))
                if result.completed {
                    append(result.voiceID, result.text, "first-day-result")
                    return
                }
            }
            throw FarmContentError.invalid("Einladung \(index) wurde nicht abgeschlossen")
        }

        for index in 0...2 {
            try completeIntroduction(index)
        }

        let morning = game.send(.sleep)
        append(morning.voiceID, morning.text, "first-day-morning")

        for index in [4, 5] {
            try completeIntroduction(index)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(entries)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data([0x0A]))
    }
}
