"""Generate the MiniFarm crop growth-stage USDZ assets.

Run with Blender 4.2+:
    blender --background --factory-startup --python Tools/Blender/crops.py

The script deliberately clears the factory-startup scene; it never opens or
modifies the user's current Blender scene.
"""

import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


CROPS = (
    "radish", "carrot", "lettuce", "pea", "potato", "strawberry", "tomato",
    "corn", "sunflower", "apple", "wheat", "pumpkin", "kale", "chives",
)
STAGES = ("seed", "sprout", "growing", "ripe")

PALETTES = {
    "radish": ("#C93654", "#F5F0DC", "#4C9B55", "#28683D"),
    "carrot": ("#ED873D", "#E6C58A", "#68A846", "#347144"),
    "lettuce": ("#79B858", "#A9CF70", "#75AE50", "#3D7C48"),
    "pea": ("#69A84D", "#A5C968", "#6BB54F", "#438A47"),
    "potato": ("#A67A4F", "#C49A65", "#70A74E", "#427444"),
    "strawberry": ("#E64A58", "#FFF4DD", "#58A94C", "#307443"),
    "tomato": ("#E84F42", "#EFCF73", "#68A84D", "#347448"),
    "corn": ("#F2C64D", "#E7D279", "#66A84D", "#377548"),
    "sunflower": ("#F4C735", "#6D482C", "#548F45", "#397044"),
    "apple": ("#D94A43", "#9E6A3F", "#68A34D", "#467143"),
    "wheat": ("#D7AE55", "#E8D18C", "#8DA54C", "#637B3B"),
    "pumpkin": ("#E98336", "#C88C49", "#68A34C", "#3B7544"),
    "kale": ("#4F914E", "#74AE58", "#4D914A", "#2D683D"),
    "chives": ("#6C9D48", "#B59BCB", "#70A64D", "#476F3D"),
}

MATERIALS = {}
CREATED = []


def hex_color(value):
    value = value.lstrip("#")
    rgb = tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in rgb) + (1.0,)


def material(name, color):
    key = (name, color)
    if key not in MATERIALS:
        mat = bpy.data.materials.new(name=name)
        mat.diffuse_color = hex_color(color)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = mat.diffuse_color
        bsdf.inputs["Roughness"].default_value = 0.78
        MATERIALS[key] = mat
    return MATERIALS[key]


def finish(obj, name, color):
    obj.name = name
    obj.data.materials.append(material(name + " material", color))
    CREATED.append(obj)
    return obj


def ball(name, color, loc, scale, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, color)


def stem(name, color, start, end, radius, vertices=8):
    a, b = Vector(start), Vector(end)
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=delta.length,
        location=(a + b) * 0.5,
    )
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return finish(obj, name, color)


def leaf(name, color, start, end, width, fullness=0.30):
    a, b = Vector(start), Vector(end)
    direction = b - a
    obj = ball(name, color, (a + b) * 0.5,
               (width, direction.length * fullness, width * 0.34), 1)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Y", "Z")
    return obj


def pod(name, color, start, end, width):
    return leaf(name, color, start, end, width, fullness=0.48)


def blossom(name, color, center, radius, petals, petal_color, disk_color):
    x, y, z = center
    for i in range(petals):
        angle = math.tau * i / petals
        ball(name + " petal", petal_color,
             (x + math.cos(angle) * radius * 0.68,
              y + math.sin(angle) * radius * 0.68, z),
             (radius * 0.46, radius * 0.27, radius * 0.20), 0)
    ball(name + " center", disk_color, center,
         (radius * 0.39, radius * 0.39, radius * 0.31), 1)


def seed_form(crop, color, z=0.035):
    forms = {
        "radish": ((0.040, 0.026, 0.023), "#80634B"),
        "carrot": ((0.048, 0.020, 0.022), "#9A7546"),
        "lettuce": ((0.035, 0.030, 0.018), "#9B8461"),
        "pea": ((0.039, 0.028, 0.025), "#6E9A48"),
        "potato": ((0.050, 0.035, 0.027), "#9B7651"),
        "strawberry": ((0.032, 0.026, 0.020), "#9E8A60"),
        "tomato": ((0.034, 0.027, 0.023), "#B28B4F"),
        "corn": ((0.050, 0.026, 0.027), "#E9C45C"),
        "sunflower": ((0.030, 0.025, 0.018), "#766042"),
        "apple": ((0.035, 0.022, 0.018), "#936D45"),
        "wheat": ((0.044, 0.018, 0.021), "#C8A54E"),
        "pumpkin": ((0.036, 0.026, 0.018), "#B6955B"),
        "kale": ((0.028, 0.021, 0.016), "#857B51"),
        "chives": ((0.042, 0.016, 0.016), "#8A7547"),
    }
    scale, seed_color = forms[crop]
    ball(crop + " seed", seed_color, (0, 0, z), scale, 1)
    if crop in ("pea", "corn", "sunflower", "wheat"):
        ball(crop + " second seed", seed_color, (0.045, 0.012, z * 0.8),
             (scale[0] * 0.7, scale[1] * 0.8, scale[2] * 0.8), 0)


def foliage(crop, height, count, leaf_color=None):
    green = leaf_color or PALETTES[crop][2]
    dark = PALETTES[crop][3]
    if crop in ("chives", "wheat", "corn"):
        stalk_limit = 3 if crop in ("corn", "wheat") else 5
        stalks = 2 if count <= 2 else min(count, stalk_limit)
        for i in range(stalks):
            x = (i - (stalks - 1) / 2) * 0.075
            tip = (x * 0.5, 0, height * (0.90 + 0.04 * (i % 2)))
            stem(crop + " stalk", dark if i % 2 else green, (x, 0, 0), tip,
                 0.012 if crop != "corn" else 0.024, 7)
            for side in (-1, 1):
                z = height * (0.24 + 0.13 * ((i + side) % 3))
                leaf(crop + " blade", green, (x * 0.5, 0, z),
                     (x * 0.5 + side * height * 0.20, 0, z + height * 0.12),
                     height * (0.075 if crop != "corn" else 0.12), 0.42)
    else:
        stem(crop + " stem", dark, (0, 0, 0), (0, 0, height), 0.018, 8)
        for i in range(count):
            angle = i * 2.399963 + (0.35 if i % 2 else 0)
            z = height * (0.22 + 0.68 * ((i + 1) / (count + 1)))
            reach = height * (0.25 + 0.04 * (i % 3))
            endpoint = (math.cos(angle) * reach, math.sin(angle) * reach,
                        z + height * (0.05 if i % 2 else -0.02))
            leaf(crop + " leaf", green, (0, 0, z), endpoint,
                 height * (0.12 if crop not in ("lettuce", "kale") else 0.19), 0.40)
    return green


def root_crop(crop, stage, height, count):
    root_color, pale, green, dark = PALETTES[crop]
    if stage == 1:
        stem(crop + " sprout stem", dark, (0, 0, 0), (0, 0, height * 0.72), 0.014, 7)
        leaf(crop + " sprout leaf", green, (0, 0, height * 0.45),
             (-height * 0.60, 0, height * 0.88), height * 0.38, 0.42)
        leaf(crop + " sprout leaf", PALETTES[crop][1],
             (0, 0, height * 0.49), (height * 0.58, 0, height * 0.91),
             height * 0.34, 0.42)
    else:
        leaf_count = (0, 0, 4, 5)[stage]
        foliage(crop, height * (1.12 if stage == 2 else 1.30),
                leaf_count, green)
    if crop == "radish":
        if stage == 2:
            ball("radish root forming", root_color, (0, 0, height * 0.12),
                 (height * 0.30, height * 0.26, height * 0.27), 1)
            stem("radish root tip", pale, (0, 0, 0.09), (0, 0, 0.015), 0.025, 7)
        if stage == 3:
            ball("ripe radish", root_color, (0, 0, 0.18), (0.17, 0.15, 0.19), 2)
            stem("radish root tip", pale, (0, 0, 0.08), (0, 0, 0.015), 0.026, 7)
            stem("radish shoulders", pale, (0, 0, 0.31), (0, 0, 0.25), 0.055, 8)
    elif crop == "carrot":
        if stage >= 2:
            ball("carrot root", root_color, (0, 0, 0.19 if stage == 3 else 0.13),
                 (0.075, 0.072, 0.22 if stage == 3 else 0.14), 1)
            stem("carrot tapered tip", root_color, (0, 0, 0.07), (0, 0, 0.005), 0.036, 7)
    elif crop == "potato":
        if stage >= 2:
            for x, y in ((-0.14, 0.04), (0.12, -0.06), (0.02, 0.14)):
                ball("potato tuber", root_color, (x, y, 0.066),
                     (0.105, 0.075, 0.055), 1)
                for dot in ((x - 0.03, y, 0.11), (x + 0.035, y + 0.02, 0.10)):
                    ball("potato eye", dark, dot, (0.012, 0.010, 0.009), 0)
    elif crop == "lettuce" and stage >= 2:
        for i in range(5 if stage == 2 else 7):
            angle = i * math.tau / (5 if stage == 2 else 7)
            leaf("lettuce outer leaf", green,
                 (0, 0, height * 0.46),
                 (math.cos(angle) * height * 0.29,
                  math.sin(angle) * height * 0.29, height * 0.55),
                 height * 0.19, 0.44)
        ball("lettuce heart", PALETTES[crop][1], (0, 0, height * 0.66),
             (height * 0.17, height * 0.16, height * 0.19), 1)


def pea_crop(stage, height):
    green = PALETTES["pea"][2]
    stem("pea vine", PALETTES["pea"][3], (0, 0, 0), (0.04, 0, height), 0.017, 7)
    for i in range((2, 4, 6, 6)[stage]):
        side = -1 if i % 2 else 1
        z = height * (0.16 + 0.78 * (i / max(1, (2, 4, 6, 8)[stage] - 1)))
        leaf("pea rounded leaf", green, (0.03, 0, z),
             (0.03 + side * 0.18, 0, z + 0.06), 0.065, 0.43)
        if stage >= 2 and i % 2 == 0:
            pod("pea pod", PALETTES["pea"][0], (0.04, 0, z),
                (0.04 + side * 0.16, 0.01, z + 0.02), 0.045)
            if stage == 3:
                for j in range(2):
                    ball("pea in pod", "#BDE17C",
                         (0.06 + side * (0.06 + j * 0.035), 0, z + 0.02),
                         (0.021, 0.021, 0.021), 0)


def strawberry_crop(stage, height):
    green = foliage("strawberry", height * 0.76, (1, 2, 4, 5)[stage])
    if stage >= 2:
        berries = 1 if stage == 2 else 3
        for i in range(berries):
            angle = math.tau * i / berries
            x, y = math.cos(angle) * 0.13, math.sin(angle) * 0.13
            ball("strawberry fruit", PALETTES["strawberry"][0], (x, y, 0.13),
                 (0.085, 0.08, 0.105), 1)
            for j in range(3):
                ball("strawberry seed", "#FFE7A6",
                     (x + (j - 1) * 0.025, y - 0.073, 0.13 + (j % 2) * 0.03),
                     (0.008, 0.006, 0.008), 0)
        if stage == 2:
            blossom("strawberry flower", "#FFF4DD", (0.13, 0, height * 0.7),
                    0.06, 5, "#FFF4DD", "#F0C54E")


def tomato_crop(stage, height):
    green = foliage("tomato", height * 0.90, (1, 2, 4, 6)[stage])
    if stage >= 2:
        fruits = 1 if stage == 2 else 4
        for i in range(fruits):
            x = (i % 2 - 0.5) * 0.20
            y = (i // 2 - 0.5) * 0.13
            z = height * (0.42 + (0.14 if i % 2 else 0))
            color = "#F2A34E" if stage == 2 else PALETTES["tomato"][0]
            ball("tomato fruit", color, (x, y, z), (0.09, 0.09, 0.085), 1)
            stem("tomato calyx", green, (x, y, z + 0.08), (x, y, z + 0.10),
                 0.018, 6)


def corn_crop(stage, height):
    green = foliage("corn", height, (1, 2, 3, 5)[stage])
    if stage >= 2:
        z = height * (0.46 if stage == 2 else 0.53)
        ball("corn cob", "#E5C044" if stage == 2 else "#F5CC4B",
             (0.075, 0, z), (0.075, 0.075, height * 0.20), 1)
        if stage == 3:
            for i in range(4):
                ball("corn kernel", "#FFE077",
                     (0.12, (i - 1.5) * 0.026, z - 0.10 + i * 0.045),
                     (0.018, 0.018, 0.021), 0)
        for side in (-1, 1):
            leaf("corn husk", "#91B653", (0.04, 0, z - 0.18),
                 (0.04 + side * 0.11, 0, z - 0.02), 0.043, 0.42)


def sunflower_crop(stage, height):
    foliage("sunflower", height * 0.91, (1, 2, 3, 4)[stage])
    if stage >= 2:
        head_z = height * 0.90
        if stage == 2:
            ball("sunflower bud", "#579146", (0, 0, head_z),
                 (0.10, 0.10, 0.12), 1)
        else:
            blossom("sunflower head", "#6D482C", (0, 0, head_z),
                    0.18, 8, "#F6C83E", "#73502D")
            for i in range(5):
                ball("sunflower seed", "#D7AE55",
                     ((i % 3 - 1) * 0.045, 0.10, head_z + (i // 3) * 0.035),
                     (0.014, 0.012, 0.014), 0)


def apple_crop(stage, height):
    trunk_top = height * (0.65 if stage < 3 else 0.76)
    stem("apple tree trunk", "#9E6A3F", (0, 0, 0), (0, 0, trunk_top), 0.055, 8)
    foliage("apple", height * 0.34, (1, 2, 4, 6)[stage], "#68A34D")
    for side in (-1, 1):
        stem("apple branch", "#9E6A3F", (0, 0, trunk_top * 0.6),
             (side * height * 0.28, 0, trunk_top * 0.86), 0.025, 7)
    if stage >= 2:
        blossoms = 1 if stage == 2 else 0
        for i in range(blossoms):
            blossom("apple blossom", "#FFF0D7",
                    ((i - 0.5) * 0.19, -0.08, trunk_top * 0.89),
                    0.055, 5, "#FFF0D7", "#EDC551")
        if stage == 3:
            for x, y, z in ((-0.15, 0, 0.67), (0.14, 0.03, 0.75), (0, -0.13, 0.91)):
                ball("ripe apple", PALETTES["apple"][0], (x, y, z),
                     (0.085, 0.08, 0.09), 1)
                stem("apple stalk", "#735032", (x, y, z + 0.07),
                     (x, y, z + 0.11), 0.009, 6)


def wheat_crop(stage, height):
    foliage("wheat", height, (1, 2, 3, 5)[stage])
    stalk_count = (1, 2, 3, 3)[stage]
    if stage >= 2:
        for i in range(stalk_count):
            x = (i - (stalk_count - 1) / 2) * 0.07
            z = height * (0.83 if stage == 2 else 0.92)
            for j in range(3 if stage == 3 else 2):
                ball("wheat grain", "#E5C56F", (x + (j % 2) * 0.023, 0,
                     z - j * 0.055), (0.024, 0.018, 0.039), 0)


def pumpkin_crop(stage, height):
    foliage("pumpkin", height * 0.65, (1, 2, 4, 5)[stage])
    if stage >= 2:
        size = 0.13 if stage == 2 else 0.26
        color = "#A5B457" if stage == 2 else PALETTES["pumpkin"][0]
        ball("pumpkin fruit", color, (0.03, 0, size * 0.86),
             (size, size * 0.92, size * 0.72), 2)
        if stage == 3:
            for i in range(5):
                angle = math.tau * i / 5
                ball("pumpkin rib", "#EF9A46",
                     (math.cos(angle) * 0.14, math.sin(angle) * 0.14, 0.23),
                     (0.09, 0.08, 0.22), 1)
        stem("pumpkin stem", "#527C3E", (0.03, 0, size * 1.3),
             (0.05, 0, size * 1.5), 0.022, 7)


def kale_crop(stage, height):
    green = PALETTES["kale"][2]
    foliage("kale", height * 0.78, (1, 2, 4, 5)[stage], green)
    if stage >= 2:
        for i in range(6 if stage == 2 else 9):
            angle = i * math.tau / (6 if stage == 2 else 9)
            leaf("kale ruffled outer leaf", "#62A653",
                 (0, 0, height * 0.35),
                 (math.cos(angle) * 0.20, math.sin(angle) * 0.20, height * 0.57),
                 0.105, 0.47)
        ball("kale crown", green, (0, 0, height * 0.61),
             (0.15, 0.14, 0.13), 1)


def chives_crop(stage, height):
    greens = PALETTES["chives"][2]
    stalk_count = (1, 2, 4, 3)[stage]
    for i in range(stalk_count):
        x = (i - (stalk_count - 1) / 2) * 0.045
        h = height * (0.90 + 0.04 * (i % 2))
        stem("chive leaf", greens, (x, 0, 0), (x + 0.025, 0, h), 0.014, 7)
        if stage == 3:
            ball("chive flower head", PALETTES["chives"][1],
                 (x + 0.025, 0, h), (0.055, 0.05, 0.06), 1)
            for j in range(3):
                ball("chive floret", "#D8C6E8",
                     (x + 0.025 + (j - 1) * 0.025, -0.022, h),
                     (0.020, 0.018, 0.024), 0)


def build_crop(crop, stage, clear_scene=True):
    CREATED.clear()
    if clear_scene:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes,):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)
    stage_index = STAGES.index(stage)
    heights = {
        "radish": (0.035, 0.13, 0.29, 0.38),
        "carrot": (0.035, 0.16, 0.36, 0.50),
        "lettuce": (0.025, 0.10, 0.24, 0.31),
        "pea": (0.035, 0.18, 0.38, 0.52),
        "potato": (0.035, 0.17, 0.35, 0.48),
        "strawberry": (0.025, 0.12, 0.25, 0.31),
        "tomato": (0.030, 0.16, 0.38, 0.54),
        "corn": (0.035, 0.20, 0.47, 0.72),
        "sunflower": (0.025, 0.18, 0.45, 0.70),
        "apple": (0.04, 0.24, 0.55, 1.10),
        "wheat": (0.035, 0.20, 0.45, 0.64),
        "pumpkin": (0.03, 0.13, 0.33, 0.46),
        "kale": (0.025, 0.12, 0.27, 0.34),
        "chives": (0.025, 0.15, 0.38, 0.57),
    }
    height = heights[crop][stage_index]
    if stage == "seed":
        seed_form(crop, PALETTES[crop][0])
    elif crop in ("radish", "carrot", "lettuce", "potato"):
        root_crop(crop, stage_index, height, 0)
    elif crop == "pea":
        pea_crop(stage_index, height)
    elif crop == "strawberry":
        strawberry_crop(stage_index, height)
    elif crop == "tomato":
        tomato_crop(stage_index, height)
    elif crop == "corn":
        corn_crop(stage_index, height)
    elif crop == "sunflower":
        sunflower_crop(stage_index, height)
    elif crop == "apple":
        apple_crop(stage_index, height)
    elif crop == "wheat":
        wheat_crop(stage_index, height)
    elif crop == "pumpkin":
        pumpkin_crop(stage_index, height)
    elif crop == "kale":
        kale_crop(stage_index, height)
    elif crop == "chives":
        chives_crop(stage_index, height)
    else:
        raise ValueError(crop)
    bpy.context.view_layer.update()
    lowest_z = min(
        (obj.matrix_world @ Vector(corner)).z
        for obj in CREATED if obj.type == "MESH"
        for corner in obj.bound_box
    )
    for obj in CREATED:
        obj.select_set(True)
        obj.location.x = 0
        obj.location.y = 0
        obj.location.z -= lowest_z
    bpy.context.view_layer.objects.active = CREATED[0] if CREATED else None
    return list(CREATED), height


def triangle_count(objects):
    total = 0
    for obj in objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
    return total


def bounds(objects):
    points = []
    for obj in objects:
        if obj.type == "MESH":
            points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        return [0, 0, 0]
    return [round(max(p[i] for p in points) - min(p[i] for p in points), 4) for i in range(3)]


def export_usdz(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=path,
        selected_objects_only=True,
        export_materials=True,
        generate_preview_surface=True,
        export_normals=True,
        export_uvmaps=False,
        export_animation=False,
        convert_orientation=True,
        export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z",
        meters_per_unit=1.0,
        convert_scene_units="METERS",
        triangulate_meshes=True,
        root_prim_path="/Crop",
    )


def verify_usdz(path):
    from pxr import Usd, UsdGeom, UsdShade

    stage = Usd.Stage.Open(path)
    if stage is None:
        raise RuntimeError("USDZ could not be opened: " + path)
    up_axis = str(UsdGeom.GetStageUpAxis(stage))
    meters_per_unit = float(UsdGeom.GetStageMetersPerUnit(stage))
    if up_axis != "Y" or abs(meters_per_unit - 1.0) > 1e-8:
        raise RuntimeError("Unexpected USD stage metadata: up={}, metersPerUnit={}".format(
            up_axis, meters_per_unit))
    root = stage.GetPrimAtPath("/Crop")
    if not root:
        raise RuntimeError("Missing /Crop root prim in " + path)
    triangle_total = 0
    mesh_count = 0
    material_count = 0
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Mesh):
            mesh_count += 1
            mesh = UsdGeom.Mesh(prim)
            triangle_total += sum(max(0, int(n) - 2)
                                  for n in mesh.GetFaceVertexCountsAttr().Get())
        if prim.IsA(UsdShade.Material):
            material_count += 1
    if not mesh_count or not triangle_total or not material_count:
        raise RuntimeError("USD geometry/material verification failed for " + path)
    cache = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_])
    box = cache.ComputeWorldBound(root).ComputeAlignedBox()
    minimum, maximum = box.GetMin(), box.GetMax()
    # Blender Z=0 is the plant's local base; the requested USD orientation maps
    # that ground plane to Y=0, with positive Y above ground.
    y_min, y_max = float(minimum[1]), float(maximum[1])
    if y_min < -1e-5 or y_min > 1e-4:
        raise RuntimeError("USD plant base is not on Y=0 ground: minY={}".format(y_min))
    return {
        "usd_up_axis": up_axis,
        "meters_per_unit": meters_per_unit,
        "usd_triangle_count": triangle_total,
        "usd_mesh_count": mesh_count,
        "usd_material_count": material_count,
        "usd_bounds_min_m": [round(float(v), 5) for v in minimum],
        "usd_bounds_max_m": [round(float(v), 5) for v in maximum],
        "usd_ground_origin_verified": True,
    }


def render_gallery(artifact_dir):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    gallery = []
    crops = ("radish", "carrot", "lettuce")
    for row, crop in enumerate(crops):
        for col, stage in enumerate(STAGES):
            objects, _ = build_crop(crop, STAGES[col], clear_scene=False)
            x, y = (col - 1.5) * 0.68, (1 - row) * 0.95
            for obj in objects:
                obj.location.x += x
                obj.location.y += y
                gallery.append(obj)
    # Soft, neutral presentation setup; this ground is not included in exports.
    bpy.ops.mesh.primitive_plane_add(size=10, location=(0, 0, -0.025))
    ground = bpy.context.object
    ground.name = "Render-only backdrop"
    ground.data.materials.append(material("warm cream backdrop", "#EADFC9"))
    gallery.append(ground)
    bpy.ops.object.camera_add(location=(0, -5.7, 4.2))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.15)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.5
    bpy.context.scene.camera = camera
    light_data = bpy.data.lights.new("Softbox", type="AREA")
    light_data.energy = 470
    light_data.shape = "DISK"
    light_data.size = 5
    light = bpy.data.objects.new("Softbox", light_data)
    bpy.context.collection.objects.link(light)
    light.location = (-3, -4, 6)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Crop render world")
    scene.world.color = (0.36, 0.36, 0.36)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.render.filepath = os.path.join(artifact_dir, "minifarm-crops-level1-stages.png")
    bpy.ops.render.render(write_still=True)


def main(output_dir=None, artifact_dir=None):
    project_root = Path(__file__).resolve().parents[2]
    output_dir = Path(output_dir or project_root / "App/Resources/Models")
    artifact_dir = Path(artifact_dir or project_root / "artifacts/crops")
    output_dir.mkdir(parents=True, exist_ok=True)
    artifact_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    records = []
    for crop in CROPS:
        for stage in STAGES:
            objects, nominal_height = build_crop(crop, stage)
            count = triangle_count(objects)
            if count > 400:
                raise RuntimeError("{} {} has {} triangles (>400)".format(crop, stage, count))
            filename = "model.crop.{}.{}.usdz".format(crop, stage)
            path = output_dir / filename
            export_usdz(str(path), objects)
            usd_check = verify_usdz(str(path))
            if usd_check["usd_triangle_count"] > 400:
                raise RuntimeError("{} {} exported to {} triangles (>400)".format(
                    crop, stage, usd_check["usd_triangle_count"]))
            records.append({
                "crop": crop,
                "stage": stage,
                "file": filename,
                "triangles": count,
                "dimensions_m": bounds(objects),
                "nominal_height_m": nominal_height,
                "file_bytes": path.stat().st_size,
                **usd_check,
            })
            print("EXPORTED {}: {} Blender / {} USD triangles, {} m, groundY={}".format(
                filename, count, usd_check["usd_triangle_count"],
                records[-1]["dimensions_m"], usd_check["usd_bounds_min_m"][1]))
    render_gallery(str(artifact_dir))
    report = {
        "units": "meters",
        "blender_up_axis": "Z",
        "usd_up_axis": "Y",
        "meters_per_unit": 1.0,
        "ground_origin": "Blender z=0; USD y=0 after orientation conversion; checked via USD world bounds",
        "triangle_budget": 400,
        "models": records,
        "render": "minifarm-crops-level1-stages.png",
    }
    report_path = artifact_dir / "crop-asset-verification.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("REPORT {}".format(report_path))
    print("MODEL_COUNT {}".format(len(records)))
    print("MAX_TRIANGLES {}".format(max(row["triangles"] for row in records)))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {}
    if len(argv) >= 1:
        args["output_dir"] = argv[0]
    if len(argv) >= 2:
        args["artifact_dir"] = argv[1]
    main(**args)
