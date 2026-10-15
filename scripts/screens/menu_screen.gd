# 剪纸坊
# menu_screen.gd - 首页
extends Control

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const LedgerSheet = preload("res://scripts/ui/ledger_sheet.gd")
const Works = preload("res://scripts/ui/works.gd")
const PaperStage = preload("res://scripts/ui/paper_stage.gd")
const Templates = preload("res://scripts/templates.gd")
const Sfx = preload("res://scripts/sfx.gd")
const PhotoSheet = preload("res://scripts/ui/photo_sheet.gd")
const PrintSheet = preload("res://scripts/print_sheet.gd")

const VERSION := "v0.3 测试版"
const SHOW_SECONDS := 4.5

var main = null
var backdrop := "paper"

var _scroll: ScrollContainer
var _show_box: Control
var _caption_rank: Label
var _caption_name: Label
var _caption_detail: Label
var _dots: HBoxContainer
var _stage_a
var _stage_b
var _items: Array = []
var _index := 0
var _timer := 0.0
var _press_pos = null
var _task := -1
var _prefetch := {}


func _ready() -> void:
	Game.tutorial_active = false
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 32)
	m.add_theme_constant_override("margin_right", 32)
	m.add_theme_constant_override("margin_top", int(main.safe_top + 26))
	m.add_theme_constant_override("margin_bottom", int(main.safe_bottom + 40))
	_scroll.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	m.add_child(v)

	# 标题
	var head := HBoxContainer.new()
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Ui.title("剪纸坊", Ui.T_LARGE))
	if Game.TEST_MODE:
		tv.add_child(Ui.label("测试版 · 全部内容免费开放", Ui.T_FOOT, Ui.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 500))
	head.add_child(tv)
	var coin := Widgets.CoinPill.new(Game.coins)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 铜钱明细入口
	coin.mouse_filter = Control.MOUSE_FILTER_STOP
	coin.add_child_chevron()
	Ui.press_fx(coin, 0.94)
	coin.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed \
				and Rect2(Vector2.ZERO, coin.size).has_point(e.position):
			LedgerSheet.open(main))
	head.add_child(coin)
	v.add_child(head)

	v.add_child(_build_showcase())

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 20)
	modes.add_child(_mode_card("scissors", "自由创作", "选纸、选折法\n随心剪一幅", _go_free))
	modes.add_child(_mode_card("eye", "照样剪纸", "沿着样稿剪\n比比谁剪得准", _go_templates))
	v.add_child(modes)

	v.add_child(Widgets.list_group([
		Widgets.list_row("image", Ui.ACCENT, "照片变样稿", "新", func(): PhotoSheet.open_picker(main)),
		Widgets.list_row("chart", Color("e0a100"), "我的记录", "%d 件" % Game.works.size(), _go_records),
		Widgets.list_row("book", Color("3b82f6"), "新手教学", "", start_tutorial),
		Widgets.list_row("gear", Color("8e8e93"), "设置", "", _open_settings),
	]))
	var foot := Ui.label("剪纸坊 %s" % VERSION, Ui.T_CAP, Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(foot)

	Ui.appear(v.get_children(), 0.06)
	_load_items()
	if not Game.first_launch_done:
		while main.splashing:
			await get_tree().process_frame
		_ask_level()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func on_back() -> void:
	main.back_to_exit()


func _mode_card(icon: String, title: String, sub: String, cb: Callable) -> PanelContainer:
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_stylebox_override("panel", Ui.card_box(28, Ui.CARD, true, 26))
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", Ui.card_box(40, Ui.ACCENT_TINT, false, 14))
	circle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(Icon.new(icon, Ui.ACCENT, 46))
	v.add_child(circle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Ui.title(title, Ui.T_TITLE3)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(Icon.new("arrow_right", Ui.LABEL3, 30))
	v.add_child(row)
	v.add_child(Ui.label(sub, Ui.T_FOOT, Ui.LABEL2))
	Ui.press_fx(c, 0.96)
	c.gui_input.connect(func(e):
		if _is_tap(e):
			cb.call())
	return c


var _tap_from = null


func _is_tap(e: InputEvent) -> bool:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return false
	if e.pressed:
		_tap_from = [e.global_position, _scroll.scroll_vertical]
		return false
	if _tap_from == null:
		return false
	var ok: bool = e.global_position.distance_to(_tap_from[0]) < 14.0 and absi(_scroll.scroll_vertical - _tap_from[1]) < 4
	_tap_from = null
	return ok


# 展示柜

func _build_showcase() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card_box(32, Ui.CARD, true, 0))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	_show_box = Control.new()
	_show_box.custom_minimum_size = Vector2(0, 470)
	_show_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_box.clip_contents = true
	v.add_child(_show_box)
	var bg := PanelContainer.new()
	var st := Ui.card_box(32, Color("efe7da"), false, 0)
	st.corner_radius_bottom_left = 0
	st.corner_radius_bottom_right = 0
	bg.add_theme_stylebox_override("panel", st)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_box.add_child(bg)
	_stage_a = PaperStage.new(true)
	_stage_b = PaperStage.new(true)
	for s in [_stage_a, _stage_b]:
		s.margin = 40
		s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_show_box.add_child(s)

	var cap := MarginContainer.new()
	for side in ["left", "right"]:
		cap.add_theme_constant_override("margin_" + side, 28)
	cap.add_theme_constant_override("margin_top", 22)
	cap.add_theme_constant_override("margin_bottom", 22)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	var ch := HBoxContainer.new()
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(ch)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cv)
	_caption_rank = Ui.label("", Ui.T_FOOT, Ui.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 700)
	cv.add_child(_caption_rank)
	_caption_name = Ui.title("", Ui.T_HEAD)
	cv.add_child(_caption_name)
	_caption_detail = Ui.label("", Ui.T_FOOT, Ui.LABEL2)
	cv.add_child(_caption_detail)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_END
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(_dots)
	card.gui_input.connect(_showcase_input)
	return card


func _load_items() -> void:
	_items = []
	var rank := 0
	for w in Game.top_works(10):
		rank += 1
		if w.get("has_mask", false):
			_items.append({"kind": "work", "data": w, "rank": rank})
	for t in Templates.all():
		if _items.size() >= 10:
			break
		_items.append({"kind": "template", "data": t})
	for c in _dots.get_children():
		c.queue_free()
	for i in _items.size():
		var d := Icon.new("dot", Ui.LABEL3, 10)
		_dots.add_child(d)
	if _items.is_empty():
		return
	_index = 0
	_ensure_model(0)
	_show(0, 0)
	_prefetch_next()


func _ensure_model(i: int) -> void:
	var it: Dictionary = _items[i]
	if it.has("model"):
		return
	if it["kind"] == "work":
		it["model"] = Works.model_for_work(it["data"])
	else:
		it["model"] = Works.model_for_template(it["data"])


func _prefetch_next() -> void:
	if _task >= 0 or _items.size() < 2:
		return
	var j := (_index + 1) % _items.size()
	if _items[j].has("model"):
		return
	var it: Dictionary = _items[j]
	_task = WorkerThreadPool.add_task(func():
		if it["kind"] == "work":
			it["model"] = Works.model_for_work(it["data"])
		else:
			it["model"] = Works.model_for_template(it["data"]))


func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _items.size() < 2 or main.has_dialog():
		return
	_timer += delta
	if _timer >= SHOW_SECONDS:
		_go_item(1)


func _go_item(dir: int) -> void:
	_timer = 0.0
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	var j := posmod(_index + dir, _items.size())
	_ensure_model(j)
	_show(j, dir)
	_index = j
	_prefetch_next()


func _show(i: int, dir: int) -> void:
	var it: Dictionary = _items[i]
	var incoming = _stage_b if _stage_a.view != null and _stage_a.modulate.a > 0.5 else _stage_a
	var outgoing = _stage_a if incoming == _stage_b else _stage_b
	var paper: String = it["data"]["paper"]
	if it.get("model") != null:
		incoming.set_model(it["model"], paper)
	if dir == 0:
		incoming.modulate.a = 1.0
		outgoing.modulate.a = 0.0
	else:
		var w: float = _show_box.size.x
		incoming.position.x = w * 0.35 * dir
		incoming.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(incoming, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(incoming, "modulate:a", 1.0, 0.45)
		tw.tween_property(outgoing, "position:x", -w * 0.35 * dir, 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(outgoing, "modulate:a", 0.0, 0.35)
	if it["kind"] == "work":
		var w: Dictionary = it["data"]
		_caption_rank.text = "No.%d · %d 铜钱" % [it["rank"], w["price"]]
		_caption_rank.add_theme_color_override("font_color", Ui.ACCENT)
		_caption_name.text = w["name"]
		_caption_detail.text = "%s 拍得 · %s" % [w["buyer"], Works.date_text(w["time"])]
	else:
		var t: Dictionary = it["data"]
		_caption_rank.text = "样稿"
		_caption_rank.add_theme_color_override("font_color", Ui.LABEL2)
		_caption_name.text = t["name"]
		_caption_detail.text = "%s · %s" % [Game.FOLDS[t["fold"]]["name"], Ui.stars_text(t["difficulty"])]
	for k in _dots.get_child_count():
		var d: Icon = _dots.get_child(k)
		d.set_icon("dot", Ui.ACCENT if k == i else Ui.LABEL3)


func _showcase_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press_pos = [e.global_position, _scroll.scroll_vertical]
		elif _press_pos != null:
			var d: Vector2 = e.global_position - _press_pos[0]
			var scrolled: bool = absi(_scroll.scroll_vertical - _press_pos[1]) > 4
			_press_pos = null
			if scrolled or _items.is_empty():
				return
			if absf(d.x) > 60.0 and absf(d.x) > absf(d.y):
				_go_item(-1 if d.x > 0 else 1)
			elif d.length() < 14.0:
				_open_item()


func _open_item() -> void:
	var it: Dictionary = _items[_index]
	if it["kind"] == "work":
		Works.open_work_sheet(main, it["data"])
	else:
		var t: Dictionary = it["data"]
		var sh = main.sheet(t["name"])
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Ui.card_box(26, Color("efe7da"), false, 0))
		box.custom_minimum_size = Vector2(0, 480)
		var st := PaperStage.new(true)
		st.margin = 34
		box.add_child(st)
		sh.content.add_child(box)
		st.set_model(Works.model_for_template(t), t["paper"])
		sh.content.add_child(Ui.wrap(Ui.label(t.get("desc", ""), Ui.T_BODY, Ui.LABEL2), 300))
		var go := Ui.filled_button("照这张样稿剪", Ui.T_HEAD)
		go.custom_minimum_size = Vector2(0, 96)
		go.pressed.connect(func():
			sh.close()
			Game.mode = "template"
			Game.current_template = t
			Game.cut_paper = t["paper"] if Game.is_owned(t["paper"]) else "red"
			Game.cut_fold = t["fold"]
			main.goto("cut"))
		sh.content.add_child(go)
		var pb := Ui.tinted_button("导出剪纸图纸", Ui.T_BODY, "print")
		pb.custom_minimum_size = Vector2(0, 88)
		pb.pressed.connect(func():
			sh.close()
			PrintSheet.open(main, Works.model_for_template(t), t["paper"], t["name"]))
		sh.content.add_child(pb)
		sh.open()


# 导航

func _go_free() -> void:
	main.goto("setup")


func _go_templates() -> void:
	main.goto("templates")


func _go_records() -> void:
	main.goto("records")


func _ask_level() -> void:
	main.dialog("欢迎来到剪纸坊", "你以前玩过剪纸吗？", [
		["我是新手，带我学一遍", _choose_new],
		["我会剪纸，直接开始", _choose_veteran, "ghost"],
	], false)


func _choose_new() -> void:
	Game.first_launch_done = true
	Game.player_level = "new"
	Game.save_game()
	start_tutorial()


func _choose_veteran() -> void:
	Game.first_launch_done = true
	Game.player_level = "veteran"
	Game.save_game()


func start_tutorial() -> void:
	Game.tutorial_active = true
	Game.mode = "free"
	Game.current_template = {}
	Game.cut_paper = "red"
	Game.cut_fold = "eight"
	main.goto("cut")


func _open_settings() -> void:
	var sh = main.sheet("设置")
	sh.content.add_child(Widgets.list_group([
		Widgets.switch_row("speaker", Color("34a853"), "音效", Game.sound_on, func(on: bool):
			Game.sound_on = on
			Game.save_game()
			if on:
				Sfx.play("tap")),
		Widgets.switch_row("film", Color("af52de"), "跳过开屏动画", Game.skip_splash, func(on: bool):
			Game.skip_splash = on
			Game.save_game()),
	]))
	sh.content.add_child(Widgets.list_group([
		Widgets.list_row("book", Color("3b82f6"), "重看新手教学", "", func():
			sh.close()
			start_tutorial()),
		Widgets.list_row("paper", Color("ff6b5b"), "清空存档", "", func():
			sh.close()
			_confirm_reset(), Ui.ACCENT),
	]))
	sh.content.add_child(Ui.label("剪纸坊 %s" % VERSION, Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER))
	sh.open()


func _confirm_reset() -> void:
	main.dialog("清空存档？", "铜钱、成交记录、作品和统计都会清零，无法恢复。", [
		["清空", _do_reset],
		["取消", Callable(), "ghost"],
	])


func _do_reset() -> void:
	Game.reset_save()
	main.goto("menu", "fade")
