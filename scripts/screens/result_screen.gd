# 剪纸坊
# result_screen.gd - 展开结果页
extends Control

signal event_happened(name: String)

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const PaperView = preload("res://scripts/paper_view.gd")
const Analyzer = preload("res://scripts/analyzer.gd")
const Templates = preload("res://scripts/templates.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
const Sfx = preload("res://scripts/sfx.gd")
const PrintSheet = preload("res://scripts/print_sheet.gd")
const FoldFacts = preload("res://scripts/fold_facts.gd")

var main = null
var backdrop := "desk"

var model
var view
var _panel: PanelContainer = null
var _sell: Button = null
var _paper_rect := Rect2()
var _holder := {}
var _task := -1
var _done := false
var _diff_tex: Texture2D = null
var _btn_back: Button
var _btn_print: Button
var tutorial = null


func _ready() -> void:
	model = Game.current_model
	view = PaperView.new()
	add_child(view)
	view.setup(model, Game.cut_paper)

	_btn_back = Ui.icon_button("back", 72)
	_btn_back.pressed.connect(_continue_cut)
	add_child(_btn_back)
	_btn_print = Ui.icon_button("print", 72)
	_btn_print.pressed.connect(_export_print)
	_btn_print.visible = false
	add_child(_btn_print)

	var holder := _holder
	var m = model
	if Game.mode == "template" and not Game.current_target.is_empty():
		var tgt: Dictionary = Game.current_target
		_task = WorkerThreadPool.add_task(func(): holder["cmp"] = Templates.compare(m, tgt))
	else:
		var img: Image = model.mask.duplicate()
		var a_w: int = model.a_w
		var a_h: int = model.a_h
		var cm: PackedByteArray = model.classmap
		var layers: int = model.layer_count()
		_task = WorkerThreadPool.add_task(func(): holder["stats"] = Analyzer.stats(img, a_w, a_h, cm, layers))

	if Game.tutorial_active:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.start_result(self)

	resized.connect(_layout)
	await get_tree().process_frame
	_layout()
	_play()


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func on_back() -> void:
	if _done:
		_continue_cut()


func rect_of(name: String) -> Rect2:
	match name:
		"panel":
			return Rect2(_panel.position, _panel.size).grow(-4) if _panel else Rect2()
		"sell":
			return Rect2(_sell.global_position - global_position, _sell.size).grow(8) if _sell else Rect2()
	return Rect2()


func _layout() -> void:
	var top: float = main.safe_top + 14.0
	_btn_back.position = Vector2(20, top)
	_btn_print.position = Vector2(size.x - 92, top)
	_paper_rect = Rect2(Vector2(24, top + 80), Vector2(size.x - 48, size.y * 0.47 - top))
	if _done:
		var f := PaperView.fit(_paper_rect, model.bounds, 20.0)
		view.set_view(f[0], f[1])
	if _panel:
		_place_panel()


func _play() -> void:
	var cut_rect := Rect2(Vector2(12, main.safe_top + 104.0), Vector2(size.x - 24, size.y - main.safe_top - 104.0 - main.safe_bottom - 250.0))
	var wedge_fit := PaperView.fit(cut_rect, model.wedge_bounds, 26.0)
	var full_fit := PaperView.fit(_paper_rect, model.bounds, 20.0)
	if model.stages.is_empty():
		view.mode = "full"
		view.set_view(wedge_fit[0], wedge_fit[1])
		view.lift = 0.6
		var tw0 := create_tween().set_parallel()
		tw0.tween_property(view, "view_scale", full_fit[0], 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		tw0.tween_property(view, "view_origin", full_fit[1], 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		tw0.tween_property(view, "lift", 0.0, 0.7)
		await tw0.finished
	else:
		view.mode = "anim"
		view.anim_stage = 0
		view.anim_t = 1.0
		view.set_view(wedge_fit[0], wedge_fit[1])
		var tw := create_tween().set_parallel()
		tw.tween_property(view, "view_scale", full_fit[0], 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(view, "view_origin", full_fit[1], 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		var dur := clampf(2.4 / model.stages.size(), 0.22, 0.6)
		Sfx.play("unfold", -3.0)
		for k in model.stages.size():
			view.anim_stage = k
			view.anim_t = 1.0
			var t2 := create_tween()
			t2.tween_property(view, "anim_t", -1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await t2.finished
		view.mode = "full"
	_done = true
	_btn_print.visible = true
	Ui.pop(_btn_print, 0.6, 0.4)

	while not WorkerThreadPool.is_task_completed(_task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1

	var result: Dictionary
	var paper_info: Dictionary = Game.PAPERS[Game.cut_paper]
	if _holder.has("cmp"):
		var cmp: Dictionary = _holder["cmp"]
		result = Templates.score(cmp, Game.current_template, paper_info)
		result["missed"] = cmp["missed"]
		result["extra"] = cmp["extra"]
		_diff_tex = ImageTexture.create_from_image(cmp["diff"])
	else:
		result = Analyzer.score_free(_holder["stats"], model.initial_area, model.layer_count(),
				paper_info, Game.FOLDS[Game.cut_fold])
	result["paper"] = Game.cut_paper
	result["fold"] = Game.cut_fold
	result["template"] = Game.current_template.get("name", "")
	Game.current_result = result
	_show_panel(result)


func _show_panel(r: Dictionary) -> void:
	_panel = PanelContainer.new()
	var st := Ui.card_box(36, Ui.BG, true, 0)
	st.corner_radius_bottom_left = 0
	st.corner_radius_bottom_right = 0
	st.shadow_size = 30
	st.shadow_offset = Vector2(0, -4)
	_panel.add_theme_stylebox_override("panel", st)
	add_child(_panel)
	if tutorial:
		move_child(tutorial, get_child_count() - 1)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 32)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", int(main.safe_bottom + 26))
	_panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)

	# 评语与星级
	var head := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	hv.add_child(Ui.label("照样剪 · " + r["template"] if r["mode"] == "template" else "%s · %s" % [Game.PAPERS[r["paper"]]["name"], Game.FOLDS[r["fold"]]["name"]], Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500))
	hv.add_child(Ui.title("「%s」" % r["comment"], Ui.T_TITLE3))
	head.add_child(hv)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 2)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star_labels := []
	for i in 5:
		var l := Ui.label("★" if i < r["stars"] else "☆", Ui.T_TITLE3, Ui.GOLD if i < r["stars"] else Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER, 700)
		stars.add_child(l)
		star_labels.append(l)
	head.add_child(stars)
	v.add_child(head)
	var fact := _fact_card(r["fold"])
	if fact:
		v.add_child(fact)

	# 指标
	var rings := HBoxContainer.new()
	rings.alignment = BoxContainer.ALIGNMENT_CENTER
	rings.add_theme_constant_override("separation", 26)
	var ring_list := []
	if r["mode"] == "template":
		var acc: float = r["accuracy"]
		ring_list.append(Widgets.Ring.new(acc, Ui.ACCENT, "%d%%" % int(round(acc * 100.0)), "吻合度", 170))
	else:
		ring_list.append(Widgets.Ring.new(r["cut_ratio"] / 0.8, Ui.ACCENT, "%d%%" % int(round(r["cut_ratio"] * 100.0)), "镂空率", 150))
		ring_list.append(Widgets.Ring.new(log(1.0 + r["holes"]) / log(61.0), Ui.GOLD, str(r["holes"]), "纹孔数", 150))
		ring_list.append(Widgets.Ring.new(r["fineness"], Color("3b82f6"), str(int(round(r["fineness"] * 100.0))), "精细度", 150))
	for rg in ring_list:
		rings.add_child(rg)
	if r["mode"] == "template":
		var side := VBoxContainer.new()
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.add_theme_constant_override("separation", 12)
		var seg := Widgets.Segmented.new([["sparkle", "作品"], ["eye", "对照"]])
		seg.custom_minimum_size = Vector2(300, 70)
		seg.tapped.connect(func(i):
			seg.select(i)
			view.set_overlay(_diff_tex if i == 1 else null))
		side.add_child(seg)
		var legend := HBoxContainer.new()
		legend.add_theme_constant_override("separation", 16)
		legend.add_child(_legend_dot(Color(0.98, 0.78, 0.24), "漏剪"))
		legend.add_child(_legend_dot(Color(0.27, 0.67, 1.0), "多剪"))
		side.add_child(legend)
		rings.add_child(side)
	v.add_child(rings)

	# 估价
	var price_card := PanelContainer.new()
	price_card.add_theme_stylebox_override("panel", Ui.card_box(22, Ui.CARD, false, 20))
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	price_card.add_child(ph)
	var pl := Ui.label("估价", Ui.T_BODY, Ui.LABEL2)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pl)
	ph.add_child(Widgets.CoinIcon.new(34))
	var price := Ui.label("0", Ui.T_TITLE3, Ui.LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 700)
	ph.add_child(price)
	v.add_child(price_card)

	# 按钮
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	var again := Ui.gray_button("继续修剪", Ui.T_BODY, "scissors")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.custom_minimum_size = Vector2(0, 96)
	again.pressed.connect(_continue_cut)
	btns.add_child(again)
	_sell = Ui.filled_button("拿去拍卖", Ui.T_HEAD, "gavel")
	_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell.custom_minimum_size = Vector2(0, 96)
	_sell.pressed.connect(_go_auction)
	btns.add_child(_sell)
	v.add_child(btns)

	await get_tree().process_frame
	_place_panel()
	var target_y := _panel.position.y
	_panel.position.y = size.y
	var tw := create_tween()
	tw.tween_property(_panel, "position:y", target_y, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tw.finished
	for i in star_labels.size():
		if i < r["stars"]:
			Ui.pop(star_labels[i], 0.2, 0.5)
			await get_tree().create_timer(0.08).timeout
	for k in ring_list.size():
		ring_list[k].play(k * 0.12)
	Ui.count_to(price, 0, r["value"], 0.9)
	if tutorial:
		tutorial.refresh()


# 对称知识卡
func _fact_card(fold: String) -> Control:
	var m_text := FoldFacts.math(fold)
	if m_text == "":
		return null
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card_box(20, Ui.GOLD_TINT, false, 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var ic := Icon.new("book", Ui.GOLD, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 4)
	h.add_child(tv)
	var ml := Ui.wrap(Ui.label(m_text, Ui.T_FOOT, Color("8a6416"), HORIZONTAL_ALIGNMENT_LEFT, 600), 200.0)
	tv.add_child(ml)
	var ll := Ui.wrap(Ui.label(FoldFacts.lore(fold), Ui.T_FOOT, Ui.LABEL2), 200.0)
	tv.add_child(ll)
	return card


func _legend_dot(c: Color, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(Icon.new("dot", c, 18))
	h.add_child(Ui.label(text, Ui.T_FOOT, Ui.LABEL2))
	return h


func _place_panel() -> void:
	_panel.reset_size()
	_panel.size = Vector2(size.x, _panel.get_combined_minimum_size().y)
	_panel.position = Vector2(0, size.y - _panel.size.y)
	var top: float = main.safe_top + 96.0
	_paper_rect = Rect2(Vector2(24, top), Vector2(size.x - 48, maxf(200.0, _panel.position.y - top - 16.0)))
	if _done:
		var f := PaperView.fit(_paper_rect, model.bounds, 20.0)
		var tw := create_tween().set_parallel()
		tw.tween_property(view, "view_scale", f[0], 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(view, "view_origin", f[1], 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


func hero_rect() -> Rect2:
	var b: Rect2 = model.bounds
	return Rect2(view.view_origin + b.position * view.view_scale, b.size * view.view_scale)


# 导出图纸
func _export_print() -> void:
	var title: String
	if Game.mode == "template":
		title = Game.current_template.get("name", "照样剪纸")
	else:
		title = "%s · %s" % [Game.PAPERS[Game.cut_paper]["name"], Game.FOLDS[Game.cut_fold]["name"]]
	PrintSheet.open(main, model, Game.cut_paper, title)


func _continue_cut() -> void:
	if not _done:
		return
	if tutorial:
		tutorial.skip()
	Game.resume_cut = true
	main.goto("cut", "fade")


func _go_auction() -> void:
	event_happened.emit("sell")
	view.set_overlay(null)
	main.goto("auction", "push", hero_rect())
