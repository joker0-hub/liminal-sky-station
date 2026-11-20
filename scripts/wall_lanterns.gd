extends RefCounted

const GLASS := preload("res://shaders/v048_lantern_glass.gdshader")
const BULB := preload("res://shaders/v048_lantern_bulb.gdshader")


static func install(parent: Node3D, sky_radiance: Texture2D, cabin: bool) -> void:
	var pattern := "*侧壁灯 * v048" if cabin else "壁灯_*｜复古灯笼 GLB v048"
	var fixtures := parent.find_children(pattern, "MeshInstance3D", true, false)
	if fixtures.is_empty():
		return
	var center_z := 0.305 if cabin else 0.532
	var lower := Vector3(0.147, -0.348, 0.148) if cabin else Vector3(0.063, 0.156, 0.069)
	var upper := Vector3(0.186, 0.094, 0.185) if cabin else Vector3(0.107, 0.386, 0.116)
	var bottom := _corners(lower, center_z)
	var top := _corners(upper, center_z)
	var bulb_position := Vector3(0.0, lerpf(lower.y, upper.y, 0.47), center_z)
	var frame := _frame(fixtures[0], bottom, top, cabin)

	var glass_material := ShaderMaterial.new()
	glass_material.shader = GLASS
	glass_material.render_priority = 6
	glass_material.set_shader_parameter("sky_radiance", sky_radiance)
	glass_material.set_shader_parameter("warmth", 0.74 if cabin else 1.02)
	var envelope := _panes(bottom, top)
	envelope.surface_set_material(0, glass_material)
	var bulb_mesh := _bulb(cabin)

	var lights := Node3D.new()
	lights.name = "Wall_Lamp_Lights"
	parent.add_child(lights)
	for fixture: MeshInstance3D in fixtures:
		fixture.mesh = frame
		_add_part(fixture, "Clear_Glass_Shade", envelope, Vector3.ZERO)
		_add_part(fixture, "Warm_Bulb", bulb_mesh, bulb_position)
		var light := _light(cabin)
		light.name = (String(fixture.name) + "｜内置光源").validate_node_name()
		light.position = lights.to_local(fixture.to_global(bulb_position))
		lights.add_child(light)


static func _frame(fixture: MeshInstance3D, bottom: PackedVector3Array, top: PackedVector3Array,
		cabin: bool) -> ArrayMesh:
	var frame := _keep_bracket(fixture, cabin)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("#ae8050") if cabin else Color("#8e693c")
	brass.metallic = 0.56
	brass.roughness = 0.43
	var trim := SurfaceTool.new()
	trim.begin(Mesh.PRIMITIVE_TRIANGLES)
	trim.set_material(brass)
	var bead_width := 0.021 if cabin else 0.010
	for i in 4:
		var next := (i + 1) % 4
		_append_bead(trim, bottom[i], top[i], bead_width)
		_append_bead(trim, bottom[i], bottom[next], bead_width * 1.15)
		_append_bead(trim, top[i], top[next], bead_width * 1.10)

	var socket := CylinderMesh.new()
	socket.top_radius = 0.045 if cabin else 0.022
	socket.bottom_radius = socket.top_radius * 1.18
	socket.height = 0.064 if cabin else 0.037
	socket.radial_segments = 12
	var socket_position := (bottom[0] + bottom[2]) * 0.5 + Vector3.UP * (socket.height * 0.5)
	trim.append_from(socket, 0, Transform3D(Basis.IDENTITY, socket_position))
	trim.commit(frame)

	var lods := ImporterMesh.from_mesh(frame)
	lods.generate_lods(28.0, 0.0, [])
	return lods.get_mesh()


static func _keep_bracket(fixture: MeshInstance3D, cabin: bool) -> ArrayMesh:
	var data := fixture.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var source: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	var front_plane := 0.082 if cabin else 0.36
	var shade_bottom := -0.35 if cabin else 0.150
	var shade_top := 0.096 if cabin else 0.384
	for index in range(0, source.size(), 3):
		var center := (vertices[source[index]] + vertices[source[index + 1]] + vertices[source[index + 2]]) / 3.0
		if center.z > front_plane and center.y > shade_bottom and center.y < shade_top:
			continue
		kept.append(source[index])
		kept.append(source[index + 1])
		kept.append(source[index + 2])
	data[Mesh.ARRAY_INDEX] = kept
	var bracket := ArrayMesh.new()
	bracket.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	bracket.surface_set_material(0, fixture.get_active_material(0))
	return bracket


static func _corners(dimensions: Vector3, center_z: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-dimensions.x, dimensions.y, center_z - dimensions.z),
		Vector3(dimensions.x, dimensions.y, center_z - dimensions.z),
		Vector3(dimensions.x, dimensions.y, center_z + dimensions.z),
		Vector3(-dimensions.x, dimensions.y, center_z + dimensions.z),
	])


static func _panes(bottom: PackedVector3Array, top: PackedVector3Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in 4:
		var next := (side + 1) % 4
		var edge := top[next] - top[side]
		var normal := edge.cross(bottom[side] - top[side]).normalized()
		for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
			var low := bottom[side].lerp(bottom[next], uv.x)
			var high := top[side].lerp(top[next], uv.x)
			surface.set_uv(uv)
			surface.set_normal(normal)
			surface.add_vertex(low.lerp(high, uv.y))
	return surface.commit()


static func _bulb(cabin: bool) -> CapsuleMesh:
	var material := ShaderMaterial.new()
	material.shader = BULB
	material.set_shader_parameter("radiance", 2.28 if cabin else 3.05)
	var bulb := CapsuleMesh.new()
	bulb.radius = 0.052 if cabin else 0.026
	bulb.height = 0.27 if cabin else 0.134
	bulb.radial_segments = 16
	bulb.rings = 8
	bulb.material = material
	return bulb


static func _light(cabin: bool) -> OmniLight3D:
	var point := OmniLight3D.new()
	point.light_color = Color("#ffd39c") if cabin else Color("#ffd19a")
	point.light_energy = 0.63 if cabin else 1.48
	point.light_volumetric_fog_energy = 0.0
	point.light_specular = 0.08 if cabin else 0.15
	point.omni_range = 2.60 if cabin else 4.00
	point.omni_attenuation = 1.55 if cabin else 1.38
	point.light_cull_mask = 2 if cabin else 17
	point.distance_fade_enabled = true
	point.distance_fade_begin = 10.0 if cabin else 17.0
	point.distance_fade_length = 7.5 if cabin else 13.0
	return point


static func _append_bead(trim: SurfaceTool, start: Vector3, end: Vector3, width: float) -> void:
	var distance := end - start
	var strip := BoxMesh.new()
	strip.size = Vector3(width, distance.length() + width, width)
	var basis := Basis(Quaternion(Vector3.UP, distance.normalized()))
	trim.append_from(strip, 0, Transform3D(basis, start.lerp(end, 0.5)))


static func _add_part(parent: MeshInstance3D, title: String, mesh: Mesh, position: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = title
	part.mesh = mesh
	part.layers = parent.layers
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = position
	parent.add_child(part)
