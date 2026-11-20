"""Build Godot assets from a read-only background session of the v048 scene."""

from collections import defaultdict
from pathlib import Path
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bake_v048_floor import FLOOR_NAME, UV_NAME, floor_uv


TO_GODOT = Matrix.Rotation(-math.pi / 2, 4, "X")
CAMERAS = {
    "platform": "精修 08｜净石月台与暮光",
    "overlook": "精修 09｜北侧车站与层云",
    "viaduct": "定稿 04｜桥拱 · 云下仰视",
    "carriage": "定稿 05｜列车 · 空车厢",
}


def visible(collection):
    if collection.hide_render:
        return
    for obj in collection.objects:
        if not obj.hide_render:
            yield obj
    for child in collection.children:
        yield from visible(child)


def convert_pose(obj):
    matrix = TO_GODOT @ obj.matrix_world
    q = matrix.to_quaternion()
    return {"position": list(matrix.translation), "rotation": [q.x, q.y, q.z, q.w]}


def bounds(obj, axis_convert=False):
    matrix = TO_GODOT @ obj.matrix_world if axis_convert else obj.matrix_world
    points = [matrix @ Vector(corner) for corner in obj.bound_box]
    return [[min(point[a] for point in points) for a in range(3)],
            [max(point[a] for point in points) for a in range(3)]]


def classify(scene):
    ordered = list(dict.fromkeys(visible(scene.collection)))
    scenery = set(bpy.data.collections["26｜天空环境"].all_objects)
    train = {
        obj
        for collection in bpy.data.collections
        if collection.name.startswith(("LIMINAL EXPRESS｜", "25｜", "列车｜灯具"))
        for obj in collection.all_objects
    }
    meshes = [obj for obj in ordered if obj.type in {"MESH", "FONT", "CURVE", "SURFACE"}]
    return ([o for o in meshes if o not in train and o not in scenery],
            [o for o in meshes if o in train], [o for o in meshes if o in scenery])


def door_axis(obj):
    ancestor = obj.parent
    while ancestor:
        if "门板轴" in ancestor.name:
            return ancestor
        ancestor = ancestor.parent
    return None


def principled(material):
    return next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)


def source_materials(objects):
    return {slot.material for obj in objects for slot in obj.material_slots
            if slot.material and slot.material.node_tree}


def reset_surface(material, color, roughness, opacity=1.0, metalness=0.0, emission=0.0):
    tree = material.node_tree
    tree.nodes.clear()
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metalness
    shader.inputs["Alpha"].default_value = opacity
    shader.inputs["Emission Color"].default_value = (*color, 1.0)
    shader.inputs["Emission Strength"].default_value = emission
    target = tree.nodes.new("ShaderNodeOutputMaterial")
    tree.links.new(shader.outputs[0], target.inputs["Surface"])
    material.surface_render_method = "BLENDED" if opacity < 1 else "DITHERED"
    return shader


def prepare_material(material):
    name = material.name
    tree = material.node_tree
    if name.startswith("环境｜"):
        image = next(n.image for n in tree.nodes if n.type == "TEX_IMAGE" and n.image)
        shader = reset_surface(material, (1, 1, 1), 1.0, opacity=0.98)
        tex = tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
        tree.links.new(tex.outputs["Alpha"], shader.inputs["Alpha"])
        return

    if "玻璃" in name and ("高透" in name or "防眩" in name or "中性玻璃" in name):
        alpha = 0.052 if name.startswith("列车") else 0.038
        reset_surface(material, (0.60, 0.75, 0.91), 0.10, opacity=alpha, metalness=0.08)
        return

    shader = principled(material)
    if not shader:
        return
    images = [n for n in tree.nodes if n.type == "TEX_IMAGE" and n.image]
    color = shader.inputs["Base Color"]
    if name.startswith("站台｜净蓝灰"):
        color.default_value = (0.13, 0.164, 0.225, 1.0)
    elif color.is_linked and color.links[0].from_node.type not in {"TEX_IMAGE", "VALTORGB"}:
        image = next((n for n in images if n.image.name.endswith(("_basecolor.jpg", "-BC.jpg"))), None)
        if image:
            tree.links.new(image.outputs["Color"], color)
            color.default_value = (1, 1, 1, 1)
    for key in ("Base Color", "Roughness", "Metallic", "Normal", "Emission Strength", "Emission Color"):
        socket = shader.inputs[key]
        if not socket.is_linked:
            continue
        link = socket.links[0]
        origin = link.from_node
        if origin.type == "VALTORGB" and key == "Base Color":
            socket.default_value = origin.color_ramp.evaluate(0.50)
        if origin.type in {"TEX_IMAGE", "NORMAL_MAP", "SEPARATE_COLOR", "SEPRGB"}:
            continue
        tree.links.remove(link)
    if name.startswith(("精修｜前照灯", "精修｜车顶灯")):
        shader.inputs["Emission Strength"].default_value = 2.1
        shader.inputs["Emission Color"].default_value = (0.95, 0.53, 0.20, 1)
    output = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
    tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for node in tree.nodes:
        if node.type in {"UVMAP", "NORMAL_MAP"}:
            node.uv_map = "UVMap"


def normalize_uv(mesh):
    if not len(mesh.uv_layers):
        textured = any(m and m.node_tree and
                       any(n.type == "TEX_IMAGE" and n.image for n in m.node_tree.nodes)
                       for m in mesh.materials)
        if not textured:
            return
        layer = mesh.uv_layers.new(name="UVMap")
        xyz = np.empty(len(mesh.vertices) * 3, np.float32)
        indices = np.empty(len(mesh.loops), np.int32)
        sizes = np.empty(len(mesh.polygons), np.int32)
        normals = np.empty(len(mesh.polygons) * 3, np.float32)
        mesh.vertices.foreach_get("co", xyz)
        mesh.loops.foreach_get("vertex_index", indices)
        mesh.polygons.foreach_get("normal", normals)
        mesh.polygons.foreach_get("loop_total", sizes)
        points = xyz.reshape(-1, 3)[indices]
        axis = np.repeat(np.abs(normals.reshape(-1, 3)).argmax(axis=1), sizes)
        uv = np.column_stack((np.where(axis == 0, points[:, 1], points[:, 0]),
                              np.where(axis == 2, points[:, 1], points[:, 2])))
        layer.uv.foreach_set("vector", (uv * 0.72).ravel())
    layer = mesh.uv_layers.active or mesh.uv_layers[0]
    name = layer.name
    for other in list(mesh.uv_layers):
        if other.name != name:
            mesh.uv_layers.remove(other)
    layer = mesh.uv_layers[0]
    layer.name = "UVMap"
    mesh.uv_layers.active_index = 0
    layer.active_render = True


def copy_model(objects, output, kind, depsgraph):
    cache = {}
    pivots = {}
    groups = defaultdict(list)
    for source in objects:
        uses_evaluation = source.type != "MESH" or bool(source.modifiers)
        key = source.data
        data = None if uses_evaluation else cache.get(key)
        if data is None:
            if uses_evaluation:
                data = bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph), depsgraph=depsgraph)
            else:
                data = key.copy()
                cache[key] = data
            if source.name == FLOOR_NAME:
                floor_uv(data)
                for other in list(data.uv_layers):
                    if other.name != UV_NAME:
                        data.uv_layers.remove(other)
            if kind != "scenery":
                normalize_uv(data)
        if not data.polygons:
            continue
        obj = bpy.data.objects.new(source.name + " v048", data)
        output.objects.link(obj)
        axis = door_axis(source) if kind == "train" else None
        if axis:
            if axis not in pivots:
                pivot = bpy.data.objects.new("DoorPivot_" + str(len(pivots) + 1), None)
                output.objects.link(pivot)
                pivot.matrix_world = axis.matrix_world.copy()
                pivot["source_name"] = axis.name
                pivots[axis] = pivot
            obj.parent = pivots[axis]
        matrix = source.matrix_world.copy()
        if source.type == "FONT":
            matrix.translation += matrix.to_quaternion() @ Vector((0, 0, 0.0025))
        obj.matrix_world = matrix

        if kind == "scenery" or source.name == FLOOR_NAME or axis or source.type == "FONT":
            continue
        if kind == "train" and source.animation_data and source.animation_data.action:
            continue
        if data.users > 1 or source.data.users > 1:
            continue
        if any(m and m.surface_render_method == "BLENDED" for m in data.materials):
            continue
        lower, upper = bounds(source)
        cx, cy, cz = [(a + b) * 0.5 for a, b in zip(lower, upper)]
        groups[(math.floor((cx + 6) / 15), cy < -3.7, cz < 9.5)].append(obj)
    bpy.context.view_layer.update()
    return groups, pivots


def write_glb(destination, objects, kind):
    scene = bpy.context.scene
    collection = bpy.data.collections.new("Godot export " + kind)
    scene.collection.children.link(collection)
    bpy.context.view_layer.update()
    groups, pivots = copy_model(objects, collection, kind, bpy.context.evaluated_depsgraph_get())

    bpy.ops.object.select_all(action="DESELECT")
    for index, group in enumerate(groups.values()):
        if len(group) < 2:
            continue
        for obj in group:
            obj.select_set(True)
        root = group[0]
        bpy.context.view_layer.objects.active = root
        bpy.ops.object.join()
        root.name = f"{kind.title()}Section{index + 1}"
        root.data.validate(clean_customdata=False)
        normalize_uv(root.data)
        root.select_set(False)
    for obj in collection.objects:
        obj.select_set(True)
    print(kind, len(objects), "source pieces,", len(collection.objects), "scene nodes", flush=True)
    bpy.ops.export_scene.gltf(
        filepath=str(destination),
        export_format="GLB",
        use_selection=True,
        export_image_format="AUTO",
        export_meshopt_compression_enable=False,
        export_gpu_instances=False,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
    )
    attributes = [{"node": pivot.name, "name": source.name, **convert_pose(source)}
                  for source, pivot in pivots.items()]
    for obj in list(collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(collection)
    return attributes


def scene_metadata(scene):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    cameras = {}
    for key, name in CAMERAS.items():
        cam = scene.objects[name]
        projection = cam.calc_matrix_camera(depsgraph, x=1920, y=1080, scale_x=1, scale_y=1)
        cameras[key] = {
            **convert_pose(cam), "name": name,
            "fov": math.degrees(2 * math.atan(1 / projection[1][1])),
            "near": cam.data.clip_start, "far": cam.data.clip_end,
        }
    lights = []
    for obj in dict.fromkeys(visible(scene.collection)):
        if obj.type != "LIGHT":
            continue
        d = obj.data
        lights.append({
            **convert_pose(obj), "name": obj.name, "type": d.type, "energy": d.energy,
            "color": list(d.color), "temperature": d.temperature if d.use_temperature else 0,
            "radius": getattr(d, "shadow_soft_size", 0.0),
            "width": getattr(d, "size", 0.0), "height": getattr(d, "size_y", 0.0),
            "shape": getattr(d, "shape", ""),
            "angle": getattr(d, "angle", 0.0),
        })
    world = scene.world.node_tree
    ramp = next(n.color_ramp for n in world.nodes if n.type == "VALTORGB")
    cloud = next(obj for obj in scene.objects if obj.type == "VOLUME" and not obj.hide_render)
    material = cloud.data.materials[0].node_tree
    tone = next(n.color_ramp for n in material.nodes if n.type == "VALTORGB")
    attribute = next(n.attribute_name for n in material.nodes if n.type == "ATTRIBUTE")
    return {
        "source": Path(bpy.data.filepath).name, "cameras": cameras, "lights": lights,
        "sky_ramp": [[e.position, *e.color[:3]] for e in ramp.elements],
        "cloud": {
            "bounds": bounds(cloud, axis_convert=True),
            "translation": list(cloud.matrix_world.translation),
            "color_ramp": [[e.position, *e.color[:3]] for e in tone.elements],
            "lighting_grid": attribute,
        },
    }


def export(destination, scenery_only=False):
    scene = bpy.context.scene
    station, train, sky = classify(scene)
    if scenery_only:
        for material in source_materials(sky):
            prepare_material(material)
        write_glb(destination / "sky-cards-v048.glb", sky, "scenery")
        return
    metadata = scene_metadata(scene)
    metadata["source_piece_counts"] = {"station": len(station), "train": len(train), "scenery": len(sky)}
    for material in source_materials(station + train + sky):
        prepare_material(material)
    destination.mkdir(parents=True, exist_ok=True)
    write_glb(destination / "station-v048.glb", station, "station")
    metadata["doors"] = write_glb(destination / "train-v048.glb", train, "train")
    write_glb(destination / "sky-cards-v048.glb", sky, "scenery")
    (destination / "v048.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:]
    export(Path(arguments[0]).resolve(), "--scenery-only" in arguments[1:])
