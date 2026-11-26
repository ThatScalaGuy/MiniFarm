# 20 – QA, Playtesting und Release-Checklisten

> Ein Kinderspiel ist erst „fertig“, wenn **Kinder es ohne Hilfe verstehen und gern wieder spielen**. Playtests mit echten Kindern sind deshalb gleichwertig zu Unit-Tests. Dieses Dokument legt Ablauf, Ethik, Metriken und Checklisten fest.

## 1. Qualitäts-Pyramide

| Ebene | Wer/Was | Wann |
|---|---|---|
| Automatisierte Tests (Doc 15 §11) | Unit, Simulation, Autopilot-Playthrough, Content-Validator | Jeder Commit/CI |
| Interne Tests | Team spielt täglich („Dogfooding“), Debug-Overlay | laufend |
| **Kinder-Playtests** | Zielgruppe in Beobachtung | ab Phase 0, jede Phase |
| Experten-Review | Frühpädagog:in, Ergotherapeut:in, Sprachtherapeut:in (Stichprobe) | Phase 1, 3 |
| Eltern-Feedback | TestFlight-Familien | Phase 3 |
| Zertifizierung | Kids-Category-/Barrierefreiheits-/Datenschutz-Checkliste | Phase 4 |

## 2. Kinder-Playtests

### 2.1 Ethik und Datenschutz (verbindlich)

| Regel | Umsetzung |
|---|---|
| **Einwilligung** | Schriftliche Einwilligung der Eltern/Sorgeberechtigten (verständlich, freiwillig, jederzeit widerrufbar); Kind kann jederzeit aufhören („Pelle macht Pause“) |
| **Keine Personendaten** | Kinder werden mit Codes (K01, K02 …) geführt; Alter in Monaten/Jahren; keine Namen in Notizen |
| **Aufzeichnung** | Bildschirm-/Audioaufzeichnung nur mit ausdrücklicher Zustimmung; **keine Gesichtsaufnahmen** als Standard; Löschung nach Auswertung (≤ 90 Tage) |
| **Anwesenheit** | Elternteil immer anwesend; Testleiter:in mit erweitertem Führungszeugnis, falls in Einrichtungen |
| **Kurz** | 10–20 Minuten (Keimling ≤ 10–15), Pausen nach Wunsch, Belohnung (Aufkleber) unabhängig vom Ergebnis |
| **Nicht testen, sondern Spiel testen** | Rückmeldung an Eltern: „Das Spiel wurde getestet, nicht Ihr Kind.“ |
| **Einrichtungen** | Kitas/Schulen: Genehmigung der Leitung und Eltern; Datenschutzkonzept |

### 2.2 Ablauf (Standard-Session)

1. **Begrüßung** (2 min): Kind setzt sich zu Eltern; Gerät wird übergeben ohne Erklärung („Schau mal, was du machen magst“).
2. **Freies Spiel** (5–10 min): Beobachtung **ohne Eingriff**; Testleiter:in notiert nur.
3. **Aufgaben-Beobachtung**: Wenn das Kind nicht selbst startet, nach 30 s sanfte Frage („Was möchtest du als Nächstes machen?“) – nie Anleitung geben.
4. **Mini-Interview** (3 min, mit Bildkarten): „Was hat dir gefallen?“ (Emoji-Skala 😀/😐/☹️), „Was hast du gemacht?“ (Erinnerung), „Was war schwer?“.
5. **Eltern-Kurzfragebogen** (2 min).

### 2.3 Beobachtungsbogen (je Session)

| Feld | Beispiele |
|---|---|
| Kind-Code, Alter, Gerät, Stage-Einstellung | K07, 4;3 J., iPad, Keimling |
| **Start selbstständig?** | ja / nach Hinweis / nein |
| **Erste Handlung** | Tippt auf Tier, Hand, Pelle … |
| **Verstehen von Wunsch-Blasen** | spontan / nach Pelle / gar nicht |
| **Touch-Probleme** | Fehltipps, Palm-Touch, Ziehen abgebrochen |
| **Frust-Momente** (Zeit, Auslöser) | Stirnrunzeln, Hämmern, Wegschauen, „Geht nicht“ |
| **Freude-Momente** | Lachen, Zeigen, „Nochmal!“ |
| **Hilfe-Stufen genutzt** | Cue / Hinweis / Ghost / Gemeinsam |
| **Sprache** | Wiederholt Pelle? Spricht mit Tieren? Zählt laut? |
| **Eltern-Interventionen** | wie oft, wobei |
| **Ende** | Kind hört freiwillig auf / will weiterspielen |

### 2.4 Teststichproben (Mindestgrößen)

| Phase | Kinder | Fokus |
|---|---|---|
| Phase 0 (Prototypen) | 6–8 (2 je Stage) | Touch/Drag (S3), Kamera (S1), Stimmen-Eindruck |
| Phase 1 (Slice) | ≥ 8 (2–3 je Stage) | Verständlichkeit, Hilfe-Leiter, Gesamtgefühl |
| Phase 2 (Alpha) | 12–15 | Wunsch-Generator, Adaptivität, Langzeit-Interesse (Wiederholungsbesuche) |
| Phase 3 (Beta) | ≥ 20 + TestFlight-Familien (2–4 Wochen) | Langzeit, Schlaf-Ritual, Elternbereich |
| Zusatz | Kinder mit Besonderheiten (motorisch/sensorisch/Sprache), 4–6 | Barrierefreiheit (Doc 18) |

### 2.5 Erfolgs-Kriterien (Auswertung)

| Metrik | Ziel |
|---|---|
| Selbstständiger Start | ≥ 85 % (Slice: ≥ 80 %) |
| Wunsch-Blase verstanden (spontan/nach Pelle) | ≥ 90 % |
| Aufgaben ohne Eltern-Hilfe abgeschlossen | ≥ 90 % (inkl. Scaffold) |
| Frust-Abbruch | < 5 % der Aufgaben |
| „Nochmal spielen“ | ≥ 90 % |
| Touch-Fehlgriffe | < 1 pro Minute (Keimling), < 0,5 (Spross/Blüte) |
| Ø Session-Länge freiwillig | Keimling ≥ 8 min · Spross ≥ 12 min · Blüte ≥ 15 min |
| Eltern: „entspannend“ | ≥ 4,5/5 |
| Verstehen der Sprache (Keimling, Sätze ≤ 8 Wörter) | ≥ 90 % |

Ergebnisse führen zu **Tuning-Tickets** (Parameter in JSON) oder **Design-Änderungen** (Doc 23 ADR).

## 3. Funktionale QA – Testfälle (Auszug)

| Bereich | Testfall |
|---|---|
| **Soft-Lock** | Autopilot-Bot 30 Tage: jederzeit ≥ 1 offener, lösbarer Wunsch; kein Ort unerreichbar; Home immer wirksam |
| **Wunsch-Generator** | Pflicht-Mix (Tier+Feld+Laden) pro Tag; Kausalketten lösen sich auf; max. 8 offen |
| **Wachstum** | Nacht-Zeitraffer erhöht alle Beete; Keimling ≤ 2 Nächte; nichts stirbt; Jahreszeit-Wechsel konsistent |
| **Wirtschaft** | Taler-Verdienst innerhalb Bandbreite; Wunschzettel-Lieferung bei genug Taler; keine negativen Salden |
| **Scaffold** | Jede Aktivität erreicht Stufe 4 und endet im Erfolg; Stufen-Reset pro Aufgabe |
| **Adaptive** | Simulations-Kinder: Erfolgsrate 85–90 %, keine Oszillation, Stage-Vorschlag plausibel |
| **Persistenz** | Speichern/Laden-Roundtrip; Autosave bei Hintergrund; Korruption → `.bak`; Migration alter Fixtures |
| **Audio** | Kein Doppelsprechen; Priorität/Ducking; Cooldown; Prefetch; Kopfhörer-Trennung; Anruf-Unterbrechung |
| **Parental Gate** | Nicht-Leser scheitern; Eltern bestehen; Sperre nach 3 Fehlern; Alternative bei VoiceOver |
| **Touch** | Palm-Touch ignoriert; Mehrfach-Tap-Schutz; Touch-Cancel räumt auf |
| **Offline** | Flugmodus: alles funktioniert; keine Netzwerk-Aufrufe (Netzwerk-Monitor im Test) |
| **Lokalisierung** | Fehlende Audio-Dateien erzeugen Fallback, keinen Crash |

## 4. Geräte- und OS-Matrix

| Klasse | Geräte (Beispiele) | Zweck |
|---|---|---|
| Minimal | iPhone 12 / iPhone SE (3. Gen), iPad (9. Gen) | Perf-Untergrenze |
| Mittel | iPhone 14/15, iPad Air | Referenz |
| Maximal | iPhone Pro Max, iPad Pro | Skalierung, Pro-Motion |
| OS | iOS/iPadOS 18 (Min), aktuelles Release, Beta | Kompatibilität (iOS-26-Pfade separat) |
| Sonder | Kleiner Bildschirm (SE), Hochformat, Zoom-Anzeige, Reduce Motion, VoiceOver | Layout/Barrierefreiheit |

Perf-Messpunkte: Kaltstart, Ortswechsel, Nacht-Zeitraffer, Fest-Szene (maximale Partikel), 30-min-Thermik.

## 5. Fehler-Schweregrade

| Stufe | Definition | Beispiel | Release-Gate |
|---|---|---|---|
| **S0 Blocker** | Absturz, Datenverlust, Soft-Lock, Kinderunsicherheit (z. B. erschreckender Ton) | Spielstand weg | 0 offen |
| **S1 Kritisch** | Kernfunktion unbrauchbar; Gate umgehbar; Sprache falsch | Aufgabe nicht abschließbar | 0 offen |
| **S2 Hoch** | Deutliche Beeinträchtigung | Hilfe erscheint nie | ≤ 3, mit Workaround |
| **S3 Mittel** | Optische/akustische Fehler | Clipping-Artefakt | akzeptabel mit Liste |
| **S4 Niedrig** | Kosmetik | Tippfehler Elternbereich | optional |

## 6. Audio- und Content-QA (Verweise)

- Voice-Zeilen: Doc 13 §7 (automatisch + manuell, Kinder-Hörtest).
- Content-Validator: Doc 16 §7.
- Grammatik-Lookup-Tests (Akkusativ/Plural) für alle Items.
- **Stimmungs-Check:** Jede Voice-Zeile wird auf Wärme/Negativität gelesen; Blockliste („falsch“, „nein“ …) automatisch.

## 7. Release-Checkliste (Kids Category & Qualität)

### 7.1 Apple/Compliance
- [ ] Keine Third-Party-SDKs (SDK-Inventar leer), Network-Monitor: 0 Verbindungen im Spiel
- [ ] Privacy Manifest vollständig, Privacy-Label „Data Not Collected“
- [ ] Parental Gate vor **allen** externen Links/Einstellungen; Datenschutz-Link gated
- [ ] Altersband gewählt, Altersfreigabe-Fragebogen korrekt
- [ ] Mikrofon-Zugriff nur Elternbereich, klarer Berechtigungstext, Aufnahme löschbar
- [ ] Screenshots/Beschreibung ehrlich; keine Wirkungsversprechen
- [ ] KI-Transparenz-Hinweis (Credits) vorhanden
- [ ] Accessibility-Labels im App Store Connect geprüft

### 7.2 Produkt/Qualität
- [ ] Playtest-Kriterien (§2.5) erfüllt
- [ ] Soft-Lock-Bot: 100 Läufe à 30 Tage ohne Befund
- [ ] Perf-Ziele auf Minimal-Gerät (60 fps, Thermik, Speicher)
- [ ] Alle Voice-Zeilen `approved`; keine Blockliste-Treffer
- [ ] Lautheit/Peak-Checks grün; Hörschutz (Limiter) geprüft
- [ ] Barrierefreiheit Muss-Teil (Doc 18) abgenommen
- [ ] Datenmigration von Vorversion getestet
- [ ] Crash-Freiheit in Beta ≥ 99,8 %
- [ ] Support-Prozess und Webseite bereit

## 8. Regression nach Updates

- Pro Update: Smoke-Test-Liste (15 Min), Autopilot-Playthrough 10 Tage, Save-Migration, Audio-Manifest-Check.
- Neue Inhalte: Content-Validator + Playtest-Stichprobe (≥ 3 Kinder) vor Release.
