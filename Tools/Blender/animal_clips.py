"""Export independent, full-model USDZ animation variants.

Run with Blender in the background:
  blender --background --factory-startup --python Tools/Blender/animal_clips.py

These are complete Y-up, metre-scale models, not skeletal animation resources.
They do not overwrite model.animal.*.usdz or alter the existing loader. Each
variant contains one 2-second cycle; the consuming player must repeat it.
RealityKit playback of the exported transform samples requires device testing.
"""
import math
import sys
from pathlib import Path

import bpy

# Do not invoke animals.main(): the original models are intentionally untouched.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import animals


OUT = animals.OUT
CLIPS = {
    "dog": ("walk", "tailwag", "care"),
    "cat": ("walk", "nuzzle"),
    "chicken": ("walk", "eat"),
}
FACE_PARTS = {
    "Head", "Eye", "Eye_glint", "Muzzle", "Nose", "Smile", "Ear",
    "Ear_inner", "Whisker", "Beak", "Comb", "Wattle",
}


def parent_keep_world(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world


def empty(name, loc=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    bpy.context.view_layer.update()
    return obj


def walk(animal, meshes):
    """Alternating steps in place; one set of feet remains planted."""
    limb = "Foot" if animal == "chicken" else "Leg"
    legs = [o for o in meshes if o.name.split(".")[0] == limb]
    assert len(legs) == (2 if animal == "chicken" else 4)
    for obj in legs:
        start = obj.location.copy()
        group = (1 if start.x > 0 else -1)
        if animal != "chicken":
            group *= 1 if start.y > 0 else -1
        for frame, phase in ((1, 0), (13, 1), (25, 0), (37, -1), (49, 0)):
            active = group * phase
            obj.location = start
            if active == 1:
                obj.location.y -= 0.045 if animal != "chicken" else 0.035
                obj.location.z += 0.025 if animal != "chicken" else 0.018
            elif active == -1:
                obj.location.y += 0.025
            obj.keyframe_insert(data_path="location", frame=frame, group="Walk")


def interaction(animal, meshes):
    if animal == "dog":
        pivot = empty("Tailwag", (0, 0.40, 0.41))
        parts = [o for o in meshes if o.name.split(".")[0] == "Tail"]
        keys = ((1, (0, 0, 0)), (13, (0, 0, 0.28)), (25, (0, 0, 0)),
                (37, (0, 0, -0.28)), (49, (0, 0, 0)))
    elif animal == "cat":
        pivot = empty("Nuzzle", (0, -0.17, 0.46))
        parts = [o for o in meshes if o.name.split(".")[0] in FACE_PARTS]
        keys = ((1, (0, 0, 0)), (13, (0.08, 0, 0.12)), (25, (0, 0, 0)),
                (37, (0.08, 0, -0.12)), (49, (0, 0, 0)))
    else:
        pivot = empty("Eat", (0, -0.10, 0.39))
        parts = [o for o in meshes if o.name.split(".")[0] in FACE_PARTS]
        keys = ((1, (0, 0, 0)), (13, (0.75, 0, 0)), (25, (0, 0, 0)),
                (37, (0.75, 0, 0)), (49, (0, 0, 0)))
    assert parts
    for obj in parts:
        parent_keep_world(obj, pivot)
    for frame, rotation in keys:
        pivot.rotation_euler = rotation
        pivot.keyframe_insert(data_path="rotation_euler", frame=frame, group=pivot.name)
        if animal == "chicken":
            pivot.location.y = -0.14 if frame in (13, 37) else -0.10
            pivot.location.z = 0.24 if frame in (13, 37) else 0.39
            pivot.keyframe_insert(data_path="location", frame=frame, group=pivot.name)
    return pivot


def care(meshes):
    """A rounded brush strokes Pelle's head; the brush belongs to this clip."""
    brush = empty("Brush")
    parts = [
        animals.ell("Brush_back", (0, -0.27, 0.98), (0.12, 0.07, 0.045), "tan"),
        animals.ell("Brush_bristles", (0, -0.27, 0.925), (0.10, 0.055, 0.025), "cream"),
        animals.link("Brush_handle", (0.09, -0.27, 0.98), (0.24, -0.27, 1.08), 0.035, "tan"),
    ]
    bpy.context.view_layer.update()
    for obj in parts:
        parent_keep_world(obj, brush)
    meshes.extend(parts)
    for frame, x in ((1, 0), (13, 0.08), (25, 0), (37, -0.08), (49, 0)):
        brush.location.x = x
        brush.keyframe_insert(data_path="location", frame=frame, group="Care")
    return brush


def export(animal, clip):
    animals.clear()
    bpy.context.scene.frame_set(1)
    meshes = animals.build(animal)
    motion = None
    if clip == "walk":
        walk(animal, meshes)
    elif clip == "care":
        motion = care(meshes)
    else:
        if clip == "eat":
            for x, y in ((-0.05, -0.43), (0.02, -0.46), (0.08, -0.41)):
                meshes.append(animals.ell("Grain", (x, y, 0.018), (0.035, 0.045, 0.018), "yellow"))
        motion = interaction(animal, meshes)
    bpy.context.scene.frame_set(1)
    facing = empty("Facing")
    for obj in meshes:
        if obj.parent is None:
            parent_keep_world(obj, facing)
    if motion:
        parent_keep_world(motion, facing)
    facing.rotation_euler.z = math.pi
    bpy.context.view_layer.update()
    path = OUT / f"anim.animal.{animal}.{clip}.usdz"
    bpy.ops.wm.usd_export(
        filepath=str(path), export_animation=True, export_materials=True,
        generate_preview_surface=True, export_cameras=False, export_lights=False,
        convert_orientation=True, export_global_up_selection="Y",
        export_global_forward_selection="NEGATIVE_Z",
        convert_scene_units="METERS", meters_per_unit=1.0,
    )
    print("CLIP", path, flush=True)


def main():
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = 1, 49
    OUT.mkdir(parents=True, exist_ok=True)
    for animal, clips in CLIPS.items():
        for clip in clips:
            export(animal, clip)


if __name__ == "__main__":
    main()
