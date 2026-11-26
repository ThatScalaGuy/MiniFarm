# 23 – Entscheidungen (ADR) und offene Fragen

> **Stand:** Konzeptphase, Annahmen aus dem Autopilot-Modus. Jede Entscheidung ist begründet und kann bewusst revidiert werden. Offene Fragen sind am Ende gesammelt und mit einer **Empfehlung** versehen, damit das Projekt ohne Antwort weiterlaufen kann.

## 1. Architektur- und Design-Entscheidungen (ADR)

Status: ✅ gesetzt (aus dem Briefing) · 🟡 Annahme (Autopilot) · 🔬 durch Spike zu bestätigen

| Nr. | Entscheidung | Begründung | Status | Details |
|---|---|---|---|---|
| ADR-01 | **Premium, Einmalkauf**, keine IAP, keine Werbung, kein Abo | Briefing; passt zu Kids Category und Elternvertrauen | ✅ | 17 |
| ADR-02 | **Nativ in Swift mit RealityKit** (SwiftUI für UI) | Briefing; ein Toolchain, gute Apple-Integration | ✅ | 15 |
| ADR-03 | **2.5D-Iso-Übersicht + echte 3D-Nahsichten** | Briefing („2,5D isometrisch, Elemente in 3D“) | ✅ | 04 |
| ADR-04 | **Kein Verlieren, keine Fehlertöne, keine Zeitlimits** | Briefing („man kann nichts falsch machen“) | ✅ | 01, 10 |
| ADR-05 | **Voice-first, Sprachausgabe signifikant** | Briefing; Zielgruppe liest nicht | ✅ | 12 |
| ADR-06 | **ElevenLabs-Audio wird vorab erzeugt** (Pipeline, MCP), nicht zur Laufzeit | Offline, Kosten, Qualitätskontrolle, Datenschutz (keine Kinderdaten an Dritte) | 🟡 | 13 |
| ADR-07 | **Offline, keine Konten, keine Analytics/Tracker** | Datenschutz, Kids Category 5.1.4 | 🟡 | 17 |
| ADR-08 | **Alter 3–8 durch drei weiche Stages** (Keimling/Spross/Blüte) + Lane-Mastery | Briefing („Steuerung wächst mit“); feingranular statt Altersschalter | 🟡 | 02, 10 |
| ADR-09 | **Tipp zuerst:** alle Aktionen mit Tippen lösbar; Ziehen/Lenken als Steigerung; Autopilot jederzeit | Motorik 3-Jähriger; Barrierefreiheit | 🟡 | 11 |
| ADR-10 | **Wünsche statt Aufträge**; Wünsche verfallen nie | Kein Druck; Zeit läuft nur durch Handlungen | 🟡 | 09 |
| ADR-11 | **Teilaufgaben sind der Spielkern** (keine „Mini-Spiele“ als Aufsatz) | Briefing („nicht aufgesetzt“) | ✅ | 09 |
| ADR-12 | **Adaptive Hilfe in 5 Stufen**, immer positives Ende („gemeinsam geschafft“) | Briefing („Spiel erkennt Schwierigkeiten“) | ✅ | 10 |
| ADR-13 | **Daten-getriebener Content (JSON)** + Validator | Neue Inhalte ohne Code; Konsistenz | 🟡 | 15, 16 |
| ADR-14 | **Mindest-OS iOS 18** (Swift 6) | `OrthographicCameraComponent`, `LowLevelMesh` nutzbar; kein iOS-26-Zwang | 🔬 | 15 |
| ADR-15 | **Hauptfigur ist Pelle (Hofhund)** als Guide und Stimme | Vertraut, warm, nonverbale Mimik möglich | 🟡 | 03, 12 |
| ADR-16 | **Taler nur kosmetisch**; Kaufen über Wunschzettel statt „Nein“ | Kein Pay-to-Win, kein Frust | 🟡 | 07 |
| ADR-17 | **Pflanzen sterben nie; Tiere werden nie traurig/krank** | Beruhigend | 🟡 | 05, 06 |
| ADR-18 | **Jahreszeit = 4 Hoftage**, Fest am Hoftag 4 | Jahreszeit ≈ 40 min, Hofjahr ≈ 2–3 Stunden erlebbar | 🟡 | 03, 08 |
| ADR-19 | **Elternbereich in Schrift**, Parental Gate per Zahlenrätsel | Kinder können nicht lesen → Gate wirkt ohne Stimme | 🟡 | 11, 17 |
| ADR-20 | **Stimmen nur mit Rechten/Consent** (Voice Library oder eigene Sprecher) | Rechtssicherheit | 🟡 | 13 |
| ADR-21 | **Art: Spielzeug-Diorama** (weiche Formen, warme Farben) | Ruhe, Lesbarkeit für Kinder | 🟡 | 14 |
| ADR-22 | **Inhalts-Katalog 14 Kulturen, 11 Tiere, 11 Maschinen, 17 Orte, 39 Aktivitäten** | Scope, der in 5 Hofstufen sinnvoll wächst | 🟡 | 21 |
| ADR-23 | **Kamera: Ortho/Perspektive Entscheidung nach Spike S1** | Technik- und Optik-Risiko | 🔬 | 04, 15 |
| ADR-24 | **Lokalisierung ab Tag 1 vorbereitet** (Texte/Audio-Schlüssel), Deutsch zuerst | Marktfokus DACH; Englisch später | 🟡 | 12, 13 |

## 2. Wichtige Annahmen (Autopilot)

1. Das Spiel richtet sich primär an **3–6 Jahre**; 6–8 Jahre werden über Spross/Blüte bedient.
2. Ein **kleines Kernteam** (Doc 19 §6: 1–2 Entwickler:innen, 1–2 3D-Artists, Audio/Sprachregie in Teilzeit, punktuelle Pädagogik-Beratung).
3. **iPhone und iPad**, Querformat primär, Hochformat unterstützt (Doc 11 §7).
4. Preis **einmalig 4,99–6,99 €** (Doc 17); Familienfreigabe aktiv.
5. Sprachen: **Deutsch** zuerst, **Englisch** nach Release 1.
6. Stimmen werden mit **ElevenLabs-Modellen vorab** erzeugt; Modellnamen/Preise sind „Stand prüfen“.
7. Alle rechtlichen Hinweise sind **keine Rechtsberatung**.

## 3. Offene Fragen (mit Empfehlung)

| Nr. | Frage | Empfehlung | Wann klären |
|---|---|---|---|
| **O-1** | Endgültiger Name (MiniFarm?) | Namensrecherche + Marken-Check vor Phase 1 | Phase 0 |
| **O-2** | Preis (4,99 / 5,99 / 6,99 €) | 5,99 €; Preis-Tier nach Content-Umfang | Phase 3 |
| **O-3** | **Pelles Stimme:** männlich/weiblich/neutral, Alter | Warm-neutrale, leicht tiefe Stimme; A/B-Hörtest mit Kindern | Phase 0 |
| **O-4** | Kids-Category-Altersband („5 & unter“ vs. „6–8“) | „5 & unter“ | Phase 3 |
| **O-5** | Sprachen bei Release (nur DE oder DE + EN) | DE bei Release 1, EN als Update | Phase 2 |
| **O-6** | Kamera: orthografisch vs. perspektivisch (leichte Perspektive) | Spike S1 vergleicht beides, Kinder-Hörtest | Phase 0 |
| **O-7** | Art-Style final (Spielzeug-Diorama vs. flaches Papercraft) | Diorama; 3 Stil-Mockups im Test | Phase 0 |
| **O-8** | Namen der Dorfbewohner (Tilda, Hanno, Mo, Lale, Yusuf) | Namen auf Diversität und Aussprache prüfen | Phase 1 |
| **O-9** | Kindernamen-Aufnahme vom Geräte-Backup ausnehmen? | Ja (`isExcludedFromBackup`), mit Hinweis | Phase 2 |
| **O-10** | Face ID/Touch ID für den Elternbereich | Optional, Standard Zahlenrätsel (Gate) | Phase 2 |
| **O-11** | **Lite-/Demo-Version** (gratis, kleiner Hof) | Eher keine; stattdessen App-Preview-Video | Phase 3 |
| **O-12** | Welches ElevenLabs-Modell (v3 expressiv vs. stabil)? | Prototyp-Set 30 Zeilen, A/B-Hörtest | Phase 0 |
| **O-13** | Mindest-iOS 18 vs. 17 | iOS 18; nach Verbreitungsdaten prüfen | Phase 0 |
| **O-14** | Musik: generiert (ElevenLabs Music) vs. komponiert | Generiert für Prototyp; später evtl. Komponist:in | Phase 2 |
| **O-15** | Unterstützung Apple Vision Pro / Mac | Nicht im Release-Scope; visionOS/macOS später prüfen (Doc 19 §4) | nach Release 1 |
| **O-16** | Einzelne vs. mehrere Profile pro Gerät (Geschwister) | Bis zu 4 lokale Profile, jeweils eigener Hof (Doc 17) | Phase 1 |
| **O-17** | Pädagogische Beratung (Frühpädagogik) einbinden | Ja, Review in Phase 1 und 3 (Doc 20) | Phase 1 |

## 4. Entscheidungsprozess

- Neue ADRs bekommen die nächste freie Nummer; **Änderungen** werden als neue ADR mit „ersetzt ADR-NN“ eingetragen.
- Jede Änderung, die Schemas oder IDs betrifft, wird in Doc 16/21 gespiegelt.
- Offene Fragen werden bei Klärung in ADRs überführt.
