# 剪纸坊
# paper_view.gd - 纸张显示与展开动画
extends Node2D

const PaperShader = preload("res://shaders/paper.gdshader")
const FoldGeom = preload("res://scripts/fold_geom.gd")

var model = null
var paper_id := "red"

var mode := "wedge":
	set(v):
		mode = v
		refresh()
var anim_stage := 0:
	set(v):
		anim_stage = v
		refresh()
var anim_t := 1.0:
	set(v):
		anim_t = v
		refresh()
var view_scale := 1.0:
	set(v):
		view_scale = v
		refresh()
var view_origin := Vector2.ZERO:
	set(v):
		view_origin = v
		refresh()
var show_stack := true
var lift := 0.0

var _shadow_root: Node2D
var _paper_root: Node2D
var _overlay: Layer
var _paper_mat: ShaderMaterial
var _shadow_mat: ShaderMaterial
var _shadow_nodes: Array = []
var _paper_nodes: Array = []


class Layer extends Node2D:
	var view
	var kind := "paper"
	var tex: Texture2D = null

	func _draw() -> void:
		view._draw_layer(self)


# 单片纸节点
class ItemNode extends Node2D:
	var sp := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var tex: Texture2D

	func _draw() -> void:
		if tex and sp.size() >= 3:
			draw_primitive(sp, cols, uvs, tex)


func setup(p_model, p_paper_id: String) -> void:
	model = p_model
	paper_id = p_paper_id
	_paper_mat = make_material(paper_id, false)
	_shadow_mat = make_material(paper_id, true)
	_shadow_root = Node2D.new()
	add_child(_shadow_root)
	_paper_root = Node2D.new()
	add_child(_paper_root)
	_overlay = _add_layer("overlay", null)
	_overlay.visible = false
	refresh()


func _add_layer(kind: String, mat: Material) -> Layer:
	var l := Layer.new()
	l.view = self
	l.kind = kind
	l.material = mat
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(l)
	return l


static func make_material(p_paper: String, shadow: bool) -> ShaderMaterial:
	var info: Dictionary = Game.PAPERS.get(p_paper, Game.PAPERS["red"])
	var mat := ShaderMaterial.new()
	mat.shader = PaperShader
	mat.set_shader_parameter("paper_color", info["color"])
	mat.set_shader_parameter("gold_amount", info.get("gold", 0.0))
	mat.set_shader_parameter("gloss", info.get("gloss", 0.0))
	mat.set_shader_parameter("metal", info.get("metal", 0.0))
	mat.set_shader_parameter("fiber_amount", info.get("fiber", 1.0))
	mat.set_shader_parameter("cloud_amount", info.get("cloud", 1.0))
	mat.set_shader_parameter("shadow_mode", 1.0 if shadow else 0.0)
	return mat


func set_overlay(tex: Texture2D) -> void:
	_overlay.tex = tex
	_overlay.visible = tex != null
	_overlay.queue_redraw()


func set_view(s: float, o: Vector2) -> void:
	view_scale = s
	view_origin = o


func refresh() -> void:
	if model == null or _paper_root == null:
		return
	var its := items()
	var tex_px := Vector2(model.tex_w, model.tex_h)
	var shadow_base := Vector2(5.0, 8.0) * clampf(view_scale * 1.4, 0.6, 1.6)
	var ns := 0
	var np := 0
	for it in its:
		var geo := _geometry(it)
		var sheet: Transform2D = it.get("sheet", Transform2D.IDENTITY)
		var lf: float = it["lift"]
		var off: Vector2 = it.get("offset", Vector2.ZERO)
		if not it.get("no_shadow", false):
			var sn := _node(_shadow_nodes, _shadow_root, _shadow_mat, ns)
			ns += 1
			_fill_node(sn, geo, off + shadow_base * (1.0 + lf * 3.0), Color(1, 1, 1, 1.0 - lf * 0.4))
			(sn.material as ShaderMaterial).set_shader_parameter("tex_px", tex_px)
		var pn := _node(_paper_nodes, _paper_root, _paper_mat, np)
		np += 1
		_fill_node(pn, geo, off, it["tint"])
		_set_sheet(pn.material, sheet, tex_px)
	for i in range(ns, _shadow_nodes.size()):
		_shadow_nodes[i].visible = false
	for i in range(np, _paper_nodes.size()):
		_paper_nodes[i].visible = false
	_overlay.queue_redraw()


func _node(pool: Array, root: Node2D, base: ShaderMaterial, i: int) -> ItemNode:
	if i >= pool.size():
		var n := ItemNode.new()
		n.material = base.duplicate()
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(n)
		pool.append(n)
	var node: ItemNode = pool[i]
	node.visible = true
	return node


func _fill_node(n: ItemNode, geo: Array, off: Vector2, col: Color) -> void:
	var sp: PackedVector2Array = geo[0].duplicate()
	for i in sp.size():
		sp[i] += off
	n.sp = sp
	n.uvs = geo[1]
	var cols := PackedColorArray()
	for i in sp.size():
		cols.append(col)
	n.cols = cols
	n.tex = model.texture
	n.queue_redraw()


func _set_sheet(mat: ShaderMaterial, sheet: Transform2D, tex_px: Vector2) -> void:
	var tr: Rect2 = model.tex_rect
	mat.set_shader_parameter("tex_px", tex_px)
	mat.set_shader_parameter("use_sheet", true)
	mat.set_shader_parameter("sheet_o", sheet * tr.position)
	mat.set_shader_parameter("sheet_x", sheet.basis_xform(Vector2(tr.size.x, 0.0)))
	mat.set_shader_parameter("sheet_y", sheet.basis_xform(Vector2(0.0, tr.size.y)))


# 单片顶点与纹理坐标
func _geometry(it: Dictionary) -> Array:
	var src: PackedVector2Array = it["src"]
	var pts: PackedVector2Array = it["pts"]
	var grow := 0.8 / view_scale
	var cs := Vector2.ZERO
	var cp := Vector2.ZERO
	for i in pts.size():
		cs += src[i]
		cp += pts[i]
	cs /= pts.size()
	cp /= pts.size()
	var sp := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in pts.size():
		sp.append(paper_to_screen(pts[i] + (pts[i] - cp).normalized() * grow))
		uvs.append(model.uv_of(src[i] + (src[i] - cs).normalized() * grow))
	return [sp, uvs]


static func fit(rect: Rect2, bounds: Rect2, margin := 0.0) -> Array:
	var r := rect.grow(-margin)
	var s := minf(r.size.x / bounds.size.x, r.size.y / bounds.size.y)
	return [s, r.get_center() - bounds.get_center() * s]


func paper_to_screen(p: Vector2) -> Vector2:
	return view_origin + p * view_scale


func screen_to_paper(s: Vector2) -> Vector2:
	return (s - view_origin) / view_scale


func items(include_stack := true) -> Array:
	var out := []
	if model == null:
		return out
	var w: PackedVector2Array = model.wedge
	match mode:
		"full":
			for g in model.cells:
				out.append({"src": w, "pts": g * w, "tint": Color.WHITE, "lift": lift, "sheet": g})
		"wedge":
			var under := mini(3, model.cells.size() - 1)
			if show_stack and include_stack:
				for k in range(under, 0, -1):
					var d := 0.70 + 0.06 * (3 - k)
					out.append({"src": w, "pts": w, "tint": Color(d, d, d), "lift": 0.0,
						"offset": Vector2(k * 1.6, k * 2.2), "no_shadow": true,
						"sheet": model.cells[k % model.cells.size()]})
			out.append({"src": w, "pts": w, "tint": Color.WHITE, "lift": 0.0, "sheet": Transform2D.IDENTITY})
		"anim":
			if model.stages.is_empty():
				return items_for("full")
			var st: Dictionary = model.stages[clampi(anim_stage, 0, model.stages.size() - 1)]
			for g in st["base"]:
				out.append({"src": w, "pts": g * w, "tint": Color.WHITE, "lift": lift, "sheet": g})
			var m := FoldGeom.partial_fold(st["u"], st["p"], anim_t)
			var refl := FoldGeom.reflection(st["u"], st["p"])
			var t := anim_t
			var shade := 0.6 + 0.4 * absf(t)
			var tint := Color(shade * 1.08, shade, shade * 0.98) if t > 0.0 else Color(shade, shade, shade)
			for g in st["flips"]:
				out.append({"src": w, "pts": m * (g * w), "tint": tint, "lift": 1.0 - absf(t), "sheet": refl * g})
	return out


func items_for(m: String) -> Array:
	var old := mode
	mode = m
	var r := items()
	mode = old
	return r


func _draw_layer(layer: Layer) -> void:
	if model == null or layer.tex == null:
		return
	for it in items(false):
		var geo := _geometry(it)
		var cols := PackedColorArray()
		for i in geo[0].size():
			cols.append(Color.WHITE)
		layer.draw_primitive(geo[0], cols, geo[1], layer.tex)


# 碎片掉落
func spawn_fall(piece: Image) -> void:
	var fp := FallingPiece.new()
	fp.view = self
	fp.tex = ImageTexture.create_from_image(piece)
	fp.material = _paper_mat.duplicate()
	fp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shadow := FallingPiece.new()
	shadow.view = self
	shadow.tex = fp.tex
	shadow.material = _shadow_mat.duplicate()
	var c := Vector2.ZERO
	for p in model.wedge:
		c += p
	c = paper_to_screen(c / model.wedge.size())
	for n in [shadow, fp]:
		n.pivot = c
		n.position = c
		n.snapshot()
		add_child(n)
		var dir := 1.0 if randf() < 0.5 else -1.0
		var tw: Tween = n.create_tween().set_parallel()
		tw.tween_property(n, "position", c + Vector2(randf_range(-80, 80), 900), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "rotation", dir * randf_range(0.4, 1.0), 1.2)
		tw.tween_property(n, "scale", Vector2(0.92, 0.92), 0.3)
		tw.tween_property(n, "modulate:a", 0.0, 0.5).set_delay(0.7)
		tw.chain().tween_callback(n.queue_free)
	shadow.position += Vector2(6, 10)


class FallingPiece extends Node2D:
	var view
	var tex: Texture2D
	var pivot := Vector2.ZERO
	var _items := []

	func snapshot() -> void:
		var it = view.items(false)
		_items = []
		for x in it:
			var sp := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in x["pts"].size():
				sp.append(view.paper_to_screen(x["pts"][i]) - pivot)
				uvs.append(view.model.uv_of(x["src"][i]))
			_items.append([sp, uvs])
		view._set_sheet(material, Transform2D.IDENTITY, Vector2(view.model.tex_w, view.model.tex_h))

	func _draw() -> void:
		for x in _items:
			var cols := PackedColorArray()
			for i in x[0].size():
				cols.append(Color.WHITE)
			draw_primitive(x[0], cols, x[1], tex)
