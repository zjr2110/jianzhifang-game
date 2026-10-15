# 剪纸坊
# tutorial.gd - 新手教学引导
extends Control

const Ui = preload("res://scripts/ui_style.gd")
const Spotlight = preload("res://shaders/spotlight.gdshader")

var screen = null
var steps: Array = []
var idx := -1
var hole := Rect2()
var _shown := Rect2()

var _dim: ColorRect
var _ring: Control
var _bubble: PanelContainer
var _arrow: Control
var _step_label: Label
var _label: Label
var _next: Button
var _skip: Button
var _advancing := false
var _arrow_up := true


class Ring extends Control:
	var tut

	func _draw() -> void:
		var h: Rect2 = tut._shown
		if h.size.x < 2.0:
			return
		var st := StyleBoxFlat.new()
		st.draw_center = false
		st.border_color = Color(1, 1, 1, 0.9)
		st.set_border_width_all(4)
		st.set_corner_radius_all(int(minf(28.0, minf(h.size.x, h.size.y) * 0.5)))
		st.anti_aliasing = true
		draw_style_box(st, h.grow(2))


class Arrow extends Control:
	var up := true

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, h), Vector2(w * 0.5, 0), Vector2(w, h)]) if up \
				else PackedVector2Array([Vector2(0, 0), Vector2(w * 0.5, h), Vector2(w, 0)])
		draw_colored_polygon(pts, Color.WHITE)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Spotlight
	_dim.material = mat
	add_child(_dim)
	_ring = Ring.new()
	_ring.tut = self
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)

	_arrow = Arrow.new()
	_arrow.size = Vector2(34, 18)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", Ui.card_box(28, Ui.CARD, true, 26))
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_bubble.add_child(v)
	_step_label = Ui.label("", Ui.T_CAP, Ui.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 700)
	v.add_child(_step_label)
	_label = Ui.label("", Ui.T_BODY, Ui.LABEL)
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_skip = Ui.plain_button("跳过教学", Ui.T_SUB, Ui.LABEL2, 400)
	_skip.custom_minimum_size = Vector2(140, 60)
	_skip.pressed.connect(skip)
	row.add_child(_skip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_next = Ui.filled_button("下一步", Ui.T_SUB)
	_next.custom_minimum_size = Vector2(150, 60)
	_next.pressed.connect(func(): _go(idx + 1))
	row.add_child(_next)
	visible = false
	resized.connect(func():
		_place_bubble()
		_update_dim())


func _has_point(point: Vector2) -> bool:
	return not hole.has_point(point)


func allows(point: Vector2) -> bool:
	if not visible:
		return true
	return hole.has_point(point)


func _process(_delta: float) -> void:
	if idx >= 0 and idx < steps.size() and visible:
		var h := _rect_for(steps[idx].get("rect", ""))
		if h != hole:
			_move_hole(h)


func _move_hole(h: Rect2) -> void:
	var from := _shown
	hole = h
	if from.size.x < 2.0 or h.size.x < 2.0:
		_shown = h
		_update_dim()
	else:
		var tw := create_tween()
		tw.tween_method(func(t: float):
			_shown = Rect2(from.position.lerp(h.position, t), from.size.lerp(h.size, t))
			_update_dim(), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_place_bubble()


func _update_dim() -> void:
	var m: ShaderMaterial = _dim.material
	m.set_shader_parameter("rect_size", size)
	m.set_shader_parameter("hole", Vector4(_shown.position.x, _shown.position.y, _shown.size.x, _shown.size.y))
	_ring.queue_redraw()


# 启动

func start(p_screen, p_steps: Array) -> void:
	screen = p_screen
	steps = p_steps
	if screen.has_signal("event_happened"):
		screen.event_happened.connect(_on_event)
	idx = -1


func refresh() -> void:
	if idx < 0:
		_go(0)


func start_cut(s) -> void:
	start(s, [
		{"text": "这是一张对角折了三次、一共八层的红纸。左上角是纸心，上边和斜边是折边，右边是纸边。在这一小块上剪，展开就是一整幅对称的团花。",
			"rect": "paper", "wait": ""},
		{"text": "双指张开可以放大纸，双指拖动可以移动（电脑上用滚轮放大、右键拖动）。先放大一点试试。",
			"rect": "paper", "wait": "zoom"},
		{"text": "点右上角这个按钮，回到原来的大小。", "rect": "view", "wait": "reset_view"},
		{"text": "剪刀：手指划过就剪开一道口子。从右边的纸边剪进去、再剪出来，剪一个三角缺口，剪下的那块会掉下去。",
			"rect": "paper", "wait": "drop", "enter": func(): s.select_tool("scissors")},
		{"text": "再在纸中间画一圈，剪回起点：中间那块掉下来，就是镂空。", "rect": "paper", "wait": "drop"},
		{"text": "剪刀只剪一道口子，不会自动连起来。口子要接上纸边或别的口子，碎片才会掉。手指画到离纸边、口子很近时，会自动接上。",
			"rect": "", "wait": ""},
		{"text": "点“纹样”，选一个喜欢的纹样。", "rect": "tool_stamp", "wait": "tool_stamp"},
		{"text": "点一下纸面，把纹样放上去。单指拖动可以挪位置。", "rect": "paper", "wait": "stamp_placed"},
		{"text": "双指转动可以旋转纹样，捏合可以缩放（电脑上：滚轮旋转，Ctrl + 滚轮缩放）。转一转试试，或者直接按“下一步”。",
			"rect": "paper", "wait": "stamp_rotated", "show_next": true},
		{"text": "位置合适了，按“雕刻”才会真正刻下去。", "rect": "ctx", "wait": "carve"},
		{"text": "再试试“刻刀”：先选刻刀，然后在纸上依次点几个点，每两点之间刻一道直线。刻两段试试。",
			"rect": "paper+tools", "wait": "knife", "cond": func(): return s.knife_segments >= 2},
		{"text": "左边两个按钮分别是“撤销”和“换张新纸”。剪错了随时可以退回。", "rect": "ctx", "wait": ""},
		{"text": "剪好了就按“展开”，看看整幅作品！", "rect": "unfold", "wait": "unfold"},
	])


func start_result(s) -> void:
	start(s, [
		{"text": "评分看镂空率、纹孔数和精细度。掉下来的碎片不扣分，放心剪。觉得还不满意，可以按“继续修剪”回去接着剪。",
			"rect": "panel", "wait": ""},
		{"text": "满意了就按“拿去拍卖”，到庙会上换铜钱。", "rect": "sell", "wait": "sell"},
	])


func start_auction(s) -> void:
	start(s, [
		{"text": "买家会轮流出价。喊“一次、两次”的时候也可能有人加价，偶尔还会杀出神秘大买家。看看能卖多少钱吧。",
			"rect": "", "wait": ""},
		{"text": "", "rect": "", "wait": "sold", "passive": true},
		{"text": "成交了！卖出的作品会进入“我的记录”，卖价最高的几件还会在首页展示。新手教学到这里结束。",
			"rect": "done", "wait": "done", "enter": func(): Game.tutorial_done = true},
	])


# 推进

func _go(i: int) -> void:
	idx = i
	if idx >= steps.size():
		_finish()
		return
	var st: Dictionary = steps[idx]
	if st.has("enter"):
		st["enter"].call()
	if st.get("passive", false):
		visible = false
		hole = Rect2()
		_shown = Rect2()
		return
	var was_visible := visible
	visible = true
	_label.text = st["text"]
	var total := 0
	var num := 0
	for k in steps.size():
		if not steps[k].get("passive", false):
			total += 1
			if k <= idx:
				num += 1
	_step_label.text = "新手教学 %d / %d" % [num, total]
	_next.visible = st.get("wait", "") == "" or st.get("show_next", false)
	_move_hole(_rect_for(st.get("rect", "")))
	if not was_visible:
		_dim.modulate.a = 0.0
		create_tween().tween_property(_dim, "modulate:a", 1.0, 0.3)
	Ui.pop(_bubble, 0.9, 0.4)
	_place_bubble.call_deferred()


func _rect_for(name: String) -> Rect2:
	if name == "" or screen == null:
		return Rect2()
	var r := Rect2()
	for part in name.split("+"):
		var pr: Rect2 = screen.rect_of(part)
		if pr.size == Vector2.ZERO:
			continue
		r = pr if r.size == Vector2.ZERO else r.merge(pr)
	return r


func _place_bubble() -> void:
	if size.x < 100.0:
		return
	var w := minf(size.x - 40.0, 640.0)
	_label.custom_minimum_size = Vector2(w - 52.0, 0)
	_label.size = Vector2(w - 52.0, 0)
	_bubble.custom_minimum_size = Vector2(w, 0)
	_bubble.size = Vector2(w, 0)
	_bubble.reset_size()
	_bubble.size.x = w
	var bh := _bubble.size.y
	var x := (size.x - w) * 0.5
	var y: float
	_arrow.visible = hole.size != Vector2.ZERO
	if hole.size == Vector2.ZERO:
		y = (size.y - bh) * 0.5
	else:
		var below := size.y - hole.end.y
		var above := hole.position.y
		if below >= bh + 40.0:
			y = hole.end.y + 26.0
			_arrow_up = true
		elif above >= bh + 40.0:
			y = hole.position.y - 26.0 - bh
			_arrow_up = false
		else:
			y = minf(hole.end.y - bh - 24.0, size.y - bh - 24.0)
			_arrow.visible = false
		var ax := clampf(hole.get_center().x - 17.0, x + 30.0, x + w - 64.0)
		(_arrow as Arrow).up = _arrow_up
		_arrow.position = Vector2(ax, y - 17.0 if _arrow_up else y + bh - 1.0)
		_arrow.queue_redraw()
	_bubble.position = Vector2(x, y)


func _on_event(name: String) -> void:
	if idx < 0 or idx >= steps.size() or _advancing:
		return
	var st: Dictionary = steps[idx]
	var waits: PackedStringArray = str(st.get("wait", "")).split(",")
	if not waits.has(name):
		return
	if st.has("cond") and not st["cond"].call():
		return
	_advancing = true
	await get_tree().create_timer(0.7).timeout
	_advancing = false
	if is_instance_valid(self) and steps.size() > 0 and idx < steps.size() and steps[idx] == st:
		_go(idx + 1)


func _finish() -> void:
	visible = false
	hole = Rect2()


func skip() -> void:
	Game.tutorial_active = false
	Game.tutorial_done = true
	Game.save_game()
	visible = false
	hole = Rect2()
	queue_free()
