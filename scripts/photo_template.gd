# 剪纸坊
# photo_template.gd - 照片识别折法与样稿生成
extends RefCounted

const FoldGeom = preload("res://scripts/fold_geom.gd")

const MAX_SIDE := 520
const HI_SIDE := 1400
const TPL_SIDE := 2048
const SOFT := 18.0
const SAMPLES := 1200
const CANDIDATES := ["half", "four", "eight", "sixteen", "twelve", "five", "accordion"]


static func load_photo(path: String) -> Image:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		for fn in ["load_jpg_from_buffer", "load_png_from_buffer", "load_webp_from_buffer"]:
			if img.call(fn, bytes) == OK:
				err = OK
				break
	if err != OK or img.is_empty():
		return null
	return img


# 分析照片
static func analyze(src: Image) -> Dictionary:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var k := float(MAX_SIDE) / maxf(img.get_width(), img.get_height())
	if k < 1.0:
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_BILINEAR)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var n := w * h

	# 分割纸与背景
	var sat := PackedFloat32Array()
	sat.resize(n)
	var lum := PackedFloat32Array()
	lum.resize(n)
	var hs := PackedInt32Array()
	hs.resize(64)
	var hl := PackedInt32Array()
	hl.resize(64)
	for i in n:
		var r := float(data[i * 3])
		var g := float(data[i * 3 + 1])
		var b := float(data[i * 3 + 2])
		var mx := maxf(r, maxf(g, b))
		var mn := minf(r, minf(g, b))
		sat[i] = mx - mn
		lum[i] = 0.299 * r + 0.587 * g + 0.114 * b
		hs[mini(63, int(sat[i] / 256.0 * 64.0))] += 1
		hl[mini(63, int(lum[i] / 256.0 * 64.0))] += 1
	var paper := PackedByteArray()
	paper.resize(n)
	var ts := _otsu(hs) * 4.0
	var s_hi := 0.0
	var s_lo := 0.0
	var c_hi := 0
	var c_lo := 0
	for i in n:
		if sat[i] > ts:
			s_hi += sat[i]
			c_hi += 1
		else:
			s_lo += sat[i]
			c_lo += 1
	var use_sat := c_hi > n * 0.02 and c_hi < n * 0.92 and (s_hi / maxf(1, c_hi)) - (s_lo / maxf(1, c_lo)) > 70.0
	var tl := 0.0
	var paper_dark := false
	if use_sat:
		for i in n:
			if sat[i] > ts:
				paper[i] = 1
	else:
		tl = _otsu(hl) * 4.0
		var border_dark := 0
		var border_n := 0
		for y in h:
			for x in w:
				if x < 4 or y < 4 or x >= w - 4 or y >= h - 4:
					border_n += 1
					if lum[y * w + x] <= tl:
						border_dark += 1
		paper_dark = border_dark < border_n / 2
		for i in n:
			if (lum[i] <= tl) == paper_dark:
				paper[i] = 1
	var col := Vector3.ZERO
	var pc := 0
	for i in n:
		if paper[i] == 1:
			col += Vector3(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
			pc += 1
	if pc < n * 0.02:
		return {"error": "没找到剪纸：照片里纸和背景分不开，换一张背景干净的试试"}
	if pc > n * 0.92:
		return {"error": "整张都是纸：请拍到纸的边缘，背景留一点空"}
	col /= pc

	# 外接框
	var box := _largest_box(paper, w, h)
	if box.size.x < 20 or box.size.y < 20:
		return {"error": "剪纸太小了，靠近一点再拍"}

	# 逐个折法打分
	var cr := _centroid(paper, w, box)
	var scores := []
	for f in CANDIDATES:
		var r := _score_fold(paper, w, h, box, f, cr[0], cr[1])
		scores.append(r)
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	# 微调角度
	var rots := [-0.105, -0.07, -0.035, 0.035, 0.07, 0.105]
	for ki in mini(3, scores.size()):
		var r2 := _score_fold(paper, w, h, box, scores[ki]["fold"], cr[0], cr[1], rots)
		if r2["score"] > scores[ki]["score"]:
			scores[ki] = r2
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	var top: float = scores[0]["score"]
	var best := "none"
	var best_layers := 1
	var best_fit := {}
	for r in scores:
		if r["score"] >= 0.62 and r["score"] >= top - 0.05 and r["layers"] > best_layers:
			best = r["fold"]
			best_layers = r["layers"]
			best_fit = r
	if best == "none":
		best_fit = _fit_none(box)

	# 高清分割
	var seg := {"sat": use_sat, "ts": ts, "tl": tl, "dark": paper_dark}
	var hi := _hi_mask(src, w, box, seg)

	return {
		"w": w, "h": h, "paper": paper, "box": box,
		"hi": hi["img"], "hk": hi["k"], "seg": seg,
		"cen": cr[0], "rad": cr[1],
		"color": Color(col.x / 255.0, col.y / 255.0, col.z / 255.0),
		"paper_id": _nearest_paper(Color(col.x / 255.0, col.y / 255.0, col.z / 255.0)),
		"scores": scores,
		"best": best,
		"fit": best_fit,
		"difficulty": _difficulty(paper, w, h, box),
		"preview": img,
	}


# 生成样稿
static func make_template(an: Dictionary, fold: String, name: String, hires := false) -> Dictionary:
	var fit: Dictionary = {}
	for r in an["scores"]:
		if r["fold"] == fold:
			fit = r
	if fit.is_empty():
		fit = _fit_none(an["box"])
	var g := FoldGeom.build(fold)
	var b: Rect2 = g["bounds"]
	if hires and an.has("hi") and an["hi"] != null:
		var himg := _render_hi(an, fit, b)
		return _tpl_dict(an, fold, name, fit, himg, false)
	var side := 640.0
	var tw := int(side * b.size.x / maxf(b.size.x, b.size.y))
	var th := int(side * b.size.y / maxf(b.size.x, b.size.y))
	var out := PackedByteArray()
	out.resize(tw * th)
	var paper: PackedByteArray = an["paper"]
	var w: int = an["w"]
	var h: int = an["h"]
	var o: Vector2 = fit["origin"]
	var s: float = fit["scale"]
	var rot: float = fit.get("rot", 0.0)
	for y in th:
		for x in tw:
			var p := b.position + Vector2((x + 0.5) / tw * b.size.x, (y + 0.5) / th * b.size.y)
			var q := o + p.rotated(rot) * s
			var qx := int(q.x)
			var qy := int(q.y)
			if qx >= 0 and qy >= 0 and qx < w and qy < h and paper[qy * w + qx] == 1:
				out[y * tw + x] = 255
	var img := Image.create_from_data(tw, th, false, Image.FORMAT_L8, out)
	return _tpl_dict(an, fold, name, fit, img, true)


static func _tpl_dict(an: Dictionary, fold: String, name: String, fit: Dictionary, img: Image, with_tex: bool) -> Dictionary:
	var id := "photo_%d_%s" % [Time.get_unix_time_from_system(), fold]
	return {
		"id": id,
		"name": name,
		"fold": fold,
		"paper": an["paper_id"],
		"difficulty": an["difficulty"],
		"price": 0,
		"desc": "从照片生成 · 识别为%s，对称度 %d%%" % [Game.FOLDS[fold]["name"], int(round(float(fit.get("score", 1.0)) * 100.0))] if fold != "none" else "从照片生成 · 不折，单层刻纸",
		"image": img,
		"texture": ImageTexture.create_from_image(img) if with_tex else null,
		"user": true,
	}


# 高清分割
static func _hi_mask(src: Image, w: int, box: Rect2, seg: Dictionary) -> Dictionary:
	var hi := src.duplicate() as Image
	if hi.is_compressed():
		hi.decompress()
	hi.convert(Image.FORMAT_RGB8)
	var k := minf(1.0, float(HI_SIDE) / maxf(hi.get_width(), hi.get_height()))
	if k < 1.0:
		hi.resize(int(hi.get_width() * k), int(hi.get_height() * k), Image.INTERPOLATE_BILINEAR)
	var hw := hi.get_width()
	var hh := hi.get_height()
	var rel := float(hw) / w
	var r := Rect2(box.position * rel, box.size * rel).grow(maxf(box.size.x, box.size.y) * rel * 0.05)
	var x0 := clampi(int(r.position.x), 0, hw)
	var y0 := clampi(int(r.position.y), 0, hh)
	var x1 := clampi(int(ceil(r.end.x)), 0, hw)
	var y1 := clampi(int(ceil(r.end.y)), 0, hh)
	var data := hi.get_data()
	var out := PackedByteArray()
	out.resize(hw * hh)
	var use_sat: bool = seg["sat"]
	var ts: float = seg["ts"]
	var tl: float = seg["tl"]
	var dark: bool = seg["dark"]
	var inv := 255.0 / SOFT
	for y in range(y0, y1):
		var row := y * hw
		for x in range(x0, x1):
			var i := row + x
			var rr := float(data[i * 3])
			var gg := float(data[i * 3 + 1])
			var bb := float(data[i * 3 + 2])
			var d: float
			if use_sat:
				d = maxf(rr, maxf(gg, bb)) - minf(rr, minf(gg, bb)) - ts
			else:
				d = 0.299 * rr + 0.587 * gg + 0.114 * bb - tl
				if dark:
					d = -d
			out[i] = int(clampf(d * inv + 127.5, 0.0, 255.0))
	return {"img": Image.create_from_data(hw, hh, false, Image.FORMAT_L8, out), "k": rel}


# 高清样稿渲染
static func _render_hi(an: Dictionary, fit: Dictionary, b: Rect2) -> Image:
	var hi: Image = an["hi"]
	var k: float = an["hk"]
	var o: Vector2 = fit["origin"] * k
	var s: float = fit["scale"] * k
	var rot: float = fit.get("rot", 0.0)
	var tw := int(TPL_SIDE * b.size.x / maxf(b.size.x, b.size.y))
	var th := int(TPL_SIDE * b.size.y / maxf(b.size.x, b.size.y))
	var u := Rect2(o + b.position * s, b.size * s)
	var src := hi
	if absf(rot) > 0.0001:
		var hw := hi.get_width()
		var hh := hi.get_height()
		var sd := hi.get_data()
		var ux0 := clampi(int(u.position.x), 0, hw)
		var uy0 := clampi(int(u.position.y), 0, hh)
		var ux1 := clampi(int(ceil(u.end.x)), 0, hw)
		var uy1 := clampi(int(ceil(u.end.y)), 0, hh)
		var out := PackedByteArray()
		out.resize(hw * hh)
		var c := cos(rot)
		var sn := sin(rot)
		for y in range(uy0, uy1):
			var dy := y + 0.5 - o.y
			var qx := o.x + c * (ux0 + 0.5 - o.x) - sn * dy
			var qy := o.y + sn * (ux0 + 0.5 - o.x) + c * dy
			var row := y * hw
			for x in range(ux0, ux1):
				var ix := int(qx)
				var iy := int(qy)
				if ix >= 0 and iy >= 0 and ix < hw and iy < hh:
					out[row + x] = sd[iy * hw + ix]
				qx += c
				qy += sn
		src = Image.create_from_data(hw, hh, false, Image.FORMAT_L8, out)
	var tpl := Image.create_empty(tw, th, false, Image.FORMAT_L8)
	var full := Rect2i(0, 0, src.get_width(), src.get_height())
	var ui := Rect2i(Vector2i(floori(u.position.x), floori(u.position.y)), Vector2i(ceili(u.size.x), ceili(u.size.y))).intersection(full)
	if ui.size.x <= 1 or ui.size.y <= 1:
		return tpl
	var crop := src.get_region(ui)
	var sx := float(tw) / u.size.x
	var sy := float(th) / u.size.y
	crop.resize(maxi(1, int(round(ui.size.x * sx))), maxi(1, int(round(ui.size.y * sy))), Image.INTERPOLATE_BILINEAR)
	var dst := Vector2i(int(round((ui.position.x - u.position.x) * sx)), int(round((ui.position.y - u.position.y) * sy)))
	tpl.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), dst)
	return tpl


# 内部

static func _otsu(hist: PackedInt32Array) -> float:
	var total := 0
	var sum := 0.0
	for i in hist.size():
		total += hist[i]
		sum += i * hist[i]
	var sum_b := 0.0
	var w_b := 0
	var best := 0.0
	var th := 0.0
	for i in hist.size():
		w_b += hist[i]
		if w_b == 0:
			continue
		var w_f := total - w_b
		if w_f == 0:
			break
		sum_b += i * hist[i]
		var m_b := sum_b / w_b
		var m_f := (sum - sum_b) / w_f
		var between := float(w_b) * float(w_f) * (m_b - m_f) * (m_b - m_f)
		if between > best:
			best = between
			th = i + 0.5
	return th


static func _largest_box(paper: PackedByteArray, w: int, h: int) -> Rect2:
	var n := w * h
	var seen := PackedByteArray()
	seen.resize(n)
	var queue := PackedInt32Array()
	queue.resize(n)
	var comps := []
	var biggest := 0
	for start in n:
		if paper[start] == 0 or seen[start] == 1:
			continue
		var head := 0
		var tail := 1
		queue[0] = start
		seen[start] = 1
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		while head < tail:
			var i := queue[head]
			head += 1
			var x := i % w
			var y := i / w
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < n and paper[j] == 1 and seen[j] == 0:
					seen[j] = 1
					queue[tail] = j
					tail += 1
		comps.append([tail, Rect2(x0, y0, x1 - x0 + 1, y1 - y0 + 1)])
		biggest = maxi(biggest, tail)
	var box := Rect2()
	for c in comps:
		if c[0] >= maxi(30, int(biggest * 0.03)):
			box = c[1] if box.size == Vector2.ZERO else box.merge(c[1])
	return box


# 重心与半径
static func _centroid(paper: PackedByteArray, w: int, box: Rect2) -> Array:
	var c := Vector2.ZERO
	var k := 0
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			if paper[y * w + x] == 1:
				c += Vector2(x + 0.5, y + 0.5)
				k += 1
	c /= maxf(1.0, k)
	var r := 0.0
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			if paper[y * w + x] == 1:
				r = maxf(r, c.distance_to(Vector2(x + 0.5, y + 0.5)))
	return [c, r]


# 折法摆放参数
static func _fit(box: Rect2, bounds: Rect2, shift := Vector2.ZERO, fold := "", cen := Vector2.ZERO, rad := 0.0) -> Dictionary:
	var s := minf(box.size.x / bounds.size.x, box.size.y / bounds.size.y)
	var o := box.get_center() + shift - bounds.get_center() * s
	match fold:
		"four", "eight", "sixteen", "twelve", "five":
			var r_in := minf(minf(-bounds.position.x, bounds.end.x), minf(-bounds.position.y, bounds.end.y))
			s = rad / (r_in * 0.97)
			o = cen + shift
		"half":
			o.x = cen.x + shift.x
		"accordion":
			s = box.size.x / bounds.size.x
			o = box.get_center() + shift - bounds.get_center() * s
	return {"origin": o, "scale": s}


static func _fit_none(box: Rect2) -> Dictionary:
	var side := maxf(box.size.x, box.size.y)
	var r := Rect2(box.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	var f := _fit(r, Rect2(-500, -500, 1000, 1000))
	f["fold"] = "none"
	f["score"] = 1.0
	f["layers"] = 1
	return f


static func _score_fold(paper: PackedByteArray, w: int, h: int, box: Rect2, fold: String, cen: Vector2, rad: float, rots := [0.0]) -> Dictionary:
	var g := FoldGeom.build(fold)
	var wedge: PackedVector2Array = g["wedge"]
	var cells: Array = g["cells"]
	var wb: Rect2 = g["wedge_bounds"]
	var bounds: Rect2 = g["bounds"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var pts := PackedVector2Array()
	var guard := 0
	while pts.size() < SAMPLES and guard < SAMPLES * 20:
		guard += 1
		var p := wb.position + Vector2(rng.randf() * wb.size.x, rng.randf() * wb.size.y)
		if Geometry2D.is_point_in_polygon(p, wedge):
			pts.append(p)
	var best := {"fold": fold, "score": -1.0, "layers": cells.size()}
	var step := minf(box.size.x, box.size.y) * 0.012
	for rot in rots:
		for dy in [0, -1, 1]:
			for dx in [0, -1, 1]:
				var fit := _fit(box, bounds, Vector2(dx, dy) * step, fold, cen, rad)
				var o: Vector2 = fit["origin"]
				var s: float = fit["scale"]
				var r: float = rot
				_try(best, paper, w, h, pts, cells, o, s, r)
	best["score"] = clampf(best["score"], 0.0, 1.0)
	return best


static func _try(best: Dictionary, paper: PackedByteArray, w: int, h: int, pts: PackedVector2Array, cells: Array,
		o: Vector2, s: float, rot: float) -> void:
	var mism := 0
	var total := 0
	var ones := 0
	var vals := 0
	for p in pts:
		var v0 := _val(paper, w, h, o + p.rotated(rot) * s)
		ones += v0
		vals += 1
		for ci in range(1, cells.size()):
			var c: Transform2D = cells[ci]
			var v := _val(paper, w, h, o + (c * p).rotated(rot) * s)
			ones += v
			vals += 1
			if v != v0:
				mism += 1
			total += 1
	var pf := float(ones) / maxf(1.0, vals)
	var base := maxf(2.0 * pf * (1.0 - pf), 0.05)
	var score := 1.0 - (float(mism) / maxf(1.0, total)) / base
	if score > best["score"]:
		best["score"] = score
		best["origin"] = o
		best["scale"] = s
		best["rot"] = rot


static func _val(paper: PackedByteArray, w: int, h: int, q: Vector2) -> int:
	var x := int(q.x)
	var y := int(q.y)
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0
	return paper[y * w + x]


static func _nearest_paper(c: Color) -> String:
	var best := "red"
	var bd := INF
	for id in ["red", "peach", "wannian", "white", "indigo", "ink"]:
		var pc: Color = Game.PAPERS[id]["color"]
		var d := Vector3(pc.r - c.r, pc.g - c.g, pc.b - c.b).length()
		if d < bd:
			bd = d
			best = id
	return best


# 难度估计
static func _difficulty(paper: PackedByteArray, w: int, h: int, box: Rect2) -> int:
	var area := 0
	var per := 0
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			var i := y * w + x
			if paper[i] == 0:
				continue
			area += 1
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 or paper[i - 1] == 0 or paper[i + 1] == 0 \
					or paper[i - w] == 0 or paper[i + w] == 0:
				per += 1
	var e := float(per) / sqrt(maxf(1.0, area))
	return clampi(1 + int(e / 9.0), 1, 5)
