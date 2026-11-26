# MiniFarm: Umsetzungsstand

Die vollständig beschriebenen Sollfunktionen stehen in [docs](docs/README.md). Eine ID im Katalog allein zählt nicht als spielbare Funktion. Die Spalte „offen“ bezeichnet entweder fehlende Implementierung oder eine ausdrücklich ausstehende Abnahme.

| Doc | Funktion | Nachweis im integrierten Stand | Offen |
|---|---|---|---|
| 01 | Ruhiger Offline-Hof, kein Verlieren | App-Host ohne externe Framework-Abhängigkeiten | Spielpfad |
| 02 | Drei Entwicklungsstufen und weiche Übergänge | Noch nicht integriert | Anpassung und Elternsteuerung |
| 03 | Einstieg, Tag, Schlafen, Hofbuch, Hofstufen | Noch nicht integriert | Durchlauf und Neustart |
| 04 | 17 Orte, Diorama, Kamera | Noch nicht integriert | Szenenwechsel |
| 05 | Kulturen und Maschinen | Noch nicht integriert | Feld-/Fahraktionen |
| 06 | Tiere, Pflege, Erzeugnisse | Noch nicht integriert | Tierinteraktionen |
| 07 | Laden, Taler, Küche, Deko | Noch nicht integriert | Wirtschaftskreislauf |
| 08 | Vier Jahreszeiten und Feste | Noch nicht integriert | Übergänge |
| 09 | Wünsche und Teilaufgaben | Noch nicht integriert | Erzeugung, Handlung, Abschluss |
| 10 | Hilfe, Fähigkeitsbahnen, Müdigkeit | Noch nicht integriert | Hilfsleiter und Langzeitsimulation |
| 11 | Tippbedienung und Orientierungen | `Configuration/Info.plist` erlaubt Hoch-/Querformat | Interaktive Prüfung |
| 12 | Offline-Stimme und Mehrkanalmix | Ordnerreferenz `Audio` in `project.yml` | Hör-/Mischprüfung |
| 13 | Offline-ElevenLabs-Pipeline | Kein Netzwerk-SDK im Host | Tondateien, Provenienz und Freigabe |
| 14 | Spielzeug-Diorama aus Blender | Ordnerreferenz `Models` | Eingebundene Modelle und Renderprüfung |
| 15 | Swift 6, iOS 18, SwiftUI/RealityKit, Tests | `project.yml`, `MiniFarmApp`, geteiltes Scheme | Integration und echte Geräteleistung |
| 16 | Versionierte Schemas und Validator | Noch nicht integriert | Daten- und Spielstandverträge |
| 17 | Familie, Schutz, kein Tracking | Privacy Manifest ohne Erhebung und Tracking | Gate, Profile, selektive Löschung, Store-Angaben |
| 18 | Barrierefreiheit und ruhige Darstellung | Noch nicht integriert | Interaktive und menschliche Abnahme |
| 19 | Spielbarer Schnitt bis Vollausbau | Host vorhanden | Spielfortschritt statt bloßer Build |
| 20 | Tests und Playtests | XCTest- und XCUITest-Ziele | Simulationssuite, echte Familien und Geräte |
| 21 | Normativer Inhaltskatalog | Bundle-Ordner `Content` | Vollständigkeit und Spielbarkeit getrennt prüfen |
| 22 | Einheitliche Begriffe | Konzeptvokabular übernommen | Sichtung in Spiel und Elternbereich |
| 23 | Annahmen und offene Entscheidungen | [DESSSICION.md](DESSSICION.md) | Produkt-/Releaseentscheidungen bestätigt niemand automatisch |
