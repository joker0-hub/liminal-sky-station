"""Render comparison plates from the current v048 source without saving the blend."""

from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_v048_floor import choose_device
from export_v048 import CAMERAS


def render_references(directory, keys):
    scene = bpy.context.scene
    directory.mkdir(parents=True, exist_ok=True)
    scene.render.engine = "CYCLES"
    choose_device(scene)
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    for key in keys:
        scene.camera = scene.objects[CAMERAS[key]]
        scene.render.filepath = str(directory / (key + ".png"))
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    path, *requested_keys = sys.argv[sys.argv.index("--") + 1:]
    render_references(Path(path).resolve(), requested_keys or CAMERAS)
