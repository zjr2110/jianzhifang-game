# 剪纸坊
# ui_style.gd - 界面样式
extends RefCounted

const Icon = preload("res://scripts/ui/icon.gd")
const Sfx = preload("res://scripts/sfx.gd")

# 颜色
const BG := Color("f6f2ea")
const CARD := Color("ffffff")
const FILL := Color("ece7dd")
const FILL2 := Color("f1ede5")
const LABEL := Color("1c1c1e")
const LABEL2 := Color("8a8a8e")
const LABEL3 := Color("b8b4ac")
const SEP := Color(0.24, 0.22, 0.2, 0.14)
const ACCENT := Color("c8102e")
const ACCENT_DARK := Color("9e0c24")
const ACCENT_TINT := Color(0.784, 0.063, 0.18, 0.11)
const GOLD := Color("c9962b")
const GOLD_TINT := Color(0.79, 0.59, 0.17, 0.14)
const SHADOW := Color(0.25, 0.18, 0.1, 0.10)

const INK := LABEL
const RICE := CARD
const RICE_DARK := LABEL2
const VERMILION := ACCENT
const VERMILION_DARK := ACCENT_DARK
const BROWN := LABEL2

# 字号
const T_LARGE := 62
const T_TITLE := 44
const T_TITLE3 := 34
const T_HEAD := 30
const T_BODY := 28
const T_SUB := 25
const T_FOOT := 22
const T_CAP := 19

# 动画时长
const D_FAST := 0.16
const D_MID := 0.32
const D_SLOW := 0.5

static var _fonts := {}


# 系统字体
static func font(weight := 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang SC", "HarmonyOS Sans SC", "MiSans", "Noto Sans CJK SC", "Source Han Sans SC",
		"Microsoft YaHei", "sans-serif",
	])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_fonts[weight] = f
	return f


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = T_BODY
	t.set_color("font_color", "Label", LABEL)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_stylebox("normal", "Button", StyleBoxEmpty.new())
	t.set_stylebox("hover", "Button", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "Button", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", card_box())
	t.set_stylebox("panel", "Panel", card_box())
	return t


# 样式盒

static func card_box(radius := 24, color := CARD, shadow := true, pad := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = SHADOW
		s.shadow_size = 18
		s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func pill_box(color: Color, pad_x := 26, pad_y := 12, shadow := false) -> StyleBoxFlat:
	var s := card_box(200, color, shadow, 0)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func box(color: Color, radius := 12, border := Color.TRANSPARENT, border_w := 0, shadow := 4) -> StyleBoxFlat:
	var s := card_box(radius, color, shadow > 0, 14)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	return s


static func paper_box() -> StyleBoxFlat:
	return card_box(24, CARD, true, 22)


# 文字

static func label(text: String, size := T_BODY, color := LABEL, align := HORIZONTAL_ALIGNMENT_LEFT, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight != 400:
		l.add_theme_font_override("font", font(weight))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := T_TITLE, color := LABEL, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return label(text, size, color, align, 700)


static func wrap(l: Label, min_w := 100.0) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size.x = min_w
	return l


static func stars_text(n: int) -> String:
	var s := ""
	for i in 5:
		s += "★" if i < n else "☆"
	return s


# 按钮

static func filled_button(text: String, size := T_HEAD, icon := "") -> Button:
	return _button(text, size, ACCENT, Color.WHITE, 700, icon)


static func tinted_button(text: String, size := T_BODY, icon := "") -> Button:
	return _button(text, size, ACCENT_TINT, ACCENT, 600, icon)


static func gray_button(text: String, size := T_BODY, icon := "") -> Button:
	return _button(text, size, FILL, LABEL, 500, icon)


static func white_button(text: String, size := T_BODY, icon := "", color := LABEL) -> Button:
	var b := _button(text, size, CARD, color, 500, icon)
	b.add_theme_stylebox_override("normal", pill_box(CARD, 26, 12, true))
	return b


static func plain_button(text: String, size := T_BODY, color := ACCENT, weight := 500) -> Button:
	var b := _button(text, size, Color(0, 0, 0, 0), color, weight, "")
	return b


static func _button(text: String, size: int, bg: Color, fg: Color, weight: int, icon: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", pill_box(bg))
	b.add_theme_stylebox_override("hover", pill_box(bg))
	b.add_theme_stylebox_override("pressed", pill_box(bg))
	b.add_theme_stylebox_override("hover_pressed", pill_box(bg))
	var dis := pill_box(Color(bg.r, bg.g, bg.b, bg.a * 0.45))
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_font_override("font", font(weight))
	b.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.4))
	if icon != "":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var ic := Icon.new(icon, fg, size * 1.05)
		row.add_child(ic)
		if text != "":
			var l := label(text, size, fg, HORIZONTAL_ALIGNMENT_CENTER, weight)
			row.add_child(l)
		b.add_child(row)
		b.set_meta("icon", ic)
		b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, size * 2.2 + text.length() * size)
	else:
		b.text = text
	press_fx(b)
	return b


static func line_edit(text := "", placeholder := "") -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.max_length = 16
	e.custom_minimum_size = Vector2(0, 88)
	e.add_theme_font_size_override("font_size", T_HEAD)
	e.add_theme_color_override("font_color", LABEL)
	e.add_theme_color_override("font_placeholder_color", LABEL3)
	e.add_theme_color_override("caret_color", ACCENT)
	var st := card_box(20, CARD, false, 0)
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.border_color = Color(0, 0, 0, 0.08)
	st.set_border_width_all(2)
	e.add_theme_stylebox_override("normal", st)
	var fo := st.duplicate()
	fo.border_color = ACCENT
	e.add_theme_stylebox_override("focus", fo)
	return e


static func icon_button(icon: String, d := 68.0, fg := LABEL, bg := Color(1, 1, 1, 0.86)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(d, d)
	var st := card_box(int(d), bg, true, 0)
	st.shadow_size = 10
	st.shadow_offset = Vector2(0, 3)
	for k in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, st)
	var dis := st.duplicate()
	dis.bg_color = Color(bg.r, bg.g, bg.b, bg.a * 0.5)
	b.add_theme_stylebox_override("disabled", dis)
	var ic := Icon.new(icon, fg, d * 0.5)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.position = Vector2(d * 0.25, d * 0.25)
	b.add_child(ic)
	b.set_meta("icon", ic)
	press_fx(b)
	return b


# 按压反馈
static func press_fx(c: Control, scale := 0.95) -> void:
	var update_pivot := func(): c.pivot_offset = c.size * 0.5
	c.resized.connect(update_pivot)
	if c is BaseButton:
		c.button_down.connect(func(): _press(c, true, scale))
		c.button_up.connect(func():
			_press(c, false, scale)
			Sfx.play("tap", -10.0))
	else:
		c.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				_press(c, e.pressed, scale))


static func _press(c: Control, down: bool, scale: float) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_parallel()
	if down:
		tw.tween_property(c, "scale", Vector2(scale, scale), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate", Color(0.9, 0.9, 0.9, c.modulate.a), 0.09)
	else:
		tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate", Color(1, 1, 1, c.modulate.a), 0.2)


# 动画

static func appear(nodes: Array, delay := 0.045) -> void:
	var i := 0
	for n in nodes:
		if not (n is Control) or not is_instance_valid(n):
			continue
		var c: Control = n
		c.modulate.a = 0.0
		c.scale = Vector2(0.96, 0.96)
		var tw := c.create_tween()
		tw.tween_interval(i * delay)
		tw.tween_callback(func(): c.pivot_offset = c.size * 0.5)
		tw.tween_property(c, "modulate:a", 1.0, 0.32)
		tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		i += 1


static func pop(c: Control, from := 0.6, dur := 0.45) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.4)


static func count_to(l: Label, from: int, to: int, dur := 0.8, fmt := "%d") -> void:
	var tw := l.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(l):
			l.text = fmt % int(round(v)), float(from), float(to), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
