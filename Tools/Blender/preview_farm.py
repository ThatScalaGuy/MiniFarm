"""Render a preview from the exported USDZ assets, not their source meshes."""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "App" / "Resources" / "Models"


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.8
    return mat


def box(name, location, scale, mat, bevel=0.1):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    obj.data.materials.append(mat)
    return obj


def add_asset(filename, position, rotation=0):
    path = MODELS / filename
    if not path.is_file():
        raise FileNotFoundError(f"Missing preview asset: {path}")
    before = set(bpy.data.objects)
    bpy.ops.wm.usd_import(filepath=str(path), import_cameras=False, import_lights=False)
    imported = set(bpy.data.objects) - before
    roots = [obj for obj in imported if obj.parent not in imported]
    if not any(obj.type == "MESH" for obj in imported):
        raise ValueError(f"No mesh in preview asset: {path}")
    pivot = bpy.data.objects.new(f"preview.{path.stem}", None)
    bpy.context.scene.collection.objects.link(pivot)
    for obj in roots:
        world = obj.matrix_world.copy()
        obj.parent = pivot
        obj.matrix_world = world
    pivot.location = position
    pivot.rotation_euler.z = math.radians(rotation)


def point_at(obj, position):
    obj.rotation_euler = (Vector(position) - obj.location).to_track_quat("-Z", "Y").to_euler()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    soil = material("soil", (0.32, 0.16, 0.09))
    grass = material("grass", (0.39, 0.68, 0.23))
    path = material("path", (0.72, 0.56, 0.36))
    box("earth", (0, 0, -0.3), (10.4, 8.3, 0.6), soil, 0.28)
    box("grass", (0, 0, -0.02), (10.5, 8.4, 0.16), grass, 0.3)
    box("farm path", (0, -0.1, 0.08), (9.5, 1.1, 0.08), path, 0.22)
    box("farm path crossing", (0.2, 1.0, 0.125), (1.0, 4.0, 0.08), path, 0.22)

    assets = [
        ("model.loc.henhouse.usdz", (-3.0, 2.0, 0.1), -5),
        ("model.loc.shop.usdz", (2.8, 2.2, 0.1), 0),
        ("model.loc.plaza.usdz", (0, 2.4, 0.1), 0),
        ("model.loc.garden.usdz", (2.3, 0.6, 0.1), 0),
        ("model.animal.dog.usdz", (0.0, -1.6, 0.1), -135),
        ("model.animal.cat.usdz", (2.0, -1.6, 0.1), -135),
        ("model.animal.chicken.usdz", (-2.4, 0.4, 0.1), -135),
        ("model.animal.chicken.usdz", (-3.2, 0.0, 0.1), -155),
        ("model.crop.carrot.ripe.usdz", (2.0, 0.6, 0.42), 0),
        ("model.crop.lettuce.ripe.usdz", (2.3, 0.6, 0.42), 0),
        ("model.crop.radish.ripe.usdz", (2.6, 0.6, 0.42), 0),
    ]
    for filename, position, rotation in assets:
        add_asset(filename, position, rotation)

    bpy.ops.object.light_add(type="AREA", location=(1, -6, 12))
    key = bpy.context.object
    key.data.energy = 1800
    key.data.shape = "DISK"
    key.data.size = 9
    point_at(key, (0, 0, 0))
    bpy.ops.object.light_add(type="AREA", location=(-7, 1, 7))
    fill = bpy.context.object
    fill.data.energy = 650
    fill.data.size = 8
    point_at(fill, (0, 0, 0))

    bpy.ops.object.camera_add(location=(12, -16, 15))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 13.5
    point_at(camera, (0, 0, 0.5))
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.world.color = (0.7, 0.8, 0.85)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = args.output
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
