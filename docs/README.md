# MiniFarm – Spielkonzept (Masterdokument)

> **MiniFarm** (Arbeitstitel) ist ein ruhiges, native iOS-/iPadOS-Spiel für Kinder von **3 bis 8 Jahren** (Vorschulalter, ohne Lesekompetenz). Es ist ein **Premium-Spiel** ohne Werbung, In-App-Käufe und Verlieren. Kinder erleben den Bauernhof-Alltag: Felder bestellen, mit dem Traktor ernten, Tiere im Stall pflegen, einen Hofladen betreiben und die Jahreszeiten erleben. Aus Wünschen der Tiere und Dorfbewohner entstehen kleine Aufgaben, die **Motorik, Merkfähigkeit und Strukturen** spielerisch fördern. Das Spiel erkennt, wenn ein Kind Schwierigkeiten hat, und hilft sanft. Die **Sprachausgabe (ElevenLabs, vorab erzeugt)** ist ein zentraler Bestandteil. Umsetzung: **Swift + RealityKit**.

**Stand:** Konzeptphase · **Sprache der Dokumente:** Deutsch · **Erstellt als:** implementierbares Masterdokument.

## Elevator Pitch

*„Ein kleiner Hof, der mit deinem Kind wächst: Pelle, der Hofhund, führt durch Wünsche statt Aufgaben – ohne Lesen, ohne Druck, ohne Verlieren.“*

## Leseempfehlung

| Rolle | Reihenfolge |
|---|---|
| **Alle (Überblick, ≈ 30 min)** | 01 → 03 → 09 → 19 |
| **Game Design** | 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 21 |
| **Pädagogik/UX** | 01 → 02 → 10 → 11 → 18 → 20 |
| **Audio/Sprache** | 12 → 13 → 21 (§12) → 17 (KI-Transparenz) |
| **Art/3D** | 04 → 14 → 21 → 15 (§Rendering) |
| **Entwicklung** | 15 → 16 → 21 → 11 → 10 → 20 |
| **Produkt/Recht** | 17 → 19 → 23 → 20 (§7) |

## Dokumentenübersicht

| Nr. | Dokument | Inhalt |
|---|---|---|
| 01 | [Vision und Designprinzipien](01-vision-und-designprinzipien.md) | Leitbild, Prinzipien (No-Fail, ruhig, Voice-first), Abgrenzung, Entscheidungs-Checkliste |
| 02 | [Zielgruppe und Mitwachsen](02-zielgruppe-und-mitwachsen.md) | Entwicklungsstufen 3–8, Keimling/Spross/Blüte, Parameter pro Stufe |
| 03 | [Spielablauf und Progression](03-spielablauf-und-progression.md) | Core Loop, Hoftag, Hofbaum, Hofstufen 1–5, Hofbuch, Onboarding |
| 04 | [Welt, Orte und Kamera](04-welt-und-orte.md) | Diorama-Hof, 17 Orte, Kamera-System, 2.5D ↔ 3D, Idle Life |
| 05 | [Felder, Saatgut, Ernte, Maschinen](05-felder-saatgut-ernte-maschinen.md) | 14 Kulturen, Wachstum, 11 Maschinen, Steuerung je Stufe |
| 06 | [Tiere und Stall](06-tiere-und-stall.md) | 11 Tiere, Bedürfnisse als Wünsche, Interaktionen, Abendritual, Produkte |
| 07 | [Hofladen, Wirtschaft, Hofküche](07-hofladen-und-wirtschaft.md) | Laden, Kunden, Taler (kosmetisch), Küche, Dorfmarkt, Deko |
| 08 | [Jahreszeiten, Wetter, Tageszeit](08-jahreszeiten-wetter-tageszeit.md) | 4 Jahreszeiten, Feste, Wetter, Tageszeit |
| 09 | [Wünsche und Teilaufgaben](09-wuensche-und-teilaufgaben.md) | Integrationsregeln, 39 Aktivitäten, Wunsch-Generator |
| 10 | [Adaptive Unterstützung](10-adaptive-unterstuetzung.md) | Signale, Hilfe-Leiter, Mastery-Modell, Frust-Erkennung |
| 11 | [Steuerung und UI](11-steuerung-und-ui.md) | Gesten, HUD, Steuerung je Stufe, Haptik, Parental Gate |
| 12 | [Audio und Sprachausgabe](12-audio-und-sprachausgabe.md) | Voice-first, Sprecher, Positiv-Sprache, Mix, Musik, Kindername |
| 13 | [ElevenLabs-Pipeline](13-elevenlabs-pipeline.md) | Vorab-Generierung, Zeilen-Katalog, MCP-Arbeitsweise, QA, Recht |
| 14 | [Art Direction und Assets](14-art-direction-und-assets.md) | Stil, Paletten, Figuren, Asset-Budgets, Blender → USD |
| 15 | [Technische Architektur](15-technische-architektur.md) | Swift 6, RealityKit-ECS, Module, Performance, Tests, Spikes |
| 16 | [Datenmodelle und Schemas](16-datenmodelle-und-schemas.md) | ID-Konventionen, JSON-Schemas, Spielstand, Validator |
| 17 | [Elternbereich, Datenschutz, Compliance](17-elternbereich-datenschutz-compliance.md) | Kids Category, Privacy, Premium-Modell, KI-Transparenz |
| 18 | [Barrierefreiheit](18-barrierefreiheit.md) | Motorik, Sehen, Hören, Kognition, Calm-Mode |
| 19 | [Roadmap und MVP](19-roadmap-und-mvp.md) | Phasen, Vertical Slice, MVP, Nicht-Ziele, Risiken |
| 20 | [QA und Playtesting](20-qa-playtesting.md) | Kinder-Playtests, Metriken, Testfälle, Release-Checklisten |
| 21 | [Content-Katalog](21-content-katalog.md) | **Master-ID-Liste** aller Inhalte, Voice-Line-Budget |
| 22 | [Glossar](22-glossar.md) | Einheitliche Begriffe |
| 23 | [Entscheidungen und offene Fragen](23-entscheidungen-und-offene-fragen.md) | ADRs, Annahmen, 17 offene Fragen mit Empfehlung |

## Kernentscheidungen auf einen Blick

| Thema | Entscheidung |
|---|---|
| Plattform | iOS/iPadOS 18+, Swift 6, RealityKit, SwiftUI; offline |
| Darstellung | 2.5D-Iso-Übersicht, echte 3D-Nahsichten (Cutaway, Chase-Cam) |
| Modell | Premium-Einmalkauf, keine IAP/Werbung/Tracker, Kids Category |
| Spielprinzip | **Wünsche statt Aufträge**, kein Verlieren, keine Zeitlimits, Pflanzen und Tiere leiden nie |
| Mitwachsen | Stages Keimling (3–4) / Spross (5–6) / Blüte (7–8) + Mastery pro Fähigkeitsbahn |
| Adaptivität | 5-stufige Hilfe-Leiter, immer „gemeinsam geschafft“ |
| Steuerung | Tippen zuerst, Autopilot für Maschinen jederzeit verfügbar |
| Audio | Voice-first; Pelle spricht; ElevenLabs-Zeilen vorab erzeugt (Pipeline) |
| Umfang (Vollausbau) | 5 Hofstufen · 17 Orte · 14 Kulturen · 11 Tiere · 11 Maschinen · 39 Aktivitäten · ≈ 4000 Sprachzeilen |
| Figuren | Pelle (Hofhund, Guide), Minka (Katze), Tilda, Hanno, Mo, Lale, Yusuf |

## Hinweise zur Verlässlichkeit

- **Technik-, Preis-, Modell- und Rechtsangaben** (ElevenLabs-Modelle, App-Store-Richtlinien, RealityKit-Versionen, DSGVO/COPPA) sind mit **„Stand prüfen“** markiert und müssen vor Entscheidungen neu verifiziert werden. Die Rechtsangaben sind **keine Rechtsberatung**.
- Alle **Zahlenwerte** (Schwellen, Taler, Zeiten, Lernraten) sind **Startwerte**, die in JSON konfigurierbar sind und durch Playtests (Doc 20) justiert werden.
- **Namen** von Figuren, Tieren und dem Spiel sind Arbeitstitel (Doc 23).
- Bei Widersprüchen zwischen Dokumenten gilt **Doc 21 (Content) + Doc 16 (Schemas)**.

## Nächste Schritte (empfohlen)

1. **Phase 0 (Doc 19):** Spikes S1–S8, Prototyp der Steuerung, Stimmen-Findung mit dem ElevenLabs-MCP (Pelles Stimme, 30 Prototyp-Zeilen).
2. **Offene Fragen** (Doc 23 §3) klären, vor allem O-1, O-3, O-4, O-6, O-12.
3. **Vertical Slice** (Doc 19 §3): Hofstufe 1–2 mit Pelle, 2 Nutztieren + Minka, 4 Kulturen, ≈ 12 Aktivitäten, ≈ 600 Sprachzeilen → Playtest mit ≥ 8 Kindern (Doc 20).
