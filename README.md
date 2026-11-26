# MiniFarm

## App lokal öffnen

`MiniFarm.xcodeproj` in Xcode öffnen, Scheme **MiniFarm** und einen iPhone- oder iPad-Simulator (iOS 18 oder neuer) wählen und starten. Für den Simulator ist kein Entwicklerkonto nötig. Geräte-Builds verwenden das persönliche Team Sven Herrmann und `de.thatscalaguy.minifarm`.

Nach Änderungen an der Dateistruktur mit `xcodegen generate` aus `project.yml` neu erzeugen. `App/` enthält den App-Code, `App/Resources/` die Offline-Inhalte, `Tests/` und `UITests/` die beiden Testziele. Den tatsächlichen Funktionsumfang sowie offene Prüfungen dokumentiert [PROGRESS.md](PROGRESS.md), die Annahmen [DESSSICION.md](DESSSICION.md).

## Blender MCP

Die Projektkonfiguration startet den [offiziellen Blender-MCP-Server](https://projects.blender.org/lab/blender_mcp)
über `uvx` aus einer festgelegten Git-Revision. Voraussetzung sind
[uv](https://docs.astral.sh/uv/getting-started/installation/) (`uvx` im PATH),
Git, Python 3.10 oder neuer und beim ersten Start eine Internetverbindung.
In Blender muss das offizielle MCP-Add-on aktiviert und dessen Server gestartet
sein (standardmäßig `localhost:9876`). Der MCP-Client muss dem Projekt vertrauen.
