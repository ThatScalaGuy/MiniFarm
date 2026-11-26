"""Generate individual MiniFarm USDZ assets in a fresh background Blender.

Run from the repository root:
  blender -b --factory-startup \
      --python Tools/Blender/environment.py -- --arkit-check \
      --preview /absolute/path/preview.png

The optional preview is a separate, non-exported scene. Coordinates are meters,
Z-up; Z=0 is at the lowest geometry. Exports are Y-up, in meters.
"""
import argparse
import math
import os
import shutil
import subprocess
import sys
import zipfile
from mathutils import Vector
import bpy
from pxr import Usd, UsdGeom, UsdShade

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "App/Resources/Models")


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1


def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.78
    return mat


COLORS = {
    "wood": (0.55, 0.30, 0.15), "lightwood": (0.73, 0.48, 0.27),
    "cream": (0.93, 0.85, 0.67), "white": (0.97, 0.92, 0.79),
    "red": (0.70, 0.25, 0.17), "roof": (0.63, 0.24, 0.15),
    "soil": (0.28, 0.15, 0.08), "green": (0.34, 0.57, 0.21),
    "leaf": (0.42, 0.66, 0.28), "darkgreen": (0.25, 0.45, 0.18),
    "blue": (0.27, 0.59, 0.67), "water": (0.30, 0.65, 0.72),
    "metal": (0.52, 0.59, 0.56), "dark": (0.19, 0.20, 0.17),
    "yellow": (0.94, 0.68, 0.24), "stone": (0.69, 0.66, 0.56),
    "pink": (0.91, 0.58, 0.53),
}


def assign(obj, name, mat):
    obj.name = name
    obj.data.materials.append(material(mat, COLORS[mat]))
    return obj


def box(name, loc, size, mat, bevel=0.035, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    if bevel:
        mod = obj.modifiers.new("Soft toy edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.affect = "EDGES"
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return assign(obj, name, mat)


def sphere(name, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return assign(obj, name, mat)


def cylinder(name, loc, radius, depth, mat, vertices=16, rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if rot:
        obj.rotation_euler = rot
    bevel = obj.modifiers.new("Soft rim", "BEVEL")
    bevel.width = min(0.025, radius * 0.2, depth * 0.1)
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return assign(obj, name, mat)


def beam(name, a, b, radius, mat):
    a, b = Vector(a), Vector(b)
    obj = cylinder(name, (a + b) / 2, radius, (b - a).length, mat, 12)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def ring(name, loc, major, minor, mat, rot=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
                                     location=loc, major_radius=major, minor_radius=minor)
    obj = bpy.context.object
    if rot:
        obj.rotation_euler = rot
    return assign(obj, name, mat)


def roof(width, depth, wall_top, rise, mat="roof"):
    # Separate named roof panels allow a host to implement cutaway.
    half = width / 2
    length = math.hypot(half, rise)
    angle = math.atan2(rise, half)
    for sign in (-1, 1):
        box("Roof_panel", (sign * half / 2, 0, wall_top + rise / 2),
            (length + .12, depth + .2, .12), mat, .035, (0, sign * angle, 0))
    beam("Ridge", (0, -depth/2-.08, wall_top+rise+.03),
         (0, depth/2+.08, wall_top+rise+.03), .045, "lightwood")


def building(width=1.65, depth=1.35, height=1.3, wall="cream"):
    box("Foundation", (0, 0, .08), (width+.08, depth+.08, .16), "stone")
    box("Walls", (0, 0, .16+height/2), (width, depth, height), wall)
    for x in (-width/2+.06, width/2-.06):
        box("Corner_trim", (x, -depth/2-.015, .16+height/2), (.10, .08, height), "lightwood")
    roof(width+.12, depth+.12, .16+height, .48)
    box("Door_frame", (0, -depth/2-.035, .56), (.57, .10, .82), "lightwood")
    box("Door", (0, -depth/2-.095, .56), (.44, .04, .69), "wood")
    sphere("Door_knob", (.14, -depth/2-.13, .57), (.035, .035, .035), "yellow")
    for x in (-.58, .58):
        if abs(x) < width/2-.12:
            box("Window_frame", (x, -depth/2-.04, 1.03), (.31, .06, .33), "white")
            box("Window", (x, -depth/2-.08, 1.03), (.23, .04, .25), "blue")
            box("Window_bar", (x, -depth/2-.105, 1.03), (.035, .025, .25), "white")


def henhouse():
    building(1.7, 1.35, 1.2, "cream")
    box("Hen_door_frame", (.48, -.72, .35), (.36, .12, .48), "lightwood")
    box("Hen_door", (.48, -.79, .35), (.25, .035, .37), "dark")
    box("Ramp", (.48, -1.02, .10), (.34, .55, .07), "lightwood", rot=(.25, 0, 0))
    for y in (-.91, -1.04, -1.17):
        box("Ramp_rung", (.48, y, .15), (.29, .035, .03), "wood")
    box("Nest_box", (-.96, .12, .48), (.35, .63, .37), "lightwood")
    box("Nest_lid", (-.96, .12, .70), (.43, .70, .10), "roof")


def shop(include_produce=True):
    for x in (-.75, .75):
        for y in (-.45, .45):
            box("Stand_post", (x, y, .83), (.11, .11, 1.66), "wood")
    box("Counter", (0, 0, .80), (1.72, 1.05, .16), "lightwood")
    box("Counter_front", (0, -.45, .44), (1.53, .10, .65), "cream")
    for x in (-.56, 0, .56):
        box("Counter_plank", (x, -.51, .44), (.04, .035, .58), "lightwood")
    # Strong red/cream stripes identify the level-one market stand.
    for i in range(6):
        box("Awning_stripe", (-.72+i*.288, 0, 1.71), (.29, 1.20, .09),
            "red" if i % 2 == 0 else "white", rot=(.12, 0, 0))
    box("Shelf", (0, .33, 1.09), (1.34, .20, .07), "wood")
    for x in (-.40, 0, .40):
        box("Produce_crate", (x, .25, 1.18), (.30, .24, .12), "lightwood")
        if include_produce:
            sphere("Produce", (x, .24, 1.27), (.085, .08, .07), "red" if x else "green")


def garden():
    box("Soil", (0, 0, .16), (.86, .86, .27), "soil")
    for x in (-.46, .46):
        box("Bed_side", (x, 0, .18), (.09, 1, .32), "lightwood")
    for y in (-.46, .46):
        box("Bed_end", (0, y, .18), (1, .09, .32), "wood")
    for y in (-.24, 0, .24):
        box("Soil_row", (0, y, .31), (.73, .08, .035), "wood", .015)


def tree(x, y, scale=1):
    cylinder("Tree_trunk", (x, y, .55*scale), .13*scale, 1.10*scale, "wood")
    for dx, dy, z, s, m in [(-.30, 0, 1.25, .46, "green"), (.27, .02, 1.28, .48, "leaf"),
                            (0, -.23, 1.48, .48, "leaf"), (0, .16, 1.60, .46, "green")]:
        sphere("Tree_canopy", (x+dx*scale, y+dy*scale, z*scale), (s*scale, s*scale, s*.86*scale), m)


def well(x, y):
    cylinder("Well_base", (x, y, .09), .42, .18, "stone")
    cylinder("Well_wall", (x, y, .31), .36, .42, "stone")
    cylinder("Well_water", (x, y, .53), .28, .025, "water")
    ring("Well_rim", (x, y, .54), .32, .055, "cream")
    for dx in (-.34, .34):
        box("Well_post", (x+dx, y, .89), (.09, .09, 1.16), "wood")
    box("Well_roof", (x, y, 1.47), (.95, .53, .11), "roof")
    beam("Well_spindle", (x-.34, y, .96), (x+.34, y, .96), .045, "lightwood")
    beam("Well_rope", (x, y, .96), (x, y, .66), .012, "cream")


def plaza():
    box("Plaza_paving", (0, 0, .06), (2.8, 1.9, .12), "stone")
    tree(-.72, .07, .90)
    well(.72, -.05)
    box("Mailbox_post", (.95, .65, .42), (.09, .09, .72), "wood")
    box("Mailbox", (.95, .65, .84), (.35, .27, .24), "red", .06)


def can():
    cylinder("Can_body", (0, 0, .27), .23, .48, "blue")
    ring("Can_rim", (0, 0, .52), .20, .035, "metal")
    beam("Spout", (.15, 0, .24), (.52, 0, .43), .07, "blue")
    cylinder("Rose", (.55, 0, .45), .11, .08, "metal", rot=(0, math.pi/2-.3, 0))
    ring("Handle", (0, 0, .52), .27, .035, "blue", (math.pi/2, 0, 0))


def basket():
    cylinder("Basket_body", (0, 0, .19), .28, .35, "lightwood", 12)
    cylinder("Basket_inner", (0, 0, .37), .235, .025, "soil", 12)
    ring("Basket_rim", (0, 0, .38), .26, .035, "wood")
    ring("Basket_handle", (0, 0, .39), .27, .028, "wood", (math.pi/2, 0, 0))
    for z in (.10, .20, .30):
        ring("Basket_weave", (0, 0, z), .28, .012, "wood")


def egg():
    # Wider at the base, narrower at the top.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(0, 0, .16))
    obj = bpy.context.object
    for v in obj.data.vertices:
        z = v.co.z
        v.co.x *= .115 * (1 - .20*z)
        v.co.y *= .115 * (1 - .20*z)
        v.co.z *= .16
    for p in obj.data.polygons:
        p.use_smooth = True
    assign(obj, "Egg", "white")


def garage():
    building(2.2, 1.7, 1.5, "lightwood")
    box("Garage_opening_frame", (0, -.89, .72), (1.18, .10, 1.15), "cream")
    box("Garage_door", (0, -.95, .72), (1.00, .045, 1.02), "wood")
    for z in (.35, .60, .85, 1.10):
        box("Door_plank", (0, -.98, z), (.95, .025, .025), "lightwood")


def cowbarn():
    building(2.0, 1.6, 1.4, "red")
    box("Barn_door_cross_a", (0, -.91, .55), (.06, .035, .70), "white", rot=(0, -.5, 0))
    box("Barn_door_cross_b", (0, -.92, .55), (.06, .035, .70), "white", rot=(0, .5, 0))


def greenhouse():
    box("Greenhouse_base", (0, 0, .08), (1.85, 1.4, .16), "stone")
    box("Greenhouse_body", (0, 0, .69), (1.65, 1.2, 1.12), "blue")
    for x in (-.8, 0, .8):
        box("Glazing_frame", (x, -.63, .73), (.07, .06, 1.10), "cream")
    box("Door", (0, -.67, .56), (.43, .07, .83), "lightwood")
    roof(1.78, 1.32, 1.25, .48, "green")


def pond():
    cylinder("Pond_edge", (0, 0, .06), .95, .12, "green", 32)
    cylinder("Pond_water", (0, 0, .12), .82, .025, "water", 32)
    for x, y in ((-.35, -.15), (.24, .31), (.46, -.28)):
        cylinder("Lily_pad", (x, y, .15), .15, .025, "leaf")
        sphere("Lily_flower", (x, y, .18), (.07, .07, .05), "pink")


def tractor():
    box("Chassis", (0, 0, .34), (1.4, .70, .20), "dark")
    box("Hood", (-.36, 0, .64), (.72, .66, .52), "red", .09)
    box("Cab", (.39, 0, .88), (.52, .60, .84), "blue", .06)
    box("Cab_roof", (.39, 0, 1.34), (.67, .73, .12), "cream")
    for x, r in ((-.46, .24), (.43, .33)):
        for y in (-.45, .45):
            cylinder("Wheel", (x, y, r), r, .18, "dark", 24, (math.pi/2, 0, 0))
            cylinder("Hub", (x, y+(-.10 if y < 0 else .10), r), r*.42, .025, "cream", 20, (math.pi/2, 0, 0))
    cylinder("Exhaust", (-.49, .19, 1.02), .045, .48, "dark")
    for y in (-.22, .22):
        sphere("Headlight", (-.74, y, .63), (.04, .07, .07), "yellow")


def place(build, x, y, z=0):
    before = set(bpy.context.scene.objects)
    build()
    for obj in set(bpy.context.scene.objects) - before:
        obj.location += Vector((x, y, z))


def field():
    box("Field", (0, 0, .08), (4, 4, .16), "soil")
    for y in (-1.6, -1.2, -.8, -.4, 0, .4, .8, 1.2, 1.6):
        box("Furrow", (0, y, .17), (3.85, .16, .08), "wood", .035)


def fence(width, depth):
    for x in (-width/2, width/2):
        for y in (-depth/2, depth/2):
            box("Fence_post", (x, y, .38), (.12, .12, .76), "wood")
        for z in (.29, .57):
            box("Fence_rail", (x, 0, z), (.08, depth, .09), "lightwood")
    for y in (-depth/2, depth/2):
        for z in (.29, .57):
            box("Fence_rail", (0, y, z), (width, .08, .09), "lightwood")


def sheepmeadow():
    box("Meadow", (0, 0, .06), (2.5, 2, .12), "green")
    fence(2.34, 1.84)
    box("Sheep_shelter", (.52, .33, .39), (.75, .65, .66), "cream")
    box("Shelter_opening", (.52, -.01, .35), (.36, .05, .45), "wood")
    box("Shelter_roof", (.52, .33, .75), (.90, .78, .12), "roof")
    box("Feed_trough", (-.52, -.2, .22), (.65, .30, .30), "lightwood")


def pigsty():
    box("Ground", (0, 0, .06), (2.4, 2, .12), "green")
    fence(2.24, 1.84)
    box("Pig_shelter", (.55, .28, .42), (.82, .72, .72), "lightwood")
    box("Pig_door", (.55, -.10, .33), (.39, .05, .44), "wood")
    box("Pig_roof", (.55, .28, .81), (.95, .85, .12), "roof")
    cylinder("Mud_puddle", (-.47, -.16, .13), .49, .03, "soil", 24)
    box("Trough", (-.47, .54, .23), (.65, .26, .24), "wood")


def orchard():
    box("Orchard_ground", (0, 0, .06), (3.2, 3.2, .12), "green")
    for x in (-.75, .75):
        for y in (-.75, .75):
            tree(x, y, .72)
            for dx, dy, z in ((-.17, -.20, 1.15), (.25, -.05, 1.02), (.04, .20, 1.22)):
                sphere("Apple", (x+dx, y+dy, z), (.07, .07, .07), "red")


def kitchen():
    building(2, 1.65, 1.42, "cream")
    box("Chimney", (.52, .25, 1.95), (.27, .29, .82), "stone")
    box("Chimney_cap", (.52, .25, 2.37), (.36, .38, .10), "roof")
    box("Oven_front", (-.61, -.89, .40), (.54, .12, .50), "stone")
    box("Oven_door", (-.61, -.97, .40), (.34, .05, .30), "dark")
    box("Kitchen_sign", (.52, -.88, 1.30), (.48, .07, .22), "yellow")


def goatpen():
    box("Ground", (0, 0, .06), (2.4, 2, .12), "green")
    fence(2.24, 1.84)
    for x, y, scale in ((-.45, -.1, .52), (.15, .12, .60), (.54, .42, .38)):
        sphere("Climbing_rock", (x, y, .12), (scale, scale*.8, scale*.65), "stone")
    box("Goat_shelter", (-.65, .49, .43), (.65, .55, .65), "lightwood")
    box("Shelter_roof", (-.65, .49, .78), (.78, .66, .10), "roof")


def paddock():
    box("Paddock_ground", (0, 0, .06), (2.8, 2.4, .12), "green")
    fence(2.64, 2.24)
    box("Horse_shelter", (.68, .48, .58), (1.05, .85, .95), "lightwood")
    box("Shelter_opening", (.68, .03, .48), (.58, .05, .67), "wood")
    box("Shelter_roof", (.68, .48, 1.08), (1.2, .98, .12), "roof")
    box("Rabbit_hutch", (-.65, .52, .38), (.75, .55, .52), "cream")
    box("Hutch_roof", (-.65, .52, .67), (.86, .65, .10), "wood")


def apiary():
    box("Apiary_ground", (0, 0, .06), (2, 1.7, .12), "green")
    for x in (-.45, .45):
        box("Hive_base", (x, 0, .18), (.58, .52, .12), "wood")
        box("Beehive", (x, 0, .54), (.50, .46, .65), "yellow")
        for z in (.36, .52, .68):
            box("Hive_band", (x, -.24, z), (.48, .025, .04), "wood")
        box("Hive_entrance", (x, -.25, .35), (.20, .04, .07), "dark")
        box("Hive_roof", (x, 0, .92), (.64, .58, .13), "roof")
    for x, y in ((-.75, -.55), (0, -.62), (.72, .50)):
        cylinder("Flower_stem", (x, y, .22), .025, .22, "darkgreen")
        sphere("Flower", (x, y, .35), (.11, .11, .07), "pink")


def village():
    box("Village_square", (0, 0, .06), (5, 4, .12), "stone")
    for x in (-1.35, 1.35):
        for y in (-1.05, 1.05):
            place(lambda: shop(include_produce=False), x, y, .12)


def wheel(x, y, radius):
    cylinder("Wheel", (x, y, radius), radius, .18, "dark", 24, (math.pi/2, 0, 0))
    cylinder("Wheel_hub", (x, y+(-.10 if y < 0 else .10), radius),
             radius*.43, .025, "cream", 20, (math.pi/2, 0, 0))


def hitch():
    beam("Hitch", (-.72, 0, .27), (-1.14, 0, .25), .055, "metal")
    ring("Hitch_eye", (-1.18, 0, .25), .08, .025, "metal")


def trailer():
    box("Trailer_frame", (0, 0, .32), (1.45, .83, .15), "dark")
    box("Trailer_floor", (0, 0, .48), (1.38, .84, .12), "lightwood")
    for y in (-.40, .40):
        box("Trailer_side", (0, y, .77), (1.42, .10, .55), "red")
    for x in (-.66, .66):
        box("Trailer_end", (x, 0, .77), (.10, .78, .55), "red")
    for y in (-.50, .50):
        wheel(.18, y, .25)
    hitch()


def watertank():
    box("Tank_frame", (0, 0, .32), (1.34, .70, .14), "dark")
    cylinder("Water_tank", (0, 0, .73), .43, 1.20, "blue", 24, (0, math.pi/2, 0))
    for x in (-.36, .36):
        ring("Tank_band", (x, 0, .73), .43, .025, "metal", (0, math.pi/2, 0))
    cylinder("Tank_cap", (0, 0, 1.17), .12, .06, "cream")
    for y in (-.45, .45):
        wheel(.24, y, .23)
    hitch()


def plow():
    box("Plow_frame", (0, 0, .55), (1.35, .65, .11), "red")
    hitch()
    for x in (-.4, 0, .4):
        beam("Plow_shank", (x, 0, .53), (x+.12, 0, .19), .055, "metal")
        box("Plow_share", (x+.12, 0, .16), (.38, .36, .10), "metal", .04, (0, 0, .35))


def seeder():
    box("Seeder_frame", (0, 0, .32), (1.20, 1.15, .12), "dark")
    box("Seed_hopper", (0, 0, .70), (.75, 1.10, .60), "yellow", .06)
    box("Hopper_lid", (0, 0, 1.02), (.84, 1.19, .10), "red")
    for y in (-.42, -.14, .14, .42):
        beam("Seed_tube", (.25, y, .46), (.38, y, .10), .035, "metal")
    for y in (-.67, .67):
        wheel(.25, y, .22)
    hitch()


def mower():
    box("Mower_body", (0, 0, .31), (1.0, 1.35, .32), "red", .08)
    box("Mower_top", (0, 0, .50), (.65, 1.12, .10), "cream")
    for y in (-.42, 0, .42):
        cylinder("Mower_disc", (.20, y, .13), .19, .08, "metal")
    hitch()


def baler():
    box("Baler_frame", (0, 0, .34), (1.48, .9, .18), "dark")
    box("Baler_body", (.1, 0, .76), (1.12, .86, .78), "yellow", .08)
    box("Bale_exit", (.70, 0, .63), (.20, .62, .52), "wood")
    cylinder("Pickup_reel", (-.52, 0, .28), .20, 1.06, "red", 20, (math.pi/2, 0, 0))
    for y in (-.53, .53):
        wheel(.30, y, .27)
    hitch()


def loader():
    for y in (-.32, .32):
        beam("Loader_arm", (.45, y, .33), (-.34, y, 1.03), .075, "yellow")
        beam("Loader_lift", (.30, y, .36), (-.14, y, .82), .035, "metal")
    box("Loader_bucket", (-.59, 0, 1.00), (.52, .94, .30), "yellow")
    box("Bucket_lip", (-.86, 0, .88), (.08, .96, .07), "metal")
    box("Mount", (.45, 0, .28), (.25, .80, .20), "dark")


def potatodigger():
    box("Digger_frame", (0, 0, .42), (1.30, .95, .16), "red")
    box("Digging_blade", (-.39, 0, .14), (.48, .90, .10), "metal", .05)
    for y in (-.35, -.18, 0, .18, .35):
        beam("Sifting_bar", (-.20, y, .19), (.55, y, .39), .025, "metal")
    for y in (-.58, .58):
        wheel(.36, y, .22)
    hitch()


def snowplow():
    box("Snow_blade", (-.20, 0, .42), (.18, 1.45, .68), "yellow", .08, (0, -.20, 0))
    box("Blade_lower_edge", (-.29, 0, .10), (.10, 1.43, .09), "metal")
    beam("Mount_left", (.55, -.32, .25), (-.08, -.48, .40), .06, "dark")
    beam("Mount_right", (.55, .32, .25), (-.08, .48, .40), .06, "dark")
    box("Mount", (.58, 0, .30), (.18, .80, .25), "dark")


def combine():
    box("Combine_chassis", (.12, 0, .47), (1.80, .90, .25), "dark")
    box("Combine_body", (.30, 0, 1.00), (1.40, 1.00, .93), "yellow", .10)
    box("Cab", (-.46, 0, 1.25), (.55, .80, .70), "blue", .07)
    box("Cab_roof", (-.46, 0, 1.64), (.68, .91, .12), "cream")
    for x, r in ((-.48, .36), (.65, .27)):
        for y in (-.58, .58):
            wheel(x, y, r)
    box("Header", (-1.12, 0, .31), (.50, 1.65, .28), "red")
    cylinder("Reel", (-1.17, 0, .56), .21, 1.50, "yellow", 20, (math.pi/2, 0, 0))
    for y in (-.6, -.3, 0, .3, .6):
        box("Reel_paddle", (-1.17, y, .56), (.10, .06, .48), "wood")
    beam("Unloading_pipe", (.45, .35, 1.44), (.60, .95, 1.55), .075, "yellow")


def carriage():
    box("Carriage_frame", (0, 0, .40), (1.52, .80, .16), "wood")
    box("Carriage_body", (.18, 0, .72), (1.02, .78, .54), "red")
    box("Seat", (-.42, 0, .82), (.35, .74, .22), "cream")
    box("Carriage_roof", (.18, 0, 1.36), (1.12, .88, .14), "cream")
    for x in (-.28, .64):
        for y in (-.32, .32):
            box("Canopy_post", (x, y, 1.10), (.06, .06, .48), "wood")
    for x in (-.48, .55):
        for y in (-.49, .49):
            wheel(x, y, .30)
    for y in (-.29, .29):
        beam("Carriage_shaft", (-.65, y, .38), (-1.55, y, .37), .045, "wood")


def bucket():
    cylinder("Bucket", (0, 0, .25), .25, .46, "metal")
    cylinder("Bucket_inside", (0, 0, .49), .21, .02, "dark")
    ring("Bucket_rim", (0, 0, .50), .23, .03, "cream")
    ring("Bucket_handle", (0, 0, .50), .25, .025, "metal", (math.pi/2, 0, 0))


def brush():
    box("Brush_body", (0, 0, .19), (.52, .29, .14), "lightwood", .06)
    box("Bristles", (0, 0, .08), (.45, .22, .14), "cream", .04)
    box("Brush_grip", (0, 0, .29), (.25, .16, .10), "wood", .05)


def shears():
    for y, angle in ((-.10, -.18), (.10, .18)):
        ring("Shear_handle", (-.20, y, .06), .105, .035, "red")
        box("Shear_blade", (.12, y*.45, .06), (.50, .075, .07), "metal", .035,
            (0, 0, angle))
    cylinder("Pivot", (-.02, 0, .105), .045, .05, "yellow")


def feed():
    box("Feed_sack", (0, 0, .31), (.55, .42, .57), "cream", .09)
    box("Sack_fold", (0, 0, .60), (.48, .39, .08), "lightwood")
    box("Feed_label", (0, -.22, .35), (.29, .03, .22), "yellow")
    for x in (-.08, 0, .08):
        sphere("Grain_symbol", (x, -.245, .35), (.025, .02, .05), "wood")


def hay():
    box("Hay_bale", (0, 0, .23), (.84, .54, .46), "yellow", .07)
    for x in (-.22, .22):
        box("Bale_tie_top", (x, 0, .47), (.035, .55, .025), "wood")
        for y in (-.27, .27):
            box("Bale_tie_side", (x, y, .23), (.035, .025, .46), "wood")


ASSETS = {
    "loc.henhouse": henhouse, "loc.shop": shop, "loc.garden": garden,
    "loc.plaza": plaza, "tool.can": can, "tool.basket": basket, "item.egg": egg,
    "loc.garage": garage, "loc.cowbarn": cowbarn, "loc.greenhouse": greenhouse,
    "loc.pond": pond, "veh.tractor": tractor,
    "loc.field": field, "loc.sheepmeadow": sheepmeadow, "loc.pigsty": pigsty,
    "loc.orchard": orchard, "loc.kitchen": kitchen, "loc.goatpen": goatpen,
    "loc.paddock": paddock, "loc.apiary": apiary, "loc.village": village,
    "veh.combine": combine, "veh.carriage": carriage,
    "imp.plow": plow, "imp.seeder": seeder, "imp.trailer": trailer,
    "imp.watertank": watertank, "imp.mower": mower, "imp.baler": baler,
    "imp.loader": loader, "imp.potatodigger": potatodigger, "imp.snowplow": snowplow,
    "tool.bucket": bucket, "tool.brush": brush, "tool.shears": shears,
    "item.feed": feed, "item.hay": hay,
}
ORIGINAL_IDS = {
    "loc.henhouse", "loc.shop", "loc.garden", "loc.plaza", "tool.can",
    "tool.basket", "item.egg", "loc.garage", "loc.cowbarn",
    "loc.greenhouse", "loc.pond", "veh.tractor",
}


def bounds():
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for obj in bpy.context.scene.objects
              if obj.type == "MESH" for corner in obj.bound_box]
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def export_assets(asset_ids):
    os.makedirs(OUT, exist_ok=True)
    for asset_id in asset_ids:
        reset()
        ASSETS[asset_id]()
        low, high = bounds()
        # Generated shapes may extend slightly below ground due to bevel/handles.
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                obj.location.z -= low[2]
        bpy.context.view_layer.update()
        low, high = bounds()
        path = os.path.join(OUT, "model." + asset_id + ".usdz")
        bpy.ops.wm.usd_export(filepath=path, selected_objects_only=False,
                              export_animation=False, export_materials=True,
                              generate_preview_surface=True, export_textures_mode="NEW",
                              convert_orientation=True, export_global_up_selection="Y",
                              export_global_forward_selection="NEGATIVE_Z",
                              meters_per_unit=1.0)
        if not zipfile.is_zipfile(path):
            raise RuntimeError("Not a USDZ archive: " + path)
        with zipfile.ZipFile(path) as archive:
            if not any(n.endswith((".usd", ".usdc", ".usda")) for n in archive.namelist()):
                raise RuntimeError("USDZ has no USD layer: " + path)
            if any(info.compress_type != zipfile.ZIP_STORED for info in archive.infolist()):
                raise RuntimeError("USDZ contains compressed entries: " + path)
        print("EXPORTED", asset_id, "dimensions_m", *(round(high[i]-low[i], 3) for i in range(3)), flush=True)


def verify_assets(asset_ids, arkit_check=False):
    # Inspect the packaged USD stage, not just the source Blender scene.
    checker = shutil.which("usdchecker") if arkit_check else None
    if arkit_check and not checker:
        raise RuntimeError("usdchecker is required for --arkit-check")
    for asset_id in asset_ids:
        path = os.path.join(OUT, "model." + asset_id + ".usdz")
        stage = Usd.Stage.Open(path)
        if not stage:
            raise RuntimeError("Cannot open USD stage: " + asset_id)
        up = UsdGeom.GetStageUpAxis(stage)
        meters = UsdGeom.GetStageMetersPerUnit(stage)
        if up != UsdGeom.Tokens.y or abs(meters - 1.0) > 1e-6:
            raise RuntimeError("Wrong USD axis/scale: " + asset_id)
        meshes = [p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
        if not meshes:
            raise RuntimeError("Missing USD meshes: " + asset_id)
        materials = set()
        triangles = 0
        for mesh in meshes:
            geom = UsdGeom.Mesh(mesh)
            binding, _ = UsdShade.MaterialBindingAPI(mesh).ComputeBoundMaterial()
            if not geom.GetPointsAttr().Get() or not geom.GetFaceVertexCountsAttr().Get() or not binding:
                raise RuntimeError("Missing mesh geometry or material in " + asset_id)
            materials.add(str(binding.GetPath()))
            triangles += sum(max(0, n-2) for n in geom.GetFaceVertexCountsAttr().Get())
        bbox = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_]).ComputeWorldBound(
            stage.GetPseudoRoot()).ComputeAlignedRange()
        minimum, maximum = bbox.GetMin(), bbox.GetMax()
        if abs(minimum[1]) > 1e-4:
            raise RuntimeError("USD ground is not Y=0 in " + asset_id + ": " + str(minimum))
        if not materials:
            raise RuntimeError("Missing mesh geometry or material in " + asset_id)
        if any(attr.GetNumTimeSamples() for prim in stage.Traverse() for attr in prim.GetAttributes()):
            raise RuntimeError("Unexpected time samples in static asset: " + asset_id)
        if checker:
            result = subprocess.run([checker, "--arkit", "--strict", path],
                                    text=True, capture_output=True)
            if result.returncode:
                raise RuntimeError("ARKit validation failed for " + asset_id + ":\n" +
                                   result.stdout + result.stderr)
        print("VERIFIED", asset_id, "meshes", len(meshes), "materials", len(materials),
              "triangles", triangles, "arkit", "passed" if checker else "not checked",
              "up", up, "meters_per_unit", meters, "USD_min", tuple(round(v, 4) for v in minimum),
              "USD_dimensions", tuple(round(maximum[i]-minimum[i], 4) for i in range(3)), flush=True)


def preview(path, expanded=False):
    reset()
    if expanded:
        layout = ((sheepmeadow, -3.2, 1.8), (apiary, -.25, 1.8), (pigsty, 2.6, 1.8),
                  (combine, -3.0, -1.4), (carriage, -.1, -1.4), (trailer, 2.5, -1.4),
                  (bucket, -1.7, -3.0), (feed, -.7, -3.0), (hay, .4, -3.0),
                  (brush, 1.45, -3.0))
    else:
        layout = ((henhouse, -2.0, .85), (shop, .1, .85), (plaza, 2.6, .9),
                  (garden, -2.1, -1.65), (can, -.9, -1.65),
                  (basket, .1, -1.65), (egg, .95, -1.65), (tractor, 2.2, -1.65))
    for build, x, y in layout:
        before = set(bpy.context.scene.objects)
        build()
        added = set(bpy.context.scene.objects) - before
        bpy.context.view_layer.update()
        low = min((o.matrix_world @ Vector(c))[2] for o in added for c in o.bound_box)
        for obj in added:
            obj.location.x += x
            obj.location.y += y
            obj.location.z -= low
    box("Studio_ground", (0, 0, -.14), (11, 8, .2) if expanded else (9, 6, .2), "cream")
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.world.color = (.35, .35, .35)
    bpy.ops.object.light_add(type="AREA", location=(-3, -4, 8))
    bpy.context.object.data.energy = 1200
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 7
    bpy.ops.object.camera_add(location=(8, -11, 9))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, .55)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 12.2 if expanded else 8.8
    scene.camera = camera
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview")
    parser.add_argument("--new-preview", help="Render a preview of the newly added assets")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--only-new", action="store_true", help="Do not rewrite the original twelve assets")
    selection.add_argument("--asset", choices=ASSETS, help="Generate only this asset ID")
    parser.add_argument("--arkit-check", action="store_true", help="Require usdchecker --arkit --strict")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    asset_ids = ([args.asset] if args.asset else
                 [asset_id for asset_id in ASSETS if not args.only_new or asset_id not in ORIGINAL_IDS])
    export_assets(asset_ids)
    verify_assets(asset_ids, args.arkit_check)
    if args.preview:
        preview(os.path.abspath(args.preview))
    if args.new_preview:
        preview(os.path.abspath(args.new_preview), expanded=True)


if __name__ == "__main__":
    main()
