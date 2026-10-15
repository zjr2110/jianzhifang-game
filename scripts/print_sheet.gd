# 剪纸坊
# print_sheet.gd - 剪纸图纸导出
extends RefCounted

const Ui = preload("res://scripts/ui_style.gd")
const PaperModel = preload("res://scripts/paper_model.gd")
const PaperView = preload("res://scripts/paper_view.gd")
const FoldGeom = preload("res://scripts/fold_geom.gd")

const PAGE := Vector2(1240, 1754)
const PX_CM := 59.055
const MARGIN := 70.0

static var _busy := false


# 生成并预览图纸
static func open(main, model, paper_id: String, title: String) -> void:
	if _busy or model == null:
		return
	_busy = true
	main.toast("正在生成剪纸图纸…", 1.2, "paper")
	var img: Image = await render(main, model, paper_id, title)
	_busy = false
	if img == null:
		main.toast("图纸生成失败")
		return
	var sh = main.sheet("剪纸图纸")
	var c: VBoxContainer = sh.content
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Ui.card_box(16, Color("efe7da"), false, 12))
	box.custom_minimum_size = Vector2(0, 640)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(tr)
	c.add_child(box)
	c.add_child(Ui.wrap(Ui.label("A4 图纸，打印时选“实际大小 / 100%”，剪样就是真实尺寸。", Ui.T_FOOT, Ui.LABEL2), 300))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var save := Ui.filled_button("保存图纸", Ui.T_HEAD, "check")
	save.custom_minimum_size = Vector2(0, 92)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func(): _save(main, img, title))
	row.add_child(save)
	c.add_child(row)
	sh.open()


static func _file_name(title: String) -> String:
	var t := title.replace("·", "").replace(" ", "").replace("/", "")
	return "剪纸图纸_%s_%s.png" % [t, Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")]


static func _save(main, img: Image, title: String) -> void:
	var fname := _file_name(title)
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var cb := func(ok: bool, paths: PackedStringArray, _i: int):
			if ok and paths.size() > 0:
				_write.call_deferred(main, img, paths[0])
		var err := DisplayServer.file_dialog_show("保存剪纸图纸", OS.get_system_dir(OS.SYSTEM_DIR_PICTURES), fname, false,
				DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.png ; PNG 图片"]), cb)
		if err == OK:
			return
	# 无保存框时存到图片目录
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir + "/剪纸坊")
		if img.save_png(dir + "/剪纸坊/" + fname) == OK:
			main.toast("已保存到 图片/剪纸坊", 2.0, "check")
			return
	DirAccess.make_dir_recursive_absolute("user://exports")
	var p := "user://exports/" + fname
	if img.save_png(p) == OK:
		main.toast("已保存：" + ProjectSettings.globalize_path(p), 3.0, "check")
	else:
		main.toast("保存失败")


static func _write(main, img: Image, path: String) -> void:
	if not path.to_lower().ends_with(".png"):
		path += ".png"
	var err := img.save_png(path)
	if err == OK:
		main.toast("图纸已保存", 1.6, "check")
		if not OS.has_feature("mobile"):
			OS.shell_open(path)
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_buffer(img.save_png_to_buffer())
			f.close()
			main.toast("图纸已保存", 1.6, "check")
		else:
			main.toast("保存失败")


# 离屏渲染图纸
static func render(main, model, paper_id: String, title: String) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(PAGE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	main.add_child(vp)
	var page := Page.new()
	page.model = model
	page.paper_id = paper_id
	page.title = title
	page.size = PAGE
	vp.add_child(page)
	# 成品预览
	var pv := PaperView.new()
	page.add_child(pv)
	pv.setup(model, paper_id)
	pv.mode = "full"
	var pr := page.preview_rect()
	var f := PaperView.fit(pr, model.bounds, 10.0)
	pv.set_view(f[0], f[1])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


# 图纸页面
class Page extends Control:
	var model
	var paper_id := "red"
	var title := ""
	var _print_tex: ImageTexture
	var _scale := 1.0
	var _paper_cm := Vector2.ZERO

	func preview_rect() -> Rect2:
		return Rect2(PAGE.x - MARGIN - 270, MARGIN, 270, 270)

	# 版面
	func _layout() -> Dictionary:
		var n := _steps().size()
		var gap := 24.0
		var pw := minf(230.0, (PAGE.x - MARGIN * 2 - gap * (n - 1)) / n)
		var y0 := 400.0
		var y1 := y0 + 30 + pw + 100
		var area := Rect2(MARGIN, y1 + 110, PAGE.x - MARGIN * 2, PAGE.y - (y1 + 110) - 110)
		return {"n": n, "gap": gap, "pw": pw, "y0": y0, "y1": y1, "area": area}

	func _ready() -> void:
		var b: Rect2 = model.bounds
		var long_cm := 24.0 if model.fold_id == "accordion" else 15.0
		_scale = long_cm * PX_CM / maxf(b.size.x, b.size.y)
		var area: Rect2 = _layout()["area"]
		var wb: Rect2 = model.wedge_bounds
		_scale = minf(_scale, minf(area.size.x / wb.size.x, area.size.y / wb.size.y) * 0.98)
		_paper_cm = b.size * _scale / PX_CM
		_build_print_tex()

	# 剪样图
	func _build_print_tex() -> void:
		var f: int = maxi(1, model.ds / 4)
		var w: int = model.tex_w / f
		var h: int = model.tex_h / f
		var src: PackedByteArray = PaperModel.shrink(model.mask, w, h)
		var keep := PackedByteArray()
		keep.resize(w * h)
		for i in w * h:
			keep[i] = 1 if src[i] > 127 else 0
		var out := PackedByteArray()
		out.resize(w * h * 4)
		for y in h:
			for x in w:
				var i := y * w + x
				var o := i * 4
				if keep[i] == 1:
					var edge := (x > 0 and keep[i - 1] == 0) or (x < w - 1 and keep[i + 1] == 0) \
							or (y > 0 and keep[i - w] == 0) or (y < h - 1 and keep[i + w] == 0)
					if edge:
						out[o] = 200; out[o + 1] = 16; out[o + 2] = 46; out[o + 3] = 255
					else:
						out[o] = 251; out[o + 1] = 218; out[o + 2] = 214; out[o + 3] = 255
				else:
					out[o] = 255; out[o + 1] = 255; out[o + 2] = 255; out[o + 3] = 255
		_print_tex = ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out))

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, PAGE), Color.WHITE)
		var f7 := Ui.font(700)
		var f5 := Ui.font(500)
		var f4 := Ui.font(400)
		var ink := Color("1c1c1e")
		var grey := Color("8a8a8e")
		var red := Color("c8102e")
		var fold: Dictionary = Game.FOLDS[model.fold_id]
		var layers: int = model.layer_count()
		# 标题
		draw_string(f5, Vector2(MARGIN, MARGIN + 30), "剪纸坊 · 剪纸图纸", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, red)
		draw_string(f7, Vector2(MARGIN, MARGIN + 100), title, HORIZONTAL_ALIGNMENT_LEFT, PAGE.x - MARGIN * 2 - 330, 60, ink)
		draw_string(f4, Vector2(MARGIN, MARGIN + 150), "%s · %s · %d 层一起剪" % [Game.PAPERS[paper_id]["name"], fold["name"], layers], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, grey)
		draw_string(f4, Vector2(MARGIN, MARGIN + 196), "准备：%.1f × %.1f 厘米的纸（形状见第 1 步），一把小剪刀。" % [_paper_cm.x, _paper_cm.y], HORIZONTAL_ALIGNMENT_LEFT, PAGE.x - MARGIN * 2 - 330, 26, ink)
		draw_string(f4, Vector2(MARGIN, MARGIN + 236), "打印时选“实际大小 / 100%”，第 2 部分的剪样就是真实尺寸。", HORIZONTAL_ALIGNMENT_LEFT, PAGE.x - MARGIN * 2 - 330, 24, grey)
		var pr := preview_rect()
		draw_string(f5, Vector2(pr.position.x, pr.end.y + 34), "展开后的样子", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 24, grey)

		# 折法步骤
		var lay := _layout()
		var y0: float = lay["y0"]
		_section_title(f7, Vector2(MARGIN, y0), "1  怎么折", ink, red)
		var steps := _steps()
		var n: int = lay["n"]
		var gap: float = lay["gap"]
		var pw: float = lay["pw"]
		for i in n:
			var r := Rect2(MARGIN + i * (pw + gap), y0 + 30, pw, pw)
			_draw_step(r, steps[i], i, n, f5, f4)

		# 剪样
		var y1: float = lay["y1"]
		_section_title(f7, Vector2(MARGIN, y1), "2  怎么剪", ink, red)
		draw_string(f4, Vector2(MARGIN, y1 + 44), "把折好的纸摆成下图的样子（纸心对准“纸心”），沿红线剪，剪掉白色部分，留下淡红部分。", HORIZONTAL_ALIGNMENT_LEFT, PAGE.x - MARGIN * 2, 24, ink)
		draw_string(f4, Vector2(MARGIN, y1 + 78), "灰色虚线是折边，不要剪断；黑实线是纸边。", HORIZONTAL_ALIGNMENT_LEFT, PAGE.x - MARGIN * 2, 24, grey)
		_draw_pattern(lay["area"], f5, f4)

		# 页脚
		draw_line(Vector2(MARGIN, PAGE.y - 90), Vector2(PAGE.x - MARGIN, PAGE.y - 90), Color(0, 0, 0, 0.1), 2)
		draw_string(f4, Vector2(MARGIN, PAGE.y - 52), "由《剪纸坊》生成 · 小提示：剪之前用夹子把折好的纸夹紧，剪口更整齐。", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, grey)
		# 标尺
		var rx := PAGE.x - MARGIN - PX_CM * 2
		draw_line(Vector2(rx, PAGE.y - 60), Vector2(rx + PX_CM * 2, PAGE.y - 60), ink, 3)
		for k in 3:
			draw_line(Vector2(rx + PX_CM * k, PAGE.y - 70), Vector2(rx + PX_CM * k, PAGE.y - 50), ink, 2)
		draw_string(f4, Vector2(rx, PAGE.y - 76), "2 厘米", HORIZONTAL_ALIGNMENT_CENTER, PX_CM * 2, 20, ink)

	func _section_title(f: Font, p: Vector2, text: String, ink: Color, red: Color) -> void:
		draw_rect(Rect2(p + Vector2(0, -26), Vector2(8, 32)), red)
		draw_string(f, p + Vector2(20, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, ink)

	# 折叠步骤
	func _steps() -> Array:
		var cells: Array = model.cells
		var stages: Array = model.stages
		var out := []
		if stages.is_empty():
			out.append({"cells": cells, "flip": [], "line": null, "text": "不用折，直接剪"})
			return out
		if stages.size() > 4:
			out.append({"cells": cells, "flip": [], "lines": stages, "text": "按虚线来回折 %d 次" % stages.size()})
			out.append({"cells": [Transform2D.IDENTITY], "flip": [], "line": null, "text": "折成这一小块", "final": true})
			return out
		var cur: Array = cells
		for k in range(stages.size() - 1, -1, -1):
			var st: Dictionary = stages[k]
			var base: Array = st["base"]
			var flip := []
			for g in cur:
				var keep := false
				for bg in base:
					if (bg as Transform2D).is_equal_approx(g):
						keep = true
				if not keep:
					flip.append(g)
			out.append({"cells": cur, "flip": flip, "line": [st["u"], st["p"]], "text": "沿虚线折"})
			cur = base
		out.append({"cells": cur, "flip": [], "line": null, "text": "折好了，在这块上剪", "final": true})
		return out

	func _draw_step(r: Rect2, st: Dictionary, i: int, n: int, f5: Font, f4: Font) -> void:
		draw_style_box(Ui.card_box(16, Color("f6f2ea"), false, 0), r)
		var b: Rect2 = model.bounds
		var inner := r.grow(-24)
		var s := minf(inner.size.x / b.size.x, inner.size.y / b.size.y)
		var o := inner.get_center() - b.get_center() * s
		var wedge: PackedVector2Array = model.wedge
		var red := Color("d8475a")
		var light := Color(0.85, 0.28, 0.35, 0.28)
		for g in st["cells"]:
			var pts := PackedVector2Array()
			for p in (g as Transform2D) * wedge:
				pts.append(o + p * s)
			var is_flip := false
			for fg in st["flip"]:
				if (fg as Transform2D).is_equal_approx(g):
					is_flip = true
			draw_colored_polygon(pts, light if is_flip else (Color("c8102e") if st.get("final", false) else red))
		if st.get("line") != null:
			_dash_line(r, o, s, st["line"][0], st["line"][1])
		if st.has("lines"):
			for l in st["lines"]:
				_dash_line(r, o, s, l["u"], l["p"])
		draw_circle(o, 4.0, Color("1c1c1e"))
		draw_string(f5, r.position + Vector2(12, 30), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("1c1c1e"))
		draw_string(f4, Vector2(r.position.x, r.end.y + 34), st["text"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color("1c1c1e"))
		if st.get("flip", []).size() > 0:
			draw_string(f4, Vector2(r.position.x, r.end.y + 62), "浅色部分翻过来", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color("8a8a8e"))

	func _dash_line(r: Rect2, o: Vector2, s: float, u: Vector2, p: Vector2) -> void:
		var c := o + p * s
		var d := u.normalized()
		var L := r.size.length()
		var a := c - d * L
		var bb := c + d * L
		var clip := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, bb]),
				PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		for seg in clip:
			if seg.size() < 2:
				continue
			var p0: Vector2 = seg[0]
			var p1: Vector2 = seg[seg.size() - 1]
			var dl := p0.distance_to(p1)
			var t := 0.0
			while t < dl:
				var e := minf(dl, t + 10.0)
				draw_line(p0.lerp(p1, t / dl), p0.lerp(p1, e / dl), Color("1c1c1e"), 2.0, true)
				t += 17.0

	# 实际尺寸剪样
	func _draw_pattern(area: Rect2, f5: Font, f4: Font) -> void:
		var wb: Rect2 = model.wedge_bounds
		var s := _scale
		var sz := wb.size * s
		if sz.x > area.size.x or sz.y > area.size.y:
			s *= minf(area.size.x / sz.x, area.size.y / sz.y)
		var o := area.get_center() - wb.get_center() * s
		var wedge: PackedVector2Array = model.wedge
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for p in wedge:
			pts.append(o + p * s)
			uvs.append(model.uv_of(p))
			cols.append(Color.WHITE)
		draw_primitive(pts, cols, uvs, _print_tex)
		# 折边虚线，纸边实线
		for i in wedge.size():
			var a: Vector2 = wedge[i]
			var bpt: Vector2 = wedge[(i + 1) % wedge.size()]
			var is_fold := false
			for g in model.neighbors:
				var cell: PackedVector2Array = (g as Transform2D) * wedge
				var ha := false
				var hb := false
				for q in cell:
					if q.distance_to(a) < 0.5:
						ha = true
					if q.distance_to(bpt) < 0.5:
						hb = true
				if ha and hb:
					is_fold = true
			var pa := o + a * s
			var pb := o + bpt * s
			if is_fold:
				var dl := pa.distance_to(pb)
				var t := 0.0
				while t < dl:
					var e := minf(dl, t + 14.0)
					draw_line(pa.lerp(pb, t / dl), pa.lerp(pb, e / dl), Color("9a9a9e"), 3.0, true)
					t += 24.0
				var mid := (pa + pb) * 0.5
				draw_string(f4, mid + Vector2(8, -8), "折边", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8a8a8e"))
			else:
				draw_line(pa, pb, Color("1c1c1e"), 3.0, true)
		if model.layer_count() > 1:
			var c := o + Vector2.ZERO * s
			if Geometry2D.is_point_in_polygon(Vector2.ZERO, wedge) or wedge[0].length() < 1.0:
				draw_circle(c, 7.0, Color("1c1c1e"))
				draw_string(f5, c + Vector2(-60, 34), "纸心", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("1c1c1e"))
		if absf(s - _scale) > 0.001:
			draw_string(f4, Vector2(area.position.x, area.end.y + 30), "（剪样太大，已按 %d%% 缩小）" % int(round(s / _scale * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8a8a8e"))
