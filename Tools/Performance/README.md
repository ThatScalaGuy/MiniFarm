# Leistungsprüfung (Doc 15 §10, Doc 20 §4)

Begrenzter, wiederholbarer QA-Pfad für den integrierten Host. Er signiert, lädt und veröffentlicht nichts und ändert weder `MiniFarm.xcodeproj` noch Profile auf anderen Simulatoren.

```bash
Tools/Performance/measure.sh                                    # alles, 5 Stichproben
MINIFARM_PERF_SAMPLES=3 MINIFARM_PERF_OUT=/tmp/perf Tools/Performance/measure.sh
MINIFARM_PERF_STEPS="size projection" Tools/Performance/measure.sh   # ohne Simulator
python3 -m unittest discover -s Tools/Performance -p 'test_*.py'
```

Schritte (`MINIFARM_PERF_STEPS`, Standard alle):

- `size`: unsignierter Release-Build für `generic/platform=iOS` in privater DerivedData. Gemeldet werden Gesamtbytes, Dateizahl, Programm, `Models/`, `Audio/`, `Content/`, `Assets.car`, Rest und ein `ditto`-Zip als Downloadnäherung. Die Größe ist ungethinnt und unverschlüsselt; App-Store-Größen weichen ab.
- `projection`: `QAFarm/main.swift` wird auf macOS mit den plattformneutralen Spiel- und Speicherquellen der App gebaut. Gemessen wird `FarmGame.worldSnapshot` (300 Läufe, Median/p95/min/max in µs) auf dem voll freigeschalteten QA-Hof (Stufe 5, alle Orte). Das ist Mac-CPU-Zeit und kein iOS-Frame-Budget.
- `simulator`: eigener, frisch angelegter Simulator (`MINIFARM_PERF_DEVICE`, Standard `iPhone 17`, neueste passende iOS-Runtime), der am Ende gelöscht wird. Das temporäre Projekt aus `project.yml` ergänzt nur das UI-Testziel `MiniFarmPerformanceUITests` und baut es in Release.
  - `fresh`: Kaltstart nach Neuinstallation bis „Profil einrichten“ bedienbar ist.
  - `qa`: Ein QA-Hof wird über die echte `FamilyStorage` in den Datencontainer dieses Simulators geschrieben, als Profil „Kaninchen“ (Stufe 5, alle 17 Orte). Danach werden Kaltstart bis zum bedienbaren QA-Profil gemessen, `XCTApplicationLaunchMetric`, das Öffnen des Hofs bis zum ersten bedienbaren Ortsknopf sowie Wechsel Übersicht → Hühnerhaus (Stufe 1) bzw. Pferdekoppel (Stufe 5) bis zu einem bedienbaren Bedienelement dieses Ortes (Feld `control`), mit Bildschirmfotos. `openFarm` ist eine Stichprobe je Lauf, Ortswechsel `MINIFARM_PERF_SAMPLES` je Ort. Die Profileinrichtung und der Ersttag werden dabei nicht umgangen und nicht nachgespielt.

Jede Messung erscheint als `MINIFARM_PERF {json}`. `summarize.py` fasst Median/min/max zusammen; Logs, `.xcresult` mit Bildschirmfotos und `context.log` (Commit, Xcode, Mac, Last, Runtime, Gerät) liegen in `MINIFARM_PERF_OUT`.

## Grenzen

- Simulatorzeiten auf einem geteilten Mac sind keine Geräte-fps, keine Akku- oder Wärmewerte und keine CI-Schwellen. Die Last steht in `context.log`; Messungen bei hoher Last zeigen nur Größenordnungen und Ausreißer.
- UI-Zeiten enthalten den Start-Handshake von XCTest und dessen Zugänglichkeitsabfragen (Auflösung etwa 0,1–0,5 s). Die Wartefunktion fragt typisierte Buttons in 100-ms-Schritten ab. Eine enge Abfrage über `descendants(matching: .any)` belegte den Hauptthread der App selbst und täuschte so einen Hänger vor.
- Der QA-Hof kann eine laufende Aktivität haben. Dann markieren deren Ziele den gezeigten Ort statt des Tierknopfs.
