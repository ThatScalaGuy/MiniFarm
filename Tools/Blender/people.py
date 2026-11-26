"""Generate the five static MiniFarm residents.

Run in a separate process, from any directory:
  blender --background --factory-startup --python Tools/Blender/people.py
Optionally add: -- --preview /absolute/path/to/people.png

The figures are built facing Blender -Y, which exports as USD +Z. USDZ files
are Y-up, in metres, and grounded. The optional preview imports the exported
files into a fresh scene rather than rendering the source geometry.
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "App" / "Resources" / "Models"
NAMES = ("tilda", "hanno", "mo", "lale", "yusuf")
PALETTE = {
    "ink": (0.055, 0.035, 0.028, 1),
    "white": (0.96, 0.91, 0.80, 1),
    "rose": (0.80, 0.38, 0.33, 1),
    "flour": (0.92, 0.84, 0.68, 1),
    "skin_tilda": (0.76, 0.48, 0.33, 1),
    "skin_hanno": (0.70, 0.49, 0.36, 1),
    "skin_mo": (0.46, 0.25, 0.15, 1),
    "skin_lale": (0.65, 0.38, 0.24, 1),
    "skin_yusuf": (0.38, 0.20, 0.12, 1),
    "hair_tilda": (0.24, 0.10, 0.055, 1),
    "hair_hanno": (0.70, 0.69, 0.63, 1),
    "hair_mo": (0.09, 0.045, 0.03, 1),
    "hair_lale": (0.12, 0.065, 0.045, 1),
    "hair_yusuf": (0.09, 0.05, 0.035, 1),
    "coral": (0.72, 0.25, 0.18, 1),
    "sage": (0.32, 0.48, 0.33, 1),
    "navy": (0.13, 0.25, 0.32, 1),
    "denim": (0.22, 0.38, 0.49, 1),
    "mustard": (0.87, 0.58, 0.17, 1),
    "turquoise": (0.20, 0.56, 0.55, 1),
    "plum": (0.45, 0.27, 0.38, 1),
    "leather": (0.34, 0.19, 0.11, 1),
    "shoe": (0.20, 0.13, 0.10, 1),
}
MATERIALS = {}


def material(key):
    if key not in MATERIALS:
        mat = bpy.data.materials.new(key)
        mat.diffuse_color = PALETTE[key]
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = PALETTE[key]
        shader.inputs["Roughness"].default_value = 0.4 if key == "ink" else 0.8
        MATERIALS[key] = mat
    return MATERIALS[key]


def ell(name, loc, scale, color, rotation=(0, 0, 0), segments=12, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(material(color))
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def capsule(name, a, b, radius, color):
    a, b = Vector(a), Vector(b)
    obj = ell(name, (a + b) / 2, (radius, radius, (b - a).length / 2 + radius), color)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    return obj


def smile(z, color):
    # A shallow curved smile follows the front of the rounded face.
    points = [(-0.070, -0.216, z + 0.016), (-0.037, -0.232, z),
              (0, -0.237, z - 0.005), (0.037, -0.232, z), (0.070, -0.216, z + 0.016)]
    for a, b in zip(points, points[1:]):
        capsule("Smile", a, b, 0.009, color)


def face(skin):
    ell("Head", (0, 0, 1.16), (0.255, 0.22, 0.275), skin, segments=16, rings=10)
    for side in (-1, 1):
        ell("Ear", (side * 0.246, 0, 1.16), (0.050, 0.045, 0.075), skin)
        ell("Eye", (side * 0.092, -0.205, 1.195), (0.028, 0.018, 0.038), "ink")
        ell("Eye_glint", (side * 0.092 - 0.008, -0.221, 1.207),
            (0.008, 0.005, 0.009), "white", segments=8, rings=6)
    ell("Nose", (0, -0.224, 1.135), (0.033, 0.030, 0.027), skin)
    smile(1.075, "ink")


def body(skin, top, trousers, width=1.0):
    ell("Torso", (0, 0.015, 0.74), (0.23 * width, 0.145, 0.28), top, segments=16)
    ell("Neck", (0, 0, 0.94), (0.085, 0.08, 0.11), skin)
    for side in (-1, 1):
        capsule("Sleeve", (side * 0.20 * width, 0.015, 0.88),
                (side * 0.29 * width, -0.015, 0.64), 0.080, top)
        ell("Hand", (side * 0.30 * width, -0.02, 0.57), (0.072, 0.065, 0.085), skin)
        ell("Leg", (side * 0.105, 0.015, 0.30), (0.095, 0.105, 0.26), trousers)
        ell("Shoe", (side * 0.105, -0.055, 0.075), (0.11, 0.17, 0.075), "shoe", segments=16)
    face(skin)


def hair_cap(color):
    ell("Hair_back", (0, 0.055, 1.25), (0.262, 0.20, 0.245), color, segments=16, rings=10)
    ell("Hair_top", (0, 0.005, 1.365), (0.247, 0.19, 0.11), color, segments=16)


def apron(color):
    ell("Apron", (0, -0.135, 0.70), (0.19, 0.045, 0.23), color, segments=16)
    for side in (-1, 1):
        capsule("Apron_strap", (side * 0.12, -0.115, 0.94),
                (side * 0.09, -0.17, 0.78), 0.019, color)
    ell("Apron_pocket", (0, -0.181, 0.65), (0.11, 0.012, 0.065), "flour")


def build(name):
    skin = "skin_" + name
    if name == "tilda":
        body(skin, "coral", "navy", 1.08)
        hair_cap("hair_tilda")
        ell("Hair_bun", (0, 0.12, 1.42), (0.13, 0.12, 0.13), "hair_tilda")
        for side in (-1, 1):
            ell("Hair_sweep", (side * 0.15, -0.16, 1.36), (0.11, 0.055, 0.075), "hair_tilda")
        apron("white")
        ell("Baker_cap_band", (0, 0.01, 1.45), (0.205, 0.16, 0.035), "flour")
        ell("Baker_cap", (0, 0.015, 1.51), (0.23, 0.18, 0.09), "white")
    elif name == "hanno":
        body(skin, "sage", "leather", 1.13)
        hair_cap("hair_hanno")
        for side in (-1, 1):
            ell("Side_hair", (side * 0.22, -0.03, 1.27), (0.065, 0.10, 0.11), "hair_hanno")
            ell("Eyebrow", (side * 0.09, -0.20, 1.25), (0.052, 0.012, 0.014), "hair_hanno")
            ell("Moustache", (side * 0.05, -0.23, 1.10), (0.062, 0.022, 0.022), "hair_hanno")
        ell("Vest", (0, -0.10, 0.74), (0.20, 0.065, 0.24), "navy")
        for z in (0.66, 0.75, 0.84):
            ell("Button", (0, -0.167, z), (0.014, 0.008, 0.014), "mustard", segments=8, rings=6)
    elif name == "mo":
        body(skin, "mustard", "denim", 0.94)
        hair_cap("hair_mo")
        for x, z in ((-0.18, 1.36), (-0.09, 1.42), (0, 1.44), (0.09, 1.42), (0.18, 1.36)):
            ell("Curl", (x, -0.12, z), (0.075, 0.08, 0.075), "hair_mo")
        ell("Overall_bib", (0, -0.143, 0.75), (0.15, 0.033, 0.15), "denim")
        for side in (-1, 1):
            capsule("Overall_strap", (side * 0.14, -0.10, 0.95),
                    (side * 0.11, -0.17, 0.79), 0.023, "denim")
            ell("Overall_button", (side * 0.11, -0.18, 0.80), (0.015, 0.008, 0.015), "flour")
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                obj.location *= 0.78
                obj.scale *= 0.78
    elif name == "lale":
        body(skin, "turquoise", "navy")
        hair_cap("hair_lale")
        ell("Ponytail", (0.19, 0.13, 1.19), (0.11, 0.12, 0.20), "hair_lale")
        ell("Cap", (0, 0.005, 1.42), (0.24, 0.19, 0.09), "navy")
        ell("Cap_brim", (0, -0.17, 1.39), (0.20, 0.13, 0.025), "navy")
        capsule("Satchel_strap", (-0.17, -0.125, 0.94), (0.18, -0.15, 0.57), 0.025, "leather")
        ell("Mail_satchel", (0.23, 0, 0.55), (0.13, 0.11, 0.15), "leather")
        ell("Satchel_flap", (0.23, -0.10, 0.59), (0.12, 0.035, 0.075), "mustard")
    elif name == "yusuf":
        body(skin, "plum", "navy", 1.14)
        hair_cap("hair_yusuf")
        for x, z in ((-0.15, 1.38), (-0.05, 1.43), (0.05, 1.43), (0.15, 1.38)):
            ell("Hair_wave", (x, -0.10, z), (0.085, 0.08, 0.065), "hair_yusuf")
        apron("mustard")
        ell("Pocket", (0, -0.193, 0.65), (0.08, 0.012, 0.045), "coral")
    bpy.context.view_layer.update()


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def export(name):
    clear()
    build(name)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    low = min((obj.matrix_world @ Vector(corner)).z for obj in meshes for corner in obj.bound_box)
    for obj in meshes:
        obj.location.z -= low
    bpy.context.view_layer.update()
    triangles = sum(sum(len(face.vertices) - 2 for face in obj.data.polygons) for obj in meshes)
    assert triangles <= 8000, (name, triangles)
    bpy.ops.wm.usd_export(filepath=str(OUT / f"model.npc.{name}.usdz"),
                          export_animation=False, export_materials=True,
                          generate_preview_surface=True, export_cameras=False,
                          export_lights=False, convert_orientation=True,
                          export_global_up_selection="Y",
                          export_global_forward_selection="NEGATIVE_Z",
                          convert_scene_units="METERS", meters_per_unit=1.0)
    print(f"EXPORTED {name}: {triangles} triangles", flush=True)


def preview(path):
    clear()
    for index, name in enumerate(NAMES):
        bpy.ops.wm.usd_import(filepath=str(OUT / f"model.npc.{name}.usdz"))
        for obj in bpy.context.selected_objects:
            if obj.parent is None:
                obj.location.x += (index - 2) * 0.85
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.006))
    bpy.context.object.data.materials.append(material("flour"))
    bpy.ops.object.light_add(type="AREA", location=(-3, -4, 6))
    bpy.context.object.data.energy = 650
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 5
    bpy.ops.object.camera_add(location=(0, -8, 2.45))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.76)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.65
    scene = bpy.context.scene
    scene.camera = camera
    scene.world.color = (0.65, 0.65, 0.65)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1
    for name in NAMES:
        export(name)
    if args.preview:
        preview(args.preview.resolve())


if __name__ == "__main__":
    main()
