extends RefCounted

const SCALES := [1.0, 1.0, 1.0, 0.875, 0.75]
const CLOUD_STEPS := [54, 50, 46, 42, 38]
const TARGET_FPS := 90.0
const SAMPLE_SECONDS := 1.0
const RECOVERY_SECONDS := 8.0

var viewport: Viewport
var clouds: ShaderMaterial
var metrics: JavaScriptObject
var target_fps := TARGET_FPS
var native_resolution := false
var level := 0
var frame_count := 0
var sample_time := 0.0
var stable_time := 0.0
var warmup := 2.0
var last_tick := 0
var highest_level := SCALES.size() - 1
var fps_before_scaling := 0.0


func configure(target: Viewport, cloud: MeshInstance3D) -> void:
	viewport = target
	if cloud:
		clouds = cloud.material_override as ShaderMaterial
	var browser := JavaScriptBridge.get_interface("window")
	if browser:
		var refresh: Variant = browser.stationDisplayHz
		if refresh is float or refresh is int:
			target_fps = clampf(float(refresh), 30.0, TARGET_FPS)
		native_resolution = browser.stationNativeResolution == true
		metrics = browser.liminalRender
	_apply_quality()


func tick() -> void:
	if native_resolution and not metrics:
		return
	var now := Time.get_ticks_usec()
	var seconds := float(now - last_tick) / 1000000.0
	last_tick = now
	if seconds > 0.4:
		frame_count = 0
		sample_time = 0.0
		stable_time = 0.0
		return
	if warmup > 0.0:
		warmup -= seconds
		return
	frame_count += 1
	sample_time += seconds
	if sample_time < SAMPLE_SECONDS:
		return
	var fps := frame_count / sample_time
	if fps_before_scaling > 0.0 and fps < fps_before_scaling * 1.04:
		# Internal scaling adds a resolve pass on WebGL. Keep the previous
		# resolution when lowering it costs more time than it saves.
		highest_level = level - 1
		level = highest_level
		fps_before_scaling = 0.0
		_apply_quality()
	elif not native_resolution and fps < target_fps * 0.90 and level < highest_level:
		fps_before_scaling = fps if SCALES[level + 1] < SCALES[level] else 0.0
		level += 1
		stable_time = 0.0
		_apply_quality()
	elif fps >= target_fps * 0.98:
		fps_before_scaling = 0.0
		stable_time += sample_time
		if not native_resolution and stable_time >= RECOVERY_SECONDS and level > 0:
			level -= 1
			stable_time = 0.0
			_apply_quality()
	else:
		fps_before_scaling = 0.0
		stable_time = 0.0
	if metrics:
		metrics.fps = snappedf(fps, 0.1)
		metrics.target = target_fps
		metrics.drawCalls = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		metrics.triangles = viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	frame_count = 0
	sample_time = 0.0


func _apply_quality() -> void:
	viewport.scaling_3d_scale = SCALES[level]
	viewport.mesh_lod_threshold = 3.0 + float(level) * 1.25
	if clouds:
		clouds.set_shader_parameter("march_steps", CLOUD_STEPS[level])
	if metrics:
		metrics.scale = SCALES[level]
