# 剪纸坊
# splash.gd - 开屏动画
extends Control

signal finished

const Ui = preload("res://scripts/ui_style.gd")
const DOOR_L := preload("res://assets/splash/door_l.png")
const DOOR_R := preload("res://assets/splash/door_r.png")
const FRAME := preload("res://assets/splash/frame.png")
const GLOW := preload("res://assets/splash/glow.png")
const BIRD := preload("res://assets/splash/bird.png")

const STAGE := 430.0
const PERSPECTIVE := 1600.0
const FRAME_BOX := Rect2(-60, -60, 550, 590)
const BIRD_BOX := 166.0
const BIRD_PAD := 40.0
const STRIPS := 28

# 时间线
const T_STAGE_IN := 0.15
const D_STAGE_IN := 1.0
const T_OPEN := 0.55
const D_LEAF := 2.6
const T_BIRD := T_OPEN + 0.9
const D_BIRD := 2.4
const T_LEAVE := T_OPEN + 2.55
const D_LEAVE := 0.5

# 燕子关键帧
const BIRD_KEYS := [
	[0.0, -0.46, -0.46, 0.16, -6.0, 0.0],
	[0.12, -0.24, -0.56, 0.7, -9.0, 1.0],
	[0.40, 0.40, -0.90, 0.98, -3.0, 1.0],
	[0.70, 1.40, -0.62, 1.02, 6.0, 1.0],
	[1.0, 3.30, -1.20, 1.2, 16.0, 0.0],
]

var main = null

var _t := 0.0
var _menu_shown := false
var _done := false
var _leaving := false
var _caption: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_caption = VBoxContainer.new()
	_caption.add_theme_constant_override("separation", 10)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", "STSong", "SimSun", "serif"])
	serif.font_weight = 700
	var h1 := Label.new()
	h1.text = "剪 纸 坊"
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h1.add_theme_font_override("font", serif)
	h1.add_theme_font_size_override("font_size", 50)
	h1.add_theme_color_override("font_color", Color("2b2b2d"))
	_caption.add_child(h1)
	var p := Label.new()
	p.text = "一  纸  一  剪"
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_theme_font_size_override("font_size", Ui.T_FOOT)
	p.add_theme_color_override("font_color", Color("b8b4ac"))
	_caption.add_child(p)
	_caption.modulate.a = 0.0
	add_child(_caption)
	resized.connect(_place_caption)
	_place_caption.call_deferred()


func _place_caption() -> void:
	_caption.reset_size()
	_caption.size.x = size.x
	_caption.position = Vector2(0, size.y * 0.89 - _caption.get_combined_minimum_size().y)


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
		skip()
		accept_event()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_caption.modulate.a = clampf((_t - 0.6) / 1.0, 0.0, 1.0)
	if not _leaving and _t >= T_LEAVE:
		_leave(D_LEAVE)
	queue_redraw()


# 绘制

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Ui.BG)
	var st := minf(size.x * 0.74, 600.0)
	var u := st / STAGE
	var center := Vector2(size.x * 0.5, size.y * 0.45)

	var floor_y := center.y + (STAGE * 0.5 + 52.0) * u
	_floor_line(floor_y, 0.20)
	_floor_line(floor_y + 6.0 * u, 0.20 * 0.45)

	# 舞台淡入
	var k_in := _bez(0.2, 0.8, 0.2, 1.0, clampf((_t - T_STAGE_IN) / D_STAGE_IN, 0.0, 1.0))
	var a_in := k_in
	var s_in := lerpf(0.95, 1.0, k_in)
	var off := Vector2(0, lerpf(0.04, 0.0, k_in) * st)
	draw_set_transform(center + off, 0.0, Vector2(s_in, s_in) * u)

	# 暖光
	var to := _t - T_OPEN - 0.1
	var g_op := 0.95 * _bez(0.25, 0.1, 0.25, 1.0, clampf(to / 2.2, 0.0, 1.0)) if to > 0.0 else 0.0
	var g_sc := lerpf(0.55, 1.06, _bez(0.2, 0.8, 0.2, 1.0, clampf(to / 2.6, 0.0, 1.0))) if to > 0.0 else 0.55
	if g_op > 0.003:
		var gs := Vector2(1.48, 1.32) * STAGE * g_sc
		draw_texture_rect(GLOW, Rect2(-gs * 0.5, gs), false, Color(1, 1, 1, g_op * a_in))

	# 门框
	var fr := Rect2(FRAME_BOX.position - Vector2(STAGE, STAGE) * 0.5, FRAME_BOX.size)
	draw_texture_rect(FRAME, fr, false, Color(1, 1, 1, a_in))

	# 两扇门
	var ang := 0.0
	if _t > T_OPEN:
		ang = deg_to_rad(84.0) * _bez(0.55, 0.04, 0.24, 1.0, clampf((_t - T_OPEN) / D_LEAF, 0.0, 1.0))
	_draw_leaf(true, ang, a_in)
	_draw_leaf(false, ang, a_in)

	# 燕子
	var tb := (_t - T_BIRD) / D_BIRD
	if tb > 0.0 and tb < 1.0:
		_draw_bird(tb, a_in)
	draw_set_transform(Vector2.ZERO)


func _floor_line(y: float, alpha: float) -> void:
	var c := Color(60.0 / 255.0, 60.0 / 255.0, 60.0 / 255.0, alpha)
	var c0 := Color(c, 0.0)
	var pts := PackedVector2Array([Vector2(0, y), Vector2(size.x * 0.16, y), Vector2(size.x * 0.84, y), Vector2(size.x, y)])
	draw_polyline_colors(pts, PackedColorArray([c0, c, c, c0]), 1.5)


# 透视投影
func _proj(x: float, y: float, z: float) -> Vector2:
	var f := PERSPECTIVE / (PERSPECTIVE - z)
	return Vector2((x - STAGE * 0.5) * f, (y - STAGE * 0.5) * f)


# 门扇上的点
func _leaf_pt(left: bool, lx: float, y: float, z: float, ang: float) -> Vector2:
	var c := cos(ang)
	var s := sin(ang)
	if left:
		return _proj(lx * c + z * s, y, -lx * s + z * c)
	return _proj(STAGE - lx * c - z * s, y, -lx * s + z * c)


func _draw_leaf(left: bool, ang: float, alpha: float) -> void:
	var w := STAGE * 0.5
	var tex: Texture2D = DOOR_L if left else DOOR_R
	var col := Color(1, 1, 1, alpha)
	var cols := PackedColorArray([col, col, col, col])
	for i in STRIPS:
		var l0 := w * i / STRIPS
		var l1 := w * (i + 1) / STRIPS
		var p := PackedVector2Array([
			_leaf_pt(left, l0, 0.0, 0.0, ang), _leaf_pt(left, l1, 0.0, 0.0, ang),
			_leaf_pt(left, l1, STAGE, 0.0, ang), _leaf_pt(left, l0, STAGE, 0.0, ang)])
		var u0 := l0 / w if left else 1.0 - l0 / w
		var u1 := l1 / w if left else 1.0 - l1 / w
		var uv := PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])
		draw_polygon(p, cols, uv, tex)
	# 门板厚度
	if ang > 0.01:
		var c_front := Color("8d0a12") if left else Color("4a040b")
		var c_back := Color("4a040b") if left else Color("8d0a12")
		c_front.a = alpha
		c_back.a = alpha
		var q := PackedVector2Array([
			_leaf_pt(left, w, 2.0, 0.0, ang), _leaf_pt(left, w, 2.0, 38.0, ang),
			_leaf_pt(left, w, STAGE - 2.0, 38.0, ang), _leaf_pt(left, w, STAGE - 2.0, 0.0, ang)])
		draw_polygon(q, PackedColorArray([c_back, c_front, c_front, c_back]))
		var edge := Color(0.9, 0.75, 0.39, 0.28 * alpha)
		draw_polyline(PackedVector2Array([q[1], q[2]]), edge, 1.0)


func _draw_bird(p: float, alpha: float) -> void:
	var i := 0
	while i < BIRD_KEYS.size() - 2 and p > BIRD_KEYS[i + 1][0]:
		i += 1
	var a: Array = BIRD_KEYS[i]
	var b: Array = BIRD_KEYS[i + 1]
	var k := _bez(0.34, 0.06, 0.6, 0.96, clampf((p - a[0]) / (b[0] - a[0]), 0.0, 1.0))
	var tx := lerpf(a[1], b[1], k)
	var ty := lerpf(a[2], b[2], k)
	var sc := lerpf(a[3], b[3], k)
	var rot := deg_to_rad(lerpf(a[4], b[4], k))
	var op := lerpf(a[5], b[5], k) * alpha
	if op <= 0.003:
		return
	var c := Vector2((tx + 0.5) * BIRD_BOX, (ty + 0.5) * BIRD_BOX)
	# 扇翅
	var ph := 0.5 - 0.5 * cos(TAU * fmod(_t - T_BIRD, 0.26) / 0.26)
	var xf := Transform2D(rot, Vector2(sc, sc), 0.0, c)
	xf = xf * Transform2D(deg_to_rad(-4.0) * ph, Vector2(1.0, 1.0 - 0.14 * ph), 0.0, Vector2.ZERO)
	var st := minf(size.x * 0.74, 600.0)
	var u := st / STAGE
	var k_in := _bez(0.2, 0.8, 0.2, 1.0, clampf((_t - T_STAGE_IN) / D_STAGE_IN, 0.0, 1.0))
	var stage_xf := Transform2D(0.0, Vector2.ONE * lerpf(0.95, 1.0, k_in) * u, 0.0,
			Vector2(size.x * 0.5, size.y * 0.45 + lerpf(0.04, 0.0, k_in) * st))
	draw_set_transform_matrix(stage_xf * xf)
	var full := BIRD_BOX + BIRD_PAD * 2.0
	draw_texture_rect(BIRD, Rect2(-full * 0.5, -full * 0.5, full, full), false, Color(1, 1, 1, op))


# 缓动曲线
static func _bez(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var lo := 0.0
	var hi := 1.0
	var s := x
	for _i in 22:
		s = (lo + hi) * 0.5
		var u := 1.0 - s
		var bx := 3.0 * u * u * s * x1 + 3.0 * u * s * s * x2 + s * s * s
		if bx < x:
			lo = s
		else:
			hi = s
	var v := 1.0 - s
	return 3.0 * v * v * s * y1 + 3.0 * v * s * s * y2 + s * s * s


# 进入首页

func _show_menu() -> void:
	if _menu_shown:
		return
	_menu_shown = true
	if main:
		main.goto("menu", "none")
		main.move_child(self, main.get_child_count() - 1)


func _leave(dur: float) -> void:
	if _leaving or _done:
		return
	_leaving = true
	_show_menu()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	_finish()


func skip() -> void:
	_leave(0.25)


func _finish() -> void:
	if _done:
		return
	_done = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	finished.emit()
	get_tree().create_timer(0.5).timeout.connect(queue_free)
