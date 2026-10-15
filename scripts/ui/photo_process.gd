# 剪纸坊
# photo_process.gd - 识别过程动画
extends VBoxContainer

signal finished

const Ui = preload("res://scripts/ui_style.gd")
const Widgets = preload("res://scripts/widgets.gd")
const FoldGeom = preload("res://scripts/fold_geom.gd")
const PhotoTemplate = preload("res://scripts/photo_template.gd")

const T_SEG := 0.0
const T_CEN := 0.9
const T_FOLDS := 1.7
const PER_FOLD := 0.42
const DOTS := 70
const C_OK := Color(0.18, 0.85, 0.45)
const C_BAD := Color(0.2, 0.5, 1.0)

var an: Dictionary
var preview_tpl: Texture2D = null

var _canvas: Canvas
var _caption: Label
var _sub: Label
var _chips := {}
var _order: Array = []
var _t := 0.0
var _total := 0.0
var _done := false
var _seg_tex: Texture2D
var _photo_tex: Texture2D
var _geo := {}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_photo_tex = ImageTexture.create_from_image(an["preview"])
	_seg_tex = _make_seg_tex()
	for r in an["scores"]:
		_order.append(r)
	_order.sort_custom(func(a, b): return a["score"] < b["score"])
	for r in _order:
		_geo[r["fold"]] = _prepare(r)
	_total = T_FOLDS + PER_FOLD * _order.size() + 1.8

	_canvas = Canvas.new()
	_canvas.view = self
	_canvas.custom_minimum_size = Vector2(0, 520)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Ui.card_box(22, Color("1c1a17"), false, 0))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_child(_canvas)
	add_child(frame)

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	_caption = Ui.title("", Ui.T_HEAD)
	tv.add_child(_caption)
	_sub = Ui.wrap(Ui.label("", Ui.T_FOOT, Ui.LABEL2), 300)
	tv.add_child(_sub)
	add_child(tv)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	var shown := _order.duplicate()
	shown.reverse()
	for r in shown:
		var chip := Chip.new()
		chip.fold = r["fold"]
		chip.label = "%s · %d 层" % [Game.FOLDS[r["fold"]]["name"], r["layers"]]
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.custom_minimum_size = Vector2(0, 62)
		grid.add_child(chip)
		_chips[r["fold"]] = chip
	add_child(grid)

	var skip := Ui.gray_button("跳过", Ui.T_BODY)
	skip.custom_minimum_size = Vector2(0, 80)
	skip.pressed.connect(_finish)
	add_child(skip)
	_update_text()


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	for r in _order:
		var chip: Chip = _chips[r["fold"]]
		var k := _fold_index(r["fold"])
		var t0 := T_FOLDS + PER_FOLD * k
		var p := clampf((_t - t0) / (PER_FOLD * 0.9), 0.0, 1.0)
		chip.value = maxf(0.0, r["score"]) * p
		chip.active = _current_fold() == r["fold"]
		chip.chosen = _t >= _t_choose() and r["fold"] == an["best"]
		chip.queue_redraw()
	_update_text()
	_canvas.queue_redraw()
	if _t >= _total:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


# 时间线

func _t_choose() -> float:
	return T_FOLDS + PER_FOLD * _order.size()


func _fold_index(f: String) -> int:
	for i in _order.size():
		if _order[i]["fold"] == f:
			return i
	return -1


func _current_fold() -> String:
	if _t < T_FOLDS or _t >= _t_choose():
		return ""
	var k := clampi(int((_t - T_FOLDS) / PER_FOLD), 0, _order.size() - 1)
	return _order[k]["fold"]


func _update_text() -> void:
	var best: String = an["best"]
	if _t < T_CEN:
		_caption.text = "① 把纸从背景里分出来"
		_sub.text = "按颜色鲜艳程度（饱和度）自动找阈值，鲜艳的是剪纸，灰白的是背景"
	elif _t < T_FOLDS:
		_caption.text = "② 找到对称中心"
		_sub.text = "纸的重心就是对称中心，最远的一点定出半径"
	elif _t < _t_choose():
		var f := _current_fold()
		var r: Dictionary = _order[_fold_index(f)]
		_caption.text = "③ 检验「%s」的对称度：%d%%" % [Game.FOLDS[f]["name"], int(round(maxf(0.0, r["score"]) * 100.0))]
		_sub.text = "在一片扇区里取点，和其它各层对应的点比较：绿点对得上，蓝点对不上"
	elif _t < _t_choose() + 1.0:
		if best == "none":
			_caption.text = "④ 没有明显的对称：按不折处理"
			_sub.text = "各种折法的对称度都不够高，当作单层刻纸"
		else:
			_caption.text = "④ 选定：%s · %d 层" % [Game.FOLDS[best]["name"], (_geo[best]["cells"] as Array).size()]
			_sub.text = "对称度接近时选层数多的：八折的图案一定也满足对折"
	else:
		_caption.text = "⑤ 生成样稿"
		_sub.text = "把选中扇区里的图案映射回折好的纸上，断开的笔画自动补上连接筋"


# 数据

# 样稿淡入贴图
static func tpl_texture(img: Image) -> Texture2D:
	var src := img.duplicate() as Image
	src.convert(Image.FORMAT_L8)
	if src.get_width() > 640:
		src.resize(640, int(640.0 * src.get_height() / src.get_width()), Image.INTERPOLATE_BILINEAR)
	var w := src.get_width()
	var h := src.get_height()
	var sd := src.get_data()
	var d := PackedByteArray()
	d.resize(w * h * 4)
	for i in w * h:
		d[i * 4] = 214
		d[i * 4 + 1] = 28
		d[i * 4 + 2] = 36
		d[i * 4 + 3] = sd[i]
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d))


# 背景压暗贴图
func _make_seg_tex() -> Texture2D:
	var w: int = an["w"]
	var h: int = an["h"]
	var paper: PackedByteArray = an["paper"]
	var d := PackedByteArray()
	d.resize(w * h * 2)
	for i in w * h:
		if paper[i] == 0:
			d[i * 2 + 1] = 170
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_LA8, d))


# 扇区轮廓与采样点
func _prepare(r: Dictionary) -> Dictionary:
	var g := FoldGeom.build(r["fold"])
	var o: Vector2 = r.get("origin", Vector2.ZERO)
	var s: float = r.get("scale", 1.0)
	var rot: float = r.get("rot", 0.0)
	var wedge: PackedVector2Array = g["wedge"]
	var cells: Array = g["cells"]
	var polys := []
	for c in cells:
		var poly := PackedVector2Array()
		for p in (c as Transform2D) * wedge:
			poly.append(o + p.rotated(rot) * s)
		polys.append(poly)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var wb: Rect2 = g["wedge_bounds"]
	var dots := []
	var guard := 0
	var paper: PackedByteArray = an["paper"]
	var w: int = an["w"]
	var h: int = an["h"]
	while dots.size() < DOTS and guard < DOTS * 30:
		guard += 1
		var p := wb.position + Vector2(rng.randf() * wb.size.x, rng.randf() * wb.size.y)
		if not Geometry2D.is_point_in_polygon(p, wedge):
			continue
		var v0 := _val(paper, w, h, o + p.rotated(rot) * s)
		var ok := true
		var pos := PackedVector2Array()
		for c in cells:
			var q: Vector2 = o + ((c as Transform2D) * p).rotated(rot) * s
			pos.append(q)
			if _val(paper, w, h, q) != v0:
				ok = false
		dots.append([pos, ok])
	return {"cells": polys, "dots": dots}


static func _val(paper: PackedByteArray, w: int, h: int, q: Vector2) -> int:
	var x := int(q.x)
	var y := int(q.y)
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0
	return paper[y * w + x]


# 画面

class Canvas extends Control:
	var view

	func _draw() -> void:
		var an: Dictionary = view.an
		var t: float = view._t
		var w: float = an["w"]
		var h: float = an["h"]
		var k := minf(size.x / w, size.y / h)
		var off := (size - Vector2(w, h) * k) * 0.5
		var M := func(q: Vector2) -> Vector2: return off + q * k
		var rect := Rect2(off, Vector2(w, h) * k)
		var tpl_a := clampf((t - view._t_choose() - 1.0) / 0.6, 0.0, 1.0)
		draw_texture_rect(view._photo_tex, rect, false, Color(1, 1, 1, 1.0 - tpl_a * 0.6))
		# 背景压暗
		var seg_a := clampf(t / 0.5, 0.0, 1.0)
		draw_texture_rect(view._seg_tex, rect, false, Color(1, 1, 1, seg_a))
		# 中心与半径
		var cen: Vector2 = M.call(an["cen"])
		var rad: float = an["rad"] * k
		if t >= T_CEN:
			var p := clampf((t - T_CEN) / 0.6, 0.0, 1.0)
			var ease_p := 1.0 - pow(1.0 - p, 3.0)
			draw_arc(cen, rad * ease_p, 0, TAU, 96, Color(1, 0.86, 0.4, 0.9), 2.5, true)
			var arm := 26.0
			draw_line(cen - Vector2(arm, 0), cen + Vector2(arm, 0), Color(1, 0.86, 0.4), 3.0, true)
			draw_line(cen - Vector2(0, arm), cen + Vector2(0, arm), Color(1, 0.86, 0.4), 3.0, true)
		# 逐个折法
		var f: String = view._current_fold()
		var chosen: bool = t >= view._t_choose()
		if chosen:
			f = an["best"]
		if f != "" and view._geo.has(f):
			var geo: Dictionary = view._geo[f]
			var cells: Array = geo["cells"]
			var lp := 1.0
			if not chosen:
				lp = clampf(fmod(t - T_FOLDS, PER_FOLD) / (PER_FOLD * 0.5), 0.0, 1.0)
			var line_col := Color(1, 1, 1, 0.85) if not chosen else Color(1, 0.86, 0.4, 0.95)
			if chosen and tpl_a < 1.0:
				var wp: PackedVector2Array = cells[0]
				var tp := PackedVector2Array()
				for q in wp:
					tp.append(M.call(q))
				draw_colored_polygon(tp, Color(1, 0.8, 0.3, 0.35 * (1.0 - tpl_a)))
			for poly in cells:
				var pts := PackedVector2Array()
				for q in poly:
					pts.append(M.call(q))
				pts.append(pts[0])
				var cut := int(ceil(pts.size() * lp))
				if cut >= 2:
					draw_polyline(pts.slice(0, cut), Color(line_col, line_col.a * (1.0 - tpl_a)), 1.6 if not chosen else 2.2, true)
			if not chosen:
				var dots: Array = geo["dots"]
				var nd := int(dots.size() * clampf(fmod(t - T_FOLDS, PER_FOLD) / (PER_FOLD * 0.7), 0.0, 1.0))
				for i in nd:
					var d: Array = dots[i]
					var c: Color = C_OK if d[1] else C_BAD
					for q in d[0]:
						draw_circle(M.call(q), 3.2, c)
		# 样稿淡入
		if tpl_a > 0.0 and view.preview_tpl != null:
			var ts: Vector2 = view.preview_tpl.get_size()
			var kk := minf(size.x / ts.x, size.y / ts.y) * 0.92
			var tr := Rect2((size - ts * kk) * 0.5, ts * kk)
			draw_texture_rect(view.preview_tpl, tr, false, Color(1, 1, 1, tpl_a))


# 折法得分条
class Chip extends Control:
	var fold := ""
	var label := ""
	var value := 0.0
	var active := false
	var chosen := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := Ui.card_box(16, Ui.CARD, false, 0)
		if chosen:
			bg.border_color = Ui.ACCENT
			bg.set_border_width_all(3)
		elif active:
			bg.border_color = Color(Ui.GOLD, 0.8)
			bg.set_border_width_all(2)
		draw_style_box(bg, r)
		var font := Ui.font(600 if chosen else 400)
		draw_string(font, Vector2(16, 28), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, Ui.T_FOOT, Ui.LABEL)
		var pct := "%d%%" % int(round(value * 100.0))
		draw_string(Ui.font(700), Vector2(size.x - 16 - 70, 28), pct, HORIZONTAL_ALIGNMENT_RIGHT, 70, Ui.T_FOOT, Ui.ACCENT if chosen else Ui.LABEL2)
		var bar := Rect2(16, size.y - 18, size.x - 32, 6)
		draw_rect(bar, Color("ece5d8"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y)), Ui.ACCENT if chosen or active else Color(Ui.ACCENT, 0.55))
