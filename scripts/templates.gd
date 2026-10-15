# 剪纸坊
# templates.gd - 样稿读取与对照评分
extends RefCounted

const FoldGeom = preload("res://scripts/fold_geom.gd")
const PaperModel = preload("res://scripts/paper_model.gd")
const DIR := "res://templates"

static var _cache: Array = []


static func all() -> Array:
	if _cache.is_empty():
		_cache = _load_all()
	return _cache


static func find(id: String) -> Dictionary:
	for t in all():
		if t["id"] == id:
			return t
	return {}


static func _load_all() -> Array:
	var out := []
	for f in DirAccess.get_files_at(DIR):
		if not f.ends_with(".cfg"):
			continue
		var base := f.get_basename()
		var cfg := ConfigFile.new()
		if cfg.load(DIR + "/" + f) != OK:
			push_warning("模板配置读不出来：" + f)
			continue
		var png_path := DIR + "/" + base + ".png"
		if not ResourceLoader.exists(png_path):
			push_warning("模板缺少图片：" + png_path)
			continue
		var tex: Texture2D = load(png_path)
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_L8)
		var fold := str(cfg.get_value("template", "fold", "eight"))
		if not FoldGeom.IDS.has(fold):
			push_warning("模板 %s 的折法 %s 不认识，按八折处理" % [base, fold])
			fold = "eight"
		var paper := str(cfg.get_value("template", "paper", "red"))
		if not Game.PAPERS.has(paper):
			paper = "red"
		out.append({
			"id": base,
			"name": str(cfg.get_value("template", "name", base)),
			"fold": fold,
			"paper": paper,
			"difficulty": clampi(int(cfg.get_value("template", "difficulty", 3)), 1, 5),
			"price": maxi(0, int(cfg.get_value("template", "price", 0))),
			"desc": str(cfg.get_value("template", "desc", "")),
			"image": img,
			"texture": tex,
		})
	out.sort_custom(func(a, b): return a["price"] < b["price"] if a["price"] != b["price"] else a["difficulty"] < b["difficulty"])
	var mine := _load_user()
	mine.reverse()
	return mine + out


const USER_DIR := "user://photo_templates"


static func _load_user() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(USER_DIR):
		return out
	var files := Array(DirAccess.get_files_at(USER_DIR))
	files.sort()
	for f in files:
		if not f.ends_with(".cfg"):
			continue
		var base: String = f.get_basename()
		var cfg := ConfigFile.new()
		if cfg.load(USER_DIR + "/" + f) != OK:
			continue
		var img := Image.load_from_file(USER_DIR + "/" + base + ".png")
		if img == null:
			continue
		img.convert(Image.FORMAT_L8)
		var fold := str(cfg.get_value("template", "fold", "none"))
		out.append({
			"id": base,
			"name": str(cfg.get_value("template", "name", "我的样稿")),
			"fold": fold if FoldGeom.IDS.has(fold) else "none",
			"paper": str(cfg.get_value("template", "paper", "red")),
			"difficulty": clampi(int(cfg.get_value("template", "difficulty", 3)), 1, 5),
			"price": 0,
			"desc": str(cfg.get_value("template", "desc", "")),
			"image": img,
			"texture": ImageTexture.create_from_image(img),
			"user": true,
		})
	return out


# 保存用户样稿
static func add_user(t: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var img: Image = t["image"]
	img.save_png("%s/%s.png" % [USER_DIR, t["id"]])
	var cfg := ConfigFile.new()
	for k in ["name", "fold", "paper", "difficulty", "desc"]:
		cfg.set_value("template", k, t[k])
	cfg.save("%s/%s.cfg" % [USER_DIR, t["id"]])
	all()
	_cache.insert(0, t)


static func rename_user(id: String, new_name: String) -> void:
	for t in all():
		if t["id"] == id:
			t["name"] = new_name
	var path := "%s/%s.cfg" % [USER_DIR, id]
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		cfg.set_value("template", "name", new_name)
		cfg.save(path)


static func delete_user(id: String) -> void:
	for i in range(all().size() - 1, -1, -1):
		if _cache[i]["id"] == id and _cache[i].get("user", false):
			_cache.remove_at(i)
	DirAccess.remove_absolute("%s/%s.cfg" % [USER_DIR, id])
	DirAccess.remove_absolute("%s/%s.png" % [USER_DIR, id])


static func user_count() -> int:
	var c := 0
	for t in all():
		if t.get("user", false):
			c += 1
	return c


# 样稿映射到扇区
static func build_target(model, img: Image, with_lines := true) -> Dictionary:
	var a_w: int = model.a_w
	var a_h: int = model.a_h
	var total := a_w * a_h
	var b: Rect2 = model.bounds
	var k: float = model.px_per_unit / model.ds
	var tw := maxi(8, int(ceil(b.size.x * k)))
	var th := maxi(8, int(ceil(b.size.y * k)))
	var src := img.duplicate() as Image
	src.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	var sdata := src.get_data()
	var classmap: PackedByteArray = model.classmap
	var off: Vector2 = (model.tex_rect.position - b.position) * k

	var keep := PackedByteArray()
	keep.resize(total)
	for y in a_h:
		var ty := clampi(int(off.y + y + 0.5), 0, th - 1)
		for x in a_w:
			var i := y * a_w + x
			if classmap[i] != 2:
				continue
			var tx := clampi(int(off.x + x + 0.5), 0, tw - 1)
			if sdata[ty * tw + tx] > 127:
				keep[i] = 1
	var keep_raw := keep
	keep = _bridge_islands(keep, classmap, a_w, a_h)
	if not with_lines:
		return {"keep": keep, "keep_raw": keep_raw, "lines": [], "cut_px": 0}

	# 待剪轮廓转虚线
	var la := PackedByteArray()
	la.resize(total * 2)
	var cut_px := 0
	for i in total:
		if classmap[i] == 2 and keep[i] == 0:
			la[i * 2 + 1] = 255
			cut_px += 1
	var bm := BitMap.new()
	bm.create_from_image_alpha(Image.create_from_data(a_w, a_h, false, Image.FORMAT_LA8, la), 0.5)
	var polys := bm.opaque_to_polygons(Rect2i(0, 0, a_w, a_h), 1.0)
	var scale: float = float(model.ds) / model.px_per_unit
	var tol: float = 2.5 * scale
	var wedge: PackedVector2Array = model.wedge
	var lines := []
	for poly in polys:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(model.tex_rect.position + q * scale)
		for seg in _split_on_edges(pts, wedge, tol):
			lines.append(_smooth(seg))
	return {"keep": keep, "keep_raw": keep_raw, "lines": lines, "cut_px": cut_px}


# 轮廓平滑
static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var closed := pts.size() > 3 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01
	var cur := pts
	if closed:
		cur = pts.slice(0, pts.size() - 1)
	for _it in 2:
		var n := cur.size()
		if n < 3:
			break
		var nxt := PackedVector2Array()
		if not closed:
			nxt.append(cur[0])
		var last := n if closed else n - 1
		for i in last:
			var a := cur[i]
			var b := cur[(i + 1) % n]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		if not closed:
			nxt.append(cur[n - 1])
		cur = nxt
	if closed and cur.size() > 0:
		cur.append(cur[0])
	return cur


# 样稿高清遮罩
static func target_mask(model, img: Image, tg: Dictionary) -> Image:
	var b: Rect2 = model.bounds
	var tr: Rect2 = model.tex_rect
	var tw: int = model.tex_w
	var th: int = model.tex_h
	var src := img.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_L8)
	var iw := src.get_width()
	var ih := src.get_height()
	var sc := Vector2(iw, ih) / b.size
	var u := Rect2((tr.position - b.position) * sc, tr.size * sc)
	var out := Image.create_empty(tw, th, false, Image.FORMAT_L8)
	var ui := Rect2i(Vector2i(floori(u.position.x), floori(u.position.y)), Vector2i(ceili(u.size.x), ceili(u.size.y))).intersection(Rect2i(0, 0, iw, ih))
	if ui.size.x > 1 and ui.size.y > 1:
		var crop := src.get_region(ui)
		var kx := tw / u.size.x
		var ky := th / u.size.y
		crop.resize(maxi(1, int(round(ui.size.x * kx))), maxi(1, int(round(ui.size.y * ky))), Image.INTERPOLATE_BILINEAR)
		out.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(int(round((ui.position.x - u.position.x) * kx)), int(round((ui.position.y - u.position.y) * ky))))
	# 连接筋与碎点
	var keep: PackedByteArray = tg["keep"]
	var raw: PackedByteArray = tg.get("keep_raw", keep)
	var a_w: int = model.a_w
	var a_h: int = model.a_h
	var add := PackedByteArray()
	add.resize(a_w * a_h * 2)
	var rem := PackedByteArray()
	rem.resize(a_w * a_h * 2)
	var any_add := false
	var any_rem := false
	for i in keep.size():
		if keep[i] == 1 and raw[i] == 0:
			add[i * 2 + 1] = 255
			any_add = true
		elif keep[i] == 0 and raw[i] == 1:
			var x := i % a_w
			var y := i / a_w
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx >= 0 and ny >= 0 and nx < a_w and ny < a_h and keep[ny * a_w + nx] == 0:
						rem[(ny * a_w + nx) * 2 + 1] = 255
			any_rem = true
	if any_rem:
		var m := Image.create_from_data(a_w, a_h, false, Image.FORMAT_LA8, rem)
		m.resize(tw, th, Image.INTERPOLATE_NEAREST)
		out.blit_rect_mask(Image.create_empty(tw, th, false, Image.FORMAT_L8), m, Rect2i(0, 0, tw, th), Vector2i.ZERO)
	if any_add:
		var m2 := Image.create_from_data(a_w, a_h, false, Image.FORMAT_LA8, add)
		m2.resize(tw, th, Image.INTERPOLATE_NEAREST)
		var white := Image.create_empty(tw, th, false, Image.FORMAT_L8)
		white.fill(Color(1, 1, 1))
		out.blit_rect_mask(white, m2, Rect2i(0, 0, tw, th), Vector2i.ZERO)
	return out


static func _split_on_edges(pts: PackedVector2Array, wedge: PackedVector2Array, tol: float) -> Array:
	var n := pts.size()
	if n < 2:
		return []
	var on_edge := []
	var any := false
	for i in n:
		var m := (pts[i] + pts[(i + 1) % n]) * 0.5
		var e := _dist_to_poly_edges(m, wedge) < tol
		on_edge.append(e)
		any = any or e
	var out := []
	if not any:
		var closed := pts.duplicate()
		closed.append(pts[0])
		out.append(closed)
		return out
	var start := 0
	while not on_edge[start]:
		start += 1
	var cur := PackedVector2Array()
	for k in n:
		var i := (start + k) % n
		if on_edge[i]:
			if cur.size() >= 2:
				out.append(cur)
			cur = PackedVector2Array()
		else:
			if cur.is_empty():
				cur.append(pts[i])
			cur.append(pts[(i + 1) % n])
	if cur.size() >= 2:
		out.append(cur)
	return out


static func _dist_to_poly_edges(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(c))
	return best


# 孤岛补连接筋
static func _bridge_islands(arr: PackedByteArray, classmap: PackedByteArray, a_w: int, a_h: int) -> PackedByteArray:
	var total := a_w * a_h
	var labels := PackedInt32Array()
	labels.resize(total)
	labels.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(total)
	var sizes := []
	var lab := 0
	for start in total:
		if arr[start] == 0 or labels[start] != -1:
			continue
		var head := 0
		var tail := 1
		queue[0] = start
		labels[start] = lab
		while head < tail:
			var idx := queue[head]
			head += 1
			var x := idx % a_w
			for j in [idx - 1 if x > 0 else -1, idx + 1 if x < a_w - 1 else -1, idx - a_w, idx + a_w]:
				if j >= 0 and j < total and arr[j] == 1 and labels[j] == -1:
					labels[j] = lab
					queue[tail] = j
					tail += 1
		sizes.append(tail)
		lab += 1
	if sizes.is_empty():
		return arr
	var main := 0
	for i in sizes.size():
		if sizes[i] > sizes[main]:
			main = i
	var out := PackedByteArray()
	out.resize(total)
	var in_main := PackedByteArray()
	in_main.resize(total)
	for i in total:
		if labels[i] == main:
			out[i] = 1
			in_main[i] = 1
	var order := range(sizes.size())
	order.sort_custom(func(a, b): return sizes[a] > sizes[b])
	var min_size := maxi(6, int(sizes[main] * 0.0015))
	var parent := PackedInt32Array()
	parent.resize(total)
	var dist := PackedInt32Array()
	dist.resize(total)
	for l in order:
		if l == main or sizes[l] < min_size:
			continue
		dist.fill(-1)
		var head := 0
		var tail := 0
		for i in total:
			if labels[i] == l:
				dist[i] = 0
				parent[i] = -1
				queue[tail] = i
				tail += 1
		var hit := -1
		while head < tail and hit < 0:
			var idx := queue[head]
			head += 1
			var x := idx % a_w
			for j in [idx - 1 if x > 0 else -1, idx + 1 if x < a_w - 1 else -1, idx - a_w, idx + a_w]:
				if j < 0 or j >= total or dist[j] != -1 or classmap[j] != 2:
					continue
				dist[j] = dist[idx] + 1
				parent[j] = idx
				if in_main[j] == 1:
					hit = j
					break
				queue[tail] = j
				tail += 1
		if hit < 0:
			continue
		var p := parent[hit]
		while p >= 0 and labels[p] != l:
			var px := p % a_w
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var q: int = p + dy * a_w + dx
					if px + dx < 0 or px + dx >= a_w or q < 0 or q >= total or classmap[q] != 2:
						continue
					out[q] = 1
					in_main[q] = 1
			p = parent[p]
		for i in total:
			if labels[i] == l:
				out[i] = 1
				in_main[i] = 1
	return out


static func _largest(arr: PackedByteArray, a_w: int, a_h: int) -> PackedByteArray:
	var total := a_w * a_h
	var labels := PackedInt32Array()
	labels.resize(total)
	labels.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(total)
	var best_lab := -1
	var best_size := 0
	var lab := 0
	for start in total:
		if arr[start] == 0 or labels[start] != -1:
			continue
		var head := 0
		var tail := 1
		queue[0] = start
		labels[start] = lab
		while head < tail:
			var idx := queue[head]
			head += 1
			var x := idx % a_w
			for j in [idx - 1 if x > 0 else -1, idx + 1 if x < a_w - 1 else -1, idx - a_w, idx + a_w]:
				if j >= 0 and j < total and arr[j] == 1 and labels[j] == -1:
					labels[j] = lab
					queue[tail] = j
					tail += 1
		if tail > best_size:
			best_size = tail
			best_lab = lab
		lab += 1
	var out := PackedByteArray()
	out.resize(total)
	for i in total:
		if labels[i] == best_lab and best_lab >= 0:
			out[i] = 1
	return out


# 作品与样稿对照
static func compare(model, target: Dictionary) -> Dictionary:
	var a_w: int = model.a_w
	var a_h: int = model.a_h
	var total := a_w * a_h
	var data: PackedByteArray = PaperModel.shrink(model.mask, a_w, a_h)
	var classmap: PackedByteArray = model.classmap
	var keep: PackedByteArray = target["keep"]

	var band := PackedByteArray()
	band.resize(total)
	for i in total:
		if classmap[i] != 2:
			continue
		var x := i % a_w
		for j in [i - 1 if x > 0 else -1, i + 1 if x < a_w - 1 else -1, i - a_w, i + a_w]:
			if j >= 0 and j < total and classmap[j] == 2 and keep[j] != keep[i]:
				band[i] = 1
				break
	var band2 := band.duplicate()
	for i in total:
		if band[i] == 1:
			var x := i % a_w
			if x > 0: band2[i - 1] = 1
			if x < a_w - 1: band2[i + 1] = 1
			if i >= a_w: band2[i - a_w] = 1
			if i < total - a_w: band2[i + a_w] = 1

	var inter := 0
	var union := 0
	var missed := 0
	var extra := 0
	var diff := PackedByteArray()
	diff.resize(total * 4)
	for i in total:
		if classmap[i] != 2 or band2[i] == 1:
			continue
		var paper := data[i] > 240
		var cut_t := keep[i] == 0
		var cut_a := not paper
		if cut_t and cut_a:
			inter += 1
		if cut_t or cut_a:
			union += 1
		if cut_t and paper:
			missed += 1
			diff[i * 4] = 250
			diff[i * 4 + 1] = 200
			diff[i * 4 + 2] = 60
			diff[i * 4 + 3] = 220
		elif (not cut_t) and cut_a:
			extra += 1
			diff[i * 4] = 70
			diff[i * 4 + 1] = 170
			diff[i * 4 + 2] = 255
			diff[i * 4 + 3] = 220
	var acc := 1.0 if union == 0 else float(inter) / float(union)
	return {
		"accuracy": acc,
		"missed": missed,
		"extra": extra,
		"diff": Image.create_from_data(a_w, a_h, false, Image.FORMAT_RGBA8, diff),
	}


static func score(cmp: Dictionary, tpl: Dictionary, paper: Dictionary) -> Dictionary:
	var acc: float = cmp["accuracy"]
	var stars := 1
	for th in [0.5, 0.68, 0.8, 0.9]:
		if acc >= th:
			stars += 1
	var q := clampf((acc - 0.3) / 0.65, 0.0, 1.0)
	var diff_mul := 0.7 + 0.3 * float(tpl.get("difficulty", 3))
	var value := 30.0 * float(paper.get("value", 1.0)) * diff_mul * (0.3 + 1.2 * q + 2.5 * q * q)
	var comments := ["和样稿差得有点远", "大致有个样子", "八九不离十", "几乎一模一样", "分毫不差"]
	return {
		"mode": "template",
		"accuracy": acc,
		"quality": q,
		"stars": stars,
		"comment": comments[stars - 1],
		"value": maxi(5, int(round(value))),
	}
