# 16 – Datenmodelle und Schemas

> Alle Spielinhalte sind **Daten** (JSON, Codable). Dieses Dokument legt ID-Schema, zentrale Typen, Beispiel-Dateien und Event-Formate fest. Die vollständigen ID-Listen stehen in Doc 21.

## 1. ID-Konventionen

| Regel | Beispiel |
|---|---|
| Format `<typ>.<name>` (kleinschreibung, ASCII, Punkt-getrennt) | `crop.carrot`, `animal.cow`, `act.shop.order` |
| IDs sind **stabil** (nie umbenennen/wiederverwenden); Änderungen = neue ID + Migration | – |
| Präfixe | `crop.` `animal.` `item.` `veh.` `imp.` `act.` `loc.` `wish.` `vl.` `npc.` `hofbook.` `season.` `deco.` |
| Voicelines | `vl.<sprecher>.<kategorie>.<nr>` (`vl.pelle.praise.047`) |
| Version | Jede Datei: `"schemaVersion": <Int>` |

## 2. Enums

```swift
enum GrowthStage: String, Codable { case sprout, shoot, bloom }          // Keimling, Spross, Blüte
enum Lane: String, Codable { case moTap, moDrag, moSteer, cogMemory, cogSequence,
                             cogMatching, mathCount, percShape, langVocab, worldTime }
enum Season: String, Codable { case spring, summer, autumn, winter }
enum DayPhase: String, Codable { case morning, forenoon, noon, afternoon, evening, night }
enum CropState: String, Codable { case empty, plowed, seeded, sprouting, growing, ripe, harvested }
enum Mood: String, Codable { case content, happy, playful, sleepy, curious }   // nur positive Stimmungen
enum AssistLevel: Int, Codable { case independent = 0, cue, hint, ghost, reduced, together }
enum VoicePriority: String, Codable { case high, mid, low }
enum Emotion: String, Codable { case warm, cheer, soft, curious, sleepy }
```

## 3. Content-Schemas (Beispiele)

### 3.1 `crops.json`
```json
{
  "schemaVersion": 1,
  "crops": [
    {
      "id": "crop.carrot",
      "nameKey": "vl.vocab.crop.carrot",
      "icon": "icon.crop.carrot",
      "seasons": ["spring", "summer", "autumn"],
      "nightsToRipe": 2,
      "unlockHofstufe": 1,
      "harvest": { "yield": 3, "item": "item.carrot", "method": "pull" },
      "stageModels": ["model.crop.carrot.s0", "model.crop.carrot.s1", "model.crop.carrot.s2", "model.crop.carrot.s3"],
      "value": 2
    }
  ]
}
```

### 3.2 `animals.json`
```json
{
  "schemaVersion": 1,
  "animals": [
    {
      "id": "animal.cow",
      "defaultName": "Rosa",
      "nameKey": "vl.vocab.animal.cow",
      "sounds": ["sfx.cow.moo.1", "sfx.cow.moo.2", "sfx.cow.hum"],
      "foods": ["item.hay", "item.carrot"],
      "products": [{ "item": "item.milk", "action": "act.animal.milk", "perDay": 1 }],
      "unlockHofstufe": 1,
      "interactions": ["pet", "brush", "feed", "milk"],
      "wishTemplates": ["wish.animal.hungry", "wish.animal.pet", "wish.animal.brush"],
      "personality": { "trait": "gemuetlich", "idleSet": "idle.cow.calm" }
    }
  ]
}
```

### 3.3 `activities.json`
```json
{
  "schemaVersion": 1,
  "activities": [
    {
      "id": "act.shop.order",
      "location": "loc.shop",
      "lanes": ["cogMemory", "mathCount"],
      "hofstufeMin": 1,
      "steps": [
        { "id": "listen",   "voice": "vl.pelle.order.listen" },
        { "id": "collect",  "lane": "cogMatching", "voice": "vl.pelle.order.collect" },
        { "id": "ring",     "lane": "moTap",       "voice": "vl.pelle.order.ring" }
      ],
      "params": {
        "sprout": { "itemTypes": [1,1], "qty": [1,2],  "memoryMode": false, "targetSize": 88 },
        "shoot":  { "itemTypes": [1,2], "qty": [1,3],  "memoryMode": false, "targetSize": 72 },
        "bloom":  { "itemTypes": [2,3], "qty": [1,5],  "memoryMode": true,  "targetSize": 60 }
      },
      "scaffold": { "hintAfterSec": 7, "ghostAfterFails": 2, "togetherAfterFails": 4 },
      "completion": { "tickValue": 1.0, "reward": "vl.praise.shop.order" }
    }
  ]
}
```

### 3.4 `items.json`
```json
{ "schemaVersion": 1,
  "items": [
    { "id": "item.apple", "kind": "fruit", "icon": "icon.item.apple",
      "shelfType": "basket", "sellValue": 2,
      "vocab": { "nom": "vl.vocab.item.apple", "acc": "vl.vocab.item.apple.acc", "plural": "vl.vocab.item.apple.pl" } }
  ] }
```

### 3.5 `seasons.json` (Auszug)
```json
{ "schemaVersion": 1,
  "seasons": [
    { "id": "season.winter",
      "lut": "lut.winter", "ambient": "amb.winter", "music": "mus.winter",
      "weather": { "sun": 0.3, "cloud": 0.2, "snow": 0.4, "fog": 0.1 },
      "festival": { "id": "festival.lights", "day": 4, "activity": "act.nature.lantern" } }
  ] }
```

### 3.6 `voicelines.json` (Auszug, Quelle: Doc 13 §3)
```json
{ "schemaVersion": 1,
  "lines": [
    { "id": "vl.pelle.praise.047", "character": "pelle", "category": "praise",
      "emotion": "cheer", "priority": "mid", "stageMin": "sprout", "stageMax": "bloom",
      "variantsGroup": "praise.generic", "file": "vo_de_vl.pelle.praise.047.m4a",
      "durationSec": 1.8, "context": "act.*.done" } ] }
```

### 3.7 `adaptive.json`
```json
{ "schemaVersion": 1,
  "mastery": { "alphaStart": 0.12, "alphaNormal": 0.08, "alphaMin": 0.03, "bootstrapObservations": 5,
               "weights": { "independent": 1.0, "hinted": 0.5, "assisted": 0.1 } },
  "scaffold": { "stillnessHintSec": [6, 8], "ghostFails": 2, "reduceFails": 3, "togetherFails": 4 },
  "thresholds": { "levelUp": { "window": 8, "minIndependent": 7 }, "levelDown": { "window": 3, "minAssisted": 2 },
                  "stageUp": { "medianMastery": 0.7, "days": 10 } },
  "fatigue": { "sproutMin": [10, 15], "shootMin": [15, 25], "bloomMin": [20, 35] } }
```

### 3.8 `economy.json` (Auszug)
```json
{ "schemaVersion": 1,
  "orderPayout": { "sprout": 3, "shoot": 6, "bloom": 10 },
  "ordersPerDay": { "sprout": 2, "shoot": 3, "bloom": 4 },
  "decoPrice": { "small": [3, 10], "large": [15, 30] } }
```

## 4. Spielstand-Schemas (pro Profil)

### 4.1 `Profile.json`
```json
{ "schemaVersion": 1,
  "profileId": "UUID",
  "avatarAnimal": "animal.sheep",
  "stage": "sprout",
  "stageLocked": false,
  "createdAt": "ISO8601",
  "settings": { "musicOn": true, "memoryMode": true, "hapticsOn": true, "weatherIntensity": 1.0,
                "sessionTimerMin": null, "subtitles": false, "speechSpeed": 1.0 },
  "childNameAudio": "audio/name.m4a" }
```

### 4.2 `World.json`
```json
{ "schemaVersion": 1,
  "day": 14, "season": "spring", "phase": "morning", "sunProgress": 0.35,
  "hofstufe": 2, "wishesDoneTotal": 37, "activityTypesDone": ["act.field.plow", "act.animal.feed"],
  "fields": [ { "id": "field.1", "tiles": [ { "x": 0, "z": 0, "crop": "crop.carrot", "state": "growing", "nightsLeft": 1, "thirsty": false } ] } ],
  "animals": [ { "id": "animal.cow.1", "name": "Rosa", "mood": "happy", "lastFedDay": 13 } ],
  "inventory": { "item.carrot": 5, "item.egg": 3 },
  "shelf": [ { "slot": 0, "item": "item.carrot", "qty": 3 } ],
  "taler": 42,
  "openWishes": [ { "id": "wish.0001", "giver": "animal.cow.1", "activity": "act.animal.feed", "createdDay": 14 } ],
  "decorations": [ { "id": "deco.bench.1", "x": 4, "z": 2, "rot": 90 } ],
  "wishlist": ["deco.windmill"],
  "hofbook": { "unlocked": ["hofbook.first_chick"], "seen": ["hofbook.first_chick"] } }
```

### 4.3 `Skills.json`
```json
{ "schemaVersion": 1,
  "mastery": { "moTap": 0.62, "moDrag": 0.4, "cogMemory": 0.3 },
  "confidence": { "moTap": 0.8, "moDrag": 0.5, "cogMemory": 0.3 },
  "recent": [ { "act": "act.shop.order", "lane": "cogMemory", "assist": "hint", "durationSec": 48, "day": 14 } ],
  "fatigue": { "todaySessionSec": 540 },
  "lastPlayedDay": 14 }
```

## 5. Lokale Events (nur zur Adaption, nie gesendet)

```swift
enum GameEvent {
    case activityStarted(id: ActivityID, lane: Lane, day: Int)
    case attempt(id: ActivityID, correct: Bool, ms: Int)
    case hintShown(level: AssistLevel)
    case frustrationSignal(kind: String)
    case activityCompleted(id: ActivityID, assist: AssistLevel, durationSec: Int)
    case wishCompleted(WishID), wishIgnored(WishID)
    case dayEnded(day: Int), seasonChanged(Season)
    case unlocked(ContentID)
}
```
Persistiert wird nur eine **aggregierte** Form (Ringpuffer ≤ 200 Events, danach Aggregation in `Skills.json`).

## 6. Wunsch-Datenmodell

```swift
struct Wish: Codable, Identifiable {
    let id: WishID
    let giver: EntityRef           // Tier/NPC/Pflanze
    let activity: ActivityID
    let payload: [String: String]  // z. B. ["item": "item.apple", "qty": "2"]
    let createdDay: Int
    var state: WishState           // open, inProgress, done, folded
    var priority: Int
}
```
**Invarianten:** Wünsche laufen nicht ab; `folded` blendet sie aus, löscht sie aber nie; ein erledigter Wunsch erzeugt immer ein sichtbares `world_change`.

## 7. Validierungsregeln (Content-Validator)

1. Alle referenzierten IDs existieren (Item, Voiceline, Modell, Icon, Sound).
2. Jede Aktivität hat Params für alle drei Stages.
3. Jede Kultur hat Modelle für alle Wachstumsstufen.
4. Jede Voiceline-ID aus Aktivitäten/Wünschen hat `approved` Audio pro aktivierter Sprache.
5. Jedes Item ist produzierbar (Kette von Rohstoff bis Produkt ohne Zyklus).
6. Preise/Zahlen innerhalb definierter Bereiche.
7. Keine verbotenen Wörter im Voiceline-Text (Blockliste: „falsch“, „nein“, „leider“, „verloren“ etc.).
8. Kein Content mit Hofstufe > 5.
