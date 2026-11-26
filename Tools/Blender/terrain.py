"""Build the stage-one island; run with Blender in background mode."""

from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "App" / "Resources" / "Models" / "model.terrain.island.usdz"


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.9
    return mat


def layer(name, dimensions, center_z, mat, radius):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, center_z))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Rounded edge", "BEVEL")
    bevel.width = radius
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    layer("Earth", (15.92, 11.92, 0.5), -0.37, material("earth", (0.32, 0.18, 0.09)), 0.16)
    layer("Upper earth", (15.96, 11.96, 0.18), -0.12, material("upper earth", (0.47, 0.28, 0.13)), 0.06)
    layer("Grass", (16, 12, 0.08), -0.04, material("grass", (0.39, 0.68, 0.23)), 0.035)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=str(OUTPUT),
        export_materials=True,
        generate_preview_surface=True,
        convert_orientation=True,
        export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z",
        meters_per_unit=1.0,
    )
    print(f"Exported {OUTPUT.name}")


if __name__ == "__main__":
    main()
