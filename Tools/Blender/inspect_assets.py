"""Inspect generated USDZ files with Blender's bundled USD Python library."""

import argparse
import json
import sys
from pathlib import Path

from pxr import Usd, UsdGeom, UsdSkel, UsdShade


ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "App" / "Resources" / "Models"

DIRECTIONAL_LOCATIONS = {
    "loc.henhouse", "loc.shop", "loc.garage", "loc.cowbarn",
    "loc.greenhouse", "loc.sheepmeadow", "loc.pigsty", "loc.kitchen",
    "loc.goatpen", "loc.paddock", "loc.apiary", "loc.village",
}

DIRECTIONAL_ITEMS = {
    "item.feed", "item.milk", "item.wool", "item.compost", "item.feather",
    "item.goatmilk", "item.flour", "item.applejuice", "item.cheese",
    "item.goatcheese", "item.jam", "item.icecream", "item.honey",
    "item.carrot", "item.pea", "item.potato", "item.strawberry", "item.corn",
    "item.sunflower", "item.wheat", "item.chives",
}


def front_axis(asset_id, kind):
    if asset_id.startswith("animal."):
        return "-Z"
    if asset_id.startswith("npc.") or asset_id in DIRECTIONAL_LOCATIONS:
        return "+Z"
    if asset_id.startswith(("veh.", "imp.")):
        return "+Z" if kind == "animationVariant" else "-X"
    if asset_id in {"tool.can", "tool.shears"}:
        return "+X"
    if asset_id.startswith("item.seed.") or asset_id in DIRECTIONAL_ITEMS:
        return "+Z"
    return None


def inspect(path):
    stage = Usd.Stage.Open(str(path))
    if not stage:
        raise ValueError(f"Cannot open USD stage: {path.name}")
    meshes = []
    materials = set()
    colors = set()
    animations = []
    sampled = []
    triangles = 0
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Mesh):
            meshes.append(str(prim.GetPath()))
            counts = UsdGeom.Mesh(prim).GetFaceVertexCountsAttr().Get() or []
            triangles += sum(max(0, n - 2) for n in counts)
            bound, _ = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
            if bound:
                materials.add(str(bound.GetPath()))
        if prim.IsA(UsdSkel.Animation):
            animations.append(prim.GetName())
        if prim.IsA(UsdShade.Shader):
            shader = UsdShade.Shader(prim)
            if shader.GetIdAttr().Get() == "UsdPreviewSurface":
                color_input = shader.GetInput("diffuseColor")
                color = color_input.Get() if color_input else None
                if color is not None:
                    colors.add(tuple(round(float(component), 4) for component in color))
        if any(prop.GetNumTimeSamples() for prop in prim.GetAttributes()):
            sampled.append(str(prim.GetPath()))
    if not meshes:
        raise ValueError(f"No meshes in {path.name}")
    if not materials:
        raise ValueError(f"No bound materials in {path.name}")
    bounds_time = stage.GetStartTimeCode() if sampled else None
    time_code = Usd.TimeCode(bounds_time) if bounds_time is not None else Usd.TimeCode.Default()
    bbox = UsdGeom.BBoxCache(time_code, [UsdGeom.Tokens.default_])
    bounds = bbox.ComputeWorldBound(stage.GetPseudoRoot()).ComputeAlignedRange()
    kind = "animationVariant" if path.name.startswith("anim.") else "model"
    asset_id = path.name.removeprefix("model.").removesuffix(".usdz")
    base_id = asset_id.removeprefix("anim.")
    return {
        "id": asset_id,
        "file": path.name,
        "kind": kind,
        "variantOf": base_id.rsplit(".", 1)[0] if kind == "animationVariant" else None,
        "motion": base_id.rsplit(".", 1)[1] if kind == "animationVariant" else None,
        "frontAxis": front_axis(base_id, kind),
        "bytes": path.stat().st_size,
        "upAxis": str(UsdGeom.GetStageUpAxis(stage)),
        "metersPerUnit": UsdGeom.GetStageMetersPerUnit(stage),
        "boundsMin": [round(float(value), 4) for value in bounds.GetMin()],
        "boundsMax": [round(float(value), 4) for value in bounds.GetMax()],
        "boundsTimeCode": bounds_time,
        "meshCount": len(meshes),
        "triangleCount": triangles,
        "materialCount": len(materials),
        "diffuseColors": sorted(colors),
        "animations": animations,
        "timeSampledPrims": sampled,
        "timeRange": (
            {
                "start": stage.GetStartTimeCode(),
                "end": stage.GetEndTimeCode(),
                "codesPerSecond": stage.GetTimeCodesPerSecond(),
            }
            if sampled
            else None
        ),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])
    paths = sorted((*MODELS.glob("model.*.usdz"), *MODELS.glob("anim.*.usdz")))
    if not paths:
        raise FileNotFoundError(f"No USDZ files in {MODELS}")
    assets = [inspect(path) for path in paths]
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump({"assets": assets}, file, ensure_ascii=False, indent=2)
        file.write("\n")
    print(f"Inspected {len(assets)} USDZ models")


if __name__ == "__main__":
    main()
