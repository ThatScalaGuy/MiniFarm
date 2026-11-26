# 02 – Zielgruppe, Entwicklungsstufen und „Mitwachsen“

## 1. Zielgruppe

**Primär:** Kinder von 3 bis 8 Jahren (Vorschule bis Ende 2. Klasse), die allein oder gemeinsam mit Eltern/Geschwistern auf iPhone oder iPad spielen.
**Sekundär:** Eltern, Großeltern, Erzieher:innen, die das Spiel auswählen, einrichten und begleiten.

**Kernannahmen**

- Lesekompetenz ist **nicht** vorhanden (3–6 J.) bzw. **entwickelt sich gerade** (6–8 J.). → Voice-first, Bild-first.
- Feinmotorik ist eingeschränkt: Kleine Ziele werden verfehlt, mehrere Finger/Handballen berühren versehentlich den Bildschirm, Gesten wie Pinch/Rotate sind für Dreijährige schwierig.
- Aufmerksamkeitsspanne: ca. 3–5 Min. pro Handlung (3 J.) bis 15–20 Min. (8 J.). Das Spiel ist in kleine, in sich abgeschlossene Wünsche geschnitten.
- Arbeitsgedächtnis wächst stark: 3 J. ≈ 1–2 Dinge, 5 J. ≈ 3 Dinge, 8 J. ≈ 4–5 Dinge. Das Spiel nutzt das als Skalierungsachse.
- Kinder wiederholen *gern* („nochmal!“) – Wiederholbarkeit ist erwünscht, kein Designfehler.
- Geräte werden oft geteilt (Geschwister, Eltern). Das Spiel unterstützt mehrere lokale Profile und gemeinsames Spielen.

> Die Altersangaben sind pädagogisch-orientierende Richtwerte, keine medizinischen oder diagnostischen Aussagen. Das Spiel macht **keine** Förderversprechen oder Diagnosen (siehe Dokument 17).

## 2. Die drei Wachstumsstufen

Das Spiel kennt intern drei **Wachstumsstufen** (`GrowthStage`). Sie heißen im Elternbereich nach Pflanzenwachstum – Kinder sehen sie nie.

| Stufe | Name | Typisches Alter | Kernerlebnis |
|---|---|---|---|
| 1 | **Keimling** | 3–4 Jahre | „Ich tippe, und der Hof reagiert.“ Alles ist groß, laut gezeigt, automatisch unterstützt. |
| 2 | **Spross** | 5–6 Jahre | „Ich ziehe, ich bringe Dinge ans richtige Ziel.“ Gesten, Zuordnen, kurze Merk- und Zählaufgaben. |
| 3 | **Blüte** | 7–8 Jahre | „Ich steuere und plane selbst.“ Lenken, Reihenfolgen, Mengen bis 20, Merken, freie Kamera. |

### Wichtig: Stufen sind **weich**, nicht hart

- Die Stufe ist nur der **Startpunkt** (Eltern wählen bei Profilanlage: 3–4 / 5–6 / 7–8, Standard ist „Keimling“, wenn leer gelassen).
- Danach steuert die **Kompetenz-Engine** (Dokument 10) **pro Kompetenzbahn** einen stufenlosen Wert `mastery ∈ [0, 1]`. Ein Kind kann beim Zählen „Blüte“ und beim Lenken „Keimling“ sein.
- Das Kind merkt nie, dass es „hoch-“ oder „runtergestuft“ wird. Es gibt keine Level-Anzeige, keine Abzeichen für Stufen.
- Eltern können im Elternbereich jede Bahn manuell überschreiben (z. B. „Traktor immer im Autopilot“).

## 3. Kompetenzbahnen (Competency Lanes)

Jede Hofaktivität (Dokument 09) ist mit 1–3 Bahnen getaggt. Die Bahnen sind die einzige Grundlage der Adaptivität.

| ID | Bahn | Beispiele im Spiel | Beobachtete Signale |
|---|---|---|---|
| `mo.tap` | Motorik – Tippen/Wischen | Beet antippen, Tier streicheln, Wischen zum Ernten | Treffgenauigkeit, Doppeltipp-Rate |
| `mo.drag` | Motorik – Ziehen/Führen | Samen zum Beet ziehen, Eimer tragen, Linie nachfahren | Zielabweichung, Abbrüche, Führung (Pfadtreue) |
| `mo.steer` | Motorik – Lenken/Timing | Traktor lenken, Mähdrescher fahren, Kutsche lenken | Spurabweichung, Reaktionszeit, Glätte |
| `cog.memory` | Merkfähigkeit | Bestellung merken, „Wer hat schon gefressen?“, Memory-Muster am Zaun | Wiedergabegenauigkeit, Rückfragen (Bubble erneut antippen) |
| `cog.sequence` | Reihenfolgen | Pflügen → Säen → Gießen; Brot backen; Tagesablauf | Reihenfolgetreue, Hinweisbedarf |
| `cog.matching` | Zuordnen/Kategorisieren | Futter zu Tier, Saat zu Beet, Eier nach Farbe/Größe | Trefferquote, Distraktor-Anzahl |
| `math.count` | Zählen & Mengen | Eier zählen, 3 Äpfel in den Korb, Münzen | Zahlenraum, Zählfehler |
| `perc.shape` | Formen/Farben/Muster | Zaunteile passend einsetzen, Muster im Beet, Fahrspuren | Passgenauigkeit |
| `lang.vocab` | Wortschatz & Sprache | Dinge benennen (Pelle), Anlaute, Reime | Wiederholungen beim „Wie heißt das?“ |
| `world.time` | Zeit & Natur | Tageszeiten, Jahreszeiten, „Was wächst wann?“ | Teilnahme an Saison-Aktivitäten |
| `soc.care` | Fürsorge/Empathie *(nicht gemessen)* | Füttern, Trösten, Teilen, Besucher begrüßen | – (nur Design, kein Tracking) |

Hinweis: `soc.care` wird bewusst **nicht** modelliert oder bewertet. Das Spiel schafft dafür Gelegenheiten, misst sie aber nicht.

## 4. Parameter-Matrix je Stufe (Startwerte – zu tunen im Playtest)

Jede Aktivität liest ihre konkreten Parameter aus dieser Matrix, abhängig von `mastery` der relevanten Bahnen (lineare Interpolation oder Schwellen, siehe Dokument 10 §5).

### 4.1 Eingabe & Präzision

| Parameter | Keimling | Spross | Blüte |
|---|---|---|---|
| Interaktionsformen | Tippen, Wischen, Halten | + Ziehen & Ablegen, Linie nachfahren | + Lenkrad/Slider, Zwei-Finger-Kamera, Timing |
| Minimale Zielgröße (Touch) | 88 pt | 72 pt | 56 pt |
| Ablage-Toleranz (Drop-Radius) | 2,0 Kacheln | 1,2 Kacheln | 0,6 Kacheln |
| Magnetismus/Snap | stark (immer) | mittel | schwach/optional |
| Multitouch-Toleranz | Zusatzfinger ignorieren | Zusatzfinger ignorieren | Zwei Finger aktiv (Kamera) |
| Haltedauer für „Halten“ | 0,4 s | 0,6 s | 0,8 s |

### 4.2 Kognitive Last

| Parameter | Keimling | Spross | Blüte |
|---|---|---|---|
| Schritte je Wunsch | 1–2 | 2–4 | 3–6 |
| Auswahl (richtig + Ablenker) | 1 + 1 | 1 + 2–3 | 1 + 3–5 |
| Zahlenraum (Zählen/Mengen) | 1–3 | 1–5 (bis 10) | 1–10 (bis 20) |
| Merklast (Dinge, die sich das Kind merken *kann*) | 0 (alles sichtbar) | 1–2 (optional, Bubble tippbar) | 3–5 (Merk-Modus, Bubble tippbar) |
| Gleichzeitige Wünsche sichtbar | 1 (max. 2) | 2–3 | 3–5 |
| Neue Konzepte pro Hoftag | 0–1 | 1–2 | 2–3 |

### 4.3 Tempo, Sprache, UI

| Parameter | Keimling | Spross | Blüte |
|---|---|---|---|
| Wünsche pro Hoftag | 4 | 5 | 6 |
| Typische Hoftag-Dauer | ~8 Min. | ~10 Min. | ~12 Min. |
| Wartezeit bis erster Hinweis | 4 s | 8 s | 15 s |
| Sprache: Wörter je Satz | 3–6 | 5–9 | 6–12 |
| Sprechtempo Pelle | langsam (~100 wpm) | normal-langsam (~115 wpm) | normal (~130 wpm) |
| Lesehilfe (Wort-Highlight beim Sprechen) | aus | optional | optional, Standard an |
| Gleichzeitige UI-Elemente | ≤ 3 | ≤ 5 | ≤ 8 |
| Kamera | Auto-Kamera, fest | Auto + Pinch-Zoom (begrenzt) | frei: Zoom, 90°-Rotation, Neigen |
| Maschinensteuerung | Autopilot/Tippen | Magnet-Lenkhilfe | freies Lenken, Gas/Bremse |
| Zahlen-Darstellung | nur Punkte/Finger | Punkte + Ziffern | Ziffern + Punkte |

## 5. Wie „Mitwachsen“ erlebt wird – drei Szenen

**Szene A – Möhren ernten.**
- *Keimling (3):* Pelle sagt „Tipp auf die Möhre!“ → Kind tippt auf eine reife Möhre, die Möhre springt in den Korb. Alle 3 Möhren sind groß, mit Glitzer markiert.
- *Spross (5):* „Zieh die Möhre aus der Erde!“ → Kind zieht nach oben; es sind 5 Möhren, nur die reifen (orange, nicht grüne Spitzen) lassen sich ziehen. Pelle: „Zähl mit: eins, zwei, drei …“
- *Blüte (7):* „Erntet 8 Möhren und bringt sie zu Tilda, aber sortiert die dicken in die Kiste links!“ → Mehrstufig, Merken, Sortieren, Zählen.

**Szene B – Traktor pflügen.**
- *Keimling:* Kind tippt aufs Feld, der Traktor fährt von selbst; Kind darf *hupen* (tippen auf Pelle-Button) und die Erde „gluckst“.
- *Spross:* Finger auf den Traktor legen und eine leuchtende Spur entlangziehen; magnetische Spurführung.
- *Blüte:* Lenkrad + Gas-Hebel, Spuren sind enger, saubere Streifen ergeben Muster („Streifenmähen“).

**Szene C – Hofladen.**
- *Keimling:* Kundin Tilda hat ein Bild von *einem* Apfel; Kind zieht einen Apfel in den Korb.
- *Spross:* Zwei Äpfel + eine Milch; Silhouetten im Korb zeigen, wo was hinkommt.
- *Blüte:* Bestellung erscheint 3 Sekunden, verschwindet (oder per Tipp wieder anzeigen); 3 Äpfel, 2 Eier, 1 Brot; Gesamtsumme in Talern darf optional zusammengezählt werden.

## 6. Altersbezogene Besonderheiten

### 3–4 Jahre (Keimling)
- Maximal 2 Schritte je Wunsch, 1 Sache gleichzeitig.
- Große, deutliche Hitboxen, keine Fehlereingaben „bestrafen“; Fehltreffer lösen **Mitnahme-Hilfe** aus (das Spiel führt die Hand sanft zum Ziel).
- Pelle spricht kurz, wiederholt Schlüsselwörter („Kuh. Die Kuh hat Durst. Wasser für die Kuh!“).
- Kamera darf **nie** versehentlich verdreht werden. Fixe isometrische Kamera.
- Berührungs-Kunstgriffe: „Sticky Touch“ (einmal berührte Objekte bleiben in der Hand, bis sie abgelegt werden – kein Festhalten nötig).

### 5–6 Jahre (Spross)
- Drag-and-Drop wird zuverlässig; kleine Mengenaufgaben; Reihenfolgen (3 Schritte).
- Erste **Merk-Momente** (Optional-Bubble: „Merk dir die zwei Äpfel!“).
- Erste Wörter/Zahlen als Schrift neben dem Bild *optional* (Lesehilfe).
- Erste Eigenständigkeit: Kind wählt selbst, welcher Wunsch zuerst erfüllt wird.

### 7–8 Jahre (Blüte)
- Planen: Mehrere Wünsche gleichzeitig, Reihenfolge selbst bestimmen („Erst säen, dann Laden füllen“).
- Lenken mit Lenkrad, Gas/Bremse, Anhänger rückwärts rangieren (Optionalmodus).
- Rechnen im Spielzusammenhang: „5 Taler + 3 Taler“, Wechselgeld bis 10 (nur optional, Kinder können es überspringen).
- Sachwissen: „Wie wird aus Weizen Brot?“ → Mühle → Backofen → Laden (Produktionsketten).
- Freies Hof-Design (Dekoration, Wegeführung) als kreative Herausforderung.

## 7. Geschwister- und Eltern-Modus (Co-Play)

- **Mehrere Profile** (max. 4 pro Gerät): Auswahl über Tier-Avatare (Bild, kein Text), jedes Profil hat eigenen Hof, Fortschritt, Mastery.
- **Gemeinsamer Hof (iPad):** Zwei Kinder dürfen gleichzeitig spielen; die Eingabe unterscheidet zwei unabhängige Hände (Zwei-Cursor-Handschuhe, farbig). Wünsche sind kooperativ („Zusammen tragen“-Aufgaben), nie kompetitiv.
- **Eltern-Mitspielen:** „Hilfs-Hand“-Option: Ein zweiter Finger-Cursor (grauer Handschuh) darf Kindern assistieren, ohne die Kind-Mastery zu beeinflussen (Mastery zählt nur den „Kind-Cursor“).
- **Mastery-Zuordnung:** Bei geteiltem Hof wird `mastery` pro Profil, nicht pro Hof geführt. Wünsche richten sich nach dem *jüngeren* anwesenden Profil.

## 8. Lernziele und Rahmung (ohne Heilsversprechen)

Das Spiel orientiert sich an üblichen Bildungsbereichen frühkindlicher Bildung (u. a. Bewegung/Motorik, Mathematik, Sprache, Natur/Umwelt, Soziales). Marketing- und Storetexte sagen: *„Fördert spielerisch …“*, niemals: *„verbessert nachweislich …“*. Konkrete Lernziele je Aktivität stehen im Aktivitätskatalog (Dokument 09).

| Lernbereich | Spielerische Förderung |
|---|---|
| Motorik | Tippen, Wischen, Ziehen, Spur halten, Lenken |
| Merkfähigkeit | Bestellungen, Tierreihenfolge, Muster merken |
| Strukturen/Logik | Arbeitsabläufe, Reihenfolgen, Ursache–Wirkung |
| Mathematik | Mengen, Zählen, Zuordnen, später Rechnen |
| Sprache | Wortschatz Bauernhof, Anlaute, Reime, Satzbau durch Vorbild |
| Natur/Welt | Wachstumsstadien, Jahreszeiten, Herkunft von Lebensmitteln |
| Sozial-emotional | Fürsorge für Tiere, Teilen, Höflichkeit (bitte/danke) |
