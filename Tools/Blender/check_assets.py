"""Check the model catalogue and budgets against the generated USD manifest."""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "App" / "Resources" / "Models"
CROPS = {
    "radish", "carrot", "lettuce", "pea", "potato", "strawberry", "tomato",
    "corn", "sunflower", "apple", "wheat", "pumpkin", "kale", "chives",
}
ANIMALS = {
    "chicken", "cat", "dog", "cow", "sheep", "pig", "duck", "goat", "horse",
    "rabbit", "bee",
}
BABIES = {"chicken", "cow", "sheep", "pig", "duck", "goat", "horse", "rabbit"}
LOCATIONS = {
    "plaza", "garden", "henhouse", "shop", "garage", "field", "cowbarn",
    "sheepmeadow", "pigsty", "orchard", "kitchen", "greenhouse", "pond",
    "goatpen", "paddock", "apiary", "village",
}
IMPLEMENTS = {
    "plow", "seeder", "trailer", "watertank", "mower", "baler", "loader",
    "potatodigger", "snowplow",
}
ITEMS = {
    "egg", "milk", "wool", "compost", "duckegg", "feather", "goatmilk",
    "honeycomb", "hay", "feed", "flour", "bread", "cake", "applejuice",
    "butter", "cheese", "goatcheese", "jam", "icecream", "honey", "beanie",
}


def expected_ids():
    return (
        {f"crop.{crop}.{stage}" for crop in CROPS for stage in ("seed", "sprout", "growing", "ripe")}
        | {f"animal.{name}" for name in ANIMALS}
        | {f"animal.{name}.baby" for name in BABIES}
        | {f"npc.{name}" for name in ("tilda", "hanno", "mo", "lale", "yusuf")}
        | {f"loc.{name}" for name in LOCATIONS}
        | {f"imp.{name}" for name in IMPLEMENTS}
        | {f"veh.{name}" for name in ("tractor", "combine", "carriage")}
        | {f"tool.{name}" for name in ("can", "bucket", "brush", "shears", "basket")}
        | {f"item.{name}" for name in ITEMS | CROPS}
        | {f"item.seed.{name}" for name in CROPS - {"apple"}}
        | {"terrain.island"}
    )


def main():
    with (MODELS / "manifest.json").open(encoding="utf-8") as file:
        assets = json.load(file)["assets"]
    errors = []
    ids = {asset["id"] for asset in assets}
    if len(ids) != len(assets):
        errors.append("Duplicate asset IDs")
    missing = expected_ids() - ids
    if missing:
        errors.append("Missing IDs: " + ", ".join(sorted(missing)))
    files = {path.name for pattern in ("model.*.usdz", "anim.*.usdz") for path in MODELS.glob(pattern)}
    if files != {asset["file"] for asset in assets}:
        errors.append("Manifest and USDZ files differ")
    for asset in assets:
        name = asset["id"]
        path = MODELS / asset["file"]
        if asset["kind"] == "animationVariant":
            base = asset["variantOf"]
            if base not in ids or name != f"anim.{base}.{asset['motion']}":
                errors.append(f"{name}: invalid animation variant or missing base model")
        if not path.is_file() or path.stat().st_size != asset["bytes"]:
            errors.append(f"{name}: file missing or size differs from manifest")
        if asset["upAxis"] != "Y" or asset["metersPerUnit"] != 1:
            errors.append(f"{name}: incorrect axis or units")
        if not asset["meshCount"] or not asset["materialCount"] or not asset["diffuseColors"]:
            errors.append(f"{name}: missing geometry or color materials")
        if name != "terrain.island" and abs(asset["boundsMin"][1]) > 0.01:
            errors.append(f"{name}: geometry is not grounded")
        budget_id = asset["variantOf"] or name
        category = budget_id.split(".")[0]
        limit = {"crop": 400, "npc": 8000, "loc": 10000, "veh": 15000, "imp": 15000}.get(category)
        if category == "animal":
            limit = 5000 if ".baby" in budget_id else 12000 if budget_id.startswith("animal.dog") else 8000
        if limit is not None and asset["triangleCount"] > limit:
            errors.append(f"{name}: {asset['triangleCount']} triangles exceeds {limit}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Verified {len(assets)} model files and {len(expected_ids())} required IDs")


if __name__ == "__main__":
    main()
