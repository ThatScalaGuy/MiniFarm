"""Inspect generated USDZ files with Blender's bundled USD Python library."""

import argparse
import json
import sys
from pathlib import Path

from pxr import Usd, UsdGeom, UsdSkel, UsdShade


ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "App" / "Resources" / "Models"


def inspect(path):
    stage = Usd.Stage.Open(str(path))
    if not stage:
        raise ValueError(f"Cannot open USD stage: {path.name}")
    bbox = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_])
    bounds = bbox.ComputeWorldBound(stage.GetPseudoRoot()).ComputeAlignedRange()
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
    return {
        "id": path.name.removeprefix("model.").removesuffix(".usdz"),
        "file": path.name,
        "bytes": path.stat().st_size,
        "upAxis": str(UsdGeom.GetStageUpAxis(stage)),
        "metersPerUnit": UsdGeom.GetStageMetersPerUnit(stage),
        "boundsMin": [round(float(value), 4) for value in bounds.GetMin()],
        "boundsMax": [round(float(value), 4) for value in bounds.GetMax()],
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
    paths = sorted(MODELS.glob("model.*.usdz"))
    if not paths:
        raise FileNotFoundError(f"No USDZ files in {MODELS}")
    assets = [inspect(path) for path in paths]
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump({"assets": assets}, file, ensure_ascii=False, indent=2)
        file.write("\n")
    print(f"Inspected {len(assets)} USDZ models")


if __name__ == "__main__":
    main()
