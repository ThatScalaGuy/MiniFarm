# MiniFarm

## App lokal öffnen

Bei Lieferung als ZIP zuerst den gesamten Ordner **MiniFarm** entpacken. `MiniFarm.xcodeproj` in Xcode öffnen, Scheme **MiniFarm** und einen iPhone- oder iPad-Simulator (iOS 18 oder neuer) wählen, dann **⌘R** drücken. Für den Simulator ist kein Entwicklerkonto nötig. Geräte-Builds verwenden das persönliche Team Sven Herrmann und `de.thatscalaguy.minifarm`.

Beim ersten Start richtet ein Erwachsener hinter der Zahlwort-Aufgabe ein Tierprofil ein. Zurück in der Profilwahl das Tier antippen. Pelle führt durch den ersten Wunsch: Radieschen säen, das Beet gießen, ein Huhn füttern, am Sonnenbogen schlafen gehen, ernten und im Hofladen verkaufen. Nach Schließen und erneutem Öffnen dasselbe Tier wählen, um am gespeicherten Schritt weiterzuspielen.

Auf dem iPad öffnet **Pause > Gemeinsam tragen** eine Korbrunde mit einem zweiten Tierprofil oder der grauen Hilfshand. Beide Seiten können ihren Griff ziehen oder erst den Griff und dann das gleich geformte Ziel antippen. Es gibt kein Zeitlimit. Danach geht es beim offenen Schritt des gastgebenden Hofs weiter.

Nach Änderungen an der Dateistruktur mit `xcodegen generate` aus `project.yml` neu erzeugen. `App/` enthält den App-Code, `App/Resources/` die Offline-Inhalte, `Tests/` und `UITests/` die beiden Testziele. Den tatsächlichen Funktionsumfang sowie offene Prüfungen dokumentiert [PROGRESS.md](PROGRESS.md), die Annahmen [DESSSICION.md](DESSSICION.md).

Für den lokalen Prüflauf die UDIDs eines iPhone- und eines iPad-Simulators aus `xcrun simctl list devices available` einsetzen:

```sh
sh Tools/test_simulators.sh <iPhone-UDID> <iPad-UDID>
```

Der Lauf erzeugt das Projekt neu, baut einmal, prüft beide Geräte und schreibt Ergebnis-Bundles, Bildschirmfotos und Testberichte unter `build/qa.*`. `Tools/verify_first_harvest.py` prüft die gespeicherten Bestände beider Testprofile: Nur der verkaufende Kuh-Hof erhält einen Taler. `Tools/verify_journey_images.swift` erkennt unter anderem abgeschnittene Bildschirmfotos. Nur die gesonderten DEBUG-Testprofile werden neu angelegt; der Lauf löscht keine Simulatoren.

`python3 Tools/export_project.py MiniFarm.zip` exportiert den zuletzt lokal eingecheckten Projektstand. Die Kopie enthält Quellcode, Medien, Generatoren, Scheme, Protokolle, die Arbeitsrichtlinie `AGEND.md`, `.gitignore` und die Blender-MCP-Projektkonfiguration `.mcp.json`, nicht jedoch `.env`, lokale Konten, Zertifikate, Benutzereinstellungen oder Caches. Zum Spielen werden Blender, ElevenLabs, ein API-Schlüssel und XcodeGen **nicht** benötigt.

## Blender MCP

Im Projektordner (Git-Checkout oder entpackte ZIP) startet die MCP-Projektkonfiguration `.mcp.json` den [offiziellen Blender-MCP-Server](https://projects.blender.org/lab/blender_mcp)
über `uvx` aus einer festgelegten Git-Revision. Voraussetzung sind
[uv](https://docs.astral.sh/uv/getting-started/installation/) (`uvx` im PATH),
Git, Python 3.10 oder neuer und beim ersten Start eine Internetverbindung.
In Blender muss das offizielle MCP-Add-on aktiviert und dessen Server gestartet
sein (standardmäßig `localhost:9876`). Der MCP-Client muss dem Projekt vertrauen.
