"""Sample the v048 boarding actions in train coordinates for the Godot project."""

import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix


AXIS = Matrix.Rotation(-math.pi / 2, 4, "X")
SOURCE_CLIPS = {"deploy": (148, 206), "retract": (236, 290)}


def train_space_pose(obj, train_root):
    # Keep the train's authored orientation and remove its animated translation.
    matrix = obj.matrix_world.copy()
    matrix.translation -= train_root.matrix_world.translation
    return (AXIS @ matrix @ AXIS.inverted()).decompose()


def rounded(values):
    return [round(value, 6) for value in values]


def export(target):
    scene = bpy.context.scene
    moving_parts = {}
    for section, car, door in (
        ("首节", "列车原点｜轨面中心", "左前厅侧门｜门板轴"),
        ("第二节", "客车厢原点｜轨面中心", "客车厢｜左前厅侧门｜门板轴"),
    ):
        root = scene.objects[car]
        moving_parts[scene.objects[door]] = root
        collection = bpy.data.collections[section + "｜站台侧登车踏步"]
        for obj in collection.all_objects:
            if obj.animation_data and obj.animation_data.action:
                moving_parts[obj] = root

    scene.frame_set(SOURCE_CLIPS["deploy"][0])
    closed_pose = {obj: train_space_pose(obj, root) for obj, root in moving_parts.items()}
    frame_step = scene.render.fps_base / scene.render.fps
    document = {"frame_step": frame_step, "clips": {}}
    for name, (start, stop) in SOURCE_CLIPS.items():
        samples = {obj: {"position": [], "rotation": [], "scale": []} for obj in moving_parts}
        for frame in range(start, stop + 1):
            scene.frame_set(frame)
            for obj, root in moving_parts.items():
                pos, rot, scale = train_space_pose(obj, root)
                base_pos, base_rot, base_scale = closed_pose[obj]
                delta = rot @ base_rot.inverted()
                if delta.w < 0.0:
                    delta.negate()
                values = samples[obj]
                values["position"].append(rounded(pos - base_pos))
                values["rotation"].append(rounded((delta.x, delta.y, delta.z, delta.w)))
                values["scale"].append(rounded(scale[i] / base_scale[i] for i in range(3)))

        tracks = []
        for obj, channels in samples.items():
            keys = {}
            for channel, frames in channels.items():
                if any(value != frames[0] for value in frames[1:]):
                    keys[channel] = frames
            if keys:
                tracks.append({"object": obj.name, **keys})
        document["clips"][name] = {"duration": (stop - start) * frame_step, "tracks": tracks}
    target.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Exported {len(moving_parts)} animated v048 parts to {target}", flush=True)


if __name__ == "__main__":
    export(Path(sys.argv[sys.argv.index("--") + 1]).resolve())
