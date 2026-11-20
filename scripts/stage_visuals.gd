extends RefCounted

const SKY := preload("res://shaders/v048_sky.gdshader")
const WORLD_MAP := preload("res://assets/textures/sky-v048.exr")
const GLASS_REFLECTION := preload("res://assets/textures/sky-glass-v048.exr")
const PLATFORM_AIR_COMPAT := preload("res://shaders/platform_air_compat.gdshader")
const CLOUDS := preload("res://shaders/v048_clouds.gdshader")
const CARDS := preload("res://shaders/v048_cards.gdshader")
const GLASS := preload("res://shaders/v048_glass.gdshader")
const SOLID_GLASS := preload("res://shaders/v048_solid_glass.gdshader")
const TRACK_FINISH := preload("res://shaders/station_finish.gdshader")
const ARCHITECTURE := preload("res://shaders/v048_architecture.gdshader")
const PLATFORM_PROPS := preload("res://shaders/v048_platform_props.gdshader")
const TRAIN_PAINT := preload("res://shaders/v048_train_paint.gdshader")
const STONE := preload("res://shaders/v048_stone.gdshader")
const BALLAST := preload("res://shaders/v048_ballast.gdshader")
const TrackBallast := preload("res://scripts/track_ballast.gd")
const WallLanterns := preload("res://scripts/wall_lanterns.gd")
const FloorReflection := preload("res://scripts/floor_reflection.gd")
const STONE_COLOR := preload("res://assets/textures/stone-color.png")
const STONE_SURFACE := preload("res://assets/textures/stone-surface.exr")
const STONE_LIGHT := preload("res://assets/textures/stone-light.exr")
const BENCH_ALBEDO := preload("res://assets/v048/station-v048_长条椅_basecolor.jpg")
const SUITCASE_ALBEDO := preload("res://assets/v048/station-v048_行李箱_basecolor.jpg")
const TRAIN_METALWORK := [
	null,
	preload("res://assets/v048/train-v048_车侧钣金｜R 板缝 · G 铆钉 · B 磨损.png"),
	preload("res://assets/v048/train-v048_车头钣金｜R 板缝 · G 铆钉 · B 磨损.png"),
	preload("res://assets/v048/train-v048_车顶钣金｜R 板缝 · G 铆钉 · B 磨损.png"),
]
const SUN_FROM := Vector3(-0.69, 0.45, -0.56)
const SKY_FILL_FROM := Vector3(0.22, 0.62, 0.76)
const CLOUD_BOUNCE_FROM := Vector3(0.58, 0.52, -0.63)
const SHAFT_POSITION := Vector3(28.0, 15.85, -3.07)
const SHAFT_SIZE := Vector3(17.5, 6.65, 3.15)


static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


static func rotation_of(values: Array) -> Quaternion:
	return Quaternion(values[0], values[1], values[2], values[3]).normalized()


static func read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func build_environment(target: Node3D) -> Environment:
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	var web := OS.has_feature("web")
	var background := ShaderMaterial.new()
	background.shader = SKY
	background.set_shader_parameter("world_map", WORLD_MAP)
	background.set_shader_parameter("sun_from", SUN_FROM.normalized())
	var sky := Sky.new()
	sky.sky_material = background
	sky.radiance_size = Sky.RADIANCE_SIZE_64 if web else Sky.RADIANCE_SIZE_256

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.455, 0.583, 0.835).linear_to_srgb()
	environment.ambient_light_energy = 0.49 if forward else 0.64
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = pow(2.0, -0.52)
	environment.tonemap_agx_contrast = 1.13
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.045
	environment.adjustment_saturation = 1.105
	environment.glow_enabled = true
	environment.glow_bloom = 0.0
	environment.glow_intensity = 0.19
	environment.glow_strength = 0.50
	environment.glow_hdr_threshold = 1.52
	if forward:
		environment.ssr_enabled = true
		environment.ssr_max_steps = 76
		environment.ssr_depth_tolerance = 0.20
		environment.ssr_fade_in = 0.125
		environment.ssao_enabled = true
		environment.ssao_radius = 1.3
		environment.ssao_intensity = 1.02
		environment.ssao_light_affect = 0.16
		environment.ssil_enabled = true
		environment.ssil_intensity = 0.28
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = 0.0
		environment.volumetric_fog_length = 32.0
		environment.volumetric_fog_detail_spread = 1.7
		environment.volumetric_fog_anisotropy = 0.39
		environment.volumetric_fog_gi_inject = 0.0
		environment.volumetric_fog_sky_affect = 1.0

	var world := WorldEnvironment.new()
	world.name = "V048_Environment"
	world.environment = environment
	target.add_child(world)
	_add_platform_air(target, forward)

	# The Web build uses the baked glass reflection and the planar deck mirror.
	if web:
		return environment
	for x in [10.0, 31.5]:
		var probe := ReflectionProbe.new()
		probe.position = Vector3(x, 12.8, 0.4)
		probe.size = Vector3(29.0, 8.0, 14.3)
		probe.intensity = 0.49
		probe.max_distance = 110.0
		probe.box_projection = true
		probe.enable_shadows = false
		probe.cull_mask = 7
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		target.add_child(probe)
	return environment


static func _add_platform_air(target: Node3D, forward: bool) -> void:
	var material := ShaderMaterial.new()
	if not forward:
		var center := Vector3(28.0, 15.48, -2.4)
		var bounds := Vector3(20.4, 7.9, 5.4)
		material.shader = PLATFORM_AIR_COMPAT
		material.render_priority = -10
		material.set_shader_parameter("volume_min", center - bounds * 0.5)
		material.set_shader_parameter("volume_max", center + bounds * 0.5)
		material.set_shader_parameter("sun_from", SUN_FROM.normalized())
		if OS.has_feature("web"):
			material.set_shader_parameter("march_steps", 10)
		var box := BoxMesh.new()
		box.size = bounds
		var shaft := MeshInstance3D.new()
		shaft.name = "PlatformSunlight"
		shaft.position = center
		shaft.mesh = box
		shaft.material_override = material
		shaft.layers = 8
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target.add_child(shaft)
		return
	var air := FogVolume.new()
	air.name = "PlatformSunlight"
	air.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	air.position = SHAFT_POSITION
	air.size = SHAFT_SIZE
	material.shader = load("res://shaders/platform_air.gdshader")
	material.set_shader_parameter("sun_from", SUN_FROM.normalized())
	air.material = material
	target.add_child(air)


static func build_lights(target: Node3D, train: Node3D, authored: Array) -> void:
	var fixtures := Node3D.new()
	fixtures.name = "V048_Light_Rig"
	target.add_child(fixtures)
	var web := OS.has_feature("web")
	_add_station_fill(fixtures, "LavenderSkyFill", SKY_FILL_FROM, Color("#b5b5f2"), 0.44 if web else 0.36)
	_add_station_fill(fixtures, "PeachCloudBounce", CLOUD_BOUNCE_FROM, Color("#ffd1b8"), 0.79)
	for data in authored:
		var source_name: String = data["name"]
		if source_name.begins_with("柱灯发光") or source_name.begins_with("车厢暖灯"):
			# The rebuilt lanterns now own their light sources.
			continue
		var light := _create_light(data, web)
		if light == null:
			continue
		light.light_volumetric_fog_energy = 0.0
		var rgb := vector(data["color"])
		light.name = source_name.validate_node_name()
		light.position = vector(data["position"])
		light.quaternion = rotation_of(data["rotation"])
		light.light_color = Color(rgb.x, rgb.y, rgb.z).linear_to_srgb()
		var temperature := float(data["temperature"])
		if temperature > 0.0:
			light.light_color = Color("#ffae68") if temperature < 2800.0 else Color("#ffc697")
		if light is DirectionalLight3D and source_name.begins_with("北侧"):
			# From the high windows on camera right, angled toward the front of the platform.
			light.basis = Basis.looking_at(-SUN_FROM.normalized(), Vector3.UP)
			light.light_color = Color("#ffc085")
			light.light_volumetric_fog_energy = 0.98
		light.light_cull_mask = 19
		# The roof and walls shelter the cabin from the outdoor light.
		light.shadow_caster_mask = 3 if web else 19
		var aboard := source_name.begins_with("车内顶棚") or source_name.begins_with("司机室")
		if source_name.begins_with("南侧原照明") or source_name.begins_with("机车正面") or aboard:
			light.light_cull_mask = 2
		var container := train if aboard else fixtures
		container.add_child(light)


static func _add_station_fill(parent: Node3D, title: String, source: Vector3, tint: Color, energy: float) -> void:
	var fill := DirectionalLight3D.new()
	fill.name = title
	fill.basis = Basis.looking_at(-source.normalized(), Vector3.UP)
	fill.light_color = tint
	fill.light_energy = energy
	fill.light_specular = 0.24
	fill.light_volumetric_fog_energy = 0.0
	fill.light_cull_mask = 1
	parent.add_child(fill)


static func _create_light(data: Dictionary, web: bool) -> Light3D:
	var name_in_blender: String = data["name"]
	var power := float(data["energy"])
	match data["type"]:
		"SUN":
			var sun := DirectionalLight3D.new()
			var primary := name_in_blender.begins_with("北侧")
			sun.light_energy = power * (1.92 if primary else 0.19)
			sun.light_angular_distance = 1.46 if primary else rad_to_deg(float(data["angle"]))
			if primary:
				sun.light_specular = 0.34
			sun.shadow_enabled = primary
			sun.shadow_bias = 0.029
			sun.shadow_normal_bias = 0.48
			sun.directional_shadow_max_distance = 155.0
			sun.directional_shadow_split_1 = 0.075
			sun.directional_shadow_split_2 = 0.23
			sun.directional_shadow_split_3 = 0.51
			sun.directional_shadow_blend_splits = true
			if web:
				# The floor bake carries the far window pattern. Render one sharp
				# shadow map for nearby station architecture.
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = 58.0
			return sun
		"AREA":
			var area := AreaLight3D.new()
			var width := maxf(0.08, float(data["width"]))
			var rectangle: bool = data["shape"] in ["RECTANGLE", "ELLIPSE"]
			var height := maxf(0.08, float(data["height"])) if rectangle else width
			if data["shape"] in ["DISK", "ELLIPSE"]:
				width *= 0.8862
				height *= 0.8862
			area.area_size = Vector2(width, height)
			area.area_range = clampf(sqrt(power) * 1.9, 4.2, 85.0)
			area.area_attenuation = 1.85
			area.area_normalize_energy = true
			area.light_energy = power * 0.0165
			area.light_specular = 0.32
			area.light_size = minf(width, height) * 0.33
			area.shadow_enabled = not web and name_in_blender.begins_with("月台斜光")
			area.shadow_bias = 0.072
			area.shadow_normal_bias = 0.7
			return area
		"POINT":
			var point := OmniLight3D.new()
			point.omni_range = clampf(sqrt(power) * 1.07, 2.0, 8.0)
			point.omni_attenuation = 1.65
			point.light_energy = power * 0.056
			point.light_size = maxf(0.055, float(data["radius"]))
			return point
	return null


static func prepare_model(root: Node3D, layer_mask: int) -> Dictionary:
	var shared: Dictionary = {}
	var stone_surfaces: Dictionary = {}
	var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var web := OS.has_feature("web")
	var glazing_reflection: Texture2D = GLASS_REFLECTION
	if layer_mask == 1 and DisplayServer.get_name() != "headless":
		var panorama := GLASS_REFLECTION.get_image()
		if panorama and not panorama.is_empty() and not panorama.has_mipmaps():
			panorama.generate_mipmaps()
			glazing_reflection = ImageTexture.create_from_image(panorama)
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var open_glass_sheet := String(mesh.name).begins_with("04_12_无色透明窗玻璃")
		var track_section := layer_mask == 1 and mesh.name == &"StationSection2"
		mesh.layers = layer_mask
		if layer_mask == 1:
			var top := (mesh.global_transform * mesh.get_aabb()).end.y
			var paving := String(mesh.name).begins_with("01_站台错缝石铺面")
			if top <= 10.57 or paving:
				mesh.layers = 16
				if paving and compatibility:
					# The stones receive shadows from the structure without casting across their own joints.
					mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# This merged section contains the solid deck, which hides the whole
			# station from a reflection camera placed below its top surface.
			elif mesh.name != &"StationSection1":
				mesh.layers |= FloorReflection.PLATFORM_LAYER
		for index in mesh.get_surface_override_material_count():
			var current := mesh.get_active_material(index)
			if current == null:
				continue
			var key: Variant = current.get_instance_id()
			if open_glass_sheet:
				key = str(key) + "_sheet"
			if track_section:
				key = str(key) + "_track"
			if not shared.has(key):
				shared[key] = _surface_material(current, layer_mask, open_glass_sheet, track_section, glazing_reflection)
			var replacement: Material = shared[key]
			if replacement != current:
				mesh.set_surface_override_material(index, replacement)
			if replacement is ShaderMaterial and replacement.shader in [GLASS, SOLID_GLASS]:
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if replacement is ShaderMaterial and replacement.shader == PLATFORM_PROPS:
				var bounds := mesh.get_aabb()
				mesh.set_instance_shader_parameter("generated_origin", bounds.position)
				mesh.set_instance_shader_parameter("generated_size", bounds.size)
			if not web and replacement is ShaderMaterial and replacement.shader == ARCHITECTURE and (mesh.layers & 1) != 0:
				# Keep the original small bevels and mouldings in the platform views.
				mesh.lod_bias = 1.9
			if replacement is ShaderMaterial and replacement.shader == STONE:
				stone_surfaces[key] = replacement
		if layer_mask == 4:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if layer_mask == 1:
		TrackBallast.build(root)
		_line_suitcase_seams(root)
		if web:
			_batch_bridge(root)
	if layer_mask in [1, 2]:
		WallLanterns.install(root, GLASS_REFLECTION, layer_mask == 2)
	return stone_surfaces


static func _batch_bridge(root: Node3D) -> void:
	var sections: Dictionary = {}
	for item in root.find_children("*", "MeshInstance3D", true, false):
		var part := item as MeshInstance3D
		var title := String(part.name)
		if part.layers != 16 or not part.visible or not part.mesh is ArrayMesh:
			continue
		if not (title.begins_with("临轨钢拱") or title.begins_with("背轨钢拱")
				or title.begins_with("临轨桥墩") or title.begins_with("背轨桥墩")):
			continue
		var position := root.to_local(part.global_position)
		var key := "%s:%d:%d" % [part.mesh.get_instance_id(), floori(position.x / 24.0), roundi(position.z)]
		if not sections.has(key):
			sections[key] = []
		sections[key].append(part)

	var from_world := root.global_transform.affine_inverse()
	var materials_applied: Dictionary = {}
	for parts: Array in sections.values():
		if parts.size() < 2:
			continue
		var source: MeshInstance3D = parts[0]
		var mesh_id := source.mesh.get_instance_id()
		if not materials_applied.has(mesh_id):
			var shared_mesh := source.mesh.duplicate() as ArrayMesh
			for surface in shared_mesh.get_surface_count():
				shared_mesh.surface_set_material(surface, source.get_active_material(surface))
			materials_applied[mesh_id] = shared_mesh
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = materials_applied[mesh_id]
		instances.instance_count = parts.size()
		for index in parts.size():
			var part: MeshInstance3D = parts[index]
			instances.set_instance_transform(index, from_world * part.global_transform)
			part.hide()

		var section := MultiMeshInstance3D.new()
		section.multimesh = instances
		section.layers = source.layers
		section.cast_shadow = source.cast_shadow
		root.add_child(section)


static func _line_suitcase_seams(station: Node3D) -> void:
	# The original shell is open along a few seams. Back them with a matte
	# leather patch sampled from the original atlas, below the visible shell.
	var leather := StandardMaterial3D.new()
	leather.albedo_texture = SUITCASE_ALBEDO
	leather.albedo_color = Color("#9a8776")
	leather.uv1_offset = Vector3(0.155, 0.697, 0.0)
	leather.uv1_scale = Vector3(0.034, 0.102, 1.0)
	leather.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	leather.roughness = 0.72
	var inset := BoxMesh.new()
	inset.size = Vector3(0.468, 0.762, 0.256)
	inset.material = leather
	for suitcase: MeshInstance3D in station.find_children("旅行皮箱 *", "MeshInstance3D", true, false):
		var liner := MeshInstance3D.new()
		liner.name = "LeatherSeamBacking"
		liner.mesh = inset
		liner.position = Vector3(0.0, 0.438, 0.010)
		liner.layers = suitcase.layers
		liner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		suitcase.add_child(liner)


static func _surface_material(material: Material, layer_mask: int, open_glass_sheet: bool,
		track_section: bool, glazing_reflection: Texture2D) -> Material:
	var source_name: String = material.resource_name
	if layer_mask == 4 and material is BaseMaterial3D and material.albedo_texture != null:
		var card := ShaderMaterial.new()
		card.shader = CARDS
		card.resource_name = source_name
		card.render_priority = -35
		card.set_shader_parameter("artwork", material.albedo_texture)
		if source_name.contains("E04"):
			card.set_shader_parameter("sunlit_cloud", false)
			card.set_shader_parameter("side_feather", 0.082)
			card.set_shader_parameter("bottom_feather", 0.29)
			card.set_shader_parameter("matte", Vector3(0.31, 0.45, 0.704))
			card.set_shader_parameter("matte_blend", 0.29 if source_name.contains("远桥") else 0.16)
		if source_name.contains("蓝霭"):
			card.set_shader_parameter("opacity", 0.65)
		card.set_shader_parameter("balance", Vector3(1.15, 1.13, 1.12))
		return card
	if source_name.contains("玻璃") and (source_name.contains("高透") or source_name.contains("中性") or source_name.contains("防眩")):
		var glass := ShaderMaterial.new()
		var station_pane := source_name.begins_with("站房")
		glass.shader = SOLID_GLASS if station_pane and not open_glass_sheet else GLASS
		glass.resource_name = source_name
		glass.render_priority = 5
		glass.set_shader_parameter("sky_radiance", glazing_reflection)
		if station_pane:
			var canopy := source_name.contains("拱顶")
			var web := OS.has_feature("web")
			glass.set_shader_parameter("authored_station_glass", true)
			glass.set_shader_parameter("canopy_glass", canopy)
			glass.set_shader_parameter("web_glazing", web)
			glass.set_shader_parameter("reflection_roughness", 0.95 if web else (2.15 if canopy else 1.38))
		return glass
	if source_name.begins_with("精修｜道砟"):
		var bedding := ShaderMaterial.new()
		bedding.shader = BALLAST
		bedding.resource_name = source_name
		bedding.set_shader_parameter("fine_bed", true)
		return bedding
	if source_name.begins_with("站台｜净蓝灰") and material is BaseMaterial3D:
		var stone := ShaderMaterial.new()
		stone.shader = STONE
		stone.resource_name = source_name
		stone.set_shader_parameter("stone_color", STONE_COLOR)
		stone.set_shader_parameter("stone_surface", STONE_SURFACE)
		stone.set_shader_parameter("stone_light", STONE_LIGHT)
		return stone
	if layer_mask == 2:
		var train_paint := _railcar_paint(source_name)
		if train_paint != null:
			return train_paint
	if material is BaseMaterial3D:
		if layer_mask == 1:
			if source_name in ["长条椅｜GLB 材质", "行李箱｜GLB 材质"]:
				return _platform_prop_finish(material)
			var finish := _track_finish(material) if track_section else _architecture_finish(material, glazing_reflection)
			if finish != null:
				return finish
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if source_name.begins_with("定稿｜前照灯") or source_name.begins_with("定稿｜站台灯具"):
			var fixture := material.duplicate() as BaseMaterial3D
			fixture.emission_energy_multiplier *= 0.45 if source_name.begins_with("定稿｜前照灯") else 0.64
			return fixture
	if material is BaseMaterial3D and source_name == "定稿｜车厢 · 暖米漆板":
		var paint := material.duplicate() as BaseMaterial3D
		paint.albedo_color *= Color(1.0, 0.78, 0.60)
		paint.emission_enabled = true
		paint.emission = Color("#f68b42")
		paint.emission_energy_multiplier = 0.14
		return paint
	if material is BaseMaterial3D and source_name.begins_with("LIMINAL｜车厢地板"):
		var railcar_floor := material.duplicate() as BaseMaterial3D
		railcar_floor.albedo_color *= Color(0.78, 0.75, 0.74)
		return railcar_floor
	return material


static func _platform_prop_finish(source: BaseMaterial3D) -> ShaderMaterial:
	var bench := source.resource_name == "长条椅｜GLB 材质"
	var finish := ShaderMaterial.new()
	finish.shader = PLATFORM_PROPS
	finish.resource_name = source.resource_name
	finish.set_shader_parameter("original_albedo", BENCH_ALBEDO if bench else SUITCASE_ALBEDO)
	finish.set_shader_parameter("saturation", 1.08 if bench else 1.07)
	finish.set_shader_parameter("roughness_base", 0.29 if bench else 0.39)
	finish.set_shader_parameter("grain_scale", 95.0 if bench else 120.0)
	finish.set_shader_parameter("grain_height", (0.003 if bench else 0.0019) * 0.30)
	finish.set_shader_parameter("metalness", source.metallic)
	finish.set_shader_parameter("coat_weight", 0.17 if bench else 0.14)
	return finish


static func _railcar_paint(source_name: String) -> ShaderMaterial:
	var part: int
	if source_name.begins_with("精修｜车侧"):
		part = 1
	elif source_name.begins_with("精修｜车头"):
		part = 2
	elif source_name.begins_with("精修｜车顶 ｜深蓝弧面"):
		part = 3
	elif source_name.begins_with("精修｜底盘"):
		part = 4
	elif source_name.begins_with("精修｜钢轮"):
		part = 5
	elif not source_name.begins_with("定稿｜列车 · 象牙"):
		return null
	var paint := ShaderMaterial.new()
	paint.shader = TRAIN_PAINT
	paint.resource_name = source_name
	if part != 0:
		paint.set_shader_parameter("paint_part", part)
	if part > 0 and part < TRAIN_METALWORK.size():
		paint.set_shader_parameter("metalwork", TRAIN_METALWORK[part])
		paint.set_shader_parameter("paint_radiance", GLASS_REFLECTION)
	return paint


static func _architecture_finish(source: BaseMaterial3D, glazing_reflection: Texture2D) -> ShaderMaterial:
	var dark: Vector3
	var light: Vector3
	var roughness: float
	var arch_metal := false
	var coat := Vector2.ZERO
	var grain_height := 0.0015
	var aspect := Vector3.ONE
	var patina_scale := 3.8
	var grain_scale := 115.0
	var interior := Vector3(1.0, 0.83, 0.70)
	var track_face := Vector3(2.40, 1.72, 1.38)
	var north_face := Vector3(0.63, 0.56, 0.64)
	var exposed_metal_scale := 1.0
	var edge_finish := 0.0
	var textured := false
	# Keep the authored maps. The tint compensates for the different material
	# response on exposed faces under the existing Forward+ light rig.
	match source.resource_name.get_slice(" · ", 0):
		"LIMINAL｜站台立柱":
			textured = true
			interior = Vector3(0.82, 0.72, 0.77)
			edge_finish = 1.0
		"LIMINAL｜桥体":
			textured = true
			arch_metal = true
			interior = Vector3(0.81, 0.79, 0.88)
			track_face = Vector3(2.12, 1.61, 1.57)
		"LIMINAL｜钢构凸缘":
			textured = true
			interior = Vector3(0.84, 0.81, 0.91)
			track_face = Vector3(2.49, 1.88, 1.92)
			edge_finish = 0.85
		"LIMINAL｜桥墩":
			textured = true
			interior = Vector3(1.03, 1.15, 1.30)
			track_face = Vector3(2.03, 1.89, 1.84)
			north_face = Vector3(1.00, 1.16, 1.33)
		"LIMINAL｜黄铜":
			textured = source.albedo_texture != null
			if not textured:
				dark = Vector3(0.396, 0.193, 0.056)
				light = Vector3(0.503, 0.267, 0.091)
				roughness = 0.245
			interior = Vector3(0.99, 0.94, 0.82)
			track_face = Vector3(2.70, 2.75, 2.70)
			north_face = Vector3(0.72, 0.56, 0.50)
			exposed_metal_scale = 0.70
			edge_finish = 0.80
		"LIMINAL｜铸铁内槽":
			dark = Vector3(0.020, 0.038, 0.073)
			light = Vector3(0.027, 0.049, 0.095)
			roughness = 0.545
			interior = Vector3(0.91, 0.80, 0.69)
			edge_finish = 0.60
		"LIMINAL｜铆钉与触碰边":
			dark = Vector3(0.114, 0.147, 0.198)
			light = Vector3(0.141, 0.189, 0.263)
			roughness = 0.345
			edge_finish = 0.90
		"定稿｜拱肋铸铁":
			arch_metal = true
			dark = Vector3(0.020, 0.050, 0.111)
			light = Vector3(0.047, 0.111, 0.224)
			roughness = 0.41
			coat = Vector2(0.13, 0.2784)
			grain_height = 0.006
			track_face = Vector3(2.51, 2.03, 1.85)
			north_face = Vector3(0.55, 0.51, 0.57)
			edge_finish = 0.85
		"定稿｜压边钢":
			arch_metal = true
			dark = Vector3(0.0423, 0.0931, 0.1746)
			light = Vector3(0.0999, 0.1779, 0.3185)
			roughness = 0.34
			coat = Vector2(0.12, 0.2378)
			interior = Vector3(1.02, 0.91, 0.91)
			track_face = Vector3(2.51, 1.86, 1.75)
			north_face = Vector3(0.54, 0.48, 0.54)
			edge_finish = 0.95
		"定稿｜沟槽铸铁":
			dark = Vector3(0.0086, 0.0185, 0.0395)
			light = Vector3(0.0222, 0.0482, 0.0823)
			roughness = 0.51
		"定稿｜精磨暖黄铜":
			dark = Vector3(0.2874, 0.1195, 0.0284)
			light = Vector3(0.7758, 0.4793, 0.1779)
			roughness = 0.24
			coat = Vector2(0.19, 0.1798)
			aspect = Vector3(0.25, 3.5, 1.0)
			patina_scale = 8.0
			grain_scale = 180.0
			grain_height = 0.0013
			interior = Vector3(1.10, 1.03, 0.84)
			track_face = Vector3(2.20, 2.44, 2.34)
			north_face = Vector3(0.77, 0.65, 0.62)
			edge_finish = 0.78
		"定稿｜氧化黄铜":
			dark = Vector3(0.1559, 0.0704, 0.0222)
			light = Vector3(0.4287, 0.2232, 0.0742)
			roughness = 0.36
			coat = Vector2(0.12, 0.2494)
			grain_scale = 170.0
			track_face = Vector3(1.95, 2.15, 2.10)
			north_face = Vector3(0.75, 0.66, 0.58)
		"定稿｜钟盘":
			dark = Vector3(0.6240, 0.4851, 0.3005)
			light = Vector3(0.9131, 0.7913, 0.6105)
			roughness = 0.27
			coat = Vector2(0.18, 0.1972)
			patina_scale = 4.0
			grain_height = 0.0008
			interior = Vector3.ONE
			track_face = Vector3(1.45, 1.40, 1.32)
			north_face = Vector3.ONE
		_:
			return null
	var finish := ShaderMaterial.new()
	finish.shader = ARCHITECTURE
	finish.resource_name = source.resource_name
	finish.set_shader_parameter("interior_tint", interior)
	finish.set_shader_parameter("track_face_tint", track_face)
	finish.set_shader_parameter("north_face_tint", north_face)
	var web_metal := arch_metal and OS.has_feature("web")
	finish.set_shader_parameter("metalness", 0.83 if web_metal else source.metallic)
	if web_metal:
		finish.set_shader_parameter("use_arch_radiance", true)
		finish.set_shader_parameter("arch_radiance", glazing_reflection)
	finish.set_shader_parameter("exposed_metal_scale", exposed_metal_scale)
	finish.set_shader_parameter("edge_finish", edge_finish)
	if textured:
		if not source.albedo_texture or not source.roughness_texture or not source.normal_texture:
			return null
		finish.set_shader_parameter("textured", true)
		finish.set_shader_parameter("albedo_map", source.albedo_texture)
		finish.set_shader_parameter("finish_map", source.roughness_texture)
		finish.set_shader_parameter("normal_map", source.normal_texture)
		finish.set_shader_parameter("normal_depth", lerpf(source.normal_scale * 0.85, source.normal_scale, edge_finish))
		finish.set_shader_parameter("roughness_base", source.roughness * (0.82 if web_metal else 1.0))
		return finish
	finish.set_shader_parameter("dark_pigment", dark)
	finish.set_shader_parameter("light_pigment", light)
	finish.set_shader_parameter("roughness_base", roughness * (0.76 if web_metal else 1.0))
	finish.set_shader_parameter("coat_weight", coat.x)
	finish.set_shader_parameter("coat_roughness", coat.y)
	finish.set_shader_parameter("noise_aspect", aspect)
	finish.set_shader_parameter("patina_scale", patina_scale)
	finish.set_shader_parameter("grain_scale", grain_scale)
	finish.set_shader_parameter("grain_height", grain_height * 0.26)
	return finish


static func _track_finish(source: BaseMaterial3D) -> ShaderMaterial:
	var palette := Vector2(0.11, 0.44)
	var pigment := 0.54
	var brightness := 1.22
	match source.resource_name.get_slice(" · ", 0):
		"定稿｜沟槽铸铁":
			pass
		"精修｜临轨压边 ｜蓝灰矿物石":
			palette = Vector2(0.26, 0.55)
			pigment = 0.48
			brightness = 1.59
		_:
			return null

	var finish := ShaderMaterial.new()
	finish.shader = TRACK_FINISH
	finish.resource_name = source.resource_name
	finish.set_shader_parameter("base_color", source.albedo_color)
	finish.set_shader_parameter("roughness_factor", source.roughness)
	finish.set_shader_parameter("metallic_factor", source.metallic * 0.90)
	finish.set_shader_parameter("palette_range", palette)
	finish.set_shader_parameter("palette_mix", pigment)
	finish.set_shader_parameter("brightness", brightness)
	if source.albedo_texture:
		finish.set_shader_parameter("albedo_map", source.albedo_texture)
		finish.set_shader_parameter("has_albedo_map", true)
	if source.roughness_texture:
		finish.set_shader_parameter("finish_map", source.roughness_texture)
		finish.set_shader_parameter("has_finish_map", true)
	if source.normal_enabled and source.normal_texture:
		finish.set_shader_parameter("normal_map", source.normal_texture)
		finish.set_shader_parameter("normal_depth", source.normal_scale * 0.70)
		finish.set_shader_parameter("has_normal_map", true)
	return finish


static func add_cloud_volume(target: Node3D) -> MeshInstance3D:
	var web := OS.has_feature("web")
	var data := read_json("res://assets/volume/cloud-web-v048.json" if web else "res://assets/volume/cloud-v048.json")
	if data.is_empty():
		push_error("v048 cloud texture metadata is missing")
		return null
	var dimensions: Array = data["dimensions"]
	var width := int(dimensions[0])
	var height := int(dimensions[1])
	var depth := int(dimensions[2])
	var stride := width * height * 2
	var packed := FileAccess.get_file_as_bytes(
		"res://assets/volume/cloud-web-v048.rg8.gz" if web else "res://assets/volume/cloud-relief-v048.rg8.gz")
	var voxel_bytes := packed.decompress(stride * depth, FileAccess.COMPRESSION_GZIP)
	if voxel_bytes.size() != stride * depth:
		push_error("v048 cloud volume could not be read")
		return null
	var layers: Array[Image] = []
	for slice in depth:
		layers.append(Image.create_from_data(width, height, false, Image.FORMAT_RG8,
			voxel_bytes.slice(stride * slice, stride * (slice + 1))))
	var field := ImageTexture3D.new()
	var error := field.create(Image.FORMAT_RG8, width, height, depth, false, layers)
	if error != OK:
		push_error("Could not upload v048 cloud volume. Error %s" % error)
		return null

	var lower := vector(data["lower"])
	var upper := vector(data["upper"])
	var appearance := ShaderMaterial.new()
	appearance.shader = CLOUDS
	appearance.render_priority = -15
	appearance.set_shader_parameter("cloud_field", field)
	appearance.set_shader_parameter("cloud_min", lower)
	appearance.set_shader_parameter("cloud_max", upper)
	appearance.set_shader_parameter("authored_density_max", float(data["max_density"]))
	var box := BoxMesh.new()
	box.size = upper - lower
	var instance := MeshInstance3D.new()
	instance.name = "V048_OpenVDB_Cloud"
	instance.mesh = box
	instance.position = (upper + lower) * 0.5
	instance.material_override = appearance
	instance.layers = 8
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(instance)
	print("Loaded v048 density and sunlit grids: %s × %s × %s" % [width, height, depth])
	return instance
