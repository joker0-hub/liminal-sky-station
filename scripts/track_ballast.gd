extends RefCounted

const SHALE := preload("res://shaders/v048_ballast.gdshader")
const BED_Y := 10.514
const X_MIN := -59.38
const X_MAX := 59.38
const Z_MIN := 4.978
const ROWS := 12
const SPACING := 0.105
const CHUNK_COLUMNS := 90
const VARIANTS := 5


static func build(parent: Node3D) -> void:
	var ballast := Node3D.new()
	ballast.name = "V048_Crushed_Stone"
	parent.add_child(ballast)
	var rng := RandomNumberGenerator.new()
	rng.seed = 480965
	var appearance := ShaderMaterial.new()
	appearance.shader = SHALE
	var stones: Array[ArrayMesh] = []
	for variant in VARIANTS:
		var shape := _rock(rng)
		shape.surface_set_material(0, appearance)
		stones.append(shape)
	var column_count := ceili((X_MAX - X_MIN) / SPACING)
	for first_column in range(0, column_count, CHUNK_COLUMNS):
		var end_column := mini(first_column + CHUNK_COLUMNS, column_count)
		var groups: Array[Array] = []
		for variant in VARIANTS:
			groups.append([])
		var center_x := X_MIN + (first_column + end_column) * 0.5 * SPACING
		for column in range(first_column, end_column):
			for row in ROWS:
				var x := X_MIN + (float(column) + rng.randf_range(0.15, 0.85)) * SPACING - center_x
				var z := Z_MIN + float(row) * SPACING + rng.randf_range(-0.027, 0.027)
				var position := Vector3(x, BED_Y + rng.randf_range(-0.008, 0.010), z)
				var radius := rng.randf_range(0.039, 0.077)
				var scale := Vector3(radius * rng.randf_range(0.76, 1.25), rng.randf_range(0.047, 0.083), radius)
				var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled_local(scale)
				groups[rng.randi_range(0, VARIANTS - 1)].append([Transform3D(basis, position), rng.randf()])
		for variant in VARIANTS:
			_add_batch(ballast, stones[variant], groups[variant], center_x)


static func _add_batch(parent: Node3D, stone: Mesh, placements: Array, center_x: float) -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = stone
	instances.instance_count = placements.size()
	for index in placements.size():
		instances.set_instance_transform(index, placements[index][0])
		instances.set_instance_custom_data(index, Color(placements[index][1], 0.0, 0.0))
	var segment := MultiMeshInstance3D.new()
	segment.position.x = center_x
	segment.layers = 16
	segment.multimesh = instances
	parent.add_child(segment)


static func _rock(rng: RandomNumberGenerator) -> ArrayMesh:
	const SIDES := 6
	var rings: Array[PackedVector3Array] = []
	for row in 3:
		var ring := PackedVector3Array()
		for side in SIDES:
			var angle := TAU * float(side) / float(SIDES) + (0.35 if row == 2 else 0.0)
			var radius: float = rng.randf_range(0.72, 1.07) * [0.68, 1.0, 0.56][row]
			var height: float = [-0.30, 0.07, 0.60][row] + rng.randf_range(-0.20, 0.19)
			ring.append(Vector3(cos(angle) * radius, height, sin(angle) * radius))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in SIDES:
		var next := (side + 1) % SIDES
		for row in 2:
			_triangle(surface, rings[row][side], rings[row + 1][side], rings[row + 1][next])
			_triangle(surface, rings[row][side], rings[row + 1][next], rings[row][next])
		_triangle(surface, rings[2][side], Vector3(0.11, 0.79, -0.08), rings[2][next])
		_triangle(surface, rings[0][side], Vector3(0.0, -0.41, 0.0), rings[0][next])
	return surface.commit()


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a)
	if normal.dot(a + b + c) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)
