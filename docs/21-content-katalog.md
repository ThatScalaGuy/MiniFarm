# 21 – Content-Katalog (Master-ID-Liste)

> Dieses Dokument ist die **zentrale Referenz aller Inhalte** und ihrer IDs. Es konsolidiert die Dokumente 03–09 und ist die Vorlage für die JSON-Dateien aus Doc 16 (`crops.json`, `animals.json`, `items.json`, `machines.json`, `activities.json`, `seasons.json`, …).
> **Bei Widersprüchen gilt: Dieses Dokument + Doc 16 (Schemas) vor den Fachdokumenten.** Änderungen an Inhalten zuerst hier eintragen, dann im Fachdokument nachziehen. Alle Namen von Figuren und Tieren sind **Arbeitstitel** (Doc 23).

## 1. Konventionen (Kurzfassung, Details Doc 16 §1)

| Regel | Beispiel |
|---|---|
| IDs: `präfix.name`, Kleinbuchstaben, ASCII, keine Umlaute, Punkt als Trenner | `crop.carrot`, `act.animal.feed` |
| Präfixe | `crop. animal. item. veh. imp. act. loc. wish. vl. npc. hofbook. season. deco.` |
| Ernte-Item einer Kultur | `item.<kulturname>` (z. B. `item.carrot`) |
| Saattüte einer Kultur | `item.seed.<kulturname>` |
| Instanzen (zur Laufzeit) | `animal.cow.1`, `deco.bench.3` |
| Voice-Zeilen | `vl.<sprecher>.<kategorie>.<nr>` → Datei `vo_<lang>_<id>.m4a` |
| Hofstufe | 1–5, immer als ganze Zahl; „ab Hofstufe N“ = freigeschaltet bei Erreichen |
| Löschen von IDs | Nie. Veraltete IDs erhalten `deprecated: true` (Speicherstände bleiben lesbar) |

## 2. Kulturen (14)

| ID | Name | Saat-Saison | Nächte bis reif¹ | Ort | Ertrag/Kachel | Taler | Hofstufe |
|---|---|---|---|---|---|---|---|
| `crop.radish` | Radieschen | Frühling, Sommer, Herbst | 1 | Garten | 3 | 1 | 1 |
| `crop.carrot` | Karotte | Frühling, Sommer | 2 | Garten, Acker | 3 | 1 | 1 |
| `crop.lettuce` | Salat | Frühling, Sommer, Herbst | 2 | Garten | 2 | 1 | 1 |
| `crop.pea` | Erbse | Frühling | 2 | Garten | 4 | 1 | 2 |
| `crop.potato` | Kartoffel | Frühling | 3 | Garten, Acker | 4 | 1 | 2 |
| `crop.strawberry` | Erdbeere | Frühling (Frucht im Sommer) | 3 | Garten | 4 | 2 | 3 |
| `crop.tomato` | Tomate | Sommer; Gewächshaus ganzjährig | 3 | Garten, Gewächshaus | 5 | 2 | 3 |
| `crop.corn` | Mais | Sommer | 4 | Acker | 2 | 2 | 3 |
| `crop.sunflower` | Sonnenblume | Sommer | 3 | Garten, Acker | 2 | 2 | 3 |
| `crop.apple` | Apfel (Baum) | Blüte Frühling, Frucht Herbst | Jahreszeit | Obstwiese | 4 pro Baum | 1 | 3 |
| `crop.wheat` | Weizen | Frühling, Herbst | 4 | Acker | 6 | 1 | 4 |
| `crop.pumpkin` | Kürbis | Sommer, Herbst | 4 | Acker, Garten | 1 (groß) | 4 | 4 |
| `crop.kale` | Grünkohl | Herbst, Winter (Gewächshaus) | 3 | Garten, Gewächshaus | 3 | 2 | 4 |
| `crop.chives` | Schnittlauch | alle (Gewächshaus) | 2 | Gewächshaus | 3 | 1 | 4 |

¹ Keimling-Stufe: maximal 2 Nächte (Doc 05). Quelle: Doc 05 §3.
Verteilung nach Hofstufe: 1 → 3 · 2 → 2 · 3 → 5 · 4 → 4 (Kulturen 14 gesamt).

## 3. Tiere und Tierfiguren (11)

| ID | Name | Baby | Produkt (Roh) | Hofstufe | Anzahl Start → Voll | Ort |
|---|---|---|---|---|---|---|
| `animal.chicken` | Huhn | Küken | `item.egg` | 1 | 3 → 6 | `loc.henhouse` |
| `animal.cat` | Hofkatze **Minka** | – | – | 1 | 1 | überall (autonom) |
| `animal.dog` | Hofhund **Pelle** (Guide) | – | – | 1 | 1 | überall (Begleiter) |
| `animal.cow` | Kuh | Kalb | `item.milk` | 2 | 2 → 4 | `loc.cowbarn` |
| `animal.sheep` | Schaf | Lamm | `item.wool` | 3 | 3 → 6 | `loc.sheepmeadow` |
| `animal.pig` | Schwein | Ferkel | `item.compost` | 3 | 2 → 3 | `loc.pigsty` |
| `animal.duck` | Ente | Entlein | `item.duckegg`, `item.feather` | 4 | 3 → 5 | `loc.pond` |
| `animal.goat` | Ziege | Zicklein | `item.goatmilk` | 4 | 2 → 3 | `loc.goatpen` |
| `animal.horse` | Pferd | Fohlen | Kutschfahrten | 5 | 1 + Fohlen | `loc.paddock` |
| `animal.rabbit` | Kaninchen | Junge | – (Streicheltier) | 5 | 2 → 4 | Hasengehege (Unterbereich von `loc.paddock`) |
| `animal.bee` | Bienen | – | `item.honeycomb` | 5 | 1 Stock | `loc.apiary` |

Gäste (nur Hofbuch-Entdeckungen, nie bedrohlich): Igel `animal.hedgehog`, Eichhörnchen `animal.squirrel`, Fuchs (scheu) `animal.fox`, Frösche `animal.frog`, Schmetterlinge `animal.butterfly`, Marienkäfer `animal.ladybug`, Vögel `animal.bird`.
Einzeltiere erhalten Namen aus Namenslisten (Doc 06 §2) und Instanz-IDs (`animal.cow.1`).

## 4. Maschinen und Geräte (11)

| ID | Name | Hofstufe | Kernaufgabe |
|---|---|---|---|
| `veh.tractor` | Traktor | 2 | Zieht alle Anbaugeräte |
| `imp.plow` | Pflug | 2 | Furchen pflügen |
| `imp.seeder` | Sämaschine | 2 | Reihen säen |
| `imp.trailer` | Anhänger (Kipper) | 2 (einfach) / 4 | Transport |
| `imp.watertank` | Wasserfass | 3 | Reihen wässern |
| `imp.mower` | Mähwerk | 3 | Wiese mähen |
| `imp.baler` | Ballenpresse | 4 | Heu → Ballen |
| `imp.loader` | Frontlader | 4 | Ballen/Kürbisse heben |
| `imp.potatodigger` | Kartoffelroder | 4 | Kartoffeln ausgraben |
| `veh.combine` | Mähdrescher | 4 | Weizen/Mais ernten |
| `imp.snowplow` | Schneeschild | 5 | Schnee räumen |

Zusätzlich (ohne Fahrbetrieb): Pferdekutsche `veh.carriage` (Hofstufe 5), Handwerkzeuge `tool.can` (Gießkanne, ab Stufe 1), `tool.bucket`, `tool.brush`, `tool.shears`, `tool.basket`.

## 5. Items

### 5.1 Ernte- und Saat-Items (aus Kulturen)

| Gruppe | IDs |
|---|---|
| Ernte-Items (14) | `item.radish`, `item.carrot`, `item.lettuce`, `item.pea`, `item.potato`, `item.strawberry`, `item.tomato`, `item.corn`, `item.sunflower`, `item.apple`, `item.wheat`, `item.pumpkin`, `item.kale`, `item.chives` |
| Saat-Tüten (13; Apfel wächst als Baum) | `item.seed.radish` … `item.seed.chives` (ohne Apfel) |

### 5.2 Tier-Rohprodukte und Futter

| ID | Name | Quelle | Taler | Hofstufe |
|---|---|---|---|---|
| `item.egg` | Ei | Huhn | 2 | 1 |
| `item.milk` | Milch | Kuh | 2 | 2 |
| `item.wool` | Wolle | Schaf | 3 | 3 |
| `item.compost` | Kompost | Schwein | – (Dünger) | 3 |
| `item.duckegg` | Enten-Ei (klein) | Ente | 2 | 4 |
| `item.feather` | Feder | Ente | 1 | 4 |
| `item.goatmilk` | Ziegenmilch | Ziege | 3 | 4 |
| `item.honeycomb` | Honigwabe | Biene | 3 | 5 |
| `item.hay` | Heu | Wiese/Mähwerk | 1 | 1 |
| `item.feed` | Körnerfutter | Laden/Hof | – | 1 |

### 5.3 Verarbeitete Produkte (Hofküche)

| ID | Name | Quelle | Taler | Hofstufe |
|---|---|---|---|---|
| `item.flour` | Mehl | Mühle | 2 | 4 |
| `item.bread` | Brot | Backofen | 4 | 4 |
| `item.cake` | Kuchen | Backofen | 6 | 4 |
| `item.applejuice` | Apfelsaft | Saftpresse | 4 | 4 |
| `item.butter` | Butter | Butterfass | 3 | 4 |
| `item.cheese` | Käse | Käserei | 5 | 4 |
| `item.goatcheese` | Ziegenkäse | Käserei | 6 | 4 |
| `item.jam` | Marmelade | Kessel | 4 | 4 |
| `item.icecream` | Erdbeereis | Eismaschine | 5 | 4 |
| `item.honey` | Honigglas | Schleuder | 5 | 5 |
| `item.beanie` | Mütze | Strickstube | 6 | 5 |

Verknüpfte Doku: Doc 07 §3.

## 6. Orte (17) und Unterbereiche

| ID | Name | Ab Hofstufe | Tiere/Kulturen/Besonderes |
|---|---|---|---|
| `loc.plaza` | Hofplatz | 1 | Hofbaum, Brunnen, Briefkasten, Windrad |
| `loc.garden` | Gemüsegarten | 1 | 6 → 12 → 18 Beete |
| `loc.henhouse` | Hühnerhaus | 1 | Hühner, Küken |
| `loc.shop` | Hofladen | 1 (Stand) → 3 (Haus) → 5 (Markt) | Kunden, Regal |
| `loc.garage` | Maschinenhalle | 2 | Traktor, Geräte |
| `loc.field` | Acker | 2 | 4×4 → 8×6 → 12×8 Kacheln |
| `loc.cowbarn` | Kuhstall | 2 | Kühe, Kalb |
| `loc.sheepmeadow` | Schafweide | 3 | Schafe, Lämmer |
| `loc.pigsty` | Schweinekoben | 3 | Schweine, Ferkel |
| `loc.orchard` | Obstwiese | 3 | 4 → 8 Apfelbäume |
| `loc.kitchen` | Hofküche | 4 | Mühle, Backofen, Saftpresse, Butterfass, Kessel, Eismaschine, Käserei |
| `loc.greenhouse` | Gewächshaus | 4 | Winteranbau, Kräuter |
| `loc.pond` | Ententeich | 4 | Enten, Frösche, Seerosen |
| `loc.goatpen` | Ziegengehege | 4 | Ziegen, Kletterfelsen |
| `loc.paddock` | Pferdekoppel | 5 | Pferd, Fohlen, Hasengehege |
| `loc.apiary` | Bienenstock | 5 | Bienen, Blumenwiese, Honigschleuder |
| `loc.village` | Dorfmarkt | 5 | Straße, Marktplatz, 4 Stände |

Inselgrößen je Hofstufe (Kacheln): 16×12 · 22×16 · 28×20 · 34×24 · 40×28 (Doc 04).
Zusatz-Unterbereiche (keine eigene Hofstufe): Strickstube (an `loc.kitchen`, Stufe 5), Hasengehege (an `loc.paddock`).

## 7. Aktivitäten (39)

Die Detailbeschreibung (Kernschritte, Lanes, Stage-Parameter) steht in **Doc 09 §2–§3**; hier nur die Master-Liste.

| Gruppe | Aktivitäten (ID → Hofstufe) |
|---|---|
| **Feld** (8) | `act.field.plow` 2 · `act.field.sow` 1 · `act.field.water` 1 · `act.field.harvest` 1 · `act.field.combine` 4 · `act.field.hay` 4 · `act.field.scarecrow` 2 · `act.field.snowplow` 5 |
| **Tiere** (9) | `act.animal.feed` 1 · `act.animal.water` 1 · `act.animal.pet` 1 · `act.animal.milk` 2 · `act.animal.eggs` 1 · `act.animal.shear` 3 · `act.animal.bed` 1 · `act.animal.find` 2 · `act.animal.baby` 3 |
| **Laden/Küche** (8) | `act.shop.stock` 1 · `act.shop.order` 1 · `act.shop.sign` 3 · `act.shop.market` 5 · `act.kitchen.bake` 4 · `act.kitchen.press` 4 · `act.kitchen.churn` 4 · `act.kitchen.jam` 4 |
| **Natur** (7) | `act.nature.flowers` 1 · `act.nature.pond` 2 · `act.nature.birdhouse` 2 · `act.nature.compost` 3 · `act.nature.kite` 3 · `act.nature.snowman` 3 · `act.nature.lantern` 3 |
| **Dorf/Hof** (7) | `act.village.mail` 4 · `act.village.helpmo` 3 · `act.farm.decorate` 2 · `act.farm.photo` 2 · `act.farm.clean` 1 · `act.farm.memory` 3 · `act.farm.sing` 2 |

Verteilung nach Hofstufe: 1 → 12 · 2 → 9 · 3 → 9 · 4 → 7 · 5 → 2 (= 39).
Gating-Hinweis: Eine Aktivität darf nur dann generiert werden, wenn **alle** beteiligten Objekte (Ort, Tier, Gerät, Item) freigeschaltet sind (Validator, Doc 16 §7).

## 8. Figuren (Sprecher-IDs)

| ID | Figur | Rolle | Hofstufe | Sprecher-Präfix |
|---|---|---|---|---|
| `animal.dog` | **Pelle** | Hofhund, Guide, Hauptstimme | 1 | `vl.pelle.*` |
| `npc.tilda` | Bäckerin **Tilda** | Stammkundin, Backen | 1 | `vl.npc.tilda.*` |
| `npc.hanno` | Opa **Hanno** | Geschichten, Schnitzen, Hofbaum | 2 | `vl.npc.hanno.*` |
| `npc.mo` | **Mo** | Nachbarskind, Spielgefährte | 3 | `vl.npc.mo.*` |
| `npc.lale` | Postbotin **Lale** | Briefe, Post | 4 | `vl.npc.lale.*` |
| `npc.yusuf` | Marktverkäufer **Yusuf** | Dorfmarkt | 4 | `vl.npc.yusuf.*` |
| `animal.cat` | Hofkatze **Minka** | Gast, Kuschel | 1 | nur SFX (Miau) |

Tiere sprechen nicht; sie machen Laute (SFX). Voice-Casting: Doc 12 §2, Doc 23 O-3.

## 9. Jahreszeiten, Wetter und Feste

| ID | Jahreszeit | Fest (Hoftag 4) | Fest-ID |
|---|---|---|---|
| `season.spring` | Frühling | Blütenfest | `season.spring.fest` |
| `season.summer` | Sommer | Erntefreudentag | `season.summer.fest` |
| `season.autumn` | Herbst | Danke-Fest | `season.autumn.fest` |
| `season.winter` | Winter | Lichterfest | `season.winter.fest` |

Eine Jahreszeit = **4 Hoftage**; ein Hofjahr = 16 Hoftage (Doc 08).
**Wetter (7):** Sonne, Bewölkt, Leichter Regen, Regenbogen, Nebel, Schnee, Wind (Gewitter gibt es nicht).

## 10. Deko (Kategorien und Richtmengen Vollausbau)

| Kategorie | Präfix | Beispiele | Menge (Ziel) |
|---|---|---|---|
| Zäune/Wege | `deco.fence.*`, `deco.path.*` | Holzzaun, Steinweg | 10 |
| Möbel | `deco.bench.*`, `deco.table.*` | Bank, Tisch | 10 |
| Pflanzen/Blumen | `deco.flower.*`, `deco.tree.*` | Tulpen, Birke | 18 |
| Licht | `deco.lantern.*` | Laternen, Lichterkette | 8 |
| Spiel/Technik | `deco.windmill`, `deco.swing`, `deco.musicbox` | Windrad, Schaukel | 12 |
| Laden-Deko | `deco.shop.*` | Markise, Schild, Blumenkasten | 14 |
| Tier-Accessoires | `deco.acc.*` | Schleife, Glöckchen, Hut | 12 |
| Fahrzeug-Sticker | `deco.sticker.*` | Stern, Blume, Herz, Regenbogen | 8 |
| Saison-Deko | `deco.season.*` | Kürbislaterne, Schneeflocke | 16 |
| **Summe** | | | **≈ 108** |

Alle Deko ist **kosmetisch**, kostet nur Taler (3–10 klein / 15–30 groß) und wird nie für Fortschritt benötigt (Doc 07 §5).

## 11. Hofbuch-Einträge

| Seite | Präfix | Einträge (Ziel) | Füllt sich durch |
|---|---|---|---|
| Pflanzen | `hofbook.plant.*` | 14 | Säen und Ernten |
| Tiere | `hofbook.animal.*` | 11 + 8 Babys + 7 Gäste = 26 | Kennenlernen |
| Maschinen | `hofbook.machine.*` | 12 (inkl. Kutsche) | Erste Fahrt |
| Dorfbewohner | `hofbook.npc.*` | 6 (Pelle + 5) + Minka | Erste Begegnung |
| Jahreszeiten | `hofbook.season.*` | 4 Seiten × 6–8 | Saison-Aktivitäten |
| Entdeckungen | `hofbook.discovery.*` | ≥ 60 | Neugierige Berührungen (Doc 04 §7) |

Unentdeckte Einträge = Silhouetten; es gibt **keine** Prozentanzeige (Doc 03 §4).

## 12. Voice-Line-Budget (Planwerte)

| Kategorie | Präfix | Slice (ca.) | Voll (ca.) |
|---|---|---|---|
| Begrüßung/Abschied | `vl.pelle.greet.*` | 20 | 60 |
| Wunsch-Ansagen | `vl.wish.*` | 130 | 700 |
| Anleitungen je Schritt | `vl.pelle.<act>.<step>` | 120 | 400 |
| Hinweise (Scaffold 1) | `vl.hint.*` | 100 | 450 |
| Lob | `vl.praise.*` | 40 | 200 |
| Zählen | `vl.count.*` | 25 | 30 |
| Wortschatz (Nom./Akk./Plural) | `vl.vocab.*` | 60 | 400 |
| Erzählung/Stimmung | `vl.story.*` | 30 | 150 |
| Jahreszeiten | `vl.season.*` | 20 | 160 |
| Rituale | `vl.ritual.*` | 15 | 80 |
| Lieder/Reime | `vl.song.*` | 4 | 24 |
| Dorfbewohner | `vl.npc.<id>.*` | 20 | 300 |
| Hofbuch-Fun-Facts | `vl.book.*` | 16 | 300 |
| Varianten/Reserve | – | – | 750 |
| **Summe** | | **≈ 600** | **≈ 4000** |

Bausteine (Doc 13 §5) senken die Anzahl der Zeilen, die für Wünsche gesprochen werden müssen. Tatsächliche Mengen ergeben sich im Zeilen-Katalog.

## 13. Konsistenz-Checkliste (Validator, Doc 16 §7)

- [ ] Jede ID kommt genau einmal vor; keine Doppelungen zwischen Präfixen
- [ ] Jede Aktivität nennt gültige `loc.*`, `animal.*`, `item.*`, `veh./imp.*`
- [ ] Hofstufe jeder Aktivität ≥ max(Hofstufe aller Beteiligten)
- [ ] Jedes Item hat Icon, 3D-Modell, `vl.vocab.*` (Nom/Akk/Plural), Verkaufswert
- [ ] Jede Kultur: 4 Wachstumsstadien, Ernte-Item, Saat-Tüte
- [ ] Jedes Tier: Idle-/Interaktions-Animation, Laut-SFX, Hofbuch-Eintrag, Baby (falls vorhanden)
- [ ] Jedes `vl.*` im Zeilen-Katalog existiert als Datei in jeder aktiven Sprache
- [ ] Anzahlen in diesem Dokument stimmen mit den JSON-Dateien überein (CI-Test)
