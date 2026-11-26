import Foundation

@main
struct CatalogReferences {
    static func main() {
        do {
            let catalog = try FarmCatalog.load(from: URL(fileURLWithPath: CommandLine.arguments[1]))
            let references = [
                "models": catalog.crops.flatMap(\.stageModels) + catalog.animals.map(\.model)
                    + catalog.machines.map(\.model) + catalog.tools.map(\.model),
                "sfx": catalog.animals.flatMap(\.sounds)
            ]
            FileHandle.standardOutput.write(try JSONEncoder().encode(references))
        } catch FarmContentError.file(let name, _) {
            fail("Content/\(name): FarmCatalog could not load this file")
        } catch {
            fail("Content: FarmCatalog rejected the bundled catalogs")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
