"""Build MiniFarm's animal USDZ assets with Blender.

Run from any directory:
  blender --background --factory-startup --python Tools/Blender/animals.py
Add ``-- --preview /absolute/path.png`` for a stage-one contact sheet.
Use ``-- --only chicken.baby`` to rebuild one model.
The source is self-contained; every run replaces only model.animal.*.usdz.
Animals are designed facing -Y, rotated to +Y for export, and rest at z=0.
Exported USD is Y-up, faces -Z, and uses metres.
Each file contains a two-second, ground-anchored breathing transform cycle.
USD transform animation playback in RealityKit still requires device testing.
"""
import argparse
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "App" / "Resources" / "Models"

COLORS = {
    "cream": (0.91, 0.84, 0.69, 1),
    "white": (0.95, 0.91, 0.81, 1),
    "brown": (0.39, 0.20, 0.11, 1),
    "tan": (0.68, 0.41, 0.23, 1),
    "dark": (0.095, 0.060, 0.045, 1),
    "pink": (0.92, 0.53, 0.52, 1),
    "blush": (1.0, 0.72, 0.65, 1),
    "coral": (0.82, 0.25, 0.17, 1),
    "yellow": (0.98, 0.69, 0.20, 1),
    "orange": (0.92, 0.43, 0.12, 1),
    "blue": (0.44, 0.72, 0.78, 1),
    "scarf": (0.33, 0.60, 0.62, 1),
    "grey": (0.52, 0.48, 0.45, 1),
}
MATS = {}
IS_BABY = False


def material(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.diffuse_color = COLORS[name]
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = COLORS[name]
        bsdf.inputs["Roughness"].default_value = 0.4 if name == "dark" else 0.78
        MATS[name] = m
    return MATS[name]


def ell(name, loc, scale, color, rot=(0, 0, 0)):
    segments, rings = (12, 6) if IS_BABY else (16, 8)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    o.rotation_euler = rot
    o.data.materials.append(material(color))
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def link(name, a, b, radius, color):
    a, b = Vector(a), Vector(b)
    o = ell(name, (a + b) / 2, (radius, radius, (b - a).length / 2 + radius), color)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    return o


def eyes(z, y, spacing, size):
    for x in (-spacing, spacing):
        ell("Eye", (x, y, z), (size, size * 0.54, size * 1.12), "dark")
        ell("Eye_glint", (x - size * 0.22, y - size * 0.50, z + size * 0.32),
            (size * 0.24, size * 0.16, size * 0.24), "white")


def face(z, y, spacing, size, muzzle_color="cream", nose_color="dark"):
    eyes(z, y, spacing, size)
    ell("Muzzle", (0, y - 0.025, z - size * 1.55),
        (spacing * 0.75, size * 0.62, size * 0.66), muzzle_color)
    front = y - 0.025 - size * 0.65
    ell("Nose", (0, front, z - size * 1.34),
        (size * 0.50, size * 0.28, size * 0.32), nose_color)
    ell("Smile", (0, front, z - size * 1.93),
        (size * 0.34, size * 0.19, size * 0.10), "brown")


def legs(color, x, front, back, z, radius):
    for xx in (-x, x):
        for yy in (front, back):
            ell("Leg", (xx, yy, z), (radius, radius * 1.05, z), color)


def ears(z, y, x, color, shape=(0.10, 0.07, 0.20), inner=None):
    for side in (-1, 1):
        ell("Ear", (side * x, y, z), shape, color, (0, side * 0.20, 0))
        if inner:
            ell("Ear_inner", (side * x, y - shape[1] * 0.83, z),
                (shape[0] * 0.52, 0.018, shape[2] * 0.7), inner, (0, side * 0.20, 0))


def dog():
    ell("Body", (0, 0.09, 0.34), (0.27, 0.39, 0.26), "white")
    ell("Back_patch", (-0.17, 0.12, 0.46), (0.15, 0.24, 0.13), "brown")
    legs("white", 0.17, -0.15, 0.32, 0.13, 0.085)
    link("Tail", (0, 0.40, 0.41), (0.03, 0.62, 0.55), 0.055, "brown")
    ell("Neck_scarf", (0, -0.20, 0.43), (0.255, 0.15, 0.13), "scarf")
    ell("Scarf_knot", (0.16, -0.32, 0.38), (0.09, 0.055, 0.07), "scarf")
    ell("Scarf_end", (0.19, -0.32, 0.30), (0.07, 0.045, 0.12), "scarf", (0, -0.3, 0))
    ell("Head", (0, -0.27, 0.65), (0.29, 0.25, 0.27), "white")
    ell("Eye_patch", (-0.135, -0.465, 0.68), (0.12, 0.045, 0.15), "brown")
    ell("Upright_ear", (-0.23, -0.26, 0.91), (0.11, 0.09, 0.21), "brown", (0, -0.25, 0))
    ell("Floppy_ear", (0.28, -0.27, 0.73), (0.105, 0.105, 0.20), "brown", (0, -0.48, 0))
    face(0.69, -0.505, 0.13, 0.052, "cream", "brown")


def cat():
    ell("Body", (0, 0.08, 0.29), (0.24, 0.34, 0.24), "tan")
    legs("tan", 0.15, -0.13, 0.27, 0.105, 0.07)
    link("Tail_base", (0.13, 0.36, 0.30), (0.30, 0.49, 0.46), 0.052, "tan")
    link("Tail_tip", (0.30, 0.49, 0.46), (0.28, 0.49, 0.64), 0.052, "tan")
    ell("Head", (0, -0.24, 0.56), (0.27, 0.23, 0.24), "tan")
    ears(0.78, -0.23, 0.19, "tan", (0.09, 0.07, 0.14), "pink")
    face(0.59, -0.45, 0.12, 0.052, "cream", "brown")
    for side in (-1, 1):
        for i in (-1, 1):
            link("Whisker", (side * 0.11, -0.48, 0.51),
                 (side * 0.27, -0.47, 0.51 + i * 0.035), 0.008, "cream")


def chicken():
    ell("Body", (0, 0.04, 0.30), (0.25, 0.30, 0.28), "white")
    ell("Head", (0, -0.19, 0.49), (0.20, 0.18, 0.20), "white")
    for side in (-1, 1):
        ell("Wing", (side * 0.23, 0.06, 0.32), (0.075, 0.19, 0.13), "cream")
        ell("Foot", (side * 0.11, -0.04, 0.035), (0.075, 0.12, 0.035), "orange")
        ell("Eye", (side * 0.10, -0.346, 0.53), (0.035, 0.023, 0.042), "dark")
    ell("Beak", (0, -0.39, 0.47), (0.07, 0.09, 0.045), "orange")
    ell("Wattle", (0, -0.34, 0.41), (0.045, 0.035, 0.065), "coral")
    for y, z in ((-0.25, 0.66), (-0.18, 0.69), (-0.11, 0.66)):
        ell("Comb", (0, y, z), (0.045, 0.05, 0.075), "coral")
    for x in (-0.1, 0, 0.1):
        ell("Tail_feather", (x, 0.29, 0.47), (0.075, 0.09, 0.16), "white", (0.35, 0, 0))


def cow():
    ell("Body", (0, 0.08, 0.48), (0.37, 0.52, 0.35), "white")
    legs("white", 0.24, -0.22, 0.39, 0.16, 0.11)
    for x in (-0.24, 0.24):
        for y in (-0.22, 0.39):
            ell("Hoof", (x, y, 0.06), (0.115, 0.12, 0.06), "brown")
    for x, y, z, s in ((-0.33, 0.04, 0.55, 0.17), (0.33, 0.20, 0.53, 0.19), (-0.16, 0.24, 0.78, 0.15)):
        ell("Spot", (x, y, z), (s * 0.5, s, s * 0.8), "brown")
    ell("Udder", (0, 0.20, 0.20), (0.18, 0.20, 0.13), "pink")
    ell("Head", (0, -0.43, 0.65), (0.30, 0.25, 0.27), "white")
    ears(0.78, -0.38, 0.31, "white", (0.15, 0.075, 0.09), "pink")
    for x in (-0.19, 0.19):
        ell("Horn", (x, -0.40, 0.90), (0.065, 0.06, 0.12), "cream", (0, x, 0))
    eyes(0.69, -0.66, 0.14, 0.048)
    ell("Muzzle", (0, -0.69, 0.53), (0.22, 0.12, 0.12), "pink")
    for x in (-0.09, 0.09):
        ell("Nostril", (x, -0.795, 0.54), (0.027, 0.014, 0.022), "brown")
    link("Tail", (0, 0.55, 0.57), (0.02, 0.68, 0.36), 0.04, "white")
    ell("Tail_tip", (0.02, 0.68, 0.34), (0.06, 0.06, 0.08), "brown")


def sheep():
    ell("Body", (0, 0.08, 0.39), (0.33, 0.45, 0.29), "white")
    legs("grey", 0.21, -0.17, 0.32, 0.13, 0.075)
    for x, y, z in ((-0.26, -0.12, 0.48), (0.26, -0.12, 0.48),
                    (-0.26, 0.22, 0.48), (0.26, 0.22, 0.48), (0, 0.05, 0.68),
                    (0, 0.34, 0.60), (0, -0.20, 0.62)):
        ell("Wool", (x, y, z), (0.17, 0.18, 0.16), "cream")
    ell("Head", (0, -0.37, 0.53), (0.23, 0.21, 0.22), "grey")
    ears(0.60, -0.35, 0.25, "grey", (0.12, 0.07, 0.07), "pink")
    ell("Forelock", (0, -0.39, 0.74), (0.20, 0.16, 0.10), "white")
    face(0.57, -0.56, 0.10, 0.04, "cream", "dark")


def pig():
    ell("Body", (0, 0.08, 0.33), (0.32, 0.43, 0.27), "pink")
    legs("pink", 0.20, -0.16, 0.32, 0.11, 0.085)
    ell("Head", (0, -0.34, 0.49), (0.27, 0.23, 0.23), "pink")
    ears(0.70, -0.32, 0.19, "pink", (0.105, 0.07, 0.13), "blush")
    eyes(0.53, -0.55, 0.13, 0.043)
    ell("Snout", (0, -0.59, 0.43), (0.16, 0.09, 0.11), "blush")
    for x in (-0.06, 0.06):
        ell("Nostril", (x, -0.67, 0.44), (0.022, 0.012, 0.03), "tan")
    link("Tail", (0, 0.48, 0.39), (0.08, 0.59, 0.45), 0.035, "pink")
    ell("Tail_tip", (0.11, 0.59, 0.49), (0.045, 0.04, 0.045), "pink")


def duck():
    ell("Body", (0, 0.04, 0.28), (0.24, 0.33, 0.23), "cream")
    ell("Head", (0, -0.22, 0.48), (0.20, 0.19, 0.19), "cream")
    for side in (-1, 1):
        ell("Wing", (side * 0.22, 0.06, 0.31), (0.07, 0.18, 0.12), "white")
        ell("Foot", (side * 0.10, -0.04, 0.035), (0.08, 0.12, 0.035), "orange")
        ell("Eye", (side * 0.10, -0.38, 0.52), (0.034, 0.023, 0.04), "dark")
    ell("Bill", (0, -0.41, 0.44), (0.11, 0.12, 0.045), "orange")
    ell("Tail", (0, 0.34, 0.38), (0.14, 0.12, 0.11), "white")


def goat():
    ell("Body", (0, 0.08, 0.37), (0.27, 0.40, 0.26), "cream")
    legs("cream", 0.18, -0.17, 0.32, 0.13, 0.075)
    ell("Head", (0, -0.32, 0.59), (0.23, 0.21, 0.23), "cream")
    ears(0.66, -0.30, 0.24, "cream", (0.13, 0.07, 0.08), "pink")
    for x in (-0.13, 0.13):
        ell("Horn", (x, -0.29, 0.83), (0.06, 0.065, 0.15), "tan", (-0.25, x, 0))
    face(0.62, -0.51, 0.10, 0.042, "white")
    ell("Beard", (0, -0.46, 0.41), (0.075, 0.07, 0.12), "white")
    ell("Tail", (0, 0.47, 0.51), (0.08, 0.13, 0.09), "white", (0.5, 0, 0))


def horse():
    ell("Body", (0, 0.08, 0.47), (0.32, 0.48, 0.31), "tan")
    legs("tan", 0.21, -0.19, 0.36, 0.17, 0.09)
    for x in (-0.21, 0.21):
        for y in (-0.19, 0.36):
            ell("Hoof", (x, y, 0.06), (0.095, 0.10, 0.06), "brown")
    ell("Neck", (0, -0.28, 0.65), (0.20, 0.20, 0.34), "tan", (-0.2, 0, 0))
    ell("Head", (0, -0.39, 0.86), (0.24, 0.22, 0.25), "tan")
    ears(1.09, -0.36, 0.15, "tan", (0.07, 0.065, 0.14), "pink")
    ell("Mane", (0, -0.16, 0.81), (0.13, 0.13, 0.33), "brown", (-0.2, 0, 0))
    ell("Forelock", (0, -0.55, 1.02), (0.14, 0.08, 0.08), "brown")
    face(0.89, -0.59, 0.11, 0.045, "cream")
    ell("Tail", (0, 0.53, 0.42), (0.11, 0.12, 0.26), "brown", (0.4, 0, 0))


def rabbit():
    ell("Body", (0, 0.08, 0.26), (0.23, 0.30, 0.22), "grey")
    legs("grey", 0.14, -0.12, 0.27, 0.08, 0.08)
    ell("Tail", (0, 0.35, 0.30), (0.10, 0.10, 0.10), "white")
    ell("Head", (0, -0.22, 0.46), (0.23, 0.20, 0.21), "grey")
    ears(0.75, -0.20, 0.13, "grey", (0.075, 0.065, 0.25), "pink")
    face(0.49, -0.40, 0.10, 0.043, "white", "pink")


def bee():
    ell("Body", (0, 0.05, 0.22), (0.19, 0.29, 0.19), "yellow")
    for y in (0.02, 0.19):
        ell("Stripe", (0, y, 0.22), (0.193, 0.045, 0.193), "brown")
    ell("Head", (0, -0.22, 0.25), (0.17, 0.15, 0.16), "yellow")
    eyes(0.28, -0.35, 0.075, 0.034)
    ell("Smile", (0, -0.36, 0.20), (0.035, 0.015, 0.014), "brown")
    for side in (-1, 1):
        ell("Wing", (side * 0.17, 0.08, 0.38), (0.16, 0.20, 0.055), "blue", (0, side * 0.25, side * 0.3))
        link("Antenna", (side * 0.07, -0.23, 0.38), (side * 0.12, -0.24, 0.48), 0.018, "brown")
        ell("Antenna_tip", (side * 0.12, -0.24, 0.48), (0.03, 0.03, 0.03), "brown")
        for y in (-0.05, 0.16):
            ell("Foot", (side * 0.12, y, 0.055), (0.045, 0.055, 0.055), "brown")


ANIMALS = {
    "dog": dog, "cat": cat, "chicken": chicken, "cow": cow,
    "sheep": sheep, "pig": pig, "duck": duck, "goat": goat,
    "horse": horse, "rabbit": rabbit, "bee": bee,
}
BABIES = ("chicken", "cow", "sheep", "pig", "duck", "goat", "horse", "rabbit")
HEAD_PARTS = {
    "Head", "Eye", "Eye_glint", "Muzzle", "Nose", "Nostril", "Snout",
    "Ear", "Ear_inner", "Horn", "Forelock", "Beard", "Beak", "Bill",
    "Comb", "Wattle", "Smile",
}


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def build(name, baby=False):
    global IS_BABY
    existing = set(bpy.context.scene.objects)
    IS_BABY = baby
    ANIMALS[name]()
    IS_BABY = False
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o not in existing]
    bpy.context.view_layer.update()
    if baby:
        # A bigger head and simplified child-specific details make these more
        # than just uniformly shrunken adults.
        omit = {"chicken": {"Comb", "Wattle"}, "cow": {"Udder"}, "goat": {"Beard"}}
        for obj in list(meshes):
            part = obj.name.split(".")[0]
            if part in omit.get(name, set()):
                meshes.remove(obj)
                bpy.data.objects.remove(obj, do_unlink=True)
            elif name == "chicken" and obj.data.materials[0].name == "white":
                obj.data.materials[0] = material("yellow")
        head = next(o for o in meshes if o.name.split(".")[0] == "Head")
        pivot = head.location.copy()
        for obj in meshes:
            if obj.name.split(".")[0] in HEAD_PARTS:
                obj.location = pivot + (obj.location - pivot) * 1.24
                obj.scale *= 1.24
            obj.location *= 0.62
            obj.scale *= 0.62
        bpy.context.view_layer.update()
    low = min((o.matrix_world @ Vector(corner)).z for o in meshes for corner in o.bound_box)
    for o in meshes:
        o.location.z -= low
    bpy.context.view_layer.update()
    mins = [min((o.matrix_world @ Vector(c)).to_tuple()[i] for o in meshes for c in o.bound_box) for i in range(3)]
    maxs = [max((o.matrix_world @ Vector(c)).to_tuple()[i] for o in meshes for c in o.bound_box) for i in range(3)]
    triangles = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)
    print("ASSET", name + (".baby" if baby else ""), "dimensions_m",
          [round(b - a, 3) for a, b in zip(mins, maxs)], "triangles", triangles, flush=True)
    assert triangles <= (5000 if baby else 12000 if name == "dog" else 8000)
    return meshes


def idle(meshes):
    """Animate a single ground-anchored parent, returning to the first pose."""
    controller = bpy.data.objects.new("Idle", None)
    bpy.context.scene.collection.objects.link(controller)
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = controller
        obj.matrix_world = world
    for frame, height in ((1, 1.0), (25, 1.02), (49, 1.0)):
        controller.scale.z = height
        controller.keyframe_insert(data_path="scale", frame=frame, group="Idle")
    bpy.context.scene.frame_set(1)


def preview(path):
    clear()
    for name, x in (("dog", -1.3), ("cat", 0), ("chicken", 1.2)):
        for o in build(name):
            o.location.x += x
    ell("Ground", (0, 0, -0.14), (3.3, 2.2, 0.14), "cream")
    bpy.ops.object.light_add(type="AREA", location=(-3, -4, 6))
    bpy.context.object.data.energy = 500
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 5
    bpy.ops.object.camera_add(location=(3.0, -7.5, 3.2))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.48)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.5
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.world.color = (0.55, 0.55, 0.55)
    scene.render.resolution_x = 390
    scene.render.resolution_y = 195
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=list(ANIMALS) + [n + ".baby" for n in BABIES])
    parser.add_argument("--preview")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = 1, 49
    models = list(ANIMALS) + [n + ".baby" for n in BABIES]
    for model in models:
        if args.only and model != args.only:
            continue
        name = model.split(".")[0]
        baby = model.endswith(".baby")
        clear()
        scene.frame_set(1)
        meshes = build(name, baby)
        for obj in meshes:
            obj.matrix_world = Matrix.Rotation(math.pi, 4, "Z") @ obj.matrix_world
        bpy.context.view_layer.update()
        idle(meshes)
        bpy.ops.wm.usd_export(filepath=str(OUT / f"model.animal.{model}.usdz"),
                              export_animation=True, export_materials=True,
                              generate_preview_surface=True, export_cameras=False,
                              export_lights=False, convert_orientation=True,
                              export_global_up_selection="Y",
                              export_global_forward_selection="NEGATIVE_Z",
                              convert_scene_units="METERS", meters_per_unit=1.0)
    if args.preview:
        preview(os.path.abspath(args.preview))


if __name__ == "__main__":
    main()
