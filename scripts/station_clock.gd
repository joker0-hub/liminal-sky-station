extends RefCounted

const SECONDS_PER_HOUR := 3600
const SECONDS_PER_DIAL := 12 * SECONDS_PER_HOUR

var hands: Array[Node3D] = []
var upright: Array[Quaternion] = []
var minute_hands := PackedByteArray()
var last_seconds := -1


func configure(station: Node3D) -> void:
	for hand: Node3D in station.find_children("*针 v048", "MeshInstance3D", true, false):
		var title := String(hand.name)
		var minute := title.ends_with("分针 v048")
		if not minute and not title.ends_with("时针 v048"):
			continue
		# The authored hand meshes all point along their local +Y. Recover
		# twelve o'clock from the dial plane so opposite faces turn correctly.
		var normal := hand.basis.z.normalized()
		var parent_up := hand.get_parent_node_3d().global_basis.inverse() * Vector3.UP
		var up := parent_up.slide(normal).normalized()
		var right := up.cross(normal).normalized()
		hands.append(hand)
		upright.append(Basis(right, up, normal).get_rotation_quaternion())
		minute_hands.append(1 if minute else 0)
	update_from_system()


func update_from_system() -> bool:
	var local := Time.get_time_dict_from_system()
	var seconds := int(local.hour) * SECONDS_PER_HOUR + int(local.minute) * 60 + int(local.second)
	if seconds == last_seconds:
		return false
	var minute_changed := floori(float(last_seconds) / 60.0) != floori(float(seconds) / 60.0)
	last_seconds = seconds
	_apply_time(seconds)
	return minute_changed


func _apply_time(seconds: int) -> void:
	var minute := Quaternion(Vector3.BACK, -TAU * float(seconds % SECONDS_PER_HOUR) / SECONDS_PER_HOUR)
	var hour := Quaternion(Vector3.BACK, -TAU * float(seconds % SECONDS_PER_DIAL) / SECONDS_PER_DIAL)
	for index in hands.size():
		hands[index].quaternion = upright[index] * (minute if minute_hands[index] else hour)
