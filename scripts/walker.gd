extends CharacterBody3D

const WALK_SPEED := 3.05
const EYE_HEIGHT := 1.60
const LOOK_SENSITIVITY := 0.00205
const LOOK_RESPONSE := 42.0
const MAX_MOUSE_DELTA := 160.0

var eye: Camera3D
var walking := false
var target_look := Vector2.ZERO
var ignore_next_motion := false


func _ready() -> void:
	# Follow the body before the station samples the camera for deck reflections.
	process_priority = -10
	collision_layer = 0
	collision_mask = 1
	floor_max_angle = deg_to_rad(62.0)
	floor_snap_length = 0.24
	floor_constant_speed = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.205
	capsule.height = 1.58
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.79
	add_child(collider)
	eye = Camera3D.new()
	eye.top_level = true
	eye.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	eye.fov = 61.5
	eye.near = 0.06
	eye.far = 1800.0
	add_child(eye)


func enter(spawn_point: Vector3, direction: Vector3) -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	target_look = Vector2(asin(clampf(direction.y, -1.0, 1.0)), atan2(-direction.x, -direction.z))
	get_global_transform_interpolated()
	reset_physics_interpolation()
	eye.global_position = spawn_point + Vector3.UP * EYE_HEIGHT
	eye.rotation = Vector3(target_look.x, target_look.y, 0.0)
	walking = true
	eye.make_current()


func begin_mouse_capture() -> void:
	# Pointer lock and cursor recentering can emit a synthetic initial motion.
	target_look = Vector2(eye.rotation.x, eye.rotation.y)
	ignore_next_motion = true


func look_around(relative: Vector2) -> void:
	if ignore_next_motion:
		ignore_next_motion = false
		return
	var motion := relative.limit_length(MAX_MOUSE_DELTA) * LOOK_SENSITIVITY
	target_look.y = wrapf(target_look.y - motion.x, -PI, PI)
	target_look.x = clampf(target_look.x - motion.y, -1.37, 1.37)


func _process(delta: float) -> void:
	if not walking:
		return
	eye.global_position = get_global_transform_interpolated().origin + Vector3.UP * EYE_HEIGHT
	var weight := 1.0 - exp(-LOOK_RESPONSE * minf(delta, 1.0 / 30.0))
	var pitch := lerpf(eye.rotation.x, target_look.x, weight)
	var yaw := lerp_angle(eye.rotation.y, target_look.y, weight)
	if absf(pitch - target_look.x) < 0.0001:
		pitch = target_look.x
	if absf(angle_difference(yaw, target_look.y)) < 0.0001:
		yaw = target_look.y
	eye.rotation = Vector3(pitch, yaw, 0.0)


func _physics_process(delta: float) -> void:
	if not walking:
		return
	var move_input := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
	var target := Vector3(move_input.x, 0.0, move_input.y).rotated(Vector3.UP, eye.rotation.y) * WALK_SPEED
	velocity.x = move_toward(velocity.x, target.x, 17.5 * delta)
	velocity.z = move_toward(velocity.z, target.z, 17.5 * delta)
	velocity.y -= 16.0 * delta
	move_and_slide()
