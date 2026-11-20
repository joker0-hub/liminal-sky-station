extends SubViewport

const DECK_HEIGHT := 10.514
const MIRROR := Vector3(1.0, -1.0, 1.0)
const PLATFORM_LAYER := 1 << 5
const STILL_HEIGHT := 900
const MOVING_HEIGHT := 540
const WEB_HEIGHT := 432
const SETTLE_MSEC := 160

var reflection_camera: Camera3D
var last_view := Transform3D.IDENTITY
var last_fov := 0.0
var needs_refresh := true
var last_motion_msec := 0


func configure(source_environment: Environment) -> void:
	size = Vector2i(960, MOVING_HEIGHT)
	use_hdr_2d = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	scaling_3d_scale = 1.0
	positional_shadow_atlas_size = 0
	render_target_update_mode = SubViewport.UPDATE_DISABLED

	var reflection_environment := source_environment.duplicate() as Environment
	reflection_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	reflection_environment.tonemap_exposure = 1.0
	reflection_environment.ssr_enabled = false
	reflection_environment.ssao_enabled = false
	reflection_environment.ssil_enabled = false
	reflection_environment.glow_enabled = false
	reflection_environment.volumetric_fog_enabled = false
	reflection_environment.adjustment_enabled = false

	reflection_camera = Camera3D.new()
	reflection_camera.environment = reflection_environment
	reflection_camera.cull_mask = PLATFORM_LAYER | 2 | 4
	add_child(reflection_camera)
	reflection_camera.make_current()


func follow(source: Camera3D, active: bool, moving_scene: bool) -> bool:
	if not active or source == null:
		return _hide_reflection()
	var source_pose := source.get_camera_transform()
	var altitude := source_pose.origin.y - DECK_HEIGHT
	var near_platform := altitude > 0.02 and altitude < 5.0 and source_pose.origin.z < 3.9
	if not near_platform:
		return _hide_reflection()
	var display := get_parent().get_viewport().get_visible_rect().size
	var aspect := display.x / maxf(display.y, 1.0)
	var facing := source_pose.basis.orthonormalized()
	var vertical_edge := tan(deg_to_rad(source.fov * 0.5))
	var downward_edge := -facing.z.y - vertical_edge * (absf(facing.y.y) + aspect * absf(facing.x.y))
	if downward_edge >= 0.01:
		return _hide_reflection()
	var camera_changed := source_pose != last_view or source.fov != last_fov
	var now := Time.get_ticks_msec()
	if camera_changed or moving_scene:
		last_motion_msec = now
	var moving := now - last_motion_msec < SETTLE_MSEC
	# Keep the sampled viewport texture allocated while the Web camera moves.
	var max_height := WEB_HEIGHT if OS.has_feature("web") else (MOVING_HEIGHT if moving else STILL_HEIGHT)
	var height := clampi(roundi(display.y), 8, max_height)
	var target_size := Vector2i(maxi(8, roundi(height * aspect)), height)
	if not (needs_refresh or moving_scene or camera_changed or size != target_size):
		return true

	var position := source_pose.origin
	position.y = DECK_HEIGHT - altitude
	var flipped := Basis(-facing.x * MIRROR, facing.y * MIRROR, facing.z * MIRROR)
	reflection_camera.global_transform = Transform3D(flipped, position)
	reflection_camera.fov = source.fov
	reflection_camera.near = source.near
	reflection_camera.far = source.far
	if size != target_size:
		size = target_size
	last_view = source_pose
	last_fov = source.fov
	needs_refresh = false
	render_target_update_mode = SubViewport.UPDATE_ONCE
	return true


func _hide_reflection() -> bool:
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	needs_refresh = true
	return false
