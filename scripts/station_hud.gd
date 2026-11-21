extends CanvasLayer

signal enter_requested
signal shot_requested(index: int)
signal walk_requested

const INK := Color("#fff5e7")
const GOLD := Color("#f2cd9e")
const MUTED := Color("#d1c5b5")
const NAVY := Color("#17283a")
const PANEL_BG := Color("#101d2eea")
const PANEL_EDGE := Color("#d7ad7460")
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
	if not OS.has_feature("web"):
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
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.grow_vertical = Control.GROW_DIRECTION_BEGIN
	copy.add_theme_constant_override("separation", 11)
	opening.add_child(copy)
	copy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	copy.offset_left = 96
	copy.offset_right = 398
	copy.offset_top = -234
	copy.offset_bottom = -88
	var brand := HBoxContainer.new()
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_theme_constant_override("separation", 8)
	copy.add_child(brand)
	brand.add_child(_emblem(23))
	var caption := _label("L I M I N A L   S K Y   S T A T I O N", 12, GOLD, title_font, true)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(caption)
	copy.add_child(_label("天空车站", 60, INK, OPENING_LETTERING, true))
	var enter := _button("进入车站  ↗")
	enter.name = "EnterStation"
	enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	enter.custom_minimum_size = Vector2(126, 39)
	enter.focus_mode = Control.FOCUS_ALL
	enter.add_theme_font_override("font", bold)
	enter.add_theme_font_size_override("font_size", 15)
	_style_button(enter, true)
	var focus := _panel(Color.TRANSPARENT, Color("#fff0cc"), 7)
	focus.draw_center = false
	focus.set_expand_margin_all(3.0)
	enter.add_theme_stylebox_override("focus", focus)
	enter.pressed.connect(func(): enter_requested.emit())
	copy.add_child(enter)
	enter.grab_focus()


func _build_interface() -> void:
	chrome = _full_layer(interface_root)

	var identity := PanelContainer.new()
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.position = Vector2(22, 18)
	identity.add_theme_stylebox_override("panel", _panel(PANEL_BG, PANEL_EDGE, 8, Vector2(9, 5)))
	chrome.add_child(identity)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 7)
	identity.add_child(header)
	header.add_child(_emblem(24))
	header.add_child(_label("L I M I N A L", 13, INK, title_font))
	header.add_child(_divider(15))
	mode_label = _label("月台", 13, GOLD, sans)
	header.add_child(mode_label)

	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 6)
	chrome.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -105
	footer.offset_bottom = -16
	notice_panel = PanelContainer.new()
	notice_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_panel.add_theme_stylebox_override("panel", _panel(PANEL_BG, PANEL_EDGE, 8))
	footer.add_child(notice_panel)
	notice_panel.hide()
	toast = _label("", 13, GOLD, sans)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_panel.add_child(toast)
	var dock := PanelContainer.new()
	dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_stylebox_override("panel", _panel(PANEL_BG, PANEL_EDGE, 10, Vector2(4, 4)))
	footer.add_child(dock)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 4)
	dock.add_child(bar)
	for index in 2:
		var button := _button(["月台", "云海"][index])
		button.name = ["PlatformView", "CloudView"][index]
		button.pressed.connect(func(): shot_requested.emit(index))
		bar.add_child(button)
		shot_buttons.append(button)
	bar.add_child(_divider(17))
	walk_button = _button("步行探索")
	walk_button.pressed.connect(func(): walk_requested.emit())
	bar.add_child(walk_button)
	reset_button = _button("复位镜头")
	reset_button.pressed.connect(func(): shot_requested.emit(1))
	bar.add_child(reset_button)
	hint = _label("", 13, MUTED, sans, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(hint)

	toggle_button = _button("隐藏界面")
	toggle_button.name = "ToggleInterface"
	toggle_button.tooltip_text = "隐藏或显示界面（H）"
	toggle_button.pressed.connect(toggle_interface)
	interface_root.add_child(toggle_button)
	toggle_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle_button.offset_left = -116
	toggle_button.offset_right = -22
	toggle_button.offset_top = 18
	toggle_button.offset_bottom = 52


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
		hint.text = "拖动环视  ·  右键平移  ·  滚轮进退  ·  WASD 移动  ·  Q / E 升降"
	elif captured:
		hint.text = "WASD 步行  ·  鼠标环视  ·  E 开门  ·  Esc 释放光标"
	else:
		hint.text = "Tab 步行  ·  E 开门  ·  T 重播进站  ·  H 隐藏界面"
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


func _divider(height: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.color = PANEL_EDGE
	rule.custom_minimum_size = Vector2(1, height)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rule


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
		style.shadow_size = 3
	label.label_settings = style
	return label


func _panel(bg: Color, outline: Color, radius := 7, padding := Vector2(10, 4)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	return style


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(70, 32)
	button.add_theme_font_override("font", sans)
	button.add_theme_font_size_override("font_size", 14)
	_style_button(button, false)
	return button


func _style_button(button: Button, selected: bool, tab := false) -> void:
	var dormant := PANEL_BG
	var rim := PANEL_EDGE
	if tab and not selected:
		dormant = Color.TRANSPARENT
		rim = Color.TRANSPARENT
	button.add_theme_stylebox_override("normal", _panel(GOLD if selected else dormant, GOLD if selected else rim))
	button.add_theme_stylebox_override("hover", _panel(Color("#ffe2bd") if selected else Color("#2c4257"), GOLD))
	button.add_theme_stylebox_override("pressed", _panel(Color("#dfb787"), GOLD))
	var text_color := NAVY if selected else INK
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_pressed_color", NAVY)
