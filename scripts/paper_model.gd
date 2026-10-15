# 剪纸坊
# paper_model.gd - 剪纸遮罩模型
extends RefCounted

const FoldGeom = preload("res://scripts/fold_geom.gd")

const VIEW_RES := 1024
const EDIT_RES := 4096
const EDIT_RES_LOW := 2048
const PX_PER_UNIT_AT_1024 := 2.5
const ANA_MAX := 640
const MARGIN := 6.0
const SLIT_UNITS := 0.8
const SLIT_MIN_PX := 2.5
const HISTORY_LIMIT := 25
const HISTORY_BYTES := 96 * 1024 * 1024

var fold_id := "eight"
var wedge := PackedVector2Array()
var cells: Array[Transform2D] = []
var stages: Array = []
var neighbors: Array[Transform2D] = []
var bounds := Rect2()
var wedge_bounds := Rect2()

var tex_rect := Rect2()
var px_per_unit := 1.0
var tex_w := 0
var tex_h := 0
var res := VIEW_RES
var ds := 2
var a_w := 0
var a_h := 0
var classmap := PackedByteArray()

var mask: Image
var texture: ImageTexture
var initial_area := 1
var cut_count := 0
var tool_uses := {}
var epoch := 0

var _strip_dst := PackedInt32Array()
var _strip_src := PackedInt32Array()
# 撤销记录，按区域保存
var _history: Array = []
var _history_bytes := 0


# 剪纸台分辨率
static func edit_res() -> int:
	var info := OS.get_memory_info()
	var phys := int(info.get("physical", -1))
	if phys > 0 and phys < 3500 * 1024 * 1024:
		return EDIT_RES_LOW
	return EDIT_RES


func _init(p_fold := "eight", p_res := VIEW_RES) -> void:
	fold_id = p_fold
	res = p_res
	var g := FoldGeom.build(fold_id)
	wedge = g["wedge"]
	cells = g["cells"]
	stages = g["stages"]
	neighbors = g["neighbors"]
	bounds = g["bounds"]
	wedge_bounds = g["wedge_bounds"]

	var wb := wedge_bounds.grow(MARGIN)
	var cap := PX_PER_UNIT_AT_1024 * res / 1024.0
	px_per_unit = minf(minf(res / wb.size.x, res / wb.size.y), cap)
	var w0 := wb.size.x * px_per_unit
	var h0 := wb.size.y * px_per_unit
	ds = 2
	while maxf(w0, h0) / ds > ANA_MAX:
		ds *= 2
	tex_w = int(ceil(w0 / ds)) * ds
	tex_h = int(ceil(h0 / ds)) * ds
	tex_rect = Rect2(wb.position, Vector2(tex_w, tex_h) / px_per_unit)
	a_w = tex_w / ds
	a_h = tex_h / ds

	_build_classmap()
	_build_strips()
	mask = Image.create_empty(tex_w, tex_h, false, Image.FORMAT_L8)
	_fill_blank()
	texture = ImageTexture.create_from_image(mask)
	initial_area = maxi(1, count_paper())


# 坐标

func to_tex(p: Vector2) -> Vector2:
	return (p - tex_rect.position) * px_per_unit


func from_tex(q: Vector2) -> Vector2:
	return q / px_per_unit + tex_rect.position


func to_ana(p: Vector2) -> Vector2:
	return to_tex(p) / ds


func uv_of(p: Vector2) -> Vector2:
	return (p - tex_rect.position) / tex_rect.size


func ana_index(p: Vector2) -> int:
	var q := to_ana(p)
	var x := int(floor(q.x))
	var y := int(floor(q.y))
	if x < 0 or y < 0 or x >= a_w or y >= a_h:
		return -1
	return y * a_w + x


func in_wedge(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, wedge)


func layer_count() -> int:
	return cells.size()


# 剪

# 剪刀与刻刀
func cut_slit(points: PackedVector2Array, tool_id := "scissors", push := true) -> void:
	if points.size() < 2:
		return
	var hw := maxf(SLIT_UNITS * px_per_unit, SLIT_MIN_PX) * 0.5
	var clip := _cut_clip()
	var quads := []
	for i in points.size() - 1:
		var a := to_tex(points[i])
		var b := to_tex(points[i + 1])
		var d := b - a
		var l := d.length()
		if l < 0.01:
			continue
		d /= l
		var nrm := Vector2(-d.y, d.x) * hw
		a -= d * hw
		b += d * hw
		quads.append(PackedVector2Array([a + nrm, b + nrm, b - nrm, a - nrm]))
	if quads.is_empty():
		return
	if push:
		_push_history(_bbox_of(quads))
	else:
		_add_patch(_bbox_of(quads))
	var edits := {}
	for q in quads:
		_fill_aa(mask, q, clip, true, edits)
	_apply_edits(edits, true)
	_after_change(tool_id)


# 纹样挖空
func cut_region(polys: Array, tool_id := "stamp") -> void:
	var clip := _cut_clip()
	var tps := []
	for poly in polys:
		if poly.size() >= 3:
			tps.append(_tex_poly(poly))
	if tps.is_empty():
		return
	_push_history(_bbox_of(tps))
	var edits := {}
	for tp in tps:
		_fill_aa(mask, tp, clip, true, edits)
	_apply_edits(edits, true)
	_after_change(tool_id)


# 碎片掉落
func drop_pieces(drop_la: Image, keep_la: Image) -> Image:
	var used := drop_la.get_used_rect()
	if used.size.x <= 0:
		return null
	var g := used.grow(1).intersection(Rect2i(0, 0, a_w, a_h))
	var rect := Rect2i(g.position * ds, g.size * ds)
	_add_patch(rect)
	var before := mask.get_region(rect)
	var up := drop_la.get_region(g)
	up.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	var black := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_L8)
	mask.blit_rect_mask(black, up, Rect2i(Vector2i.ZERO, rect.size), rect.position)
	# 边缘带逐像素处理
	_resolve_band(drop_la, keep_la, rect)
	_mirror_strips()
	texture.update(mask)
	# 掉落动画用图
	var kp := keep_la.get_region(g)
	kp.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_NEAREST)
	before.blit_rect_mask(black, kp, Rect2i(Vector2i.ZERO, rect.size), Vector2i.ZERO)
	var f := 1
	while maxi(tex_w, tex_h) / f > 1024 and f < ds:
		f *= 2
	var piece := Image.create_empty(tex_w / f, tex_h / f, false, Image.FORMAT_L8)
	if f > 1:
		before.resize(rect.size.x / f, rect.size.y / f, Image.INTERPOLATE_BILINEAR)
	piece.blit_rect(before, Rect2i(Vector2i.ZERO, before.get_size()), rect.position / f)
	return piece


# 碎片边缘带
func _resolve_band(drop_la: Image, keep_la: Image, rect: Rect2i) -> void:
	var dd := drop_la.get_data()
	var kd := keep_la.get_data()
	var g0 := rect.position / ds
	var g1 := (rect.end + Vector2i(ds - 1, ds - 1)) / ds
	g0 = Vector2i(maxi(0, g0.x), maxi(0, g0.y))
	g1 = Vector2i(mini(a_w, g1.x), mini(a_h, g1.y))
	var st := PackedByteArray()
	st.resize(a_w * a_h)
	for gi in st.size():
		if dd[gi * 2 + 1] > 0:
			st[gi] = 1
		elif kd[gi * 2 + 1] == 0 and classmap[gi] != 0:
			st[gi] = 2
	var data := mask.get_data()
	var n_px := data.size()
	var seen := {}
	var queue := PackedInt32Array()
	for gy in range(g0.y, g1.y):
		for gx in range(g0.x, g1.x):
			if st[gy * a_w + gx] != 2:
				continue
			for py in range(gy * ds, gy * ds + ds):
				for px in range(gx * ds, gx * ds + ds):
					var idx := py * tex_w + px
					if data[idx] < 128:
						continue
					for nb in [idx - 1 if px > 0 else -1, idx + 1 if px < tex_w - 1 else -1, idx - tex_w, idx + tex_w]:
						if nb >= 0 and nb < n_px and st[((nb / tex_w) / ds) * a_w + (nb % tex_w) / ds] == 1:
							seen[idx] = true
							queue.append(idx)
							break
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		data[idx] = 0
		var x := idx % tex_w
		for nb in [idx - 1 if x > 0 else -1, idx + 1 if x < tex_w - 1 else -1, idx - tex_w, idx + tex_w]:
			if nb < 0 or nb >= n_px or seen.has(nb):
				continue
			if st[((nb / tex_w) / ds) * a_w + (nb % tex_w) / ds] != 2:
				continue
			if data[nb] < 128:
				data[nb] = 0
				seen[nb] = true
				continue
			seen[nb] = true
			queue.append(nb)
	mask.set_data(tex_w, tex_h, false, Image.FORMAT_L8, data)


# 载入剪纸图
func set_mask(img: Image) -> void:
	var m := img.duplicate() as Image
	if m.is_compressed():
		m.decompress()
	m.convert(Image.FORMAT_L8)
	if m.get_width() != tex_w or m.get_height() != tex_h:
		m.resize(tex_w, tex_h, Image.INTERPOLATE_BILINEAR)
	mask = m
	_mirror_strips()
	texture.update(mask)


# 由样稿目标生成成品
func set_mask_from_keep(keep: PackedByteArray) -> void:
	var data := PackedByteArray()
	data.resize(a_w * a_h)
	for i in keep.size():
		if keep[i] == 1:
			data[i] = 255
	var img := Image.create_from_data(a_w, a_h, false, Image.FORMAT_L8, data)
	img.resize(tex_w, tex_h, Image.INTERPOLATE_BILINEAR)
	mask = img
	_mirror_strips()
	texture.update(mask)


func undo() -> bool:
	if _history.is_empty():
		return false
	var entry: Array = _history.pop_back()
	for i in range(entry.size() - 1, -1, -1):
		var patch: Array = entry[i]
		var img: Image = patch[1]
		mask.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), patch[0])
		_history_bytes -= img.get_data_size()
	_mirror_strips()
	texture.update(mask)
	cut_count = maxi(0, cut_count - 1)
	epoch += 1
	return true


func reset() -> void:
	_push_history(Rect2i(0, 0, tex_w, tex_h))
	_fill_blank()
	texture.update(mask)
	cut_count = 0
	tool_uses.clear()
	epoch += 1


func can_undo() -> bool:
	return not _history.is_empty()


func count_paper() -> int:
	var data := shrink(mask, a_w, a_h)
	var c := 0
	for i in data.size():
		if data[i] > 240 and classmap[i] == 2:
			c += 1
	return c


# 缩小到分析尺寸
static func shrink(img: Image, w: int, h: int) -> PackedByteArray:
	var m := img.duplicate() as Image
	if m.get_format() != Image.FORMAT_L8:
		m.convert(Image.FORMAT_L8)
	var lvl := 0
	while (m.get_width() >> lvl) > w:
		lvl += 1
	if lvl == 0:
		if m.get_width() != w or m.get_height() != h:
			m.resize(w, h, Image.INTERPOLATE_BILINEAR)
		return m.get_data()
	if (m.get_width() >> lvl) == w and (m.get_height() >> lvl) == h \
			and m.get_width() % (1 << lvl) == 0 and m.get_height() % (1 << lvl) == 0:
		m.generate_mipmaps()
		var off := m.get_mipmap_offset(lvl)
		return m.get_data().slice(off, off + w * h)
	m.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return m.get_data()


func _after_change(tool_id: String) -> void:
	texture.update(mask)
	cut_count += 1
	tool_uses[tool_id] = tool_uses.get(tool_id, 0) + 1


# 撤销

func _push_history(rect: Rect2i) -> void:
	_history.append([])
	_add_patch(rect)
	while _history.size() > HISTORY_LIMIT or (_history_bytes > HISTORY_BYTES and _history.size() > 1):
		for patch in _history.pop_front():
			_history_bytes -= (patch[1] as Image).get_data_size()


func _add_patch(rect: Rect2i) -> void:
	rect = rect.intersection(Rect2i(0, 0, tex_w, tex_h))
	if _history.is_empty() or rect.size.x <= 0 or rect.size.y <= 0:
		return
	var img := mask.get_region(rect)
	_history[_history.size() - 1].append([rect.position, img])
	_history_bytes += img.get_data_size()


func _bbox_of(polys: Array) -> Rect2i:
	var r := Rect2()
	var first := true
	for poly in polys:
		for p in poly:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return Rect2i(Vector2i(floori(r.position.x) - 2, floori(r.position.y) - 2),
			Vector2i(ceili(r.size.x) + 5, ceili(r.size.y) + 5))


# 铺满扇区
func _fill_blank() -> void:
	mask.fill(Color(0, 0, 0))
	var w := _tex_poly(wedge)
	_fill(mask, w, w, 1.0)
	_mirror_strips()


# 剪切范围外扩 2 像素
func _cut_clip() -> PackedVector2Array:
	if _clip_cache.is_empty():
		var g := Geometry2D.offset_polygon(_tex_poly(wedge), 2.0)
		_clip_cache = g[0] if not g.is_empty() else _tex_poly(wedge)
	return _clip_cache


var _clip_cache := PackedVector2Array()


func _tex_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = to_tex(poly[i])
	return out


# 扇区分类与镜像边带

func _build_classmap() -> void:
	var img := Image.create_empty(a_w, a_h, false, Image.FORMAT_L8)
	var s := px_per_unit / ds
	for g in cells:
		var poly := PackedVector2Array()
		for p in g * wedge:
			poly.append((p - tex_rect.position) * s)
		_fill(img, poly, poly, 1.0 / 255.0)
	var wp := PackedVector2Array()
	for p in wedge:
		wp.append((p - tex_rect.position) * s)
	_fill(img, wp, wp, 2.0 / 255.0)
	classmap = img.get_data()


func _build_strips() -> void:
	var seen := {}
	var center := Vector2.ZERO
	for p in wedge:
		center += p
	center /= wedge.size()
	var offs := [0.4, 1.2, 2.0, 2.8, 3.6] if res <= VIEW_RES else [0.4, 1.2, 2.0, 2.8, 3.6, 4.4, 5.2]
	for n in neighbors:
		var cell := n * wedge
		var inv := n.affine_inverse()
		for i in wedge.size():
			var a := wedge[i]
			var b := wedge[(i + 1) % wedge.size()]
			if not (_has_vertex(cell, a) and _has_vertex(cell, b)):
				continue
			var edge := b - a
			var len_px := edge.length() * px_per_unit
			var out := Vector2(-edge.y, edge.x).normalized()
			if out.dot((a + b) * 0.5 - center) < 0.0:
				out = -out
			var steps := int(len_px * 2.0) + 1
			for k in steps + 1:
				var base := a + edge * (float(k) / steps)
				for o in offs:
					var x: Vector2 = base + out * (o / px_per_unit)
					var q := to_tex(x)
					var qx := int(floor(q.x))
					var qy := int(floor(q.y))
					if qx < 0 or qy < 0 or qx >= tex_w or qy >= tex_h:
						continue
					var di := qy * tex_w + qx
					if seen.has(di):
						continue
					seen[di] = true
					var pc := from_tex(Vector2(qx + 0.5, qy + 0.5))
					if Geometry2D.is_point_in_polygon(pc, wedge):
						continue
					var sp := inv * pc
					var src := to_tex(sp)
					for _t in 4:
						var sc := from_tex(Vector2(floor(src.x) + 0.5, floor(src.y) + 0.5))
						if Geometry2D.is_point_in_polygon(sc, wedge):
							break
						sp += (center - sp).normalized() * (0.7 / px_per_unit)
						src = to_tex(sp)
					var sx := clampi(int(floor(src.x)), 0, tex_w - 1)
					var sy := clampi(int(floor(src.y)), 0, tex_h - 1)
					_strip_dst.append(di)
					_strip_src.append(sy * tex_w + sx)


static func _has_vertex(poly: PackedVector2Array, v: Vector2) -> bool:
	for p in poly:
		if p.distance_to(v) < 0.5:
			return true
	return false


func _mirror_strips() -> void:
	if _strip_dst.is_empty():
		return
	var data := mask.get_data()
	_mirror_into(data)
	mask.set_data(tex_w, tex_h, false, Image.FORMAT_L8, data)


func _mirror_into(data: PackedByteArray) -> void:
	for i in _strip_dst.size():
		data[_strip_dst[i]] = data[_strip_src[i]]


# 写回边缘像素并刷新边带
func _apply_edits(edits: Dictionary, cut: bool) -> void:
	var data := mask.get_data()
	if cut:
		for idx in edits:
			data[idx] = int(data[idx] * float(edits[idx]) + 0.5)
	else:
		for idx in edits:
			data[idx] = maxi(data[idx], int(float(edits[idx]) * 255.0 + 0.5))
	_mirror_into(data)
	mask.set_data(tex_w, tex_h, false, Image.FORMAT_L8, data)


# 填充

# 扫描线填充
static func _fill(img: Image, poly: PackedVector2Array, clip: PackedVector2Array, value: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var keys := PackedFloat64Array()
	var np := poly.size()
	for i in np:
		var a := poly[i]
		var b := poly[(i + 1) % np]
		if a.y == b.y:
			continue
		var ylo := minf(a.y, b.y)
		var yhi := maxf(a.y, b.y)
		var ra := maxi(0, int(ceil(ylo - 0.5)))
		var rb := mini(h - 1, int(ceil(yhi - 0.5)) - 1)
		if rb < ra:
			continue
		var inv := (b.x - a.x) / (b.y - a.y)
		for y in range(ra, rb + 1):
			var yc := y + 0.5
			var x := clampf(a.x + (yc - a.y) * inv, -2000.0, 4000.0)
			keys.append(y * 8192.0 + x + 2048.0)
	if keys.size() < 2:
		return
	keys.sort()
	var col := Color(value, value, value)
	var count := keys.size()
	var i := 0
	while i < count:
		var row := int(keys[i] / 8192.0)
		var j := i
		while j < count and int(keys[j] / 8192.0) == row:
			j += 1
		var span := _clip_span(clip, row + 0.5)
		if span.x <= span.y:
			var base := row * 8192.0 + 2048.0
			var k := i
			while k + 1 < j:
				var l := maxf(keys[k] - base, span.x)
				var r := minf(keys[k + 1] - base, span.y)
				if r > l:
					var xa := clampi(int(ceil(l - 0.5)), 0, w)
					var xb := clampi(int(ceil(r - 0.5)), 0, w)
					if xb > xa:
						img.fill_rect(Rect2i(xa, row, xb - xa, 1), col)
				k += 2
		i = j


static func _clip_span(clip: PackedVector2Array, yc: float) -> Vector2:
	var l := INF
	var r := -INF
	var nc := clip.size()
	for i in nc:
		var a := clip[i]
		var b := clip[(i + 1) % nc]
		if (a.y <= yc and b.y >= yc) or (b.y <= yc and a.y >= yc):
			if absf(b.y - a.y) < 1e-6:
				l = minf(l, minf(a.x, b.x))
				r = maxf(r, maxf(a.x, b.x))
			else:
				var x := a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y)
				l = minf(l, x)
				r = maxf(r, x)
	return Vector2(l, r)


# 抗锯齿填充
static func _fill_aa(img: Image, poly: PackedVector2Array, clip: PackedVector2Array, cut: bool, edits: Dictionary) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var np := poly.size()
	if np < 3:
		return
	var ymin := INF
	var ymax := -INF
	for p in poly:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var r0 := maxi(0, int(floor(ymin)))
	var r1 := mini(h - 1, int(ceil(ymax)) - 1)
	var col := Color(0, 0, 0) if cut else Color(1, 1, 1)
	for row in range(r0, r1 + 1):
		var subs := []
		var same := true
		var cnt := -1
		var any := false
		for s in 4:
			var yc := row + (s + 0.5) * 0.25
			var xs := PackedFloat32Array()
			for i in np:
				var a := poly[i]
				var b := poly[(i + 1) % np]
				if (a.y <= yc) == (b.y <= yc):
					continue
				xs.append(a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y))
			xs.sort()
			var cs := _clip_span(clip, yc)
			var sp := PackedFloat32Array()
			var k := 0
			while k + 1 < xs.size():
				var l := maxf(maxf(xs[k], cs.x), 0.0)
				var r := minf(minf(xs[k + 1], cs.y), float(w))
				if r > l:
					sp.append(l)
					sp.append(r)
				k += 2
			subs.append(sp)
			if not sp.is_empty():
				any = true
			if cnt == -1:
				cnt = sp.size()
			elif cnt != sp.size():
				same = false
		if not any:
			continue
		var base := row * w
		if same:
			for j in range(0, cnt, 2):
				var lmin := INF
				var lmax := -INF
				var rmin := INF
				var rmax := -INF
				for s in 4:
					var sp: PackedFloat32Array = subs[s]
					lmin = minf(lmin, sp[j])
					lmax = maxf(lmax, sp[j])
					rmin = minf(rmin, sp[j + 1])
					rmax = maxf(rmax, sp[j + 1])
				var cl := int(ceil(lmax))
				var cr := int(floor(rmin))
				if cr > cl:
					img.fill_rect(Rect2i(cl, row, cr - cl, 1), col)
					_edge_px(subs, j, j + 2, int(floor(lmin)), cl, base, cut, edits)
					_edge_px(subs, j, j + 2, cr, int(ceil(rmax)), base, cut, edits)
				else:
					_edge_px(subs, j, j + 2, int(floor(lmin)), int(ceil(rmax)), base, cut, edits)
		else:
			var lo := INF
			var hi := -INF
			for sp in subs:
				if not sp.is_empty():
					lo = minf(lo, sp[0])
					hi = maxf(hi, sp[sp.size() - 1])
			_edge_px(subs, 0, -1, int(floor(lo)), int(ceil(hi)), base, cut, edits)


static func _edge_px(subs: Array, j0: int, j1: int, x0: int, x1: int, base: int, cut: bool, edits: Dictionary) -> void:
	for x in range(x0, x1):
		var c := 0.0
		for s in 4:
			var sp: PackedFloat32Array = subs[s]
			var jb := sp.size() if j1 < 0 else mini(j1, sp.size())
			var k := j0
			while k + 1 < jb:
				c += clampf(minf(x + 1.0, sp[k + 1]) - maxf(float(x), sp[k]), 0.0, 1.0)
				k += 2
		c *= 0.25
		if c <= 0.002:
			continue
		var idx := base + x
		if cut:
			edits[idx] = float(edits.get(idx, 1.0)) * (1.0 - c)
		else:
			edits[idx] = maxf(float(edits.get(idx, 0.0)), c)
