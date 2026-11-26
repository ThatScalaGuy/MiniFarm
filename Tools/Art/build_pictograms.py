#!/usr/bin/env python3
"""Rebuild checked-in SVG imagesets and the ID/VoiceOver index: python3 Tools/Art/build_pictograms.py.

No dependencies and no Xcode build step. --check fails on missing or stale output.
Aliases reuse a single compiled image. A seed packet, unlike an alias, has its own silhouette.
"""

import argparse
import json
import re
from pathlib import Path

import drawings as art


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "App" / "Art"
CATALOG = APP / "FarmPictograms.xcassets"
INFO = {"author": "xcode", "version": 1}

CROPS = {
    "radish": "Radieschen", "carrot": "Karotte", "lettuce": "Salat", "pea": "Erbse", "potato": "Kartoffel",
    "strawberry": "Erdbeere", "tomato": "Tomate", "corn": "Mais", "sunflower": "Sonnenblume",
    "apple": "Apfel", "wheat": "Weizen", "pumpkin": "Kürbis", "kale": "Grünkohl", "chives": "Schnittlauch",
}
ANIMALS = {
    "dog": "Pelle, der Hofhund", "cat": "Minka, die Hofkatze", "chicken": "Huhn", "cow": "Kuh", "sheep": "Schaf",
    "pig": "Schwein", "duck": "Ente", "goat": "Ziege", "horse": "Pferd", "rabbit": "Kaninchen", "bee": "Biene",
    "hedgehog": "Igel", "squirrel": "Eichhörnchen", "fox": "Fuchs", "frog": "Frosch", "butterfly": "Schmetterling",
    "ladybug": "Marienkäfer", "bird": "Vogel",
}
BABIES = {"chick": "Küken", "calf": "Kalb", "lamb": "Lamm", "piglet": "Ferkel", "duckling": "Entenküken",
          "kid": "Zicklein", "foal": "Fohlen", "kit": "Kaninchenjunges"}
PARENTS = {"chick": "chicken", "calf": "cow", "lamb": "sheep", "piglet": "pig", "duckling": "duck",
           "kid": "goat", "foal": "horse", "kit": "rabbit"}
MACHINES = {"tractor": "Traktor", "plow": "Pflug", "seeder": "Sämaschine", "trailer": "Anhänger",
            "watertank": "Wasserfass", "mower": "Mähwerk", "baler": "Ballenpresse", "loader": "Frontlader",
            "potatodigger": "Kartoffelroder", "combine": "Mähdrescher", "snowplow": "Schneeschild", "carriage": "Pferdekutsche"}
TOOLS = {"can": "Gießkanne", "bucket": "Eimer", "brush": "Bürste", "shears": "Schere", "basket": "Korb"}
PRODUCTS = {"egg": "Hühnerei", "milk": "Milch", "wool": "Wolle", "compost": "Kompost", "duckegg": "Entenei",
            "feather": "Feder", "goatmilk": "Ziegenmilch", "honeycomb": "Honigwabe", "hay": "Heu", "feed": "Körnerfutter",
            "flour": "Mehl", "bread": "Brot", "cake": "Kuchen", "applejuice": "Apfelsaft", "butter": "Butter", "cheese": "Käse",
            "goatcheese": "Ziegenkäse", "jam": "Marmelade", "icecream": "Erdbeereis", "honey": "Honig", "beanie": "Mütze"}
PLACES = {"plaza": "Hofplatz", "garden": "Gemüsegarten", "henhouse": "Hühnerhaus", "shop": "Hofladen",
          "garage": "Maschinenhalle", "field": "Acker", "cowbarn": "Kuhstall", "sheepmeadow": "Schafweide",
          "pigsty": "Schweinekoben", "orchard": "Obstwiese", "kitchen": "Hofküche", "greenhouse": "Gewächshaus",
          "pond": "Ententeich", "goatpen": "Ziegengehege", "paddock": "Pferdekoppel", "apiary": "Bienenstock", "village": "Dorfmarkt"}
ACTIVITIES = {
    "field.plow": "Feld pflügen", "field.sow": "Säen", "field.water": "Beete gießen", "field.harvest": "Ernten",
    "field.combine": "Mähdrescher fahren", "field.hay": "Heuballen rollen", "field.scarecrow": "Vogelscheuche bauen", "field.snowplow": "Schnee schieben",
    "animal.feed": "Tiere füttern", "animal.water": "Tränke füllen", "animal.pet": "Streicheln", "animal.milk": "Melken",
    "animal.eggs": "Eier sammeln", "animal.shear": "Scheren", "animal.bed": "Ins Bett bringen", "animal.find": "Tier suchen", "animal.baby": "Tierbaby pflegen",
    "shop.stock": "Regal füllen", "shop.order": "Bestellung erfüllen", "shop.sign": "Schild gestalten", "shop.market": "Zum Markt fahren",
    "kitchen.bake": "Backen", "kitchen.press": "Saft pressen", "kitchen.churn": "Butter rühren", "kitchen.jam": "Marmelade kochen",
    "nature.flowers": "Blumen pflücken", "nature.pond": "Frösche entdecken", "nature.birdhouse": "Vögel füttern", "nature.compost": "Würmer suchen",
    "nature.kite": "Drachen steigen lassen", "nature.snowman": "Schneemann bauen", "nature.lantern": "Laternen aufstellen",
    "village.mail": "Briefe austragen", "village.helpmo": "Mo helfen", "farm.decorate": "Hof schmücken", "farm.photo": "Foto machen",
    "farm.clean": "Aufräumen", "farm.memory": "Bildpaare finden", "farm.sing": "Mit Pelle singen",
}
PEOPLE = {"tilda": "Bäckerin Tilda", "hanno": "Opa Hanno", "mo": "Nachbarskind Mo", "lale": "Postbotin Lale", "yusuf": "Marktverkäufer Yusuf"}
SEASONS = {"spring": "Frühling", "summer": "Sommer", "autumn": "Herbst", "winter": "Winter"}


def vocabulary():
    cards, aliases = {}, {}
    animals, crops, machines, tools, people = art.animals(), art.crops(), art.machines(), art.tools(), art.people()
    products = art.products(crops, animals)
    places = art.locations(animals, crops, machines, products)
    activities = art.activities(animals, crops, machines, products, tools, places, people)

    def add(prefix, shapes, labels):
        assert shapes.keys() == labels.keys(), (prefix, shapes.keys() ^ labels.keys())
        for key, label in labels.items():
            cards[f"{prefix}.{key}"] = (label, shapes[key])

    add("animal", animals, ANIMALS)
    add("animal", art.babies(animals), BABIES)
    add("npc", people, PEOPLE)
    add("season", art.seasons(), SEASONS)
    add("crop", crops, CROPS)
    add("item", products, PRODUCTS)
    add("tool", tools, TOOLS)
    add("loc", places, PLACES)
    add("act", activities, ACTIVITIES)
    for key, label in MACHINES.items():
        kind = "veh" if key in {"tractor","combine","carriage"} else "imp"
        cards[f"{kind}.{key}"] = (label, machines[key])
        aliases[f"hofbook.machine.{key}"] = f"{kind}.{key}"
    for key in crops:
        aliases[f"item.{key}"] = aliases[f"hofbook.plant.{key}"] = f"crop.{key}"
        if key != "apple":
            cards[f"item.seed.{key}"] = (f"Saatgut: {CROPS[key]}", art.seed_packet(crops[key]))
    for key in list(ANIMALS) + list(BABIES):
        aliases[f"hofbook.animal.{key}"] = f"animal.{key}"
    for young, parent in PARENTS.items():
        for prefix in ("animal","hofbook.animal"):
            aliases[f"{prefix}.{parent}.baby"] = f"animal.{young}"
    for key in people:
        aliases[f"hofbook.npc.{key}"] = "npc." + key
    for key in SEASONS:
        aliases[f"hofbook.season.{key}"] = "season." + key
    cards["hofbook.cover"] = ("Hofbuch", art.field_book())
    cards["tool.hand"] = ("Hand", art.hand())
    cards["tool.seed"] = ("Saattüte", art.seed_packet(art.sprig(45,76,1.95)))
    cards["item.water"] = ("Wasser", art.drop())
    aliases.update({"npc.pelle": "animal.dog", "npc.minka": "animal.cat", "hofbook.npc.pelle": "animal.dog",
                    "hofbook.npc.minka": "animal.cat", "tool.feed": "item.feed", "wish.animal.hungry": "act.animal.feed",
                    "wish.animal.pet": "act.animal.pet", "wish.animal.brush": "act.animal.pet"})
    assert not cards.keys() & aliases.keys()
    assert set(aliases.values()) <= cards.keys()
    return cards, aliases


def asset_name(key):
    return "farm-pic-" + key.replace(".", "-")


def verify_master(cards, aliases):
    doc = (ROOT / "docs/21-content-katalog.md").read_text()
    for prefix, expected in [("act", 39), ("loc", 17), ("crop", 14), ("tool", 5)]:
        keys = set(re.findall(rf"`({prefix}\.[a-z.]+)`",doc)) - {prefix + "."}
        assert len(keys) == expected and keys <= cards.keys(), (prefix, keys - cards.keys())
    ids = set(re.findall(r"`((?:item|animal|npc|veh|imp)\.[a-z]+(?:\.[a-z]+)*)`",doc))
    assert ids <= (cards.keys() | aliases.keys()), ids - (cards.keys() | aliases.keys())


def generate(check=False):
    cards, aliases = vocabulary()
    verify_master(cards, aliases)
    outputs = {}
    def json_file(path, value):
        outputs[path] = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    json_file(CATALOG / "Contents.json", {"info": INFO})
    # The combine activity can share the vehicle drawing without sharing its spoken label.
    assets_by_drawing = {}
    entries = []
    for key,(label, drawing) in sorted(cards.items(),key=lambda pair: (pair[0].startswith("act."),pair[0])):
        if drawing not in assets_by_drawing:
            name = asset_name(key)
            folder = CATALOG / (name + ".imageset")
            outputs[folder / "picture.svg"] = art.svg(drawing)
            json_file(folder / "Contents.json", {"images":[{"filename":"picture.svg","idiom":"universal"}],"info":INFO,
                                                 "properties":{"preserves-vector-representation":True,"template-rendering-intent":"original"}})
            assets_by_drawing[drawing] = name
        entries.append(f'        "{key}": Entry(asset: "{assets_by_drawing[drawing]}", label: "{label}"),')
    index = ["// Generated by Tools/Art/build_pictograms.py; edit the drawings and vocabulary there.",
             "enum FarmPictogramIndex {", "    struct Entry {", "        let asset: String", "        let label: String", "    }",
             "", "    static let entries: [String: Entry] = [", *sorted(entries), "    ]",
             "", "    static let aliases: [String: String] = ["]
    index.extend(f'        "{key}": "{target}",' for key,target in sorted(aliases.items()))
    index.extend(["    ]", "}", ""])
    outputs[APP / "FarmPictogramIndex.swift"] = "\n".join(index)
    stale = [p for p in CATALOG.rglob("*") if p.is_file() and p not in outputs and not p.name.startswith(".")]
    if stale:
        raise SystemExit("Orphaned catalog files: " + ", ".join(map(str,stale)))
    for file, content in outputs.items():
        if file.is_file() and file.read_text() == content:
            continue
        if check:
            raise SystemExit(f"Missing or stale: {file.relative_to(ROOT)}")
        file.parent.mkdir(parents=True,exist_ok=True)
        file.write_text(content)
    print(f"{len(assets_by_drawing)} vector assets; {len(cards)} cards; {len(aliases)} aliases.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    generate(parser.parse_args().check)
