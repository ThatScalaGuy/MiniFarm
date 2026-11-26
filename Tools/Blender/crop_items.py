"""Original MiniFarm harvest items and seed packets, no external asset inputs.

Run in an isolated process, never in the interactive Blender scene:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python-exit-code 1 --python Tools/Blender/crop_items.py -- \
    --artifacts <session-files-directory>

Only the 14 model.item.<crop>.usdz and 13 model.item.seed.<crop>.usdz
files are written to the model directory. Reports and an exported-asset contact
sheet go to --artifacts. Existing target files are refused unless --overwrite
is supplied. No dependency on crops.py or third-party assets. The front is
Blender -Y, converted to USD +Z; labels, seeds and open pea pods face that side.
"""

import argparse
import hashlib
import json
import math
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

import bpy
from mathutils import Vector
from pxr import Usd, UsdGeom, UsdShade


CROPS = (
    "radish", "carrot", "lettuce", "pea", "potato", "strawberry", "tomato",
    "corn", "sunflower", "apple", "wheat", "pumpkin", "kale", "chives",
)
PALETTE = {
    "radish": "#C93654", "carrot": "#ED873D", "lettuce": "#79B858",
    "pea": "#69A84D", "potato": "#A67A4F", "strawberry": "#E64A58",
    "tomato": "#E84F42", "corn": "#F2C64D", "sunflower": "#F4C735",
    "apple": "#D94A43", "wheat": "#D7AE55", "pumpkin": "#E98336",
    "kale": "#4F914E", "chives": "#6C9D48",
}
GREEN, LIGHT_GREEN, DARK_GREEN = "#68A846", "#A9CF70", "#347144"
CREAM, BROWN, GOLD = "#F5F0DC", "#8E603F", "#E8C164"
BUDGET = 400
PARTS = []
MATERIALS = {}


def linear_color(hex_value):
    values = [int(hex_value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                 for v in values) + (1.0,)


def material(color):
    if color not in MATERIALS:
        mat = bpy.data.materials.new("Felt_" + color[1:])
        mat.diffuse_color = linear_color(color)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = mat.diffuse_color
        shader.inputs["Roughness"].default_value = 0.78
        shader.inputs["Metallic"].default_value = 0
        MATERIALS[color] = mat
    return MATERIALS[color]


def mesh_part(name, vertices, faces, color, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(color))
    for polygon in mesh.polygons:
        polygon.use_smooth = smooth
    PARTS.append(obj)
    return obj


def lathe(name, color, profile, segments=8, center=(0, 0, 0),
          scale=(1, 1, 1), lobes=0):
    """Closed, capped low-poly surfaces, without coincident pole vertices."""
    vertices, faces, rings = [], [], []
    for z, radius in profile:
        ring = []
        for i in range(1 if radius == 0 else segments):
            angle = math.tau * i / segments
            r = radius * (1 + (0.10 * math.cos(angle * lobes) if lobes else 0))
            ring.append(len(vertices))
            vertices.append((center[0] + r * math.cos(angle) * scale[0],
                             center[1] + r * math.sin(angle) * scale[1],
                             center[2] + z * scale[2]))
        rings.append(ring)
    for lower, upper in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            if len(lower) == 1:
                faces.append((lower[0], upper[j], upper[i]))
            elif len(upper) == 1:
                faces.append((lower[i], lower[j], upper[0]))
            else:
                faces.append((lower[i], lower[j], upper[j], upper[i]))
    return mesh_part(name, vertices, faces, color)


def oval(name, color, center, size, segments=8):
    return lathe(name, color, [(-1, 0), (-0.62, 0.76), (0, 1),
                              (0.62, 0.76), (1, 0)], segments, center, size)


def bead(name, color, center, size):
    return lathe(name, color, [(-1, 0), (0, 1), (1, 0)], 4, center, size)


def rod(name, color, start, end, radius, sides=6):
    a, b = Vector(start), Vector(end)
    direction = b - a
    obj = lathe(name, color, [(0, 0), (0, radius),
                             (direction.length, radius), (direction.length, 0)], sides)
    obj.location = a
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    return obj


def leaf(name, color, start, end, width, curl=0):
    a, b = Vector(start), Vector(end)
    direction = b - a
    side = direction.cross(Vector((0, -1, 0))).normalized()
    if side.length < 0.5:
        side = Vector((1, 0, 0))
    normal = side.cross(direction).normalized()
    boundary = [(0, 0), (0.20, 0.65), (0.52, 1), (0.84, 0.68),
                (1, 0), (0.84, -0.68), (0.52, -1), (0.20, -0.65)]
    vertices = []
    for t, w in boundary:
        p = a + direction * t + side * width * w
        p += normal * (curl * math.sin(t * math.pi) * (1 if w > 0 else -1))
        vertices.append(tuple(p))
    center = (a + b) / 2
    vertices.extend((tuple(center + normal * width * 0.26),
                     tuple(center - normal * width * 0.13)))
    faces = []
    for i in range(8):
        j = (i + 1) % 8
        faces.extend(((8, i, j), (9, j, i)))
    return mesh_part(name, vertices, faces, color)


def tip_leaves(z, count=3, reach=0.11):
    for i in range(count):
        angle = math.tau * i / count + 0.2
        leaf("Harvest foliage", GREEN if i % 2 else LIGHT_GREEN, (0, 0, z),
             (reach * math.cos(angle), reach * math.sin(angle), z + 0.13),
             0.035)


def harvest(crop):
    color = PALETTE[crop]
    if crop == "radish":
        lathe("White rounded root", CREAM,
              [(0, 0), (0.025, 0.015), (0.07, 0.05), (0.09, 0)], 8)
        lathe("Pink radish bulb", color,
              [(0.04, 0), (0.07, 0.065), (0.13, 0.11),
               (0.21, 0.095), (0.24, 0.045), (0.25, 0)], 12)
        tip_leaves(0.23)
    elif crop == "carrot":
        lathe("Soft tapered carrot", color,
              [(0, 0), (0.025, 0.018), (0.13, 0.045),
               (0.27, 0.073), (0.31, 0.045), (0.32, 0)], 8)
        for z, width in ((0.13, 0.029), (0.23, 0.046)):
            rod("Carrot crease", "#CE682F", (-width, -0.045, z),
                (width, -0.045, z + 0.006), 0.004, 4)
        tip_leaves(0.30, 3, 0.085)
    elif crop in ("lettuce", "kale"):
        oval("Leafy heart", LIGHT_GREEN if crop == "lettuce" else color,
             (0, 0, 0.105), (0.09, 0.08, 0.10))
        for i in range(7):
            angle = math.tau * i / 7
            reach = 0.14 if crop == "lettuce" else 0.11
            leaf("Broad cupped leaf" if crop == "lettuce" else "Curly kale leaf",
                 (color, LIGHT_GREEN if crop == "lettuce" else DARK_GREEN)[i % 2],
                 (0, 0, 0.025),
                 (math.cos(angle) * reach, math.sin(angle) * reach,
                  0.18 if crop == "lettuce" else 0.26),
                 0.075 if crop == "lettuce" else 0.065,
                 curl=0.006 if crop == "lettuce" else 0.035)
    elif crop == "pea":
        oval("Opened pea pod", DARK_GREEN, (0, 0.018, 0.075), (0.18, 0.05, 0.072))
        leaf("Pod lower lip", color, (-0.17, -0.033, 0.045),
             (0.17, -0.033, 0.045), 0.05)
        for i in range(4):
            oval("Round pea", LIGHT_GREEN, ((i - 1.5) * 0.073, -0.035, 0.095),
                 (0.037, 0.037, 0.037), 6)
    elif crop == "potato":
        oval("Potato", color, (0, 0, 0.08), (0.14, 0.085, 0.08), 10)
        for x, z in ((-0.065, 0.115), (0.045, 0.13), (0.09, 0.08)):
            bead("Potato eye", "#805C3F", (x, -0.064, z), (0.011, 0.007, 0.008))
    elif crop == "strawberry":
        lathe("Heart strawberry", color,
              [(0, 0), (0.035, 0.035), (0.12, 0.095),
               (0.20, 0.10), (0.23, 0.05), (0.235, 0)], 10)
        for x, z, y in ((-0.04, 0.12, -0.087), (0.025, 0.15, -0.098),
                        (-0.035, 0.19, -0.092), (0.035, 0.085, -0.069),
                        (0, 0.055, -0.055)):
            bead("Strawberry seed", GOLD, (x, y, z), (0.007, 0.004, 0.011))
        for i in range(5):
            angle = math.tau * i / 5
            leaf("Strawberry calyx", GREEN, (0, 0, 0.23),
                 (0.08 * math.cos(angle), 0.08 * math.sin(angle), 0.215), 0.018)
    elif crop in ("tomato", "apple"):
        lathe("Tomato body" if crop == "tomato" else "Apple body", color,
              [(0, 0), (0.02, 0.065), (0.08, 0.11), (0.16, 0.115),
               (0.215, 0.075), (0.19, 0)], 12, lobes=3 if crop == "apple" else 0)
        rod("Fruit stalk", BROWN if crop == "apple" else DARK_GREEN,
            (0, 0, 0.19), (0.014, 0, 0.27), 0.012)
        if crop == "apple":
            leaf("Apple leaf", GREEN, (0.01, 0, 0.25), (0.12, 0, 0.28), 0.035)
        else:
            for i in range(5):
                angle = math.tau * i / 5
                leaf("Star tomato calyx", DARK_GREEN, (0, 0, 0.215),
                     (0.072 * math.cos(angle), 0.072 * math.sin(angle), 0.23), 0.018)
    elif crop == "corn":
        oval("Golden corn cob", color, (0, 0, 0.17), (0.062, 0.060, 0.17), 10)
        for z in (0.09, 0.145, 0.20, 0.255):
            for x in (-0.026, 0.026):
                bead("Raised corn kernels", "#FFE08A", (x, -0.055, z),
                     (0.022, 0.013, 0.022))
        for side in (-1, 1):
            leaf("Peeled corn husk", GREEN, (0, 0.015, 0.005),
                 (side * 0.13, 0.02, 0.23), 0.035)
    elif crop == "sunflower":
        rod("Cut sunflower stem", GREEN, (0, 0, 0), (0, 0, 0.25), 0.014)
        for i in range(10):
            angle = math.tau * i / 10
            leaf("Sunflower petal", color,
                 (0.04 * math.cos(angle), 0, 0.30 + 0.04 * math.sin(angle)),
                 (0.15 * math.cos(angle), 0, 0.30 + 0.15 * math.sin(angle)), 0.026)
        oval("Sunflower seed disk", "#6D482C", (0, -0.012, 0.30),
             (0.069, 0.028, 0.069), 10)
        for x, z in ((-0.028, 0.29), (0.028, 0.29), (0, 0.33)):
            bead("Sunflower seeds", GOLD, (x, -0.039, z), (0.009, 0.006, 0.012))
    elif crop == "wheat":
        for i in range(3):
            x = (i - 1) * 0.06
            top = 0.29 + (0.05 if i == 1 else 0)
            rod("Cut wheat stalk", color, (x * 0.35, 0, 0), (x, 0, top), 0.008)
            for j in range(3):
                side = -1 if j % 2 else 1
                leaf("Wheat grain", GOLD, (x, 0, top - j * 0.032),
                     (x + side * 0.041, 0, top - j * 0.032 + 0.043), 0.016)
        rod("Wheat bundle tie", BROWN, (-0.026, -0.008, 0.09),
            (0.026, -0.008, 0.09), 0.013)
    elif crop == "pumpkin":
        lathe("Plump ribbed pumpkin", color,
              [(0, 0), (0.025, 0.105), (0.10, 0.16),
               (0.20, 0.145), (0.245, 0.075), (0.23, 0)], 24, lobes=8)
        rod("Pumpkin stalk", DARK_GREEN, (0, 0, 0.23), (0.022, 0, 0.30), 0.022)
        leaf("Pumpkin leaf", GREEN, (0, 0, 0.25), (-0.10, 0, 0.26), 0.027)
    elif crop == "chives":
        for i in range(7):
            x = (i - 3) * 0.013
            rod("Cut tubular chive", GREEN if i % 2 else DARK_GREEN,
                (x * 0.55, (i % 2) * 0.012, 0),
                (x * 1.4, (i % 2) * 0.012, 0.28 + (i % 3) * 0.03), 0.008)
        rod("Chive bundle tie", GOLD, (-0.039, -0.012, 0.075),
            (0.039, -0.012, 0.075), 0.010)
    else:
        raise ValueError(crop)


def box(name, color, location, dimensions, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft paper corners", "BEVEL")
        mod.width, mod.segments = bevel, 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(material(color))
    PARTS.append(obj)
    return obj


def world_points(objects):
    bpy.context.view_layer.update()
    return [obj.matrix_world @ vertex.co for obj in objects for vertex in obj.data.vertices]


def make_model(crop, seed_packet=False):
    PARTS.clear()
    bpy.ops.object.select_all(action="DESELECT")
    harvest(crop)
    if seed_packet:
        icon = list(PARTS)
        points = world_points(icon)
        lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
        hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
        center = (lo + hi) / 2
        scale = min(0.185 / (hi.x - lo.x), 0.205 / (hi.z - lo.z))
        depth_scale = 0.023 / max(hi.y - lo.y, 0.001)
        for obj in icon:
            matrix = obj.matrix_world.copy()
            for vertex in obj.data.vertices:
                p = matrix @ vertex.co - center
                vertex.co = (p.x * scale, p.y * depth_scale - 0.050,
                             p.z * scale + 0.215)
            obj.matrix_world.identity()
        box("Cream paper seed packet", "#EACF96", (0, 0, 0.20),
            (0.29, 0.07, 0.40), 0.018)
        box("Packet folded top seam", "#BE864E", (0, 0, 0.374),
            (0.28, 0.075, 0.028))
        box("Packet folded bottom seam", "#D5AD72", (0, 0, 0.025),
            (0.27, 0.073, 0.020))
        for x in (-0.047, 0, 0.047):
            bead("Sowing symbol seed", BROWN, (x, -0.039, 0.065),
                 (0.012, 0.004, 0.018))
    points = world_points(PARTS)
    lowest = min(p.z for p in points)
    # Bake every mesh to one grounded, centered object. Object origin remains
    # (0,0,0); exported Y=0 is the lowest actual vertex, not just a nominal base.
    for obj in PARTS:
        matrix = obj.matrix_world.copy()
        for vertex in obj.data.vertices:
            p = matrix @ vertex.co
            p.z -= lowest
            vertex.co = p
        obj.matrix_world.identity()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PARTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = "Item_" + ("seed_" if seed_packet else "") + crop
    obj.data.name = obj.name + "_mesh"
    mod = obj.modifiers.new("Explicit triangle budget", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.calc_loop_triangles()
    if len(obj.data.loop_triangles) > BUDGET:
        raise RuntimeError(f"{obj.name}: {len(obj.data.loop_triangles)} triangles > {BUDGET}")
    return obj


def export_model(obj, target):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    options = dict(
        filepath=str(target), selected_objects_only=True, export_materials=True,
        generate_preview_surface=True, export_normals=True, export_uvmaps=False,
        export_animation=False, export_lights=False, export_cameras=False,
        convert_orientation=True, export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z", meters_per_unit=1.0,
        root_prim_path="/Item", triangulate_meshes=True,
    )
    if "generate_materialx_network" in bpy.ops.wm.usd_export.get_rna_type().properties:
        options["generate_materialx_network"] = False
    bpy.ops.wm.usd_export(**options)


def verify(target):
    stage = Usd.Stage.Open(str(target))
    assert stage and stage.GetDefaultPrim(), f"No default prim: {target}"
    assert UsdGeom.GetStageUpAxis(stage) == "Y"
    assert abs(UsdGeom.GetStageMetersPerUnit(stage) - 1.0) < 1e-8
    triangle_count, meshes, material_paths = 0, 0, set()
    colors, points, seed_symbol_depths = set(), [], []
    transforms = UsdGeom.XformCache()
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Mesh):
            meshes += 1
            mesh = UsdGeom.Mesh(prim)
            counts = mesh.GetFaceVertexCountsAttr().Get()
            assert all(n == 3 for n in counts), target
            triangle_count += len(counts)
            binding, _ = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
            assert binding, f"No bound material: {target} {prim.GetPath()}"
            material_paths.add(str(binding.GetPath()))
            matrix = transforms.GetLocalToWorldTransform(prim)
            positions = [matrix.Transform(p) for p in mesh.GetPointsAttr().Get()]
            points.extend(positions)
            if ".seed." in target.name:
                indices = mesh.GetFaceVertexIndicesAttr().Get()
                for subset in UsdGeom.Subset.GetAllGeomSubsets(mesh):
                    bound, _ = UsdShade.MaterialBindingAPI(subset.GetPrim()).ComputeBoundMaterial()
                    if bound and "8E603F" in str(bound.GetPath()):
                        for face in subset.GetIndicesAttr().Get():
                            seed_symbol_depths.extend(float(positions[indices[face * 3 + j]][2])
                                                      for j in range(3))
        if prim.IsA(UsdShade.Shader):
            shader = UsdShade.Shader(prim)
            if shader.GetIdAttr().Get() == "UsdPreviewSurface":
                color = shader.GetInput("diffuseColor").Get()
                colors.add(tuple(round(float(v), 5) for v in color))
    assert 0 < triangle_count <= BUDGET and colors
    lo = [min(float(p[i]) for p in points) for i in range(3)]
    hi = [max(float(p[i]) for p in points) for i in range(3)]
    assert abs(lo[1]) < 1e-5, f"Floating/buried model: {target} minY={lo[1]}"
    if ".seed." in target.name:
        assert seed_symbol_depths and min(seed_symbol_depths) > 0, (
            f"Sowing symbol is not on USD +Z front: {target}")
    with zipfile.ZipFile(target) as package:
        assert package.testzip() is None
        assert all(m.compress_type == zipfile.ZIP_STORED for m in package.infolist())
    return dict(file=target.name, triangles=triangle_count, mesh_count=meshes,
                bound_materials=len(material_paths), diffuse_colors=sorted(colors),
                usd_up_axis="Y", meters_per_unit=1.0,
                usd_min_m=[round(v, 6) for v in lo],
                usd_max_m=[round(v, 6) for v in hi],
                width_height_depth_m=[round(hi[i] - lo[i], 6) for i in range(3)],
                ground_contact_verified=True, usd_front="+Z",
                packet_seed_symbol_min_front_z_m=(
                    round(min(seed_symbol_depths), 6) if seed_symbol_depths else None),
                bytes=target.stat().st_size)


def strict_check(target, checker):
    command = [checker, "--arkit", "--strict", str(target)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=90)
    return dict(command=command, exit_code=result.returncode,
                output=(result.stdout + result.stderr).strip(),
                passed=result.returncode == 0)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def text_label(text, location, size, rotation):
    bpy.ops.object.text_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = size
    obj.data.extrude = 0
    obj.data.materials.append(material("#594B3C"))


def preview(models, artifacts):
    """Render imported USDZs, not the pre-export Blender scene."""
    clear_scene()
    camera_pos, target = Vector((0, -6.0, 4.7)), Vector((0, 0.1, 0.15))
    camera_rotation = (target - camera_pos).to_track_quat("-Z", "Y").to_euler()
    for index, crop in enumerate(CROPS):
        col, row = index % 7, index // 7
        cx, cy = (col - 3) * 0.74, (0.5 - row) * 1.25
        for seed in (False, True):
            if seed and crop == "apple":
                continue
            name = f"model.item.{'seed.' if seed else ''}{crop}.usdz"
            bpy.ops.object.select_all(action="DESELECT")
            bpy.ops.wm.usd_import(filepath=str(models / name), import_materials=True)
            imported = list(bpy.context.selected_objects)
            for obj in imported:
                if obj.parent is None:
                    obj.location += Vector((cx + (0.18 if seed else -0.16), cy, 0.018))
        text_label(crop, (cx, cy - 0.36, 0.015), 0.085, camera_rotation)
    box("Preview plinth", "#EEE2C8", (0, 0, -0.035), (5.6, 3.1, 0.08), 0.03)
    bpy.ops.object.camera_add(location=camera_pos)
    camera = bpy.context.object
    camera.rotation_euler = camera_rotation
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 5.65
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 2100, 1250
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Warm preview studio")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.68, 0.74, 0.82, 1)
    background.inputs["Strength"].default_value = 0.55
    for name, position, power, size in (
        ("Warm key", (-3, -4, 6), 420, 5),
        ("Soft fill", (3, 0, 5), 260, 4),
    ):
        bpy.ops.object.light_add(type="AREA", location=position)
        light = bpy.context.object
        light.name = name
        light.data.energy, light.data.shape, light.data.size = power, "DISK", size
        light.rotation_euler = (-light.location).to_track_quat("-Z", "Y").to_euler()
    scene.view_settings.view_transform = "AgX"
    scene.render.filepath = str(artifacts / "crop-items-contact-sheet.png")
    bpy.ops.render.render(write_still=True)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def catalog_status(models):
    source = "13adab7:App/Resources/Content/items.json"
    content = subprocess.check_output(["git", "show", source], text=True)
    ids = [row["id"] for row in json.loads(content)["items"]]
    missing = [item_id for item_id in ids if not (models / f"model.{item_id}.usdz").is_file()]
    tracked = subprocess.check_output(
        ["git", "ls-files", "App/Resources/Models"], text=True).splitlines()
    changed = []
    for filename in tracked:
        path = Path(filename)
        original = subprocess.check_output(["git", "show", "HEAD:" + filename])
        if not path.is_file() or path.read_bytes() != original:
            changed.append(filename)
    return dict(catalog_source=source, expected_item_ids=ids, expected_count=len(ids),
                missing_item_ids=missing, covered_count=len(ids) - len(missing),
                tracked_asset_count=len(tracked), changed_tracked_assets=changed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[2]
    parser.add_argument("--models", type=Path, default=root / "App/Resources/Models")
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    args.models = args.models.resolve()
    args.artifacts = args.artifacts.resolve()
    checker = shutil.which("usdchecker")
    if not checker:
        raise RuntimeError("usdchecker is required for ARKit strict validation")
    targets = [(crop, seed, args.models / f"model.item.{'seed.' if seed else ''}{crop}.usdz")
               for crop in CROPS for seed in (False, True) if not (seed and crop == "apple")]
    existing = [str(path) for _, _, path in targets if path.exists()]
    if existing and not args.overwrite:
        raise FileExistsError("Refusing to overwrite: " + ", ".join(existing))
    target_paths = {path for _, _, path in targets}
    protected = {p: sha(p) for p in args.models.glob("*") if p.is_file() and p not in target_paths}
    args.models.mkdir(parents=True, exist_ok=True)
    args.artifacts.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    records = []
    for crop, seed, path in targets:
        clear_scene()
        obj = make_model(crop, seed)
        export_model(obj, path)
        record = verify(path)
        record.update(id=f"item.{'seed.' if seed else ''}{crop}",
                      arkit_strict=strict_check(path, checker), sha256=sha(path))
        records.append(record)
        print(f"ITEM {path.name}: {record['triangles']} triangles; "
              f"ARKit strict={record['arkit_strict']['passed']}", flush=True)
    unchanged = all(p.exists() and sha(p) == before for p, before in protected.items())
    report = dict(
        harvest_items=14, seed_packets=13, omitted_seed="apple (Doc 21)",
        triangle_budget=BUDGET, blender_up_axis="Z", usd_up_axis="Y",
        blender_front="-Y", usd_front="+Z",
        asymmetric_front_details="packet icons, open pea pod, corn kernels, sunflower disk, fruit markings",
        meters_per_unit=1.0, untouched_existing_assets=unchanged,
        protected_existing_file_count=len(protected), models=records,
        preview="crop-items-contact-sheet.png",
        limitations=[
            "Solid-color PBR felt/paper materials; no hand-painted texture atlas.",
            "Static meshes; no rig, animation, physics, or application manifest changes.",
            "ARKit strict validator checks format compatibility, not device rendering or child playtesting.",
            "Seed packets use raised crop silhouettes and a three-seed symbol, not text.",
        ],
        catalog_comparison=catalog_status(args.models),
    )
    (args.artifacts / "crop-items-verification.json").write_text(json.dumps(report, indent=2) + "\n")
    assert unchanged, "An existing non-target asset changed during generation"
    failed = [r["file"] for r in records if not r["arkit_strict"]["passed"]]
    if failed:
        raise RuntimeError("ARKit strict failed; see report: " + ", ".join(failed))
    preview(args.models, args.artifacts)
    print(f"COMPLETE {len(records)} models; max triangles "
          f"{max(r['triangles'] for r in records)}; protected {len(protected)} files")


if __name__ == "__main__":
    main()
