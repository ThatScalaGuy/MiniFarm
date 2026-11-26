"""Generate the Doc-21 product items in a fresh background Blender.

Run from the repository root, for example:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      --python-exit-code 1 --python Tools/Blender/product_items.py -- \
      --preview /absolute/path/products.png

The only output models are the IDs listed in PRODUCTS. Blender uses meters and
Z-up; USDZ uses meters and Y-up. Blender -Y (label side) becomes USD +Z.
Models are static and grounded at USD Y=0.
Requires Blender's pxr modules and usdchecker on PATH.
"""
import argparse
import math
import os
import shutil
import subprocess
import sys
import zipfile

import bpy
from mathutils import Vector
from pxr import Usd, UsdGeom, UsdShade

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "App/Resources/Models")
COLORS = {
    "cream": (0.92, 0.85, 0.70), "white": (0.98, 0.94, 0.84),
    "milk": (0.96, 0.92, 0.77), "blue": (0.31, 0.58, 0.70),
    "teal": (0.35, 0.63, 0.53), "dark": (0.25, 0.20, 0.15),
    "wood": (0.57, 0.34, 0.17), "brown": (0.39, 0.23, 0.13),
    "green": (0.40, 0.63, 0.27), "pink": (0.95, 0.61, 0.62),
    "red": (0.72, 0.24, 0.22), "berry": (0.58, 0.21, 0.35),
    "yellow": (0.96, 0.72, 0.27), "gold": (0.80, 0.48, 0.12),
    "orange": (0.83, 0.50, 0.16), "purple": (0.56, 0.42, 0.69),
    "eggblue": (0.70, 0.85, 0.79), "gray": (0.63, 0.65, 0.59),
}


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1


def mat(name):
    material = bpy.data.materials.get("Product_" + name)
    if not material:
        material = bpy.data.materials.new("Product_" + name)
        material.diffuse_color = (*COLORS[name], 1)
        material.use_nodes = True
        shader = material.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*COLORS[name], 1)
        shader.inputs["Roughness"].default_value = .78
    return material


def assign(obj, name, color):
    obj.name = name
    obj.data.materials.append(mat(color))
    return obj


def bevel(obj, width=.025):
    mod = obj.modifiers.new("Soft_edges", "BEVEL")
    mod.width = width
    mod.segments = 2
    obj.modifiers.new("Weighted_normals", "WEIGHTED_NORMAL")


def box(name, loc, size, color, width=.02, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if width:
        bevel(obj, width)
    return assign(obj, name, color)


def sphere(name, loc, size, color):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return assign(obj, name, color)


def cylinder(name, loc, radius, depth, color, vertices=20, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if rotation:
        obj.rotation_euler = rotation
    bevel(obj, min(.018, radius*.18, depth*.12))
    return assign(obj, name, color)


def cone(name, loc, bottom, top, depth, color):
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=bottom, radius2=top,
                                   depth=depth, location=loc)
    obj = bpy.context.object
    bevel(obj, .012)
    return assign(obj, name, color)


def ring(name, loc, major, minor, color, rotation=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
                                     major_radius=major, minor_radius=minor, location=loc)
    obj = bpy.context.object
    if rotation:
        obj.rotation_euler = rotation
    return assign(obj, name, color)


def beam(name, start, end, radius, color):
    a, b = Vector(start), Vector(end)
    obj = cylinder(name, (a+b)/2, radius, (b-a).length, color, 12)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return obj


def milk():
    cylinder("Milk_bottle", (0, 0, .23), .145, .43, "milk")
    sphere("Bottle_shoulder", (0, 0, .445), (.145, .145, .08), "milk")
    cylinder("Bottle_neck", (0, 0, .51), .08, .10, "milk")
    cylinder("Blue_cap", (0, 0, .58), .09, .055, "blue")
    box("Blue_label", (0, -.145, .26), (.19, .025, .17), "blue")
    sphere("Cream_label_dot", (0, -.165, .26), (.045, .012, .045), "white")


def wool():
    sphere("Wool_ball", (0, 0, .22), (.23, .21, .22), "white")
    for angle in (-.72, 0, .72):
        ring("Wool_strand", (0, 0, .22), .211, .012, "cream", (math.pi/2, angle, 0))
    box("Wool_band", (0, -.205, .22), (.17, .03, .15), "purple")


def compost():
    box("Compost_sack", (0, 0, .24), (.42, .32, .44), "brown", .07)
    box("Folded_sack_top", (0, 0, .48), (.36, .29, .07), "wood", .03)
    box("Green_label", (0, -.17, .25), (.24, .025, .18), "green")
    sphere("Soil_symbol", (0, -.19, .25), (.07, .012, .05), "brown")


def duckegg():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(0, 0, .14))
    obj = bpy.context.object
    for vertex in obj.data.vertices:
        z = vertex.co.z
        vertex.co.x *= .10*(1-.18*z)
        vertex.co.y *= .10*(1-.18*z)
        vertex.co.z *= .14
    for poly in obj.data.polygons:
        poly.use_smooth = True
    assign(obj, "Duck_egg", "eggblue")


def feather():
    vertices = []
    levels = ((.06, .012), (.16, .075), (.30, .115), (.44, .09), (.54, .045), (.59, .006))
    for z, width in levels:
        vertices += [(-width, 0, z), (width, 0, z)]
    faces = [(2*i, 2*i+1, 2*i+3, 2*i+2) for i in range(len(levels)-1)]
    mesh = bpy.data.meshes.new("Feather_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Feather_vane", mesh)
    bpy.context.collection.objects.link(obj)
    solidify = obj.modifiers.new("Feather_thickness", "SOLIDIFY")
    solidify.thickness = .012
    bevel(obj, .006)
    assign(obj, "Feather_vane", "white")
    beam("Feather_quill", (0, -.012, .02), (0, -.012, .59), .012, "cream")
    for z in (.19, .28, .37, .46):
        for side in (-1, 1):
            beam("Feather_barb", (0, -.015, z), (side*.07, -.015, z+.04), .005, "cream")


def goatmilk():
    box("Goat_milk_bottle", (0, 0, .24), (.31, .26, .43), "white", .065)
    sphere("Bottle_shoulder", (0, 0, .44), (.155, .13, .07), "white")
    cylinder("Bottle_neck", (0, 0, .50), .075, .10, "white")
    cylinder("Teal_cap", (0, 0, .565), .085, .05, "teal")
    box("Goat_milk_label", (0, -.14, .26), (.21, .025, .20), "teal")
    sphere("Milk_drop", (0, -.16, .26), (.045, .012, .065), "white")


def honeycomb():
    cylinder("Comb_back", (0, 0, .045), .34, .09, "gold", 6)
    centers = [(0, 0)] + [(.19*math.cos(i*math.pi/3), .19*math.sin(i*math.pi/3)) for i in range(6)]
    vertices, faces = [], []
    for x, y in centers:
        base = len(vertices)
        for z, radius in ((.09, .12), (.09, .085), (.13, .12), (.13, .085)):
            vertices.extend((x+radius*math.cos(i*math.pi/3),
                             y+radius*math.sin(i*math.pi/3), z) for i in range(6))
        for i in range(6):
            j = (i+1) % 6
            faces.extend(((base+12+i, base+12+j, base+18+j, base+18+i),
                          (base+i, base+6+i, base+6+j, base+j),
                          (base+i, base+j, base+12+j, base+12+i),
                          (base+6+j, base+6+i, base+18+i, base+18+j)))
    mesh = bpy.data.meshes.new("Honeycomb_cells_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Honeycomb_cells", mesh)
    bpy.context.collection.objects.link(obj)
    bevel(obj, .005)
    assign(obj, "Honeycomb_cells", "yellow")


def flour():
    box("Flour_sack", (0, 0, .25), (.40, .32, .46), "cream", .065)
    box("Sack_neck", (0, 0, .50), (.25, .23, .10), "white", .035)
    box("Sack_tie", (0, 0, .53), (.27, .25, .045), "blue")
    box("Flour_label", (0, -.17, .27), (.21, .025, .18), "white")
    sphere("Flour_symbol", (0, -.19, .27), (.045, .012, .045), "blue")


def bread():
    sphere("Bread_loaf", (0, 0, .18), (.38, .23, .18), "orange")
    for x in (-.19, 0, .19):
        box("Bread_score", (x, 0, .35), (.035, .28, .02), "cream", .009, (0, 0, -.35))


def cake():
    cylinder("Cake_bottom", (0, 0, .15), .28, .28, "orange", 24)
    cylinder("Cake_icing", (0, 0, .29), .29, .07, "pink", 24)
    cylinder("Icing_center", (0, 0, .33), .22, .025, "white", 24)
    for i in range(6):
        angle = i*math.tau/6
        sphere("Cake_decoration", (.18*math.cos(angle), .18*math.sin(angle), .35),
               (.045, .045, .035), "red")


def applejuice():
    cylinder("Juice_bottle", (0, 0, .22), .15, .42, "orange")
    sphere("Juice_shoulder", (0, 0, .42), (.15, .15, .075), "orange")
    cylinder("Juice_neck", (0, 0, .49), .08, .10, "orange")
    cylinder("Juice_cap", (0, 0, .555), .085, .05, "green")
    box("Juice_label", (0, -.15, .22), (.20, .025, .18), "cream")
    sphere("Juice_symbol", (0, -.17, .22), (.055, .012, .055), "red")


def butter():
    box("Butter_wrapper", (0, 0, .065), (.47, .30, .12), "cream", .025)
    box("Butter_block", (0, 0, .14), (.39, .24, .14), "yellow", .035)
    box("Butter_band", (0, 0, .218), (.11, .25, .025), "white", .01)


def cheese():
    vertices = [(-.30, -.22, 0), (-.30, .22, 0), (.31, 0, 0),
                (-.30, -.22, .28), (-.30, .22, .28), (.31, 0, .28)]
    vertices = [(y, -x, z) for x, y, z in vertices]
    faces = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    mesh = bpy.data.meshes.new("Cheese_wedge_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Cheese_wedge", mesh)
    bpy.context.collection.objects.link(obj)
    bevel(obj, .025)
    assign(obj, "Cheese_wedge", "yellow")
    for x, y, radius in ((-.18, -.07, .045), (-.03, .04, .035), (-.15, .10, .032)):
        cylinder("Cheese_spot", (y, -x, .282), radius, .008, "orange")


def goatcheese():
    cylinder("Goat_cheese_round", (0, 0, .12), .24, .22, "white", 24)
    cylinder("Cheese_top", (0, 0, .235), .21, .025, "cream", 24)
    for x in (-.10, 0, .10):
        box("Herb_stripe", (x, 0, .253), (.025, .31, .012), "green", .006)
    box("Goat_cheese_label", (0, -.245, .12), (.17, .025, .10), "teal")


def jam():
    cylinder("Jam_jar", (0, 0, .18), .18, .34, "berry", 20)
    cylinder("Jam_lid", (0, 0, .37), .19, .07, "red", 20)
    box("Jam_label", (0, -.18, .19), (.24, .03, .15), "white")
    sphere("Jam_label_mark", (0, -.20, .19), (.055, .012, .048), "pink")


def icecream():
    cone("Ice_cream_cup", (0, 0, .17), .12, .19, .34, "cream")
    ring("Cup_rim", (0, 0, .34), .18, .02, "pink")
    sphere("Strawberry_scoop", (0, 0, .41), (.19, .19, .17), "pink")
    sphere("Cream_topping", (.03, 0, .55), (.08, .08, .07), "white")
    sphere("Cherry", (.03, 0, .62), (.045, .045, .04), "red")
    box("Cup_label", (0, -.17, .18), (.14, .025, .10), "pink")


def honey():
    cylinder("Honey_jar", (0, 0, .18), .20, .34, "gold", 20)
    cylinder("Honey_lid", (0, 0, .37), .21, .07, "yellow", 20)
    box("Honey_label", (0, -.20, .18), (.24, .03, .15), "cream")
    cylinder("Hex_emblem", (0, -.22, .18), .055, .015, "gold", 6, (math.pi/2, 0, 0))


def beanie():
    sphere("Knitted_cap", (0, 0, .20), (.24, .24, .20), "blue")
    cylinder("Cap_brim", (0, 0, .10), .25, .13, "purple", 24)
    for y in (-.16, -.08, 0, .08, .16):
        beam("Knitted_rib", (-.20, y, .14), (.20, y, .14), .008, "blue")
    sphere("Cap_pompom", (0, 0, .40), (.075, .075, .075), "cream")


PRODUCTS = {
    "milk": milk, "wool": wool, "compost": compost, "duckegg": duckegg,
    "feather": feather, "goatmilk": goatmilk, "honeycomb": honeycomb,
    "flour": flour, "bread": bread, "cake": cake, "applejuice": applejuice,
    "butter": butter, "cheese": cheese, "goatcheese": goatcheese, "jam": jam,
    "icecream": icecream, "honey": honey, "beanie": beanie,
}
FRONT_FEATURES = {
    "milk": "Blue_label", "wool": "Wool_band", "compost": "Green_label",
    "goatmilk": "Goat_milk_label", "flour": "Flour_label",
    "applejuice": "Juice_label", "goatcheese": "Goat_cheese_label",
    "jam": "Jam_label", "icecream": "Cup_label", "honey": "Honey_label",
}


def mesh_bounds():
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for obj in bpy.context.scene.objects
              if obj.type == "MESH" for corner in obj.bound_box]
    if not points:
        raise RuntimeError("No Blender mesh")
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def build_grounded(build):
    reset()
    build()
    low, _ = mesh_bounds()
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.location.z -= low[2]
    return mesh_bounds()


def export_product(name, build):
    low, high = build_grounded(build)
    path = os.path.join(OUT, "model.item." + name + ".usdz")
    bpy.ops.wm.usd_export(filepath=path, selected_objects_only=False,
                          export_animation=False, export_materials=True,
                          generate_preview_surface=True, export_textures_mode="NEW",
                          convert_orientation=True, export_global_up_selection="Y",
                          export_global_forward_selection="NEGATIVE_Z", meters_per_unit=1.0)
    if not zipfile.is_zipfile(path):
        raise RuntimeError("Not a USDZ archive: " + path)
    with zipfile.ZipFile(path) as archive:
        if (not any(item.filename.endswith((".usd", ".usdc", ".usda")) for item in archive.infolist())
                or any(item.compress_type != zipfile.ZIP_STORED for item in archive.infolist())):
            raise RuntimeError("Invalid USDZ package: " + path)
    print("EXPORTED item." + name, "blender_xyz_m",
          tuple(round(high[i]-low[i], 4) for i in range(3)), flush=True)


def verify_product(name, checker):
    path = os.path.join(OUT, "model.item." + name + ".usdz")
    stage = Usd.Stage.Open(path)
    if not stage:
        raise RuntimeError("Cannot open USD stage: " + path)
    if UsdGeom.GetStageUpAxis(stage) != UsdGeom.Tokens.y or abs(UsdGeom.GetStageMetersPerUnit(stage)-1) > 1e-6:
        raise RuntimeError("Incorrect up axis or scale: " + path)
    meshes = [prim for prim in stage.Traverse() if prim.IsA(UsdGeom.Mesh)]
    if not meshes:
        raise RuntimeError("No USD meshes: " + path)
    materials = set()
    triangles = 0
    for prim in meshes:
        mesh = UsdGeom.Mesh(prim)
        counts = mesh.GetFaceVertexCountsAttr().Get()
        binding, _ = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()
        if not mesh.GetPointsAttr().Get() or not counts or not binding:
            raise RuntimeError("Missing geometry or material: " + str(prim.GetPath()))
        materials.add(str(binding.GetPath()))
        triangles += sum(max(0, n-2) for n in counts)
    bbox = UsdGeom.BBoxCache(Usd.TimeCode.Default(), [UsdGeom.Tokens.default_]).ComputeWorldBound(
        stage.GetPseudoRoot()).ComputeAlignedRange()
    if abs(bbox.GetMin()[1]) > 1e-4:
        raise RuntimeError("USD ground is not Y=0: " + path)
    if name in FRONT_FEATURES:
        prim = next((p for p in stage.Traverse() if p.GetName() == FRONT_FEATURES[name]), None)
        if not prim:
            raise RuntimeError("Missing front feature: " + path)
        front = UsdGeom.XformCache().GetLocalToWorldTransform(prim).ExtractTranslation()[2]
        if front <= 0:
            raise RuntimeError("Front feature does not face USD +Z: " + path)
    if name == "cheese":
        body = next(p for p in meshes if p.GetParent().GetName() == "Cheese_wedge")
        transform = UsdGeom.XformCache().GetLocalToWorldTransform(body)
        points = [transform.Transform(p) for p in UsdGeom.Mesh(body).GetPointsAttr().Get()]
        front = [p[0] for p in points if p[2] > .20]
        back = [p[0] for p in points if p[2] < -.20]
        if not front or not back or max(front)-min(front) >= max(back)-min(back):
            raise RuntimeError("Cheese tip is not oriented toward USD +Z")
    if any(attr.GetNumTimeSamples() for prim in stage.Traverse() for attr in prim.GetAttributes()):
        raise RuntimeError("Unexpected animation: " + path)
    result = subprocess.run([checker, "--arkit", "--strict", path], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("ARKit validation failed for " + path + ":\n" + result.stdout + result.stderr)
    print("VERIFIED item." + name, "meshes", len(meshes), "materials", len(materials),
          "triangles", triangles, "up Y meters_per_unit 1 ground_y",
          round(bbox.GetMin()[1], 6), "arkit strict passed", flush=True)


def preview(path):
    reset()
    for index, (name, build) in enumerate(PRODUCTS.items()):
        x, y = (index % 6 - 2.5)*1.25, (1 - index//6)*1.32
        before = set(bpy.context.scene.objects)
        build()
        added = set(bpy.context.scene.objects) - before
        bpy.context.view_layer.update()
        points = [obj.matrix_world @ Vector(corner) for obj in added for corner in obj.bound_box]
        minimum = min(p.z for p in points)
        for obj in added:
            obj.location += Vector((x, y, -minimum))
        bpy.ops.object.text_add(location=(x, y-.47, .015))
        text = bpy.context.object
        text.name = "Preview_label"
        text.data.body = name
        text.data.align_x = "CENTER"
        text.data.size = .17
        text.data.extrude = .001
        text.data.materials.append(mat("dark"))
    box("Preview_ground", (0, 0, -.08), (8.3, 4.8, .14), "cream")
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.world.color = (.4, .4, .4)
    bpy.ops.object.light_add(type="AREA", location=(-3, -4, 8))
    bpy.context.object.data.energy = 1200
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 7
    bpy.ops.object.camera_add(location=(0, -7, 11))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, .1))-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 8.9
    scene.camera = camera
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    checker = shutil.which("usdchecker")
    if not checker:
        raise RuntimeError("usdchecker is required for strict ARKit validation")
    os.makedirs(OUT, exist_ok=True)
    for name, build in PRODUCTS.items():
        export_product(name, build)
        verify_product(name, checker)
    if args.preview:
        preview(os.path.abspath(args.preview))


if __name__ == "__main__":
    main()
