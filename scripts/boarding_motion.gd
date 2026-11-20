extends AnimationPlayer

const DEPLOY := &"deploy"
const RETRACT := &"retract"
const CHANNELS := {
	"position": Animation.TYPE_POSITION_3D,
	"rotation": Animation.TYPE_ROTATION_3D,
	"scale": Animation.TYPE_SCALE_3D,
}


func configure(train: Node3D, source: Dictionary, hinges: Array) -> bool:
	if source.is_empty():
		push_error("Missing v048 boarding motion")
		return false
	var hinge_names := {}
	for hinge: Dictionary in hinges:
		hinge_names[hinge["name"]] = hinge["node"]
	root_node = NodePath("..")
	var library := AnimationLibrary.new()
	var frame_step := float(source["frame_step"])
	for clip_name in [DEPLOY, RETRACT]:
		var clip: Dictionary = source["clips"][clip_name]
		var animation := Animation.new()
		animation.length = float(clip["duration"])
		animation.step = frame_step
		for track: Dictionary in clip["tracks"]:
			var part_name := String(track["object"])
			var node_name: String = hinge_names.get(part_name, part_name + " v048")
			var part := train.find_child(node_name, true, false) as Node3D
			if part == null:
				push_error("Missing v048 boarding part: " + node_name)
				return false
			var path := train.get_path_to(part)
			for channel in CHANNELS:
				if track.has(channel):
					_add_track(animation, path, part, channel, track[channel], frame_step)
		library.add_animation(clip_name, animation)
	return add_animation_library(&"", library) == OK


func _add_track(animation: Animation, path: NodePath, part: Node3D, channel: String,
		frames: Array, frame_step: float) -> void:
	var track := animation.add_track(CHANNELS[channel])
	animation.track_set_path(track, path)
	for index in frames.size():
		var sample: Array = frames[index]
		var time := minf(index * frame_step, animation.length)
		match channel:
			"position":
				var position := Vector3(sample[0], sample[1], sample[2])
				animation.position_track_insert_key(track, time, part.position + position)
			"rotation":
				var rotation := Quaternion(sample[0], sample[1], sample[2], sample[3]).normalized()
				animation.rotation_track_insert_key(track, time, rotation * part.quaternion)
			"scale":
				var stretch := Vector3(sample[0], sample[1], sample[2])
				animation.scale_track_insert_key(track, time, part.scale * stretch)
