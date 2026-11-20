extends Node3D

const Visuals := preload("res://scripts/stage_visuals.gd")
const Collision := preload("res://scripts/station_collision.gd")
const StationHUD := preload("res://scripts/station_hud.gd")
const StationClock := preload("res://scripts/station_clock.gd")
const FloorReflection := preload("res://scripts/floor_reflection.gd")
const BoardingMotion := preload("res://scripts/boarding_motion.gd")
const WebRenderBudget := preload("res://scripts/web_render_budget.gd")
const KEYS := ["platform", "overlook"]
const CAPTURE_KEYS := ["platform", "overlook", "viaduct", "carriage"]
const CLOUD_SPEED := 21.0
# West is negative X. The whole consist still fits on the modeled track here.
const WEST_APPROACH_X := -46.0
const ARRIVAL_CRUISE_TIME := 4.6
const ARRIVAL_BRAKING_TIME := 3.6

@onready var station: Node3D = $Station
@onready var train: Node3D = $Train
@onready var horizon: Node3D = $DistantScenery
@onready var framing: Camera3D = $FramingCamera
@onready var walker = $Walker

var hud: CanvasLayer
var native_cloud: MeshInstance3D
var reflection: FloorReflection
var stone_surfaces: Dictionary
var reflecting := false
var ambience: AudioStreamPlayer
var metadata: Dictionary
var walkable: Dictionary
var boarding: BoardingMotion
var boarding_available := false
var doors_open := false
var train_in_motion := false
var active_view := 0
var opening_active := true
var notice_sequence := 0
var station_clock: StationClock
var web_budget: WebRenderBudget


func _ready() -> void:
	metadata = Visuals.read_json("res://assets/v048/v048.json")
	if metadata.is_empty():
		push_error("v048 scene metadata is missing")
		return
	stone_surfaces = Visuals.prepare_model(station, 1)
	station_clock = StationClock.new()
	station_clock.configure(station)
	Visuals.prepare_model(train, 2)
	Visuals.prepare_model(horizon, 4)
	var environment := Visuals.build_environment(self)
	if DisplayServer.get_name() != "headless":
		reflection = FloorReflection.new()
		reflection.name = "DeckReflection"
		add_child(reflection)
		reflection.configure(environment)
		for stone: ShaderMaterial in stone_surfaces.values():
			stone.set_shader_parameter("reflected_scene", reflection.get_texture())
	Visuals.build_lights(self, train, metadata["lights"])
	for source: Dictionary in metadata["lights"]:
		if String(source["name"]).begins_with("月台斜光"):
			var color := Visuals.vector(source["color"]).lerp(Vector3.ONE, 0.36)
			for stone: ShaderMaterial in stone_surfaces.values():
				stone.set_shader_parameter("raking_lamp_position", Visuals.vector(source["position"]))
				stone.set_shader_parameter("raking_lamp_color", color)
			break
	native_cloud = Visuals.add_cloud_volume(self)
	if OS.has_feature("web"):
		web_budget = WebRenderBudget.new()
		web_budget.configure(get_viewport(), native_cloud)
	walkable = Collision.build(self, station, train)
	boarding = BoardingMotion.new()
	boarding.name = "V048_BoardingMotion"
	train.add_child(boarding)
	var boarding_tracks := Visuals.read_json("res://assets/v048/boarding-v048.json")
	boarding_available = boarding.configure(train, boarding_tracks, metadata["doors"])
	_bind_movement_keys()
	if not OS.has_feature("web"):
		_add_ambience()

	hud = StationHUD.new()
	hud.name = "StationHUD"
	add_child(hud)
	hud.enter_requested.connect(enter_station)
	hud.shot_requested.connect(select_view)
	hud.walk_requested.connect(begin_walk)

	print("Loaded v048 station, railcars and distant scenery. Boarding animations ready: ", boarding_available)
	var args := OS.get_cmdline_user_args()
	var capture_arg := args.find("--capture-dir")
	if capture_arg >= 0 and capture_arg + 1 < args.size():
		_capture_views(args[capture_arg + 1])
	elif DisplayServer.get_name() == "headless":
		enter_station()
	else:
		_pose_camera("viaduct")
		print("Station opening ready")


func enter_station() -> void:
	if not opening_active:
		return
	opening_active = false
	hud.show_opening(false)
	select_view(0)
	if OS.has_feature("web"):
		_add_ambience()
	_start_first_arrival()


func _start_first_arrival() -> void:
	train_in_motion = true
	train.position.x = WEST_APPROACH_X
	await get_tree().create_timer(1.0).timeout
	await _arrive_from_west()


func _bind_movement_keys() -> void:
	var keys := {"walk_left": KEY_A, "walk_right": KEY_D, "walk_forward": KEY_W, "walk_back": KEY_S}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var input := InputEventKey.new()
		input.physical_keycode = keys[action]
		InputMap.action_add_event(action, input)


func _add_ambience() -> void:
	if "--capture-dir" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	ambience = AudioStreamPlayer.new()
	var stream := preload("res://assets/reference/station-wind.mp3").duplicate() as AudioStreamMP3
	stream.loop = true
	ambience.stream = stream
	ambience.volume_db = -21
	add_child(ambience)
	ambience.play()


func select_view(index: int) -> void:
	if index < 0 or index >= KEYS.size():
		return
	active_view = index
	walker.walking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pose_camera(KEYS[index])
	if index == 1:
		framing.far = 1800.0
	_update_hud()


func _pose_camera(key: String) -> void:
	var pose: Dictionary = metadata["cameras"][key]
	framing.position = Visuals.vector(pose["position"])
	framing.quaternion = Visuals.rotation_of(pose["rotation"])
	framing.fov = float(pose["fov"])
	framing.near = float(pose["near"])
	framing.far = float(pose["far"])
	framing.make_current()


func begin_walk() -> void:
	if opening_active or active_view != 0:
		return
	if not walker.walking:
		var pose: Dictionary = metadata["cameras"]["platform"]
		var place := Visuals.vector(pose["position"])
		place.y = Collision.PLATFORM_TOP + 0.040
		var front := Visuals.rotation_of(pose["rotation"]) * Vector3.FORWARD
		walker.enter(place, front)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()


func _update_hud() -> void:
	hud.set_display(active_view, walker.walking, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func _notice(content: String) -> void:
	notice_sequence += 1
	var serial := notice_sequence
	hud.show_message(content)
	await get_tree().create_timer(3.2).timeout
	if notice_sequence == serial:
		hud.show_message("")


func _set_doors(open: bool) -> void:
	if not boarding_available:
		return
	if boarding.is_playing():
		await boarding.animation_finished
	if open == doors_open:
		return
	doors_open = open
	if not open:
		_set_boarding(false)
	boarding.play(BoardingMotion.DEPLOY if open else BoardingMotion.RETRACT)
	await boarding.animation_finished
	if doors_open:
		_set_boarding(true)


func _set_boarding(enabled: bool) -> void:
	for ramp: CollisionShape3D in walkable["ramps"]:
		ramp.set_deferred("disabled", not enabled)
	for guard: CollisionShape3D in walkable["guards"]:
		guard.set_deferred("disabled", enabled)


func request_door() -> void:
	if train_in_motion:
		_notice("列车进站停稳后可以开门")
		return
	if not boarding_available or boarding.is_playing():
		return
	if doors_open and walker.walking and Collision.on_boarding_steps(walker.position):
		_notice("请先离开登车踏梯")
		return
	var open := not doors_open
	_notice("车门开启，踏梯展开中" if open else "踏梯正在收起")
	await _set_doors(open)
	if not train_in_motion:
		_notice("踏梯已放下，可以登车" if open else "踏梯已收起，车门已关闭")


func run_train_cycle() -> void:
	if train_in_motion:
		return
	if walker.walking and (walker.position.z >= 3.90 or Collision.on_boarding_steps(walker.position)):
		_notice("回到月台内侧后可运行列车演示")
		return
	train_in_motion = true
	await _set_doors(false)
	_notice("列车驶离月台")
	var departure := create_tween()
	departure.tween_property(train, "position:x", WEST_APPROACH_X, 6.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	departure.tween_interval(0.7)
	await departure.finished
	await _arrive_from_west()


func _arrive_from_west() -> void:
	_notice("列车正从西侧进站")
	# Match the speed at the transition from coasting to quadratic braking.
	var speed := absf(WEST_APPROACH_X) / (ARRIVAL_CRUISE_TIME + ARRIVAL_BRAKING_TIME * 0.5)
	var braking_start := -speed * ARRIVAL_BRAKING_TIME * 0.5
	var arrival := create_tween()
	arrival.tween_property(train, "position:x", braking_start, ARRIVAL_CRUISE_TIME)
	arrival.tween_property(train, "position:x", 0.0, ARRIVAL_BRAKING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await arrival.finished
	_notice("列车已停稳，踏梯展开中" if boarding_available else "列车已停稳")
	await _set_doors(true)
	train_in_motion = false
	if boarding_available:
		_notice("踏梯已放下，可以登车")


func _process(delta: float) -> void:
	if web_budget:
		web_budget.tick()
	if station_clock and station_clock.update_from_system() and reflection:
		reflection.needs_refresh = true
	if not opening_active and active_view == 1 and get_window().has_focus():
		var planar := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
		var vertical := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
		var movement := framing.basis * Vector3(planar.x, 0, planar.y) + Vector3.UP * vertical
		if not movement.is_zero_approx():
			_move_cloud_camera(movement.limit_length() * CLOUD_SPEED * delta)
	if walker.walking and walker.position.y < 7.5:
		walker.walking = false
		active_view = 0
		begin_walk()
	if reflection:
		var moving_scene := train_in_motion or boarding.is_playing()
		var enabled := reflection.follow(get_viewport().get_camera_3d(), true, moving_scene)
		if reflecting != enabled:
			reflecting = enabled
			for stone: ShaderMaterial in stone_surfaces.values():
				stone.set_shader_parameter("reflect_deck", reflecting)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ambience):
		ambience.stop()


func _unhandled_input(event: InputEvent) -> void:
	if opening_active:
		return
	if active_view == 1 and _cloud_camera_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and walker.walking and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		walker.look_around(event.screen_relative)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if active_view == 0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			begin_walk()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode:
		KEY_1, KEY_F1: select_view(0)
		KEY_2, KEY_F2: select_view(1)
		KEY_TAB, KEY_W, KEY_A, KEY_S, KEY_D:
			if active_view == 0 and (not walker.walking or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
				begin_walk()
		KEY_HOME:
			if active_view == 1:
				select_view(1)
		KEY_E:
			if active_view == 0:
				request_door()
		KEY_T: run_train_cycle()
		KEY_H: hud.toggle_interface()
		KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if hud.interface_hidden:
				hud.toggle_interface()
			_update_hud()


func _move_cloud_camera(offset: Vector3) -> void:
	# Keep the camera within the rendered sky and distant scenery.
	framing.position = (framing.position + offset).clamp(Vector3(-360, -24, -360), Vector3(360, 220, 360))


func _cloud_camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var motion: Vector2 = event.screen_relative
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_move_cloud_camera((framing.basis.x * -motion.x + framing.basis.y * motion.y) * 0.072)
			return true
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var pitch := clampf(framing.rotation.x - motion.y * 0.0035, -1.55, 1.55)
			var yaw := wrapf(framing.rotation.y - motion.x * 0.0035, -PI, PI)
			framing.rotation = Vector3(pitch, yaw, 0)
			return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var sign := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			var factor := clampf(event.factor, 0.22, 4.0) if event.factor > 0.0 else 1.0
			_move_cloud_camera(-framing.basis.z * (sign * factor * 5.5))
			return true
	return false


func _capture_views(directory: String) -> void:
	await get_tree().process_frame
	_pose_camera("viaduct")
	for frame in 14:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("opening.png"))
	hud.hide()
	for key in CAPTURE_KEYS:
		_pose_camera(key)
		for frame in 14:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(directory.path_join(key + ".png"))
		print("Captured live v048 view ", key, " at ", image.get_size())
	hud.show()
	hud.show_opening(false)
	select_view(0)
	for frame in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("godot-preview.png"))
	get_tree().quit()
