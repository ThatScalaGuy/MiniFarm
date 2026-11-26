# 22 – Glossar

> Einheitliche Begriffe für Team, Design und Code. Deutsche Spielbegriffe werden im Spiel (Kinder-Sprache) und in den Dokumenten verwendet; technische Begriffe bleiben englisch. Die Spalte „Doc“ verweist auf die Stelle mit der Definition.

## 1. Spielwelt und Fortschritt

| Begriff | Bedeutung | Doc |
|---|---|---|
| **MiniFarm** | Arbeitstitel des Spiels | 01, 23 |
| **Hof / Diorama-Hof** | Die schwebende Spielzeug-Insel, auf der alles stattfindet | 04 |
| **Hofstufe** | Fortschrittsstufe des Hofs (1–5); schaltet Orte, Tiere, Kulturen, Maschinen frei. Nie ein Verlust, nur Wachstum | 03 |
| **Hofbaum** | Baum auf dem Hofplatz; zeigt die Hofstufe als Wachstum (Blätter, Früchte, Lichter) – für Nicht-Leser statt einer Zahl | 03 |
| **Hofbuch** | Bebildertes Sammelalbum (Pflanzen, Tiere, Maschinen, Dorfbewohner, Jahreszeiten, Entdeckungen); Silhouetten statt Prozentanzeige | 03, 21 |
| **Hoftag** | Spielzeiteinheit; Zeit schreitet durch Handlungen und Schlafen voran, nie in Echtzeit | 03, 08 |
| **Jahreszeit** | 4 Hoftage; Hofjahr = 16 Hoftage | 08 |
| **Fest** | Jeweils am Hoftag 4 einer Jahreszeit (Blüten-, Erntefreuden-, Danke-, Lichterfest) | 08 |
| **Nacht-Zeitraffer** | Kurze Sequenz beim Schlafengehen, in der Pflanzen wachsen und Produkte fertig werden | 05, 08 |
| **Taler** | Spielwährung; **nur kosmetisch** (Deko, Accessoires), nie notwendig für Fortschritt | 07 |
| **Wunschzettel** | Liste von Dingen, die das Kind sich wünscht; ersetzt das Wort „Nein“ beim Kaufen | 07 |
| **Hofküche** | Ort mit Verarbeitungsstationen (Mühle, Backofen, Saftpresse …) | 07 |
| **Dorfmarkt** | Optionaler Ausflug ab Hofstufe 5 auf eigener Karte | 07 |
| **Kachel** | Rasterfeld der Welt (Iso-Raster); Felder bestehen aus Kacheln | 04, 05 |
| **Idle Life** | Lebendige Hintergrundwelt: Tiere, Besucher, Wetter, ≥ 60 berührbare Details | 04 |

## 2. Wünsche und Aktivitäten

| Begriff | Bedeutung | Doc |
|---|---|---|
| **Wunsch** | Eine kleine Bitte einer Figur (Tier, Kunde, Dorfbewohner); der einzige „Auftrag“ im Spiel. Läuft nie ab | 09 |
| **Wunsch-Blase** | Sprechblase aus Bildern (und Stimme), die den Wunsch zeigt | 09 |
| **Wunschkette** | Wunsch, der Folge-Wünsche auslöst (z. B. Mehl → Brot) | 07 |
| **Wunsch-Generator** | Algorithmus, der passende Wünsche anhand Hofstufe, Jahreszeit und Fähigkeitsprofil erzeugt | 09, 15 |
| **Aktivität** (`act.*`) | Spielbare Handlung hinter einem Wunsch (Gießen, Melken, Backen …); 39 insgesamt | 09, 21 |
| **Teilaufgabe** | Ein Schritt einer Aktivität (z. B. „Kanne füllen“) | 09 |
| **Merk-Modus** | Bestell-Blase verschwindet nach 3 s; Tipp zeigt sie erneut – übt das Merken | 07, 10 |
| **Freies Spiel (Sandbox)** | Spielen ohne Wunsch; immer möglich | 03 |
| **Pelles Lied** | Musik-/Reihenfolge-Aktivität (`act.farm.sing`) | 09 |

## 3. Adaptivität und Pädagogik

| Begriff | Bedeutung | Doc |
|---|---|---|
| **Stage** | Mitwachs-Stufe der Steuerung/Anforderung: **Keimling** (3–4 Jahre), **Spross** (5–6), **Blüte** (7–8). Nur Startpunkt; die Feinsteuerung läuft pro Lane über Mastery. Nicht als Label sichtbar | 02 |
| **Lane** | Messbare Fähigkeits-Bahn (`mo.tap`, `mo.drag`, `mo.steer`, `cog.memory`, `cog.sequence`, `cog.matching`, `math.count`, `perc.shape`, `lang.vocab`, `world.time`; `soc.care` wird nicht gemessen) | 10 |
| **Mastery** | Wert 0–1 pro Lane, Elo-ähnlich aus Beobachtungen berechnet; nur lokal gespeichert | 10 |
| **Scaffold / Hilfe-Leiter** | Hilfe-Stufen 0–4: Hinweis (Cue) → gesprochener Hinweis → Ghost-Hand → Reduktion → Gemeinsam (Pelle hilft zu Ende) | 10 |
| **Ghost-Hand** | Transparente Hand, die eine Geste vormacht (Scaffold-Stufe 2) | 10 |
| **Gemeinsam geschafft** | Immer positives Ende einer Aufgabe, auch bei maximaler Hilfe | 10 |
| **No-Fail** | Designprinzip: Es gibt weder Fehler-Töne, Verlust noch Game-over | 01 |
| **Frust-/Langeweile-Signal** | Erkannte Muster (Hämmern, Abbruch, Leerlauf), die Hilfe oder neue Reize auslösen | 10 |
| **Eltern-Override** | Eltern setzen Stage, Autopilot oder Merk-Modus manuell | 17 |

## 4. Steuerung und Kamera

| Begriff | Bedeutung | Doc |
|---|---|---|
| **2.5D / Iso-Ansicht** | Isometrische Übersicht von oben, in der 3D-Objekte gerendert werden | 04 |
| **Nahsicht / Cutaway** | Kamerafahrt in Stall/Küche; Dach oder Wand blendet sich aus | 04 |
| **Chase-Cam** | Verfolgerkamera hinter Traktor/Kutsche | 04, 05 |
| **Autopilot (Spielhilfe)** | Maschine fährt die Spur selbst; Kind tippt, hupt, wählt Tempo. Jederzeit verfügbar, nie erzwungen | 05, 11 |
| **Autopilot-Bot (QA)** | Testprogramm, das das Spiel ohne Kind durchspielt (Soft-Lock-Suche) – nicht zu verwechseln mit der Spielhilfe | 15, 20 |
| **Magnet-Lenkhilfe** | Lenkung rastet sanft auf die Spur ein | 11 |
| **Intent** | Abstrahierter Eingabe-Befehl (z. B. `pick`, `dragEnd`), den Touch, Autopilot und Ghost-Hand gleichermaßen erzeugen | 11, 15 |
| **Parental Gate** | Eltern-Sperre vor Einstellungen/Links; per Zahlenrätsel in Schrift (ohne Sprachausgabe), für Nicht-Leser nicht lösbar | 11, 17 |
| **Elternbereich** | Text-Bereich für Einstellungen, Profile, Aufnahme der Kindernamen, Datenschutz | 17 |

## 5. Audio

| Begriff | Bedeutung | Doc |
|---|---|---|
| **Voice-Line (`vl.*`)** | Eine vorab erzeugte Sprachzeile (Datei `vo_<lang>_<id>.m4a`) | 12, 13 |
| **Zeilen-Katalog** | Quelle der Wahrheit für alle Sprachzeilen (Text, Sprecher, Emotion, Hash) | 13 |
| **Bausteinsprache** | Dynamische Sätze aus kurzen, gleich betonten Teilen („Rosa“ + „möchte“ + „Heu“) | 13 |
| **Sprecher** | Pelle (Hauptstimme) + 5 Dorfbewohner; Tiere machen Laute | 12 |
| **Bus / Ducking** | Getrennte Kanäle (Voice/SFX/Ambience/Music); Musik/Ambience werden bei Sprache leiser | 12 |
| **LUFS** | Lautheitsmaß; Ziel Stimme −16 LUFS, SFX-Peak ≤ −6 dBFS | 12 |
| **Kindername-Aufnahme** | Eltern sprechen den Namen des Kindes ein; lokal, löschbar | 12, 17 |
| **ElevenLabs MCP** | Werkzeug-Schnittstelle für Sprach-/SFX-/Musikgenerierung in der Entwicklungsphase | 13 |

## 6. Technik

| Begriff | Bedeutung | Doc |
|---|---|---|
| **RealityKit** | Apples 3D-/ECS-Framework (Rendering, Physik, Audio) | 15 |
| **ECS** | Entity-Component-System: Entities + Components + Systems | 15 |
| **USD / USDZ** | Austauschformat für 3D-Assets; in Reality Composer Pro eingebunden | 14, 15 |
| **Data-driven Content** | Inhalte als JSON, nicht im Code; neue Inhalte ohne Codeänderung | 15, 16 |
| **Content-Validator** | CI-Prüfung aller IDs, Referenzen und Hofstufen | 16 |
| **Spike (S1–S8)** | Zeitlich begrenzter Technik-Versuch zur Risikoklärung | 15, 19 |
| **Vertical Slice** | Kleine, aber vollständig spielbare Version mit finaler Qualität | 19 |
| **Soft-Lock** | Zustand, in dem das Kind nichts Sinnvolles mehr tun kann – darf nie vorkommen | 20 |
| **Privacy Manifest** | Apples Datei zur Deklaration von Datenzugriffen | 17 |
| **Kids Category** | Apple-Kategorie mit besonderen Datenschutz- und Gate-Regeln | 17 |

## 7. Figuren

| Name | Beschreibung |
|---|---|
| **Pelle** | Hofhund, Guide und Hauptstimme |
| **Minka** | Hofkatze, kommt und geht, schnurrt |
| **Tilda** | Bäckerin, Stammkundin |
| **Hanno** | Opa, Geschichtenerzähler |
| **Mo** | Nachbarskind, Spielgefährte |
| **Lale** | Postbotin |
| **Yusuf** | Marktverkäufer |

Alle Namen sind Arbeitstitel (Doc 23).
