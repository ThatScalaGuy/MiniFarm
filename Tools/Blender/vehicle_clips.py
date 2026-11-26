"""Export independent full-model wheel-animation variants, not replacement models.

Run in fresh background Blender:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python-exit-code 1 --python Tools/Blender/vehicle_clips.py

The original model.*.usdz files are never opened for writing. Each new
anim.<vehicle-or-implement>.wheels.usdz is a complete model with one two-second
in-place rolling cycle. These are transform animation variants, not animation
resources that can be bound to the existing model; the consumer must load the
variant and repeat the animation. RealityKit playback requires device testing.
Front is USD +Z, up is +Y, and units are meters.
"""
import argparse
import math
import shutil
import subprocess
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from pxr import Usd, UsdGeom, UsdShade

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import environment

ASSETS = {
    "veh.tractor": 4,
    "veh.combine": 4,
    "veh.carriage": 4,
    "imp.seeder": 2,
    "imp.trailer": 2,
    "imp.watertank": 2,
    "imp.baler": 2,
    "imp.potatodigger": 2,
}
FRONT_PARTS = {
    "veh.tractor": "Headlight",
    "veh.combine": "Header",
    "veh.carriage": "Carriage_shaft",
    "imp.seeder": "Hitch_eye",
    "imp.trailer": "Hitch_eye",
    "imp.watertank": "Hitch_eye",
    "imp.baler": "Hitch_eye",
    "imp.potatodigger": "Hitch_eye",
}


def empty(name, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    bpy.context.view_layer.update()
    return obj


def parent_keep_world(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def base_name(obj):
    return obj.name.split(".")[0]


def generate(asset_id):
    environment.reset()
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 49
    scene.render.fps = 24
    scene.frame_set(1)
    environment.ASSETS[asset_id]()
    bpy.context.view_layer.update()
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    wheels = [obj for obj in meshes if base_name(obj) == "Wheel"]
    hubs = [obj for obj in meshes if base_name(obj) in ("Hub", "Wheel_hub")]
    if len(wheels) != ASSETS[asset_id] or len(hubs) != len(wheels):
        raise RuntimeError(f"{asset_id}: expected {ASSETS[asset_id]} wheel/hub pairs")
    for wheel in wheels:
        wheel_pos = wheel.matrix_world.translation.copy()
        hub = min(hubs, key=lambda obj: (obj.matrix_world.translation-wheel_pos).length)
        if (hub.matrix_world.translation-wheel_pos).length > .13:
            raise RuntimeError(f"{asset_id}: no matching hub for {wheel.name}")
        hubs.remove(hub)
        pivot = empty("Rolling_wheel", wheel_pos)
        parent_keep_world(wheel, pivot)
        parent_keep_world(hub, pivot)
        for frame, angle in ((1, 0), (13, math.pi/2), (25, math.pi),
                             (37, 3*math.pi/2), (49, 2*math.pi)):
            pivot.rotation_euler.y = angle
            pivot.keyframe_insert(data_path="rotation_euler", frame=frame, group="Wheel_roll")
    scene.frame_set(1)
    facing = empty("Facing")
    for obj in list(scene.objects):
        if obj != facing and obj.parent is None:
            parent_keep_world(obj, facing)
    # Original vehicle front is Blender -X. Rotate to Blender -Y / USD +Z.
    facing.rotation_euler.z = math.pi/2
    bpy.context.view_layer.update()
    low, _ = environment.bounds()
    facing.location.z -= low[2]
    bpy.context.view_layer.update()
    path = Path(environment.OUT) / f"anim.{asset_id}.wheels.usdz"
    bpy.ops.wm.usd_export(filepath=str(path), export_animation=True, export_materials=True,
                          generate_preview_surface=True, export_cameras=False, export_lights=False,
                          convert_orientation=True, export_global_up_selection="Y",
                          export_global_forward_selection="NEGATIVE_Z", meters_per_unit=1.0)
    return path


def verify(asset_id, path, checker):
    stage = Usd.Stage.Open(str(path))
    if not stage:
        raise RuntimeError(f"Cannot open {path}")
    if UsdGeom.GetStageUpAxis(stage) != UsdGeom.Tokens.y or abs(UsdGeom.GetStageMetersPerUnit(stage)-1) > 1e-6:
        raise RuntimeError(f"{path}: wrong axis or units")
    pivots = [prim for prim in stage.Traverse() if prim.GetName().startswith("Rolling_wheel")]
    if len(pivots) != ASSETS[asset_id]:
        raise RuntimeError(f"{path}: wrong rolling pivot count")
    for pivot in pivots:
        if not any(a.GetNumTimeSamples() > 1 for a in pivot.GetAttributes()):
            raise RuntimeError(f"{path}: no time samples on {pivot.GetPath()}")
        first = UsdGeom.XformCache(Usd.TimeCode(1)).GetLocalToWorldTransform(pivot)
        quarter = UsdGeom.XformCache(Usd.TimeCode(13)).GetLocalToWorldTransform(pivot)
        if (first.ExtractTranslation()-quarter.ExtractTranslation()).GetLength() > 1e-4:
            raise RuntimeError(f"{path}: wheel pivot moves off its axle")
        if all(abs(first[i][j]-quarter[i][j]) < .01 for i in range(3) for j in range(3)):
            raise RuntimeError(f"{path}: wheel orientation does not change")
    bbox = UsdGeom.BBoxCache(Usd.TimeCode(1), [UsdGeom.Tokens.default_]).ComputeWorldBound(
        stage.GetPseudoRoot()).ComputeAlignedRange()
    if abs(bbox.GetMin()[1]) > 1e-4:
        raise RuntimeError(f"{path}: not grounded at USD Y=0")
    prim = next((p for p in stage.Traverse() if p.GetName() == FRONT_PARTS[asset_id]), None)
    if not prim or UsdGeom.XformCache(Usd.TimeCode(1)).GetLocalToWorldTransform(prim).ExtractTranslation()[2] <= 0:
        raise RuntimeError(f"{path}: front is not USD +Z")
    meshes = [p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
    if not meshes or any(not UsdGeom.Mesh(p).GetPointsAttr().Get() or
                         not UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0] for p in meshes):
        raise RuntimeError(f"{path}: missing mesh geometry or materials")
    result = subprocess.run([checker, "--arkit", "--strict", str(path)], text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"ARKit validation failed for {path}:\n{result.stdout}{result.stderr}")
    print("VERIFIED", asset_id, "wheel_pivots", len(pivots), "frame_range",
          stage.GetStartTimeCode(), stage.GetEndTimeCode(), "fps", stage.GetTimeCodesPerSecond(),
          "front +Z up Y meters_per_unit 1 ground_y", round(bbox.GetMin()[1], 6),
          "geometry materials ARKit strict passed", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", choices=ASSETS)
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    checker = shutil.which("usdchecker")
    if not checker:
        raise RuntimeError("usdchecker is required for strict ARKit validation")
    Path(environment.OUT).mkdir(parents=True, exist_ok=True)
    for asset_id in [args.asset] if args.asset else ASSETS:
        path = generate(asset_id)
        verify(asset_id, path, checker)


if __name__ == "__main__":
    main()
