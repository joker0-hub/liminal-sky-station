extends RefCounted

const PLATFORM_TOP := 10.513
const TRAIN_FLOOR := 11.76
const DOOR_CENTERS := [15.70, 0.44]
const BOARDING_START := 3.42
const BOARDING_END := 4.46


static func on_boarding_steps(position: Vector3) -> bool:
	if position.z < BOARDING_START - 0.12 or position.z > BOARDING_END + 0.18:
		return false
	for center: float in DOOR_CENTERS:
		if absf(position.x - center) < 0.64:
			return true
	return false


static func _box(target: Node3D, center: Vector3, dimensions: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	target.add_child(body)
	return collision


static func _boarding_floor(target: Node3D, x: float) -> CollisionShape3D:
	# The incline eases capsule movement over the treads. Its short landing overlaps the carriage floor.
	var landing_y := TRAIN_FLOOR + 0.018
	var lower_y := PLATFORM_TOP - 0.20
	var outline := [Vector2(BOARDING_START, lower_y), Vector2(BOARDING_START, PLATFORM_TOP - 0.018),
		Vector2(4.19, landing_y), Vector2(BOARDING_END, landing_y), Vector2(BOARDING_END, lower_y)]
	var points := PackedVector3Array()
	for side in [-0.445, 0.445]:
		for point: Vector2 in outline:
			points.append(Vector3(side, point.y, point.x))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.disabled = true
	var body := StaticBody3D.new()
	body.position.x = x
	body.collision_mask = 0
	body.add_child(collision)
	target.add_child(body)
	return collision


static func build(target: Node3D, station: Node3D, train: Node3D) -> Dictionary:
	var world := Node3D.new()
	world.name = "Walkable_Station"
	target.add_child(world)
	_box(world, Vector3(0, PLATFORM_TOP - 0.25, -0.635), Vector3(119.5, 0.50, 9.01))
	_box(world, Vector3(0, 11.15, -5.04), Vector3(119.5, 1.3, 0.09))
	for x in [-59.6, 59.6]:
		_box(world, Vector3(x, 11.17, -0.65), Vector3(0.3, 1.4, 8.95))
	for interval in [[-59.6, -0.12], [1.0, 15.13], [16.27, 59.6]]:
		_wall(world, interval[0], interval[1], 3.84, 11.28)

	for item in station.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var item_name := String(mesh.name)
		if not (item_name.contains("长椅") or item_name.contains("花盆") or item_name.contains("行李箱")):
			continue
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		if bounds.size.x > 0.21 and bounds.size.x < 3.8 and bounds.size.y > 0.20 and bounds.size.z < 2.7:
			_box(world, bounds.get_center(), bounds.size * Vector3(0.92, 0.96, 0.90))

	var interior := Node3D.new()
	interior.name = "Walkable_Railcars"
	train.add_child(interior)
	_box(interior, Vector3(2.20, TRAIN_FLOOR - 0.15, 5.57), Vector3(29.5, 0.30, 2.57))
	_wall(interior, -12.45, 16.91, 6.85, 12.45)
	for interval in [[-12.4, -0.05], [0.94, 15.22], [16.15, 16.95]]:
		_wall(interior, interval[0], interval[1], 4.29, 12.45)
	for x in [-12.35, 16.7]:
		_box(interior, Vector3(x, 12.47, 5.57), Vector3(0.15, 1.5, 2.6))
	for z in [4.67, 6.47]:
		for interval in [[-11.25, -0.48], [3.25, 14.95]]:
			var width: float = interval[1] - interval[0]
			_box(interior, Vector3(interval[0] + width * 0.5, 12.20, z), Vector3(width, 0.89, 0.67))
	var ramps: Array[CollisionShape3D] = []
	var guards: Array[CollisionShape3D] = []
	for x in DOOR_CENTERS:
		ramps.append(_boarding_floor(world, x))
		guards.append(_box(world, Vector3(x, 11.20, 3.87), Vector3(1.13, 1.6, 0.10)))
	return {"ramps": ramps, "guards": guards}


static func _wall(target: Node3D, left: float, right: float, z: float, y: float) -> void:
	_box(target, Vector3((left + right) * 0.5, y, z), Vector3(right - left, 1.65, 0.10))
