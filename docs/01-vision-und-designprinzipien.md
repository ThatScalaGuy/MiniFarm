# 01 – Vision und Designprinzipien

> Status: Konzept v1.0 · Arbeitstitel: **MiniFarm** · Plattform: iPhone + iPad (iOS/iPadOS) · Umsetzung: nativ Swift + RealityKit

## 1. Vision in einem Satz

**MiniFarm ist ein ruhiges 3D-Bauernhof-Spiel für Kinder von 3 bis 8 Jahren, in dem man nichts falsch machen kann, alles vorgesprochen wird und der Hof mit dem Kind wächst.**

## 2. Pitch (Elevator)

Ein kleiner Hof liegt wie ein Diorama auf dem Bildschirm. Der Hofhund **Pelle** begrüßt das Kind mit warmer Stimme. Über den Tieren, Beeten und Maschinen erscheinen **Wunschblasen** mit Bildern: Die Kuh hat Durst, das Beet wartet auf Möhrensamen, die Bäckerin braucht zwei Äpfel. Das Kind erfüllt die Wünsche, indem es direkt mit der Welt spielt: Samen in die Erde legen, mit dem Traktor Furchen ziehen, den Mähdrescher über das goldene Weizenfeld steuern, Eier einsammeln, den Hofladen füllen. Die Sonne wandert mit jedem erfüllten Wunsch weiter, am Abend wird es still, der Hof geht schlafen, und über Nacht wächst alles ein Stück. Die Jahreszeiten wechseln, der Hof verändert sich, und mit jedem Jahr wird das Spiel ein wenig anspruchsvoller – genau so, wie das Kind wächst.

## 3. Was das Spiel ist – und was nicht

| Ist | Ist nicht |
|---|---|
| Ruhiges Spielzeug und Werkzeugkasten für kleine Hände | Wettbewerb, Highscore, Ranking |
| Premium: einmal kaufen, alles drin | Free-to-Play, Pay-to-Win, Abo, Werbung |
| Spielerisches Üben von Motorik, Merkfähigkeit, Reihenfolgen, Zählen | Lernspiel mit Prüfungscharakter, Quiz, Noten |
| Sprachgeführt (Voice-first) – kein Lesen nötig | Textlastig, menülastig |
| Immer gewinnbar, immer sicher, immer wiederholbar | Mit Fail-State, Zeitdruck, Mangel, Verlust |
| Offline, ohne Konto, ohne Tracking | Social, Chat, Online-Zwang, Datensammlung |
| Mitwachsend (3–8 Jahre) | Einheitsschwierigkeit |

## 4. Die zehn Goldenen Regeln (nicht verhandelbar)

Diese Regeln gelten für **jede** Funktion, jedes Asset, jede Sprachzeile. Jede neue Idee wird dagegen geprüft (siehe Checkliste in Abschnitt 6).

1. **Man kann nicht verlieren.** Es gibt keinen Fail-State, keine Game-Over-Situation, keine Punkte, die abgezogen werden.
2. **Es gibt keinen Zeitdruck.** Keine Timer, keine Countdowns, keine Echtzeit-Wartezeiten, keine Push-Nachrichten, keine Tagesbelohnungen, keine Serien (Streaks).
3. **Nichts geht verloren.** Pflanzen verwelken nicht, Tiere werden nicht krank, Ernte verdirbt nicht, Gegenstände verschwinden nicht. Ein Gegenstand, der danebenfällt, kehrt sanft in die Hand zurück.
4. **Nichts ist knapp.** Saatgut, Wasser, Futter sind unbegrenzt. Es gibt keine Währungsnot, die das Spiel blockiert.
5. **Kein „Nein“.** Es gibt kein rotes X, keinen Buzzer, keine Wörter wie „falsch“, „nicht“, „schade“. Jede Handlung hat eine freundliche, oft lustige Reaktion; „Fehler“ sind Umwege mit Animation und führen zu einem Hinweis.
6. **Jede Berührung ist willkommen.** Wildes Tippen ist Spiel, kein Fehler. Alles Berührbare reagiert (Tiere, Bäume, Schornstein, Windrad …). Kleine Überraschungen belohnen Neugier.
7. **Sprache zuerst, Bild zweitens, Text zuletzt.** Alles Wichtige wird gesprochen *und* gezeigt (Piktogramm, Farbe, Animation). Text ist nur optionale Zusatzinformation für Eltern bzw. für Leseanfänger.
8. **Ruhe ist ein Feature.** Gedämpfte Farben, sanfte Musik, langsames Tempo, keine Blitze, kein plötzlicher Lärm, keine Jump-Scares, keine Dunkelheit, die ängstigt.
9. **Das Spiel hilft, bevor Frust entsteht.** Es erkennt Schwierigkeiten (siehe Dokument 10) und stützt unauffällig, bis das Kind es „gemeinsam geschafft“ hat – nie als „Hilfe, weil du versagt hast“, sondern als „Wir machen das zusammen“.
10. **Aufgaben sind Teil der Welt, nie aufgesetzt.** Es gibt keine Minispiel-Menüs. Jede Lernaktivität ist eine glaubwürdige Hoftätigkeit (Eier nach Größe sortieren, Hühner zählen, Zaun reparieren).

## 5. Die sechs Säulen des Designs

### Säule 1 – Ruhe & Geborgenheit
Pastellige, warme Farbpalette, weiches Licht, runde Formen, ruhige Kameraführung, Musik auf Spieluhr-/Akustikgitarren-Niveau, Tier- und Naturgeräusche. Der Tagesrhythmus (Morgen → Abend → Schlaf) gibt dem Spiel ein natürliches, sanftes Ende („Feierabend“) statt eines „Noch eine Runde“-Sogs.

### Säule 2 – Tun statt Tippen (direkte Manipulation)
Das Kind *fasst* Dinge an: Samen aufnehmen, in die Erde drücken, Gießkanne kippen, Traktor ziehen. Kein Menü-Navigieren. Gesten sind physikalisch plausibel (ziehen, halten, wischen, kippen, kreisen). Die 3D-Welt gibt haptische und akustische Rückmeldung (Hand-Cursor, Partikel, Töne, Vibration auf dem iPhone).

### Säule 3 – Die Stimme führt (Voice-first)
Der gesamte Spielfluss funktioniert ohne Text. Pelle erklärt, ermutigt, lobt, beschreibt. Sprache ist ein *Systemelement* (Priorität, Warteschlange, Ducking, Wiederholbarkeit) und kein nachträglicher „Audio-Layer“. Details: Dokument 12 und 13.

### Säule 4 – Der Hof lebt und wächst
Der Hof ist kein Menü-Hub, sondern ein lebendiger Ort mit Tageszeit, Wetter, Jahreszeit, laufenden Tieren und neugierigen Besuchern. Fortschritt ist *sichtbar* (der Hofbaum wächst, neue Gebäude, neue Tiere, Deko), nie nur eine Zahl.

### Säule 5 – Mitwachsende Tiefe (3 → 8 Jahre)
Dasselbe Spiel, andere Griffe: Ein Dreijähriger tippt und lässt den Traktor allein fahren, ein Achtjähriger lenkt präzise, merkt sich Bestellungen und zählt bis 20. Das Spiel passt sich *unsichtbar und stufenlos* an (Dokumente 02, 10, 11).

### Säule 6 – Vertrauen für Eltern
Kein Tracking, keine Werbung, keine Käufe im Spiel, keine Konten, alles offline. Ein Elternbereich (hinter Parental Gate) zeigt Lernfortschritt in verständlichen Worten und erlaubt Einstellungen (Dokument 17).

## 6. Design-Checkliste für jede neue Idee

Bevor etwas ins Spiel kommt, muss es **alle** Fragen mit „Ja“ beantworten:

- [ ] Kann ein 3-jähriges Kind es nur mit Tippen/Wischen erleben (oder gibt es einen Autopilot)?
- [ ] Kann ein Kind, das *gar nichts richtig macht*, trotzdem am Ende „gemeinsam geschafft!“ erleben?
- [ ] Gibt es eine gesprochene Erklärung *und* ein Bild/eine Animation, die ohne Sprache verstanden wird?
- [ ] Gibt es keinen negativen Ton, kein negatives Wort, keinen Verlust?
- [ ] Ist es Teil der Hofwelt (diegetisch) und kein Fremdkörper-Minispiel?
- [ ] Skaliert es nach oben, sodass ein 8-Jähriger nicht gelangweilt ist?
- [ ] Ist es ruhig (Tempo, Lautstärke, Farben, keine Blitzeffekte > 3 Hz)?
- [ ] Funktioniert es offline, ohne Konto, ohne Datenübertragung?
- [ ] Ist es auch für ein Kind mit motorischen/sensorischen Besonderheiten bedienbar (Dokument 18)?

## 7. Emotionale Ziele (Player Experience Goals)

| Gefühl | Wie wir es erzeugen |
|---|---|
| **Geborgenheit** | Pelles warme Stimme, Tageszeit-Licht, Tiere reagieren freundlich |
| **Stolz („Ich hab’s gemacht!“)** | Sichtbare Folgen: Feld ist bestellt, Laden ist voll, Tiere sind satt – Pelle lobt konkret („Du hast alle fünf Eier gefunden!“) |
| **Neugier** | Berührbare Dinge, Überraschungen, jedes Jahr neue Jahreszeiten-Ereignisse |
| **Fürsorge** | Tiere füttern, streicheln, Kälbchen/Küken willkommen heißen |
| **Selbstwirksamkeit** | Steuerung wächst mit; Autopilot nie aufgezwungen, nie verboten |
| **Entspannung** | Kein Druck, sanfte Musik, „Feierabend“-Ritual |

## 8. Erfolgskriterien (woran wir erkennen, dass das Konzept funktioniert)

Qualitative Playtests mit Kindern (Dokument 20) und Beobachtung durch Eltern:

- Ein 3-jähriges Kind erlebt innerhalb von **5 Minuten** seine erste vollständige Ernte ohne fremde Hilfe.
- Kein Kind zeigt in Playtests Frust-Signale (Weglegen des Geräts, Weinen, „Ich kann das nicht“) in > 5 % der Sessions.
- Ein 7–8-jähriges Kind spielt freiwillig weiter, weil es neue Herausforderungen (Lenken, Merken, Zählen) findet.
- Eltern beschreiben das Spiel mit Worten wie *ruhig, schön, vertrauenswürdig, sinnvoll*.
- Wiederkehr nach Wochen löst keine Schuld/Verpassen-Gefühle aus („Willkommen zurück!“ statt „Du hast etwas verpasst“).

## 9. Abgrenzung / Inspirationen (ohne zu kopieren)

- *Toca Boca / Sago Mini*: Offene Spielwiese, keine Ziele, direkte Berührung – wir ergänzen sanfte Struktur (Wünsche) und Fortschritt.
- *Monument Valley / Townscaper*: Dioramen-Ästhetik, ruhige Stimmung.
- *Stardew Valley / Farming-Sims*: Zyklus aus Säen–Wachsen–Ernten–Verkaufen – wir entfernen Zeitdruck, Mangel, Energie.
- *Kinderlernapps (Montessori-Ansatz)*: Selbsttätigkeit, Fehlerfreundlichkeit, Konzentration auf *eine* Handlung.
- *Bilderbuch-Bauernhöfe / Wimmelbücher*: Wiedererkennbare, benannte Dinge, Wortschatzaufbau.
