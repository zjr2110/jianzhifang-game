# 剪纸坊
# stamps.gd - 纹样印章形状
extends RefCounted
# 形状定义


static func shapes(id: String) -> Array:
	match id:
		"moon":
			return [_crescent(Vector2.ZERO, 1.0)]
		"saw":
			return _saw()
		"drop":
			return [_drop()]
		"hole":
			return [_circle(Vector2.ZERO, 0.8)]
		"leaf":
			return [_leaf()]
		"plum":
			return _plum()
		"scale":
			return _scale()
		"cloud":
			return _cloud()
		"coin":
			return _coin()
		"fret":
			return _fret()
	return []


# 按位置角度大小摆放
static func placed(id: String, center: Vector2, angle: float, size: float) -> Array:
	var xf := Transform2D(angle, Vector2.ZERO).scaled(Vector2(size * 0.5, size * 0.5))
	xf.origin = center
	var out := []
	for poly in shapes(id):
		out.append(xf * poly)
	return out


static func _circle(c: Vector2, r: float, steps := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * i / steps
		pts.append(c + Vector2(cos(t), sin(t)) * r)
	return pts


static func _crescent(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var phi := -PI / 2.0 + PI * i / steps
		pts.append(c + Vector2(-cos(phi) + 0.5, sin(phi)) * s)
	for i in range(steps - 1, 0, -1):
		var phi := -PI / 2.0 + PI * i / steps
		pts.append(c + Vector2(-0.38 * cos(phi) + 0.5, sin(phi) * 0.96) * s)
	return pts


static func _saw() -> Array:
	var out := []
	for i in 5:
		var x0 := -1.0 + i * 0.4
		out.append(PackedVector2Array([
			Vector2(x0 + 0.04, 0.45), Vector2(x0 + 0.36, 0.45), Vector2(x0 + 0.2, -0.75)]))
	return out


static func _drop() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 36
	for i in steps:
		var t := TAU * i / steps
		pts.append(Vector2(cos(t) * 1.0 + 0.1, sin(t) * pow(sin(t * 0.5), 1.5) * 0.8))
	return pts


static func _leaf() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 20
	for i in steps + 1:
		var t := PI * i / steps
		pts.append(Vector2(-cos(t), -sin(t) * 0.3))
	for i in range(steps - 1, 0, -1):
		var t := PI * i / steps
		pts.append(Vector2(-cos(t), sin(t) * 0.3))
	return pts


static func _plum() -> Array:
	var out := []
	for k in 5:
		var a := -PI / 2.0 + TAU * k / 5.0
		out.append(_circle(Vector2(cos(a), sin(a)) * 0.55, 0.42))
	out.append(_circle(Vector2.ZERO, 0.35))
	return out


static func _scale() -> Array:
	var out := []
	for p in [Vector2(-0.6, -0.4), Vector2(0.0, -0.4), Vector2(0.6, -0.4), Vector2(-0.3, 0.3), Vector2(0.3, 0.3)]:
		var pts := PackedVector2Array()
		var steps := 14
		for i in steps + 1:
			var t := PI * i / steps
			pts.append(p + Vector2(-cos(t) * 0.3, sin(t) * 0.36))
		for i in range(steps - 1, 0, -1):
			var t := PI * i / steps
			pts.append(p + Vector2(-cos(t) * 0.22, sin(t) * 0.2))
		out.append(pts)
	return out


static func _cloud() -> Array:
	return [
		_circle(Vector2(0.0, -0.25), 0.45),
		_circle(Vector2(-0.5, 0.05), 0.36),
		_circle(Vector2(0.5, 0.05), 0.36),
		PackedVector2Array([Vector2(-0.12, 0.2), Vector2(0.12, 0.2), Vector2(0.06, 0.95), Vector2(-0.06, 0.95)]),
	]


static func _coin() -> Array:
	var out := []
	for k in 4:
		var a0 := deg_to_rad(90.0 * k + 14.0)
		var a1 := deg_to_rad(90.0 * (k + 1) - 14.0)
		var pts := PackedVector2Array()
		var steps := 12
		for i in steps + 1:
			var t := lerpf(a0, a1, float(i) / steps)
			pts.append(Vector2(cos(t), sin(t)) * 0.95)
		var mid := deg_to_rad(90.0 * k + 45.0)
		pts.append(Vector2(cos(mid), sin(mid)) * 0.42)
		out.append(pts)
	return out


static func _fret() -> Array:
	var rects := [
		[-0.9, -0.9, 0.9, -0.72], [0.72, -0.9, 0.9, 0.9], [-0.6, 0.72, 0.9, 0.9],
		[-0.6, -0.3, -0.42, 0.9], [-0.6, -0.3, 0.3, -0.12], [0.12, -0.3, 0.3, 0.45],
	]
	var out := []
	for r in rects:
		out.append(PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[2], r[1]), Vector2(r[2], r[3]), Vector2(r[0], r[3])]))
	return out
