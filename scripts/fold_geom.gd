# 剪纸坊
# fold_geom.gd - 折法几何与展开顺序
extends RefCounted

const IDS := ["none", "half", "four", "five", "twelve", "eight", "sixteen", "accordion"]


static func build(fold_id: String) -> Dictionary:
	match fold_id:
		"none":
			return _make(_rect(-500, -500, 1000, 1000), [Transform2D.IDENTITY], [])
		"half":
			return _binary(_rect(0, -500, 500, 1000), [[Vector2(0, 1), Vector2.ZERO]])
		"four":
			return _binary(_rect(0, 0, 500, 500), [[Vector2(0, 1), Vector2.ZERO], [Vector2(1, 0), Vector2.ZERO]])
		"five":
			return _fan_dihedral(5, 404.5, PI * 0.5)
		"twelve":
			return _binary_dihedral(6, 433.0, [30.0, 60.0, 120.0, 0.0])
		"sixteen":
			return _binary_dihedral(8, 462.0, [22.5, 45.0, 90.0, 0.0])
		"accordion":
			return _accordion(6, 160.0, 320.0)
		_:
			return _binary_dihedral(4, 500.0, [45.0, 90.0, 0.0])


# 构造

static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _sector(n: int, apothem: float) -> PackedVector2Array:
	var th := PI / n
	return PackedVector2Array([Vector2.ZERO, Vector2(apothem, 0.0), Vector2(apothem, apothem * tan(th))])


static func _binary_dihedral(n: int, apothem: float, line_degs: Array) -> Dictionary:
	var lines := []
	for d in line_degs:
		var phi := deg_to_rad(float(d))
		lines.append([Vector2(cos(phi), sin(phi)), Vector2.ZERO])
	return _binary(_sector(n, apothem), lines)


# 二分展开，每步层数翻倍
static func _binary(wedge: PackedVector2Array, lines: Array) -> Dictionary:
	var cells: Array[Transform2D] = [Transform2D.IDENTITY]
	var stages := []
	for l in lines:
		var s := reflection(l[0], l[1])
		var base: Array[Transform2D] = cells.duplicate()
		var flips: Array[Transform2D] = []
		for g in base:
			var h := s * g
			if not _contains(cells, h):
				flips.append(g)
				cells.append(h)
		stages.append({"u": l[0], "p": l[1], "base": base, "flips": flips})
	return _make(wedge, cells, stages)


# 扇形逐片展开
static func _fan_dihedral(n: int, apothem: float, rot := 0.0) -> Dictionary:
	var lines := []
	var th := PI / n
	for k in range(1, 2 * n):
		lines.append([Vector2(cos(k * th + rot), sin(k * th + rot)), Vector2.ZERO])
	var w := _sector(n, apothem)
	for i in w.size():
		w[i] = w[i].rotated(rot)
	return _fan(w, lines)


# 连续拉花
static func _accordion(k: int, seg_w: float, h: float) -> Dictionary:
	var x0 := -seg_w * k * 0.5
	var lines := []
	for i in range(1, k):
		lines.append([Vector2(0, 1), Vector2(x0 + seg_w * i, 0)])
	return _fan(_rect(x0, -h * 0.5, seg_w, h), lines)


static func _fan(wedge: PackedVector2Array, lines: Array) -> Dictionary:
	var cells: Array[Transform2D] = [Transform2D.IDENTITY]
	var stages := []
	for l in lines:
		var s := reflection(l[0], l[1])
		var last: Transform2D = cells[cells.size() - 1]
		var base: Array[Transform2D] = cells.duplicate()
		stages.append({"u": l[0], "p": l[1], "base": base, "flips": [last] as Array[Transform2D]})
		cells.append(s * last)
	return _make(wedge, cells, stages)


static func _make(wedge: PackedVector2Array, cells: Array[Transform2D], stages: Array) -> Dictionary:
	var bounds := Rect2(wedge[0], Vector2.ZERO)
	for g in cells:
		for p in g * wedge:
			bounds = bounds.expand(p)
	var wb := Rect2(wedge[0], Vector2.ZERO)
	for p in wedge:
		wb = wb.expand(p)
	# 共边的相邻片，用于补镜像边带
	var neighbors: Array[Transform2D] = []
	for g in cells:
		if g.is_equal_approx(Transform2D.IDENTITY):
			continue
		var shared := 0
		for p in g * wedge:
			for q in wedge:
				if p.distance_to(q) < 0.5:
					shared += 1
					break
		if shared >= 2:
			neighbors.append(g)
	return {
		"wedge": wedge,
		"cells": cells,
		"stages": stages,
		"bounds": bounds,
		"wedge_bounds": wb,
		"neighbors": neighbors,
	}


# 变换

# 关于直线的镜像
static func reflection(u: Vector2, p := Vector2.ZERO) -> Transform2D:
	var r := Transform2D(
		Vector2(2.0 * u.x * u.x - 1.0, 2.0 * u.x * u.y),
		Vector2(2.0 * u.x * u.y, 2.0 * u.y * u.y - 1.0),
		Vector2.ZERO)
	r.origin = p - r.basis_xform(p)
	return r


# 翻折过程变换
static func partial_fold(u: Vector2, p: Vector2, t: float) -> Transform2D:
	var a := u.x * u.x
	var b := u.x * u.y
	var c := u.y * u.y
	var m := Transform2D(
		Vector2(a + t * (1.0 - a), b - t * b),
		Vector2(b - t * b, c + t * (1.0 - c)),
		Vector2.ZERO)
	m.origin = p - m.basis_xform(p)
	return m


static func _contains(list: Array[Transform2D], m: Transform2D) -> bool:
	for g in list:
		if (g.x - m.x).length() < 1e-4 and (g.y - m.y).length() < 1e-4 and (g.origin - m.origin).length() < 1e-3:
			return true
	return false
