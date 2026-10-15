# 剪纸坊
# cut_screen.gd - 剪纸台
extends Control

signal event_happened(name: String)

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const Works = preload("res://scripts/ui/works.gd")
const PaperStage = preload("res://scripts/ui/paper_stage.gd")
const PaperModel = preload("res://scripts/paper_model.gd")
const PaperView = preload("res://scripts/paper_view.gd")
const Stamps = preload("res://scripts/stamps.gd")
const Analyzer = preload("res://scripts/analyzer.gd")
const Templates = preload("res://scripts/templates.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
const Sfx = preload("res://scripts/sfx.gd")

const MAX_ZOOM := 10.0
const SNAP_PX := 18.0
const STAMP_DEFAULT_PX := 90.0
const CHOOSE_COLORS := [Color(1.0, 0.78, 0.2, 0.75), Color(0.3, 0.7, 1.0, 0.75), Color(0.45, 0.9, 0.45, 0.75), Color(1.0, 0.45, 0.85, 0.75)]
const TOOL_ORDER := ["scissors", "knife", "stamp"]

var main = null
var backdrop := "desk"

var model
var view
var target := {}
var tool := "scissors"
var stamp_id := "moon"
var pending = null
var chain := PackedVector2Array()
var busy := true
var choosing := false
var knife_segments := 0

var paper_rect := Rect2()
var fit_s := 1.0
var fit_o := Vector2.ZERO

var _touches := {}
var _gesture := ""
var _stroke := PackedVector2Array()
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _moved := false
var _knife_preview = null
var _pinch := {}
var _desk_pan = null
var _stamp_rot_acc := 0.0

var _task := -1
var _holder := {}
var _dirty := false
var _task_epoch := 0
var _choose_comp := {}
var _choose_labels := []

var _overlay: Control
var _title_pill: PanelContainer
var _title: Label
var _hint_pill: PanelContainer
var _hint: Label
var _hint_serial := 0
var _btn_back: Button
var _btn_view: Button
var _btn_sample: Button
var _toolbar: PanelContainer
var _seg
var _ctx: HBoxContainer
var _btn_unfold: Button = null
var _btn_carve: Button = null
var _popup: Control = null
var tutorial = null


class Overlay extends Control:
	var screen

	func _draw() -> void:
		screen._draw_overlay(self)


func _ready() -> void:
	if Game.resume_cut and Game.current_model != null and Game.current_model.fold_id == Game.cut_fold:
		model = Game.current_model
		target = Game.current_target
	else:
		model = PaperModel.new(Game.cut_fold, PaperModel.edit_res())
		if Game.mode == "template" and not Game.current_template.is_empty():
			target = Templates.build_target(model, Game.current_template["image"])
	Game.resume_cut = false
	Game.current_model = model
	Game.current_target = target

	view = PaperView.new()
	add_child(view)
	view.setup(model, Game.cut_paper)

	_overlay = Overlay.new()
	_overlay.screen = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# 顶部按钮
	_btn_back = Ui.icon_button("back", 72)
	_btn_back.pressed.connect(_on_back)
	add_child(_btn_back)
	var title_text: String
	if Game.mode == "template":
		title_text = Game.current_template.get("name", "照样剪纸")
	else:
		title_text = "%s · %s" % [Game.PAPERS[Game.cut_paper]["name"], Game.FOLDS[Game.cut_fold]["name"]]
	_title_pill = PanelContainer.new()
	_title_pill.add_theme_stylebox_override("panel", Ui.pill_box(Color(1, 1, 1, 0.86), 26, 14, true))
	_title_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Ui.label(title_text, Ui.T_SUB, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER, 600)
	_title_pill.add_child(_title)
	add_child(_title_pill)
	_btn_view = Ui.icon_button("fit", 72)
	_btn_view.pressed.connect(_on_reset_view)
	add_child(_btn_view)
	if Game.mode == "template":
		_btn_sample = Ui.icon_button("eye", 72)
		_btn_sample.pressed.connect(_show_sample)
		add_child(_btn_sample)

	# 提示
	_hint_pill = PanelContainer.new()
	var hst := Ui.pill_box(Color(1, 1, 1, 0.92), 26, 12, true)
	hst.set_corner_radius_all(30)
	_hint_pill.add_theme_stylebox_override("panel", hst)
	_hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Ui.label("", Ui.T_FOOT, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER, 500)
	_hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_hint_pill.add_child(_hint)
	_hint_pill.modulate.a = 0.0
	add_child(_hint_pill)

	# 工具栏
	_toolbar = PanelContainer.new()
	var tst := Ui.card_box(40, Color(1, 1, 1, 0.94), true, 14)
	tst.shadow_size = 26
	_toolbar.add_theme_stylebox_override("panel", tst)
	add_child(_toolbar)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 12)
	_toolbar.add_child(tv)
	_seg = Widgets.Segmented.new([["scissors", "剪刀"], ["knife", "刻刀"], ["flower", "纹样"]])
	_seg.tapped.connect(_on_seg)
	tv.add_child(_seg)
	_ctx = HBoxContainer.new()
	_ctx.add_theme_constant_override("separation", 10)
	_ctx.custom_minimum_size = Vector2(0, 76)
	tv.add_child(_ctx)

	if Game.tutorial_active:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.start_cut(self)

	resized.connect(_layout)
	_update_tool_labels()
	select_tool("scissors")
	await get_tree().process_frame
	_layout()
	_seg.select(0, false)
	_play_fold_in()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# 布局

func _layout() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0:
		return
	var top: float = main.safe_top + 14.0
	_btn_back.position = Vector2(20, top)
	_btn_view.position = Vector2(w - 92, top)
	var right := w - 104.0
	if _btn_sample:
		_btn_sample.position = Vector2(w - 176, top)
		right = w - 188.0
	_title_pill.reset_size()
	var tw := minf(_title_pill.get_combined_minimum_size().x, right - 112.0)
	_title_pill.size = Vector2(tw, 72)
	_title_pill.position = Vector2((w - tw) * 0.5, top)
	if _title_pill.position.x < 108.0 or _title_pill.position.x + tw > right:
		_title_pill.position.x = 108.0 + (right - 108.0 - tw) * 0.5

	var tb_h := 14.0 + 76.0 + 12.0 + 76.0 + 14.0
	_toolbar.size = Vector2(w - 32, tb_h)
	_toolbar.position = Vector2(16, h - main.safe_bottom - 16.0 - tb_h)
	_place_hint()

	var pt := top + 90.0
	paper_rect = Rect2(Vector2(12, pt), Vector2(w - 24, _toolbar.position.y - pt - 12.0))
	var f := PaperView.fit(paper_rect, model.wedge_bounds, 26.0)
	fit_s = f[0]
	fit_o = f[1]
	if not busy:
		_set_view(view.view_scale, view.view_origin)
	_overlay.queue_redraw()


func _place_hint() -> void:
	var w := size.x
	var font: Font = _hint.get_theme_font("font")
	var fs: int = _hint.get_theme_font_size("font_size")
	var tw: float = font.get_string_size(_hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 4.0
	var pad := 52.0
	var mw := minf(tw + pad, w - 64.0)
	_hint.custom_minimum_size.x = mw - pad
	_hint.size = Vector2(mw - pad, 0)
	_hint_pill.size = Vector2.ZERO
	_hint_pill.reset_size()
	_hint_pill.size.x = mw
	_hint_pill.position = Vector2((w - mw) * 0.5, main.safe_top + 100.0)
	_settle_hint.call_deferred(mw)


func _settle_hint(mw: float) -> void:
	if is_instance_valid(_hint_pill):
		_hint_pill.size = Vector2(mw, 0)


func hero_target() -> Rect2:
	var full := PaperView.fit(paper_rect, model.bounds, 30.0)
	var b: Rect2 = model.bounds
	return Rect2(full[1] + b.position * full[0], b.size * full[0])


func _local_rect(c: Control) -> Rect2:
	return Rect2(c.global_position - global_position, c.size)


func rect_of(name: String) -> Rect2:
	match name:
		"paper":
			return paper_rect
		"tools":
			return _local_rect(_seg).grow(8)
		"tool_scissors", "tool_knife", "tool_stamp":
			var r := _local_rect(_seg)
			var i := TOOL_ORDER.find(name.substr(5))
			var sw := r.size.x / 3.0
			return Rect2(r.position + Vector2(sw * i, 0), Vector2(sw, r.size.y)).grow(6)
		"ctx":
			return _local_rect(_ctx).grow(8)
		"view":
			return _local_rect(_btn_view).grow(8)
		"unfold":
			return _local_rect(_btn_unfold).grow(8) if _btn_unfold else Rect2()
	return Rect2()


# 开场折纸动画
func _play_fold_in() -> void:
	busy = true
	var full := PaperView.fit(paper_rect, model.bounds, 30.0)
	if model.stages.is_empty():
		view.mode = "wedge"
		view.set_view(fit_s * 0.85, paper_rect.get_center() - model.wedge_bounds.get_center() * fit_s * 0.85)
		view.modulate.a = 0.0
		await get_tree().create_timer(0.35).timeout
		var tw0 := create_tween().set_parallel()
		tw0.tween_property(view, "modulate:a", 1.0, 0.25)
		tw0.tween_property(view, "view_scale", fit_s, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw0.tween_property(view, "view_origin", fit_o, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw0.finished
	else:
		var last: int = model.stages.size() - 1
		view.set_view(full[0], full[1])
		view.mode = "anim"
		view.anim_stage = last
		view.anim_t = -1.0
		await get_tree().create_timer(0.55).timeout
		var dur := clampf(1.4 / model.stages.size(), 0.16, 0.42)
		for k in range(last, -1, -1):
			view.anim_stage = k
			view.anim_t = -1.0
			var tw := create_tween()
			tw.tween_property(view, "anim_t", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw.finished
		view.mode = "wedge"
		var tw2 := create_tween().set_parallel()
		tw2.tween_property(view, "view_scale", fit_s, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw2.tween_property(view, "view_origin", fit_o, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await tw2.finished
	busy = false
	_refresh_hint()
	_refresh_ctx()
	_overlay.queue_redraw()
	if tutorial:
		tutorial.refresh()


# 视图

func _set_view(s: float, o: Vector2) -> void:
	s = clampf(s, fit_s, fit_s * MAX_ZOOM)
	var b: Rect2 = model.wedge_bounds
	var sb := Rect2(o + b.position * s, b.size * s)
	var r := paper_rect
	var mx := minf(sb.size.x, r.size.x) * 0.5
	var my := minf(sb.size.y, r.size.y) * 0.5
	if sb.end.x < r.position.x + mx:
		o.x += r.position.x + mx - sb.end.x
	if sb.position.x > r.end.x - mx:
		o.x -= sb.position.x - (r.end.x - mx)
	if sb.end.y < r.position.y + my:
		o.y += r.position.y + my - sb.end.y
	if sb.position.y > r.end.y - my:
		o.y -= sb.position.y - (r.end.y - my)
	view.set_view(s, o)
	_overlay.queue_redraw()
	if s > fit_s * 1.25:
		event_happened.emit("zoom")


func _zoom_at(pivot: Vector2, factor: float) -> void:
	var s0: float = view.view_scale
	var s := clampf(s0 * factor, fit_s, fit_s * MAX_ZOOM)
	var o: Vector2 = pivot - (pivot - view.view_origin) * (s / s0)
	_set_view(s, o)


func _on_reset_view() -> void:
	if busy:
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(view, "view_scale", fit_s, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "view_origin", fit_o, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_overlay.queue_redraw)
	event_happened.emit("reset_view")


# 工具

func _on_seg(i: int) -> void:
	var id: String = TOOL_ORDER[i]
	if id == "stamp":
		_open_stamp_picker()
		return
	if not Game.is_owned(id):
		if Game.buy(id):
			main.toast("解锁了「%s」" % Game.TOOLS[id]["name"], 1.6, "check")
		else:
			main.toast("铜钱不够，还差 %d 铜钱" % (Game.price_of(id) - Game.coins))
			return
	select_tool(id)


func select_tool(id: String) -> void:
	if id != "stamp":
		pending = null
	if id != "knife":
		chain = PackedVector2Array()
	tool = id
	if _seg and _seg.is_inside_tree():
		_seg.select(TOOL_ORDER.find(id))
	_cancel_single()
	_refresh_ctx()
	_refresh_hint()
	_overlay.queue_redraw()
	event_happened.emit("tool_" + id)


func _update_tool_labels() -> void:
	_seg.set_text(2, "纹样·%s" % Game.STAMPS[stamp_id]["name"].trim_suffix("纹"))


func _refresh_hint() -> void:
	if busy:
		return
	var text := ""
	var sticky := false
	if choosing:
		text = "这一刀把纸分成了几大块，点一下要留下的那块"
		sticky = true
	else:
		match tool:
			"scissors":
				text = "划过即剪开一道口子，接上纸边或别的口子，围住的纸片就会掉下"
			"knife":
				text = "依次点点，每两点刻一道直线；点回起点闭合" if chain.is_empty() else "继续点下一个点，或按“收刀”换个地方起刀"
			"stamp":
				text = "点一下纸面，放下%s" % Game.STAMPS[stamp_id]["name"] if pending == null else "单指拖动，双指旋转缩放，满意了按“雕刻”"
	if Game.tutorial_active:
		text = ""
	_show_hint(text, sticky)


func _show_hint(text: String, sticky := false) -> void:
	_hint_serial += 1
	var serial := _hint_serial
	if text == "":
		create_tween().tween_property(_hint_pill, "modulate:a", 0.0, 0.2)
		return
	var same := _hint.text == text and _hint_pill.modulate.a > 0.5
	_hint.text = text
	_place_hint()
	if not same:
		_hint_pill.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_hint_pill, "modulate:a", 1.0, 0.25)
	if not sticky:
		await get_tree().create_timer(4.5).timeout
		if is_instance_valid(self) and serial == _hint_serial:
			create_tween().tween_property(_hint_pill, "modulate:a", 0.0, 0.4)


func _ctx_button(text: String, icon: String, cb: Callable, kind := "gray") -> Button:
	var b: Button
	match kind:
		"filled":
			b = Ui.filled_button(text, Ui.T_BODY, icon)
		"tinted":
			b = Ui.tinted_button(text, Ui.T_SUB, icon)
		_:
			b = Ui.gray_button(text, Ui.T_SUB, icon)
	b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, 0), 76)
	b.pressed.connect(cb)
	return b


func _refresh_ctx() -> void:
	for c in _ctx.get_children():
		c.queue_free()
	_btn_unfold = null
	_btn_carve = null
	if choosing:
		var l := Ui.label("点选要留下的那块纸", Ui.T_SUB, Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER, 500)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ctx.add_child(l)
		return
	if tool == "stamp" and pending != null:
		var cancel := _ctx_button("取消", "close", _on_cancel_stamp)
		cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ctx.add_child(cancel)
		_btn_carve = _ctx_button("雕刻", "check", _on_carve, "filled")
		_btn_carve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ctx.add_child(_btn_carve)
		Ui.pop(_btn_carve, 0.8, 0.4)
		return
	var undo := _ctx_button("", "undo", _on_undo)
	undo.custom_minimum_size.x = 96
	undo.disabled = not model.can_undo()
	_ctx.add_child(undo)
	var fresh := _ctx_button("", "paper", _on_reset)
	fresh.custom_minimum_size.x = 96
	_ctx.add_child(fresh)
	if tool == "knife":
		var end := _ctx_button("收刀", "line_end", _on_end_chain)
		end.disabled = chain.is_empty()
		_ctx.add_child(end)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctx.add_child(sp)
	var label := "对照样稿" if Game.mode == "template" and model.stages.is_empty() else "展开"
	_btn_unfold = _ctx_button(label, "unfold", _on_unfold, "filled")
	_btn_unfold.custom_minimum_size.x = 210
	_ctx.add_child(_btn_unfold)


func _open_stamp_picker() -> void:
	if _popup:
		return
	var sh = main.sheet("选择纹样")
	_popup = sh
	sh.closed.connect(func():
		_popup = null
		_seg.select(TOOL_ORDER.find(tool)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 18)
	for id in Game.STAMP_ORDER:
		grid.add_child(_stamp_tile(id, sh))
	sh.content.add_child(grid)
	if Game.TEST_MODE:
		sh.content.add_child(Ui.label("测试版全部免费，标注的是原价", Ui.T_CAP, Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER))
	sh.open()
	event_happened.emit("stamp_picker")


func _stamp_tile(id: String, sh) -> Control:
	var info: Dictionary = Game.STAMPS[id]
	var sel := id == stamp_id and tool == "stamp"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	var tile := PanelContainer.new()
	var st := Ui.card_box(24, Ui.CARD, not sel, 16)
	if sel:
		st.border_color = Ui.ACCENT
		st.set_border_width_all(4)
	tile.add_theme_stylebox_override("panel", st)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Widgets.StampIcon.new(id, 96, Ui.ACCENT if sel else Ui.LABEL)
	tile.add_child(ic)
	v.add_child(tile)
	v.add_child(Ui.label(info["name"], Ui.T_FOOT, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER, 600 if sel else 400))
	var p := Game.price_of(id)
	v.add_child(Ui.label("基础款" if p == 0 else "原价 %d" % p, Ui.T_CAP, Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER))
	Ui.press_fx(v, 0.92)
	v.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			_on_stamp_pick(id, sh))
	return v


func _on_stamp_pick(id: String, sh) -> void:
	if not Game.is_owned(id):
		if Game.buy(id):
			main.toast("解锁了「%s」" % Game.STAMPS[id]["name"], 1.6, "check")
		else:
			main.toast("铜钱不够，还差 %d 铜钱" % (Game.price_of(id) - Game.coins))
			return
	stamp_id = id
	if pending != null:
		pending["id"] = id
	_update_tool_labels()
	sh.close()
	select_tool("stamp")
	event_happened.emit("stamp_" + id)


func _close_popup() -> void:
	if _popup:
		_popup.close()


func _show_sample() -> void:
	if Game.current_template.is_empty():
		return
	var t: Dictionary = Game.current_template
	var sh = main.sheet(t["name"])
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Ui.card_box(26, Color("efe7da"), false, 0))
	box.custom_minimum_size = Vector2(0, 520)
	var st := PaperStage.new(false)
	st.margin = 30
	box.add_child(st)
	sh.content.add_child(box)
	st.set_model(Works.model_for_template(t), Game.cut_paper)
	if t.get("desc", "") != "":
		sh.content.add_child(Ui.wrap(Ui.label(t["desc"], Ui.T_BODY, Ui.LABEL2), 300))
	sh.open()


# 按钮

func on_back() -> void:
	if _popup:
		_close_popup()
		return
	_confirm_leave()


func _on_back() -> void:
	if model.cut_count > 0 or Game.tutorial_active:
		_confirm_leave()
	else:
		_leave()


func _confirm_leave() -> void:
	var text := "这张纸上剪的内容不会保存。" if model.cut_count > 0 else ""
	if Game.tutorial_active:
		text = "教学还没完成，返回会退出教学。"
	main.dialog("确定返回吗？", text, [
		["返回", _leave],
		["继续剪纸", Callable(), "ghost"],
	])


func _leave() -> void:
	if Game.tutorial_active:
		if tutorial:
			tutorial.skip()
		Game.tutorial_active = false
		main.goto("menu", "pop")
		return
	main.goto("templates" if Game.mode == "template" else "setup", "pop")


func _on_undo() -> void:
	if busy:
		return
	if model.undo():
		if chain.size() > 1:
			chain.remove_at(chain.size() - 1)
		_end_choose()
		view.refresh()
		_request_analysis()
	_refresh_ctx()
	_overlay.queue_redraw()


func _on_reset() -> void:
	if busy:
		return
	model.reset()
	chain = PackedVector2Array()
	_end_choose()
	view.refresh()
	_refresh_ctx()
	_overlay.queue_redraw()
	main.toast("换了一张新纸，可以撤销", 1.6, "paper")


func _on_end_chain() -> void:
	chain = PackedVector2Array()
	_refresh_ctx()
	_refresh_hint()
	_overlay.queue_redraw()


func _on_carve() -> void:
	if pending == null or busy:
		return
	var polys := Stamps.placed(pending["id"], pending["pos"], pending["angle"], pending["size"])
	model.cut_region(polys, pending["id"])
	Sfx.play("carve")
	Game.add_cuts(1)
	pending = null
	view.refresh()
	_request_analysis()
	_refresh_ctx()
	_refresh_hint()
	_overlay.queue_redraw()
	event_happened.emit("carve")


func _on_cancel_stamp() -> void:
	pending = null
	_refresh_ctx()
	_refresh_hint()
	_overlay.queue_redraw()


func _on_unfold() -> void:
	if busy:
		return
	if choosing:
		main.toast("先点选要留下的那块纸")
		return
	if model.cut_count == 0:
		main.toast("还一刀没剪呢，先剪几刀吧")
		return
	busy = true
	if _btn_unfold:
		_btn_unfold.disabled = true
	while _task >= 0 or _dirty:
		await get_tree().process_frame
	if choosing:
		busy = false
		_refresh_ctx()
		return
	event_happened.emit("unfold")
	main.goto("result", "fade")


# 输入

func _input(event: InputEvent) -> void:
	if busy or _popup != null or main.current() != self or not is_visible_in_tree():
		return
	if main.has_dialog():
		return
	var e := make_input_local(event)
	if e is InputEventScreenTouch:
		if e.pressed:
			if _touches.is_empty() and not paper_rect.has_point(e.position):
				return
			if tutorial and _touches.is_empty() and not tutorial.allows(e.position):
				return
			_touches[e.index] = e.position
			_touch_down(e.position)
		elif _touches.has(e.index):
			_touches.erase(e.index)
			_touch_up(e.position)
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if _touches.has(e.index):
			_touches[e.index] = e.position
			_touch_move(e.position)
	elif e is InputEventMouseButton:
		if not paper_rect.has_point(e.position):
			return
		if e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var d := 1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			if pending != null:
				if e.ctrl_pressed:
					_scale_stamp(1.0 + 0.08 * d)
				else:
					_rotate_stamp(deg_to_rad(10.0) * d)
			else:
				_zoom_at(e.position, 1.0 + 0.12 * d)
		elif e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_desk_pan = e.position if e.pressed else null
	elif e is InputEventMouseMotion and _desk_pan != null:
		_set_view(view.view_scale, view.view_origin + (e.position - _desk_pan))
		_desk_pan = e.position


func _touch_down(pos: Vector2) -> void:
	var n := _touches.size()
	if n == 1:
		_gesture = "single"
		_start = pos
		_last = pos
		_moved = false
		if choosing:
			return
		match tool:
			"scissors":
				_stroke = PackedVector2Array([pos])
			"knife":
				_knife_preview = pos
			"stamp":
				if pending == null:
					pending = {"id": stamp_id, "pos": view.screen_to_paper(pos), "angle": 0.0,
						"size": STAMP_DEFAULT_PX / view.view_scale}
					_stamp_rot_acc = 0.0
					_refresh_ctx()
					_refresh_hint()
					event_happened.emit("stamp_placed")
	elif n == 2:
		_cancel_single()
		_gesture = "pinch"
		var ps: Array = _touches.values()
		var c: Vector2 = (ps[0] + ps[1]) * 0.5
		var d: float = maxf(1.0, (ps[1] - ps[0]).length())
		var a: float = (ps[1] - ps[0]).angle()
		_pinch = {"c": c, "d": d, "a": a, "s": view.view_scale, "o": view.view_origin}
		if pending != null:
			_pinch["stamp"] = pending.duplicate()
	else:
		_cancel_single()
		_gesture = "ignore"
	_overlay.queue_redraw()


func _touch_move(pos: Vector2) -> void:
	if _gesture == "single":
		if pos.distance_to(_start) > 10.0:
			_moved = true
		if choosing:
			return
		match tool:
			"scissors":
				if _stroke.size() > 0 and _stroke[_stroke.size() - 1].distance_to(pos) >= 4.0:
					_stroke.append(pos)
			"knife":
				_knife_preview = pos
			"stamp":
				if pending != null:
					pending["pos"] += (pos - _last) / view.view_scale
		_last = pos
		_overlay.queue_redraw()
	elif _gesture == "pinch" and _touches.size() >= 2:
		var ps: Array = _touches.values()
		var c: Vector2 = (ps[0] + ps[1]) * 0.5
		var d: float = maxf(1.0, (ps[1] - ps[0]).length())
		var a: float = (ps[1] - ps[0]).angle()
		if _pinch.has("stamp") and pending != null:
			var st: Dictionary = _pinch["stamp"]
			var old_angle: float = pending["angle"]
			pending["angle"] = st["angle"] + wrapf(a - _pinch["a"], -PI, PI)
			pending["size"] = _clamp_stamp_size(st["size"] * d / _pinch["d"])
			pending["pos"] = st["pos"] + (c - _pinch["c"]) / view.view_scale
			_stamp_rot_acc += absf(wrapf(pending["angle"] - old_angle, -PI, PI))
			if _stamp_rot_acc > deg_to_rad(25.0):
				event_happened.emit("stamp_rotated")
		else:
			var s0: float = _pinch["s"]
			var s := clampf(s0 * d / _pinch["d"], fit_s, fit_s * MAX_ZOOM)
			var o: Vector2 = c - (_pinch["c"] - _pinch["o"]) * (s / s0)
			_set_view(s, o)
		_overlay.queue_redraw()


func _touch_up(pos: Vector2) -> void:
	if _gesture == "single" and _touches.is_empty():
		if choosing:
			if not _moved:
				_choose_at(pos)
		else:
			match tool:
				"scissors":
					_finish_stroke()
				"knife":
					if _knife_preview != null:
						_knife_point(pos)
					_knife_preview = null
	if _touches.is_empty():
		_gesture = ""
	elif _gesture == "pinch":
		_gesture = "ignore"
	_overlay.queue_redraw()


func _cancel_single() -> void:
	_stroke = PackedVector2Array()
	_knife_preview = null


func _rotate_stamp(da: float) -> void:
	pending["angle"] += da
	_stamp_rot_acc += absf(da)
	if _stamp_rot_acc > deg_to_rad(25.0):
		event_happened.emit("stamp_rotated")
	_overlay.queue_redraw()


func _scale_stamp(f: float) -> void:
	pending["size"] = _clamp_stamp_size(pending["size"] * f)
	event_happened.emit("stamp_rotated")
	_overlay.queue_redraw()


func _clamp_stamp_size(s: float) -> float:
	var b: Rect2 = model.wedge_bounds
	return clampf(s, 14.0, maxf(b.size.x, b.size.y) * 0.9)


# 剪刀与刻刀

func _finish_stroke() -> void:
	var pts := _stroke
	_stroke = PackedVector2Array()
	if pts.size() < 2:
		return
	var length := 0.0
	for i in pts.size() - 1:
		length += pts[i].distance_to(pts[i + 1])
	if length < 10.0:
		return
	pts = _simplify(pts, 1.4)
	var paper := PackedVector2Array()
	for p in pts:
		paper.append(view.screen_to_paper(p))
	var r: float = SNAP_PX / view.view_scale
	# 闭合判断
	var closed := false
	if length > SNAP_PX * 4.0 and paper[paper.size() - 1].distance_to(paper[0]) < r:
		paper.append(paper[0])
		closed = true
	if not closed:
		var e := _snap(paper[paper.size() - 1], r)
		if e != paper[paper.size() - 1]:
			paper.append(e)
		var s := _snap(paper[0], r)
		if s != paper[0]:
			paper.insert(0, s)
	model.cut_slit(paper, "scissors")
	Sfx.play("snip", 0.0, randf_range(0.92, 1.08))
	_after_cut()


func _knife_point(pos: Vector2) -> void:
	var p: Vector2 = view.screen_to_paper(pos)
	var r: float = SNAP_PX / view.view_scale
	if chain.size() >= 2 and p.distance_to(chain[0]) < r:
		model.cut_slit(PackedVector2Array([chain[chain.size() - 1], chain[0]]), "knife")
		Sfx.play("tick", 0.0, 1.3)
		chain = PackedVector2Array()
		knife_segments += 1
		_after_cut()
		event_happened.emit("knife")
		return
	var sp := _snap(p, r)
	if chain.is_empty():
		chain.append(sp)
		_refresh_hint()
		_refresh_ctx()
		return
	if sp.distance_to(chain[chain.size() - 1]) < 2.0 / model.px_per_unit:
		return
	model.cut_slit(PackedVector2Array([chain[chain.size() - 1], sp]), "knife")
	Sfx.play("tick", 0.0, randf_range(1.2, 1.4))
	chain.append(sp)
	knife_segments += 1
	_after_cut()
	event_happened.emit("knife")


func _after_cut() -> void:
	Game.add_cuts(1)
	view.refresh()
	_request_analysis()
	_refresh_ctx()
	_refresh_hint()
	event_happened.emit("cut")


# 端点吸附
func _snap(p: Vector2, r: float) -> Vector2:
	var w: PackedVector2Array = model.wedge
	if not Geometry2D.is_point_in_polygon(p, w):
		return p
	var best_d := r
	var best := p
	var push: float = 2.5 / model.px_per_unit
	for i in w.size():
		var c := Geometry2D.get_closest_point_to_segment(p, w[i], w[(i + 1) % w.size()])
		var d := p.distance_to(c)
		if d < best_d:
			best_d = d
			var dir := (c - p).normalized() if d > 0.001 else (c - _centroid(w)).normalized()
			best = c + dir * push
	var q: Vector2 = model.to_tex(p)
	var stride: int = maxi(1, int(model.px_per_unit / 2.5))
	var rt := int(minf(best_d, 24.0) * model.px_per_unit)
	if rt >= 1:
		var data: PackedByteArray = model.mask.get_data()
		var tw: int = model.tex_w
		var th: int = model.tex_h
		var cx := int(q.x)
		var cy := int(q.y)
		if cx >= 0 and cy >= 0 and cx < tw and cy < th and data[cy * tw + cx] < 128:
			return p
		var best_t := float(rt * rt) + 1.0
		var hit := Vector2(-1, -1)
		for dy in range(-rt, rt + 1, stride):
			var y := cy + dy
			if y < 0 or y >= th:
				continue
			for dx in range(-rt, rt + 1, stride):
				var dd := float(dx * dx + dy * dy)
				if dd >= best_t:
					continue
				var x := cx + dx
				if x < 0 or x >= tw:
					continue
				if data[y * tw + x] < 128:
					var ai: int = (y / model.ds) * model.a_w + (x / model.ds)
					if ai < model.classmap.size() and model.classmap[ai] == 2:
						best_t = dd
						hit = Vector2(x + 0.5, y + 0.5)
		if hit.x >= 0.0:
			var hp: Vector2 = model.from_tex(hit)
			var dir := (hp - p).normalized()
			return hp + dir * (1.0 / model.px_per_unit)
	return best


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / poly.size()


static func _simplify(pts: PackedVector2Array, eps: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var keep := PackedByteArray()
	keep.resize(pts.size())
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var stack := [[0, pts.size() - 1]]
	while not stack.is_empty():
		var seg: Array = stack.pop_back()
		var a: int = seg[0]
		var b: int = seg[1]
		var best := -1.0
		var idx := -1
		for i in range(a + 1, b):
			var c := Geometry2D.get_closest_point_to_segment(pts[i], pts[a], pts[b])
			var d := pts[i].distance_to(c)
			if d > best:
				best = d
				idx = i
		if best > eps and idx > 0:
			keep[idx] = 1
			stack.append([a, idx])
			stack.append([idx, b])
	var out := PackedVector2Array()
	for i in pts.size():
		if keep[i] == 1:
			out.append(pts[i])
	return out


# 连通分析与碎片掉落

func _request_analysis() -> void:
	if _task >= 0:
		_dirty = true
		return
	_dirty = false
	var snap: Image = model.mask.duplicate()
	var a_w: int = model.a_w
	var a_h: int = model.a_h
	var cm: PackedByteArray = model.classmap
	var holder := {}
	_holder = holder
	_task_epoch = model.epoch
	_task = WorkerThreadPool.add_task(func(): holder["comp"] = Analyzer.components(snap, a_w, a_h, cm))


func _process(_delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_epoch == model.epoch and not choosing:
			_on_components(_holder.get("comp", {}))
		elif _task_epoch != model.epoch:
			_dirty = true
		if _dirty and not choosing:
			_request_analysis()


func _on_components(comp: Dictionary) -> void:
	if comp.is_empty():
		return
	var sizes: PackedInt32Array = comp["sizes"]
	if sizes.size() <= 1:
		return
	var order := range(sizes.size())
	order.sort_custom(func(a, b): return sizes[a] > sizes[b])
	var keep: int = order[0]
	if not target.is_empty():
		keep = _best_for_target(comp)
	else:
		var total := 0
		for s in sizes:
			total += s
		var big := []
		for l in order:
			if sizes[l] >= 0.12 * total:
				big.append(l)
		if big.size() >= 2 and not Game.tutorial_active:
			_start_choose(comp, big)
			return
	_apply_keep(comp, keep)


func _best_for_target(comp: Dictionary) -> int:
	var labels: PackedInt32Array = comp["labels"]
	var tk: PackedByteArray = target["keep"]
	var sizes: PackedInt32Array = comp["sizes"]
	# 按样稿保留部分选主体
	var score := PackedInt32Array()
	score.resize(sizes.size())
	for i in labels.size():
		var l := labels[i]
		if l >= 0 and tk[i] == 1:
			score[l] += 1
	var best := 0
	for l in sizes.size():
		if score[l] > score[best] or (score[l] == score[best] and sizes[l] > sizes[best]):
			best = l
	return best


func _apply_keep(comp: Dictionary, keep: int) -> void:
	var dr := Analyzer.build_drop(comp, keep, model.classmap)
	if not dr["any"]:
		return
	var piece: Image = model.drop_pieces(dr["drop"], dr["keep"])
	view.spawn_fall(piece)
	Sfx.play("rustle", -5.0, randf_range(0.9, 1.1))
	view.refresh()
	event_happened.emit("drop")


func _start_choose(comp: Dictionary, labels: Array) -> void:
	choosing = true
	_choose_comp = comp
	_choose_labels = labels
	var lab: PackedInt32Array = comp["labels"]
	var a_w: int = comp["a_w"]
	var a_h: int = comp["a_h"]
	var data := PackedByteArray()
	data.resize(a_w * a_h * 4)
	for i in lab.size():
		var k := labels.find(lab[i])
		if k >= 0:
			var c: Color = CHOOSE_COLORS[k % CHOOSE_COLORS.size()]
			data[i * 4] = int(c.r * 255)
			data[i * 4 + 1] = int(c.g * 255)
			data[i * 4 + 2] = int(c.b * 255)
			data[i * 4 + 3] = int(c.a * 160)
	view.set_overlay(ImageTexture.create_from_image(Image.create_from_data(a_w, a_h, false, Image.FORMAT_RGBA8, data)))
	_refresh_ctx()
	_refresh_hint()


func _choose_at(pos: Vector2) -> void:
	var p: Vector2 = view.screen_to_paper(pos)
	var idx: int = model.ana_index(p)
	if idx < 0:
		return
	var lab: PackedInt32Array = _choose_comp["labels"]
	var l := lab[idx]
	if not _choose_labels.has(l):
		main.toast("点在要留下的那块纸上")
		return
	var comp := _choose_comp
	_end_choose()
	_apply_keep(comp, l)
	if _dirty:
		_request_analysis()


func _end_choose() -> void:
	if not choosing:
		return
	choosing = false
	_choose_comp = {}
	_choose_labels = []
	view.set_overlay(null)
	_refresh_ctx()
	_refresh_hint()


# 绘制

func _draw_overlay(o: Control) -> void:
	if busy and view.mode != "wedge":
		return
	# 样稿虚线
	if not target.is_empty() and view.mode == "wedge":
		for line in target["lines"]:
			var sp := PackedVector2Array()
			for p in line:
				sp.append(view.paper_to_screen(p))
			var light: bool = Game.PAPERS[Game.cut_paper]["color"].get_luminance() > 0.45
			var under := Color(1.0, 0.97, 0.9, 0.7) if light else Color(0.15, 0.06, 0.03, 0.55)
			var top := Color(0.55, 0.08, 0.05, 0.95) if light else Color(1.0, 0.95, 0.8, 0.95)
			_dashed_poly(o, sp, under, 4.0, 9.0, 7.0)
			_dashed_poly(o, sp, top, 2.0, 9.0, 7.0)
	# 剪刀轨迹
	if _stroke.size() >= 2:
		o.draw_polyline(_stroke, Color(0.1, 0.05, 0.03, 0.9), 3.0, true)
		o.draw_circle(_stroke[_stroke.size() - 1], 7.0, Color(0.98, 0.9, 0.65))
	# 刻刀
	if tool == "knife":
		for i in chain.size():
			var sp: Vector2 = view.paper_to_screen(chain[i])
			o.draw_circle(sp, 8.0 if i == 0 else 5.0, Color(0.98, 0.9, 0.65))
			o.draw_arc(sp, 8.0 if i == 0 else 5.0, 0, TAU, 20, Color(0.15, 0.06, 0.03), 1.5, true)
		if _knife_preview != null:
			if not chain.is_empty():
				_dashed_poly(o, PackedVector2Array([view.paper_to_screen(chain[chain.size() - 1]), _knife_preview]),
						Color(0.98, 0.9, 0.65), 2.5, 10.0, 6.0)
			o.draw_circle(_knife_preview, 6.0, Color(0.98, 0.9, 0.65))
	# 待刻纹样
	if pending != null:
		var c: Vector2 = view.paper_to_screen(pending["pos"])
		var s: float = pending["size"] * view.view_scale
		for poly in Stamps.placed(pending["id"], c, pending["angle"], s):
			o.draw_colored_polygon(poly, Color(0.1, 0.04, 0.02, 0.45))
			var closed: PackedVector2Array = poly.duplicate()
			closed.append(poly[0])
			o.draw_polyline(closed, Color(1.0, 0.93, 0.75), 2.5, true)
		o.draw_arc(c, s * 0.62, 0, TAU, 48, Color(1.0, 0.93, 0.75, 0.35), 1.5, true)


static func _dashed_poly(o: Control, pts: PackedVector2Array, col: Color, width: float, dash: float, gap: float) -> void:
	var phase := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var l := a.distance_to(b)
		if l < 0.01:
			continue
		var dir := (b - a) / l
		var t := 0.0
		while t < l:
			var period := dash + gap
			var m := fmod(phase + t, period)
			if m < dash:
				var e := minf(l, t + (dash - m))
				o.draw_line(a + dir * t, a + dir * e, col, width, true)
				t = e
			else:
				t += period - m
		phase = fmod(phase + l, dash + gap)
