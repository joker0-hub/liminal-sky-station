extends CharacterBody3D

const WALK_SPEED := 3.05
const EYE_HEIGHT := 1.60

var eye: Camera3D
var walking := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_max_angle = deg_to_rad(62.0)
	floor_snap_length = 0.24
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.205
	capsule.height = 1.58
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.79
	add_child(collider)
	eye = Camera3D.new()
	eye.position.y = EYE_HEIGHT
	eye.fov = 61.5
	eye.near = 0.06
	eye.far = 1800.0
	add_child(eye)


func enter(spawn_point: Vector3, direction: Vector3) -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	rotation.y = atan2(-direction.x, -direction.z)
	eye.rotation.x = asin(clampf(direction.y, -1.0, 1.0))
	walking = true
	eye.make_current()


func look_around(relative: Vector2) -> void:
	rotation.y -= relative.x * 0.00205
	eye.rotation.x = clampf(eye.rotation.x - relative.y * 0.00205, -1.37, 1.37)


func _physics_process(delta: float) -> void:
	if not walking:
		return
	var move_input := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
	var target := transform.basis * Vector3(move_input.x, 0.0, move_input.y) * WALK_SPEED
	velocity.x = move_toward(velocity.x, target.x, 17.5 * delta)
	velocity.z = move_toward(velocity.z, target.z, 17.5 * delta)
	velocity.y -= 16.0 * delta
	move_and_slide()
