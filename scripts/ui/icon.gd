# 剪纸坊
# icon.gd - 矢量图标
extends Control

var icon := ""
var color := Color("1c1c1e")
var stroke := 0.085


func _init(p_icon := "", p_color := Color("1c1c1e"), d := 40.0) -> void:
	icon = p_icon
	color = p_color
	custom_minimum_size = Vector2(d, d)
	size = Vector2(d, d)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_icon(p_icon: String, p_color = null) -> void:
	icon = p_icon
	if p_color != null:
		color = p_color
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var w := maxf(1.5, s * stroke)
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match icon:
		"back":
			_line([P.call(0.62, 0.18), P.call(0.3, 0.5), P.call(0.62, 0.82)], w)
		"chevron":
			_line([P.call(0.38, 0.2), P.call(0.68, 0.5), P.call(0.38, 0.8)], w)
		"close":
			_line([P.call(0.25, 0.25), P.call(0.75, 0.75)], w)
			_line([P.call(0.75, 0.25), P.call(0.25, 0.75)], w)
		"check":
			_line([P.call(0.2, 0.52), P.call(0.42, 0.74), P.call(0.8, 0.28)], w)
		"eye":
			var pts := []
			for i in 25:
				var t := PI * i / 24.0
				pts.append(P.call(0.5 - 0.42 * cos(t), 0.5 - 0.26 * sin(t)))
			for i in range(1, 24):
				var t := PI * i / 24.0
				pts.append(P.call(0.5 + 0.42 * cos(t), 0.5 + 0.26 * sin(t)))
			pts.append(pts[0])
			_line(pts, w)
			draw_arc(P.call(0.5, 0.5), s * 0.13, 0, TAU, 24, color, w, true)
		"fit":
			for c in [[0.18, 0.18, 1, 1], [0.82, 0.18, -1, 1], [0.18, 0.82, 1, -1], [0.82, 0.82, -1, -1]]:
				_line([P.call(c[0], c[1] + 0.2 * c[3]), P.call(c[0], c[1]), P.call(c[0] + 0.2 * c[2], c[1])], w)
		"scissors":
			draw_arc(P.call(0.28, 0.74), s * 0.13, 0, TAU, 24, color, w, true)
			draw_arc(P.call(0.72, 0.74), s * 0.13, 0, TAU, 24, color, w, true)
			_line([P.call(0.36, 0.64), P.call(0.68, 0.14)], w)
			_line([P.call(0.64, 0.64), P.call(0.32, 0.14)], w)
		"knife":
			_line([P.call(0.18, 0.82), P.call(0.62, 0.38)], w * 1.5)
			_line([P.call(0.62, 0.38), P.call(0.84, 0.16), P.call(0.74, 0.46), P.call(0.62, 0.38)], w)
		"flower":
			for k in 5:
				var a := -PI / 2.0 + TAU * k / 5.0
				draw_arc(P.call(0.5 + 0.22 * cos(a), 0.5 + 0.22 * sin(a)), s * 0.15, 0, TAU, 20, color, w, true)
			draw_circle(P.call(0.5, 0.5), s * 0.07, color)
		"undo":
			draw_arc(P.call(0.52, 0.56), s * 0.28, deg_to_rad(-170), deg_to_rad(110), 28, color, w, true)
			_line([P.call(0.18, 0.28), P.call(0.24, 0.53), P.call(0.47, 0.44)], w)
		"paper":
			_line([P.call(0.24, 0.12), P.call(0.6, 0.12), P.call(0.78, 0.3), P.call(0.78, 0.88), P.call(0.24, 0.88), P.call(0.24, 0.12)], w)
			_line([P.call(0.6, 0.12), P.call(0.6, 0.3), P.call(0.78, 0.3)], w)
		"line_end":
			_line([P.call(0.16, 0.72), P.call(0.66, 0.32)], w)
			draw_circle(P.call(0.16, 0.72), s * 0.08, color)
			draw_circle(P.call(0.74, 0.26), s * 0.11, color)
		"chart":
			for c in [[0.2, 0.55], [0.42, 0.3], [0.64, 0.42], [0.84, 0.18]]:
				_line([P.call(c[0], 0.84), P.call(c[0], c[1])], w * 1.6)
		"book":
			_line([P.call(0.5, 0.26), P.call(0.5, 0.84)], w)
			_line([P.call(0.5, 0.26), P.call(0.32, 0.18), P.call(0.12, 0.2), P.call(0.12, 0.78), P.call(0.32, 0.76), P.call(0.5, 0.84)], w)
			_line([P.call(0.5, 0.26), P.call(0.68, 0.18), P.call(0.88, 0.2), P.call(0.88, 0.78), P.call(0.68, 0.76), P.call(0.5, 0.84)], w)
		"gear":
			draw_arc(P.call(0.5, 0.5), s * 0.24, 0, TAU, 32, color, w, true)
			draw_arc(P.call(0.5, 0.5), s * 0.08, 0, TAU, 16, color, w, true)
			for k in 8:
				var a := TAU * k / 8.0
				_line([P.call(0.5 + 0.3 * cos(a), 0.5 + 0.3 * sin(a)), P.call(0.5 + 0.4 * cos(a), 0.5 + 0.4 * sin(a))], w * 1.3)
		"trophy":
			_line([P.call(0.3, 0.16), P.call(0.7, 0.16), P.call(0.68, 0.42), P.call(0.5, 0.56), P.call(0.32, 0.42), P.call(0.3, 0.16)], w)
			_line([P.call(0.5, 0.56), P.call(0.5, 0.74)], w)
			_line([P.call(0.32, 0.84), P.call(0.68, 0.84)], w)
			draw_arc(P.call(0.24, 0.3), s * 0.09, PI * 0.5, PI * 1.5, 12, color, w, true)
			draw_arc(P.call(0.76, 0.3), s * 0.09, -PI * 0.5, PI * 0.5, 12, color, w, true)
		"gavel":
			_line([P.call(0.18, 0.84), P.call(0.56, 0.46)], w * 1.3)
			_line([P.call(0.4, 0.3), P.call(0.7, 0.6)], w * 2.6)
			_line([P.call(0.54, 0.16), P.call(0.84, 0.46)], w * 1.2)
		"arrow_right":
			_line([P.call(0.18, 0.5), P.call(0.8, 0.5)], w)
			_line([P.call(0.56, 0.26), P.call(0.8, 0.5), P.call(0.56, 0.74)], w)
		"sparkle":
			var pts2 := []
			for k in 9:
				var a := -PI / 2.0 + TAU * k / 8.0
				var r := 0.4 if k % 2 == 0 else 0.12
				pts2.append(P.call(0.5 + r * cos(a), 0.5 + r * sin(a)))
			draw_colored_polygon(PackedVector2Array(pts2.slice(0, 8)), color)
		"unfold":
			_line([P.call(0.14, 0.86), P.call(0.14, 0.14), P.call(0.86, 0.14)], w)
			_line([P.call(0.14, 0.86), P.call(0.86, 0.14)], w * 0.8)
			_line([P.call(0.5, 0.86), P.call(0.86, 0.86), P.call(0.86, 0.5)], w)
		"coin":
			draw_circle(P.call(0.5, 0.5), s * 0.46, Color("a8792a"))
			draw_circle(P.call(0.5, 0.5), s * 0.4, Color("e2b453"))
			draw_rect(Rect2(P.call(0.38, 0.38), Vector2(s, s) * 0.24), Color("8a5d1c"))
		"dot":
			draw_circle(P.call(0.5, 0.5), s * 0.5, color)
		"more":
			for k in 3:
				draw_circle(P.call(0.22 + 0.28 * k, 0.5), s * 0.075, color)
		"pencil":
			_line([P.call(0.2, 0.8), P.call(0.72, 0.28)], w * 1.6)
			_line([P.call(0.66, 0.22), P.call(0.78, 0.34)], w * 1.6)
			_line([P.call(0.14, 0.86), P.call(0.24, 0.84)], w)
		"trash":
			_line([P.call(0.18, 0.28), P.call(0.82, 0.28)], w)
			_line([P.call(0.4, 0.28), P.call(0.42, 0.16), P.call(0.58, 0.16), P.call(0.6, 0.28)], w)
			_line([P.call(0.26, 0.3), P.call(0.3, 0.86), P.call(0.7, 0.86), P.call(0.74, 0.3)], w)
		"print":
			_line([P.call(0.28, 0.36), P.call(0.28, 0.14), P.call(0.72, 0.14), P.call(0.72, 0.36)], w)
			_line([P.call(0.28, 0.66), P.call(0.12, 0.66), P.call(0.12, 0.36), P.call(0.88, 0.36), P.call(0.88, 0.66), P.call(0.72, 0.66)], w)
			_line([P.call(0.28, 0.56), P.call(0.28, 0.88), P.call(0.72, 0.88), P.call(0.72, 0.56), P.call(0.28, 0.56)], w)
		"speaker":
			draw_colored_polygon(PackedVector2Array([P.call(0.12, 0.38), P.call(0.3, 0.38), P.call(0.52, 0.18),
					P.call(0.52, 0.82), P.call(0.3, 0.62), P.call(0.12, 0.62)]), color)
			draw_arc(P.call(0.5, 0.5), s * 0.2, -0.9, 0.9, 16, color, w, true)
			draw_arc(P.call(0.5, 0.5), s * 0.34, -0.9, 0.9, 20, color, w, true)
		"film":
			_line([P.call(0.14, 0.2), P.call(0.86, 0.2), P.call(0.86, 0.8), P.call(0.14, 0.8), P.call(0.14, 0.2)], w)
			draw_colored_polygon(PackedVector2Array([P.call(0.42, 0.36), P.call(0.64, 0.5), P.call(0.42, 0.64)]), color)
		"image":
			_line([P.call(0.12, 0.2), P.call(0.88, 0.2), P.call(0.88, 0.8), P.call(0.12, 0.8), P.call(0.12, 0.2)], w)
			_line([P.call(0.16, 0.74), P.call(0.4, 0.48), P.call(0.56, 0.62), P.call(0.68, 0.52), P.call(0.86, 0.72)], w)
			draw_circle(P.call(0.66, 0.36), s * 0.07, color)


func _line(pts: Array, w: float) -> void:
	draw_polyline(PackedVector2Array(pts), color, w, true)
	for p in [pts[0], pts[pts.size() - 1]]:
		draw_circle(p, w * 0.5, color)
