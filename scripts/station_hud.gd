extends CanvasLayer

signal enter_requested
signal shot_requested(index: int)
signal walk_requested

const INK := Color("#fff5e7")
const GOLD := Color("#f2cd9e")
const NAVY := Color("#192d43")
const COPPER := Color("#8b4c43")
const COMPASS := preload("res://assets/reference/compass.png")
const OPENING_LETTERING := preload("res://assets/fonts/liminal-title.ttf")

var title_font: Font
var sans: Font
var bold: Font
var opening: Control
var interface_root: Control
var chrome: Control
var mode_label: Label
var hint: Label
var toast: Label
var notice_panel: PanelContainer
var walk_button: Button
var reset_button: Button
var toggle_button: Button
var shot_buttons: Array[Button] = []
var interface_hidden := false


func _ready() -> void:
	_set_fonts()
	opening = _full_layer(self)
	interface_root = _full_layer(self)
	_build_opening()
	_build_interface()
	interface_root.hide()


func _set_fonts() -> void:
	if OS.has_feature("web"):
		sans = preload("res://assets/fonts/liminal-sans.ttf")
		title_font = sans
		var heavy := FontVariation.new()
		heavy.base_font = sans
		heavy.variation_opentype = {"wght": 700}
		bold = heavy
		return
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	title_font = serif
	var regular := SystemFont.new()
	regular.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	sans = regular
	var heavy := regular.duplicate() as SystemFont
	heavy.font_weight = 700
	bold = heavy


func _build_opening() -> void:
	var paper := Color("#faf2e4")
	var wash := _gradient(
		[paper, Color(paper, 0.96), Color(paper, 0.78), Color(paper, 0.27), Color(paper, 0.0)],
		[0.0, 0.18, 0.34, 0.51, 0.70], Vector2.RIGHT)
	opening.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var mark := _emblem(43)
	mark.position = Vector2(53, 36)
	mark.modulate = COPPER
	opening.add_child(mark)

	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 17)
	opening.add_child(copy)
	copy.set_anchor_and_offset(SIDE_RIGHT, 0.054, 0)
	copy.set_anchor_and_offset(SIDE_LEFT, 0.054, 0)
	copy.set_anchor_and_offset(SIDE_BOTTOM, 0.50, -151)
	copy.set_anchor_and_offset(SIDE_TOP, 0.50, -151)
	var kicker := VBoxContainer.new()
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kicker.add_theme_constant_override("separation", 9)
	copy.add_child(kicker)
	kicker.add_child(_label("云 端 铁 路", 19, COPPER, bold))
	var line := ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Color("#aa6756")
	line.custom_minimum_size = Vector2(121, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	kicker.add_child(line)
	copy.add_child(_label("天空车站", 128, NAVY, OPENING_LETTERING))
	copy.add_child(_label("L I M I N A L   S K Y   S T A T I O N", 20, Color("#354c64"), title_font))
	var enter := _button("进入车站  ↗")
	enter.name = "EnterStation"
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enter.custom_minimum_size = Vector2(194, 56)
	enter.focus_mode = Control.FOCUS_ALL
	enter.add_theme_font_override("font", bold)
	enter.add_theme_font_size_override("font_size", 21)
	enter.add_theme_stylebox_override("normal", _panel(NAVY, Color("#b17461"), 6, 2))
	enter.add_theme_stylebox_override("hover", _panel(Color("#2f4c66"), COPPER, 6, 2))
	enter.add_theme_stylebox_override("pressed", _panel(Color("#102235"), COPPER, 6, 2))
	enter.add_theme_color_override("font_pressed_color", INK)
	enter.pressed.connect(func(): enter_requested.emit())
	copy.add_child(enter)
	enter.grab_focus()


func _build_interface() -> void:
	chrome = _full_layer(interface_root)
	var top_shade := _gradient([Color("#13223b79"), Color("#13223b00")], [0.0, 1.0], Vector2.DOWN)
	chrome.add_child(top_shade)
	top_shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_shade.offset_bottom = 128
	var bottom_shade := _gradient([Color("#13223b00"), Color("#13223b8e")], [0.0, 1.0], Vector2.DOWN)
	chrome.add_child(bottom_shade)
	bottom_shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_shade.offset_top = -132

	var identity := PanelContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.position = Vector2(34, 24)
	identity.add_theme_stylebox_override("panel", _panel(Color("#102039c6"), Color("#dbc29168"), 13))
	chrome.add_child(identity)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 13)
	identity.add_child(header)
	header.add_child(_emblem(37))
	var caption := VBoxContainer.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("separation", 2)
	header.add_child(caption)
	caption.add_child(_label("L I M I N A L", 24, INK, title_font))
	mode_label = _label("月台", 15, GOLD, sans)
	caption.add_child(mode_label)

	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 9)
	chrome.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -143
	footer.offset_bottom = -22
	notice_panel = PanelContainer.new()
	notice_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.add_theme_stylebox_override("panel", _panel(Color("#102039d8"), Color("#d9b98169"), 10))
	footer.add_child(notice_panel)
	notice_panel.hide()
	toast = _label("", 16, GOLD, sans, true)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_panel.add_child(toast)
	var dock := PanelContainer.new()
	dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim := _panel(Color("#102038e8"), Color("#ebcd9ea6"), 15)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		rim.set_content_margin(side, 6.0)
	dock.add_theme_stylebox_override("panel", rim)
	footer.add_child(dock)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 5)
	dock.add_child(bar)
	for index in 2:
		var button := _button(["月台", "云海"][index])
		button.name = ["PlatformView", "CloudView"][index]
		button.pressed.connect(func(): shot_requested.emit(index))
		bar.add_child(button)
		shot_buttons.append(button)
	var divider := ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color("#f4d9ae42")
	divider.custom_minimum_size = Vector2(1, 25)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(divider)
	walk_button = _button("步行探索")
	walk_button.pressed.connect(func(): walk_requested.emit())
	bar.add_child(walk_button)
	reset_button = _button("复位镜头")
	reset_button.pressed.connect(func(): shot_requested.emit(1))
	bar.add_child(reset_button)
	hint = _label("", 15, INK, sans, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(hint)

	toggle_button = _button("隐藏界面")
	toggle_button.name = "ToggleInterface"
	toggle_button.tooltip_text = "隐藏或显示界面（H）"
	toggle_button.pressed.connect(toggle_interface)
	interface_root.add_child(toggle_button)
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle_button.offset_left = -159
	toggle_button.offset_right = -34
	toggle_button.offset_top = 26
	toggle_button.offset_bottom = 69


func show_opening(show_intro: bool) -> void:
	opening.visible = show_intro
	interface_root.visible = not show_intro


func toggle_interface() -> void:
	interface_hidden = not interface_hidden
	chrome.visible = not interface_hidden
	toggle_button.text = "显示界面" if interface_hidden else "隐藏界面"


func set_display(index: int, walking: bool, captured: bool) -> void:
	var cloud_view := index == 1
	var view_name := "云海" if cloud_view else ("自由探索" if walking else "月台")
	mode_label.text = view_name
	if cloud_view:
		hint.text = "拖动环视   ·   右键平移   ·   滚轮进退   ·   WASD 移动   ·   Q / E 升降"
	elif captured:
		hint.text = "WASD 步行   ·   鼠标环视   ·   E 开门   ·   Esc 释放光标"
	else:
		hint.text = "Tab 步行探索   ·   E 开门   ·   T 重播进站   ·   H 隐藏界面"
	for slot in shot_buttons.size():
		_style_button(shot_buttons[slot], slot == index, true)
	walk_button.visible = not cloud_view
	reset_button.visible = cloud_view
	_style_button(walk_button, walking)


func show_message(message: String) -> void:
	toast.text = message
	notice_panel.visible = not message.is_empty()


func _full_layer(parent: Node) -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer


func _gradient(colors: PackedColorArray, offsets: PackedFloat32Array, direction: Vector2) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var paint := GradientTexture2D.new()
	paint.gradient = gradient
	paint.fill_to = direction
	paint.width = 640
	paint.height = 192
	var rect := TextureRect.new()
	rect.texture = paint
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _emblem(side: int) -> TextureRect:
	var emblem := TextureRect.new()
	emblem.texture = COMPASS
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(side, side)
	emblem.size = emblem.custom_minimum_size
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return emblem


func _label(text: String, point_size: int, color: Color, letterform: Font, shadow := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := LabelSettings.new()
	style.font = letterform
	style.font_size = point_size
	style.font_color = color
	if shadow:
		style.shadow_color = Color("#091426ec")
		style.shadow_size = 4
	label.label_settings = style
	return label


func _panel(bg: Color, outline: Color, radius := 9, edge := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = outline
	style.set_border_width_all(edge)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(94, 41)
	button.add_theme_font_override("font", sans)
	button.add_theme_font_size_override("font_size", 16)
	_style_button(button, false)
	return button


func _style_button(button: Button, selected: bool, tab := false) -> void:
	var dormant := Color("#192d43eb")
	var rim := Color("#eee2d581")
	if tab and not selected:
		dormant = Color.TRANSPARENT
		rim = Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", _panel(GOLD if selected else dormant, GOLD if selected else rim))
	button.add_theme_stylebox_override("hover", _panel(Color("#ffe2bd") if selected else Color("#344f6b"), GOLD))
	button.add_theme_stylebox_override("pressed", _panel(GOLD, GOLD))
	var text_color := NAVY if selected else INK
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", NAVY)
