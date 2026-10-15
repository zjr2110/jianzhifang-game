# 剪纸坊
# sheet.gd - 底部面板
extends Control

signal closed

const Ui = preload("res://scripts/ui_style.gd")

var panel: PanelContainer
var content: VBoxContainer
var title_text := ""
var bottom_pad := 0.0
var max_ratio := 0.88

var _dim: ColorRect
var _drag_from := -1.0
var _drag_y0 := 0.0
var _closing := false
var _rest_y := 0.0


func _init(p_title := "", p_bottom_pad := 0.0) -> void:
	title_text = p_title
	bottom_pad = p_bottom_pad


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.1, 0.08, 0.05, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(_dim)

	panel = PanelContainer.new()
	var st := Ui.card_box(34, Ui.BG, true, 0)
	st.corner_radius_bottom_left = 0
	st.corner_radius_bottom_right = 0
	st.shadow_size = 30
	st.shadow_offset = Vector2(0, -4)
	panel.add_theme_stylebox_override("panel", st)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_panel_input)
	panel.position = Vector2(0, 100000)
	add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_right", 28)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", int(24 + bottom_pad))
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(m)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	outer.mouse_filter = Control.MOUSE_FILTER_PASS
	m.add_child(outer)
	var grab := CenterContainer.new()
	grab.mouse_filter = Control.MOUSE_FILTER_PASS
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(76, 10)
	bar.add_theme_stylebox_override("panel", Ui.card_box(5, Color("d3cdc2"), false, 0))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grab.add_child(bar)
	outer.add_child(grab)
	if title_text != "":
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_PASS
		var t := Ui.title(title_text, Ui.T_TITLE3)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var x := Ui.icon_button("close", 56, Ui.LABEL2, Ui.FILL)
		x.pressed.connect(close)
		head.add_child(x)
		outer.add_child(head)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	outer.add_child(content)


func open() -> void:
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var w := size.x
	panel.reset_size()
	var h := minf(panel.get_combined_minimum_size().y, size.y * max_ratio)
	panel.size = Vector2(w, h)
	_rest_y = size.y - h
	panel.position = Vector2(0, size.y)
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "position:y", _rest_y, 0.45).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim, "color:a", 0.32, 0.3)


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "position:y", size.y, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_dim, "color:a", 0.0, 0.28)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())


func _panel_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed and e.position.y < 110.0:
			_drag_from = e.global_position.y
			_drag_y0 = panel.position.y
		elif not e.pressed and _drag_from >= 0.0:
			_drag_from = -1.0
			if panel.position.y - _rest_y > 140.0:
				close()
			else:
				create_tween().tween_property(panel, "position:y", _rest_y, 0.35).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	elif e is InputEventMouseMotion and _drag_from >= 0.0:
		panel.position.y = maxf(_rest_y, _drag_y0 + e.global_position.y - _drag_from)
