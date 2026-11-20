"""Render the v048 world or its cloud reflections to a linear HDR panorama."""

import math
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_v048_floor import choose_device


def render(path, reflection):
    scene = bpy.context.scene
    scenery = set(bpy.data.collections["26｜天空环境"].all_objects) if reflection else set()
    for obj in scene.objects:
        if obj not in scenery and not (reflection and obj.type in {"VOLUME", "LIGHT"}):
            obj.hide_render = True
    data = bpy.data.cameras.new("World probe")
    data.type = "PANO"
    data.panorama_type = "EQUIRECTANGULAR"
    camera = bpy.data.objects.new("World probe", data)
    scene.collection.objects.link(camera)
    camera.rotation_euler = (math.pi / 2, 0, 0)
    if reflection:
        camera.location = (28.0, 1.0, 13.7)
    scene.camera = camera
    scene.render.engine = "CYCLES"
    if reflection:
        choose_device(scene)
    else:
        scene.cycles.device = "CPU"
    scene.cycles.samples = 20 if reflection else 2
    scene.cycles.use_denoising = reflection
    scene.render.resolution_x = 2048
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.use_border = False
    scene.render.film_transparent = False
    scene.render.use_compositing = False
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "16"
    scene.render.image_settings.exr_codec = "ZIP"
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    render(Path(args[0]).resolve(), "--reflection" in args[1:])
