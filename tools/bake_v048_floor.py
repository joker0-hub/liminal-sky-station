"""Bake the original v048 stone shaders into textures for the Godot material."""

from pathlib import Path
import sys

import bmesh
import bpy
import numpy as np


FLOOR_NAME = "01_站台错缝石铺面"
UV_NAME = "StationFloorBake"
X_MIN, X_MAX = -59.85, 59.85
Y_MIN, Y_MAX = -3.884, 5.173


def floor_uv(mesh):
    """Use the same survey coordinates when baking and when exporting."""
    layer = mesh.uv_layers.get(UV_NAME) or mesh.uv_layers.new(name=UV_NAME)
    vertices = np.empty(len(mesh.vertices) * 3, np.float32)
    corners = np.empty(len(mesh.loops), np.int32)
    mesh.vertices.foreach_get("co", vertices)
    mesh.loops.foreach_get("vertex_index", corners)
    xy = vertices.reshape((-1, 3))[corners, :2]
    uv = (xy - np.array([X_MIN, Y_MIN], dtype=np.float32)) / np.array(
        [X_MAX - X_MIN, Y_MAX - Y_MIN], dtype=np.float32
    )
    layer.uv.foreach_set("vector", uv.ravel())
    mesh.uv_layers.active = layer
    layer.active_render = True


def use_top_faces(floor):
    """The bottoms and tops of the individual tiles overlap in the deck UVs."""
    mesh = floor.data.copy()
    editable = bmesh.new()
    editable.from_mesh(mesh)
    bmesh.ops.delete(editable, geom=[face for face in editable.faces if face.normal.z < 0.48], context="FACES")
    editable.to_mesh(mesh)
    editable.free()
    floor.data = mesh


def choose_device(scene):
    scene.cycles.device = "CPU"
    preferences = bpy.context.preferences.addons["cycles"].preferences
    try:
        preferences.compute_device_type = "OPTIX"
        preferences.refresh_devices()
        for device in preferences.devices:
            device.use = device.type == "OPTIX"
        if any(device.use for device in preferences.devices):
            scene.cycles.device = "GPU"
    except RuntimeError:
        pass


def bake_floor(destination):
    scene = bpy.context.scene
    floor = scene.objects[FLOOR_NAME]
    for obj in scene.objects:
        if obj != floor:
            obj.hide_render = True
    bpy.ops.object.select_all(action="DESELECT")
    floor.hide_set(False)
    floor.select_set(True)
    bpy.context.view_layer.objects.active = floor
    use_top_faces(floor)
    floor_uv(floor.data)
    print("Baking v048 floor", len(floor.data.polygons), flush=True)

    scene.render.engine = "CYCLES"
    choose_device(scene)
    scene.cycles.samples = 2
    mats = set(floor.data.materials)
    targets = []
    for material in mats:
        tree = material.node_tree
        surface = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
        output = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
        emission = tree.nodes.new("ShaderNodeEmission")
        tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
        target = tree.nodes.new("ShaderNodeTexImage")
        tree.nodes.active = target
        targets.append((tree, surface, emission.inputs["Color"], target))

    destination.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.new("v048 stone color", width=6144, height=512, alpha=False)
    image.colorspace_settings.name = "sRGB"
    for tree, surface, emit, target in targets:
        target.image = image
        source = surface.inputs["Base Color"]
        if source.is_linked:
            tree.links.new(source.links[0].from_socket, emit)
        else:
            emit.default_value = source.default_value
    bpy.ops.object.bake(type="EMIT", uv_layer=UV_NAME, margin=8, use_clear=True)
    image.file_format = "PNG"
    image.filepath_raw = str(destination / "stone-color.png")
    image.save()
    print("Saved", image.filepath_raw, flush=True)


if __name__ == "__main__":
    bake_floor(Path(sys.argv[sys.argv.index("--") + 1]).resolve())
