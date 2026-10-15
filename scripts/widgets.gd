# 剪纸坊
# widgets.gd - 通用界面组件
extends RefCounted

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const PaperShader = preload("res://shaders/paper.gdshader")
const FoldGeom = preload("res://scripts/fold_geom.gd")
const Stamps = preload("res://scripts/stamps.gd")


# 方孔铜钱
class CoinIcon extends Control:
	func _init(d := 34.0) -> void:
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color("a8792a"))
		draw_circle(c, r * 0.84, Color("e2b453"))
		var h := r * 0.3
		draw_rect(Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), Color("8a5d1c"))


# 铜钱胶囊
class CoinPill extends PanelContainer:
	var value := 0
	var _label: Label

	func _init(v := 0, size := Ui.T_BODY) -> void:
		value = v
		add_theme_stylebox_override("panel", Ui.pill_box(Ui.CARD, 18, 8, true))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		h.add_child(CoinIcon.new(size * 1.05))
		_label = Ui.label(str(v), size, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
		h.add_child(_label)

	func add_child_chevron() -> void:
		var ch := Icon.new("chevron", Ui.LABEL3, 24)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		get_child(0).add_child(ch)

	func set_value(v: int, animate := true) -> void:
		if animate:
			Ui.count_to(_label, value, v, 0.9)
		else:
			_label.text = str(v)
		value = v


static func coin_badge(amount: int, size := 28) -> Control:
	return CoinPill.new(amount, size)


# 折法图标
class FoldIcon extends Control:
	var geom := {}
	var tint := Color("c8102e")

	func _init(f := "eight", d := 88.0) -> void:
		geom = FoldGeom.build(f)
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var b: Rect2 = geom["bounds"]
		var r := Rect2(Vector2.ZERO, size).grow(-6)
		var s := minf(r.size.x / b.size.x, r.size.y / b.size.y)
		var o := r.get_center() - b.get_center() * s
		var w: PackedVector2Array = geom["wedge"]
		for g in geom["cells"]:
			var pts := PackedVector2Array()
			for p in g * w:
				pts.append(o + p * s)
			draw_colored_polygon(pts, tint)
		for g in geom["cells"]:
			var pts := PackedVector2Array()
			for p in g * w:
				pts.append(o + p * s)
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 1, 1, 0.55), 1.2, true)
		var top := PackedVector2Array()
		for p in w:
			top.append(o + p * s)
		draw_colored_polygon(top, tint.lightened(0.22))


# 纹样图标
class StampIcon extends Control:
	var stamp := "moon"
	var color := Color("1c1c1e")

	func _init(id := "moon", d := 64.0, c := Color("1c1c1e")) -> void:
		stamp = id
		color = c
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.78
		for poly in Stamps.placed(stamp, c, 0.0, s):
			draw_colored_polygon(poly, color)


# 纸样色块
static func paper_swatch(paper_id: String, d := 88.0, round := false) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(d, d)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := _swatch_material(paper_id, 2.2)
	mat.set_shader_parameter("circle", round)
	r.material = mat
	return r


# 样稿缩略图
static func template_thumb(tpl: Dictionary, d := 150.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tpl["texture"]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(d, d)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := _swatch_material(tpl["paper"], 1000.0 / d)
	mat.set_shader_parameter("tex_px", Vector2(tpl["image"].get_width(), tpl["image"].get_height()))
	t.material = mat
	return t


static func _swatch_material(paper_id: String, wscale: float) -> ShaderMaterial:
	var info: Dictionary = Game.PAPERS[paper_id]
	var mat := ShaderMaterial.new()
	mat.shader = PaperShader
	mat.set_shader_parameter("paper_color", info["color"])
	mat.set_shader_parameter("gold_amount", info.get("gold", 0.0))
	mat.set_shader_parameter("gloss", info.get("gloss", 0.0))
	mat.set_shader_parameter("metal", info.get("metal", 0.0))
	mat.set_shader_parameter("fiber_amount", info.get("fiber", 1.0))
	mat.set_shader_parameter("cloud_amount", info.get("cloud", 1.0))
	mat.set_shader_parameter("w_scale", Vector2(wscale, wscale))
	mat.set_shader_parameter("tex_px", Vector2(256, 256))
	return mat


# 选择卡片
static func card(icon: Control, title: String, desc: String, price: String, selected: bool, locked: bool) -> PanelContainer:
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := Ui.card_box(20, Ui.CARD, not selected, 14)
	if selected:
		style.border_color = Ui.ACCENT
		style.set_border_width_all(4)
	elif locked:
		style.bg_color = Ui.FILL2
	c.add_theme_stylebox_override("panel", style)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	if icon:
		h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(Ui.label(title, Ui.T_BODY, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600))
	if desc != "":
		v.add_child(Ui.wrap(Ui.label(desc, Ui.T_FOOT, Ui.LABEL2), 80))
	v.add_child(Ui.wrap(Ui.label(price, Ui.T_CAP, Ui.LABEL2), 80))
	Ui.press_fx(c, 0.97)
	return c


# 分段控件
class Segmented extends Control:
	signal tapped(index: int)
	var items: Array = []
	var selected := 0
	var _thumb_x := 0.0
	var _labels: Array = []
	var _icons: Array = []

	func _init(p_items: Array) -> void:
		items = p_items
		custom_minimum_size = Vector2(0, 76)
		for it in items:
			var ic := Icon.new(it[0], Ui.LABEL, 30)
			add_child(ic)
			_icons.append(ic)
			var l := Ui.label(it[1], Ui.T_SUB, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600)
			add_child(l)
			_labels.append(l)
		resized.connect(_relayout)

	func set_text(i: int, text: String) -> void:
		_labels[i].text = text
		_relayout()

	func select(i: int, animate := true) -> void:
		selected = i
		var w := _seg_w()
		var target := 6.0 + i * w
		if animate and is_inside_tree():
			var tw := create_tween()
			tw.tween_method(func(v: float):
				_thumb_x = v
				queue_redraw(), _thumb_x, target, 0.38).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		else:
			_thumb_x = target
			queue_redraw()

	func _seg_w() -> float:
		return (size.x - 12.0) / maxf(1.0, items.size())

	func _relayout() -> void:
		var w := _seg_w()
		for i in items.size():
			var l: Label = _labels[i]
			var ic: Control = _icons[i]
			var lw: float = l.get_minimum_size().x
			var total: float = 30.0 + 8.0 + lw
			var x0: float = 6.0 + i * w + (w - total) * 0.5
			ic.position = Vector2(x0, (size.y - 30.0) * 0.5)
			l.position = Vector2(x0 + 38.0, 0)
			l.size = Vector2(lw, size.y)
		_thumb_x = 6.0 + selected * w
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Ui.card_box(int(size.y * 0.5), Ui.FILL, false, 0), r)
		var th := Ui.card_box(int(size.y * 0.5) - 6, Ui.CARD, true, 0)
		th.shadow_size = 8
		th.shadow_offset = Vector2(0, 2)
		draw_style_box(th, Rect2(_thumb_x, 6, _seg_w(), size.y - 12))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			var i := clampi(int((e.position.x - 6.0) / _seg_w()), 0, items.size() - 1)
			tapped.emit(i)


# 数据卡片
static func stat_tile(caption: String, value: String, unit := "", color := Ui.LABEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", Ui.card_box(22, Ui.CARD, true, 22))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(Ui.label(caption, Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val := Ui.label(value, Ui.T_TITLE, color, HORIZONTAL_ALIGNMENT_LEFT, 700)
	val.name = "Value"
	h.add_child(val)
	if unit != "":
		var u := Ui.label(unit, Ui.T_FOOT, Ui.LABEL2)
		u.size_flags_vertical = Control.SIZE_SHRINK_END
		u.custom_minimum_size.y = 50
		h.add_child(u)
	v.add_child(h)
	return p


# 分组列表
static func list_group(rows: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.card_box(22, Ui.CARD, true, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	for i in rows.size():
		if i > 0:
			var sep := ColorRect.new()
			sep.color = Ui.SEP
			sep.custom_minimum_size = Vector2(0, 1)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", 92)
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.add_child(sep)
			v.add_child(m)
		v.add_child(rows[i])
	return p


# 列表行
static func list_row(icon: String, icon_bg: Color, title: String, detail := "", cb := Callable(), title_color := Ui.LABEL) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 92)
	for k in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0, 0, 0, 0.05)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(4, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pad)
	if icon != "":
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", Ui.card_box(14, icon_bg, false, 9))
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(Icon.new(icon, Color.WHITE, 38))
		h.add_child(tile)
	var t := Ui.label(title, Ui.T_BODY, title_color, HORIZONTAL_ALIGNMENT_LEFT, 500)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if detail != "":
		h.add_child(Ui.label(detail, Ui.T_SUB, Ui.LABEL2))
	var ch := Icon.new("chevron", Ui.LABEL3, 26)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ch)
	var pad2 := Control.new()
	pad2.custom_minimum_size = Vector2(8, 0)
	pad2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pad2)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


# 开关
class Switch extends Control:
	signal toggled(on: bool)
	var on := false
	var _t := 0.0

	func _init(v := false) -> void:
		on = v
		_t = 1.0 if v else 0.0
		custom_minimum_size = Vector2(100, 60)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_on(v: bool, animate := true) -> void:
		on = v
		if animate and is_inside_tree():
			var tw := create_tween()
			tw.tween_method(func(x: float):
				_t = x
				queue_redraw(), _t, 1.0 if on else 0.0, 0.3).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		else:
			_t = 1.0 if on else 0.0
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, (size.y - 60.0) * 0.5), Vector2(100, 60))
		var col := Color("ddd7cc").lerp(Ui.ACCENT, clampf(_t, 0.0, 1.0))
		draw_style_box(Ui.card_box(30, col, false, 0), r)
		var kx := lerpf(r.position.x + 30.0, r.end.x - 30.0, _t)
		var c := Vector2(kx, r.get_center().y)
		draw_circle(c + Vector2(0, 2), 25.0, Color(0, 0, 0, 0.12))
		draw_circle(c, 25.0, Color.WHITE)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			set_on(not on)
			toggled.emit(on)
			accept_event()


static func switch_row(icon: String, icon_bg: Color, title: String, value: bool, cb: Callable) -> Control:
	var m := MarginContainer.new()
	m.custom_minimum_size = Vector2(0, 92)
	m.add_theme_constant_override("margin_left", 4)
	m.add_theme_constant_override("margin_right", 16)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	m.add_child(h)
	if icon != "":
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", Ui.card_box(14, icon_bg, false, 9))
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(Icon.new(icon, Color.WHITE, 38))
		h.add_child(tile)
	var t := Ui.label(title, Ui.T_BODY, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 500)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var sw := Switch.new(value)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.toggled.connect(cb)
	h.add_child(sw)
	return m


# 柱状图
class BarChart extends Control:
	var values: Array = []
	var _t := 0.0

	func _init(v: Array) -> void:
		values = v
		custom_minimum_size = Vector2(0, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var tw := create_tween()
		tw.tween_method(func(x: float):
			_t = x
			queue_redraw(), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		if values.is_empty():
			return
		var mx := 1.0
		for v in values:
			mx = maxf(mx, float(v))
		var n := values.size()
		var gap := 14.0
		var slots := maxi(n, 8)
		var bw := (size.x - gap * (slots - 1)) / slots
		var font := Ui.font(500)
		for i in n:
			var h := (size.y - 34.0) * float(values[i]) / mx * _t
			var x := i * (bw + gap)
			var r := Rect2(x, size.y - 30.0 - h, bw, maxf(h, 4.0))
			var last := i == n - 1
			var sb := Ui.card_box(int(minf(bw * 0.5, 10.0)), Ui.ACCENT if last else Color(0.784, 0.063, 0.18, 0.28), false, 0)
			draw_style_box(sb, r)
			var t := str(values[i])
			var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, Ui.T_CAP)
			draw_string(font, Vector2(x + (bw - ts.x) * 0.5, size.y - 6.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.T_CAP, Ui.LABEL2)


# 进度圆环
class Ring extends Control:
	var value := 0.0
	var color := Color("c8102e")
	var center_text := ""
	var caption := ""
	var _t := 0.0

	func _init(v: float, c: Color, text: String, cap: String, d := 150.0) -> void:
		value = clampf(v, 0.0, 1.0)
		color = c
		center_text = text
		caption = cap
		custom_minimum_size = Vector2(d, d + 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func play(delay := 0.0) -> void:
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_method(func(x: float):
			_t = x
			queue_redraw(), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var d := minf(size.x, size.y - 40.0)
		var c := Vector2(size.x * 0.5, d * 0.5)
		var r := d * 0.5 - 10.0
		var w := 14.0
		draw_arc(c, r, 0, TAU, 64, Color(color.r, color.g, color.b, 0.15), w, true)
		if value * _t > 0.001:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * value * _t, 64, color, w, true)
		var font := Ui.font(700)
		var ts := font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_CENTER, -1, Ui.T_TITLE3)
		draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.T_TITLE3, Ui.LABEL)
		var f2 := Ui.font(500)
		var cs := f2.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, Ui.T_FOOT)
		draw_string(f2, Vector2(size.x * 0.5 - cs.x * 0.5, d + 30.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.T_FOOT, Ui.LABEL2)
