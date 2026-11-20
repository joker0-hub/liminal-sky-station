"""Capture the v048 deck's Cycles light into the same survey UVs as its stone textures."""

from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_v048_floor import FLOOR_NAME, X_MIN, X_MAX, Y_MIN, Y_MAX, choose_device


def use_surface_data(tree, node):
    channels = tree.nodes.new("ShaderNodeCombineColor")
    for channel, name in enumerate(("Roughness", "Coat Weight", "Coat Roughness")):
        source = node.inputs[name]
        if source.is_linked:
            tree.links.new(source.links[0].from_socket, channels.inputs[channel])
        else:
            channels.inputs[channel].default_value = source.default_value
    emit = tree.nodes.new("ShaderNodeEmission")
    output = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
    tree.links.new(channels.outputs["Color"], emit.inputs["Color"])
    tree.links.new(emit.outputs["Emission"], output.inputs["Surface"])


def bake(destination, surface_only):
    scene = bpy.context.scene
    floor = scene.objects[FLOOR_NAME]
    for obj in scene.objects:
        if obj != floor and obj.type not in {"CAMERA", "LIGHT", "EMPTY"}:
            obj.visible_camera = False

    for material in set(floor.data.materials):
        if not material or not material.node_tree:
            continue
        for node in material.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            if surface_only:
                use_surface_data(material.node_tree, node)
            else:
                coat = node.inputs["Coat Weight"]
                for link in list(coat.links):
                    material.node_tree.links.remove(link)
                coat.default_value = 0.0
                node.inputs["Specular IOR Level"].default_value = 0.0

    lens = bpy.data.cameras.new("v048 stone light capture")
    lens.type = "ORTHO"
    lens.ortho_scale = X_MAX - X_MIN
    lens.clip_start, lens.clip_end = 0.01, 2000.0
    camera = bpy.data.objects.new("v048 stone light capture", lens)
    scene.collection.objects.link(camera)
    camera.location = ((X_MIN + X_MAX) * 0.5, (Y_MIN + Y_MAX) * 0.5, 22.0)
    scene.camera = camera

    scene.render.engine = "CYCLES"
    choose_device(scene)
    scene.cycles.samples = 12 if surface_only else 48
    scene.cycles.use_denoising = not surface_only
    scene.render.resolution_x = 4096
    scene.render.resolution_y = 310
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = (X_MAX - X_MIN) / (Y_MAX - Y_MIN) * 310 / 4096
    scene.render.pixel_aspect_y = 1.0
    scene.render.use_compositing = False
    scene.render.use_sequencer = False
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "16"
    scene.render.filepath = str(destination)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    flag, name = sys.argv[sys.argv.index("--") + 1:]
    path = Path(name).resolve()
    if flag not in {"--light", "--surface"}:
        raise ValueError("Expected --light or --surface followed by an EXR output path")
    bake(path, surface_only=flag == "--surface")
