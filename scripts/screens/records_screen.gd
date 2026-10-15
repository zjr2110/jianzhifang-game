# 剪纸坊
# records_screen.gd - 记录页
extends Control

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const Works = preload("res://scripts/ui/works.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")

var main = null
var backdrop := "paper"

var _scroll: ScrollContainer
var _tap = null


func _ready() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 32)
	m.add_theme_constant_override("margin_right", 32)
	m.add_theme_constant_override("margin_top", int(main.safe_top + 12))
	m.add_theme_constant_override("margin_bottom", int(main.safe_bottom + 40))
	_scroll.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	m.add_child(v)

	var back := Ui.plain_button("", Ui.T_BODY)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icon.new("back", Ui.ACCENT, 36))
	row.add_child(Ui.label("首页", Ui.T_BODY, Ui.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 500))
	back.add_child(row)
	back.custom_minimum_size = Vector2(130, 64)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(on_back)
	var nav := MarginContainer.new()
	nav.add_theme_constant_override("margin_left", -14)
	nav.add_child(back)
	v.add_child(nav)
	v.add_child(Ui.title("我的记录", Ui.T_TITLE))

	var works: Array = Game.works
	var blocks := []
	var hscrolls := []

	# 概览
	var income := 0
	var stars_sum := 0
	var best_acc := -1.0
	for w in works:
		income += int(w["price"])
		stars_sum += int(w["stars"])
		if w.get("mode", "") == "template":
			best_acc = maxf(best_acc, float(w.get("accuracy", -1.0)))
	var n := works.size()
	var tiles := [
		Widgets.stat_tile("总收入", str(income), "铜钱", Ui.ACCENT),
		Widgets.stat_tile("售出", str(maxi(n, Game.total_sold)), "件"),
		Widgets.stat_tile("最高成交", str(Game.best_price), "铜钱"),
		Widgets.stat_tile("平均成交", str(int(round(float(income) / n))) if n > 0 else "—", "铜钱" if n > 0 else ""),
		Widgets.stat_tile("平均评级", ("%.1f" % (float(stars_sum) / n)) if n > 0 else "—", "星" if n > 0 else ""),
		Widgets.stat_tile("最高吻合度", ("%d" % int(round(best_acc * 100.0))) if best_acc >= 0.0 else "—", "%" if best_acc >= 0.0 else ""),
		Widgets.stat_tile("隐藏买家", str(int(Game.stats.get("hidden", 0))), "次", Ui.GOLD),
		Widgets.stat_tile("累计剪了", str(int(Game.stats.get("cuts", 0))), "刀"),
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for t in tiles:
		grid.add_child(t)
	blocks.append(_section("概览", grid))
	if n == 0 and Game.total_sold > 0:
		blocks.append(Ui.wrap(Ui.label("更早卖出的作品没有保存记录，从现在起的成交都会记在这里。", Ui.T_FOOT, Ui.LABEL2), 300))

	# 近期走势
	if n > 0:
		var recent := []
		for w in works.slice(maxi(0, n - 10)):
			recent.append(int(w["price"]))
		var chart_card := PanelContainer.new()
		chart_card.add_theme_stylebox_override("panel", Ui.card_box(24, Ui.CARD, true, 24))
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 12)
		chart_card.add_child(cv)
		cv.add_child(Ui.label("最近 %d 次成交价" % recent.size(), Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500))
		cv.add_child(Widgets.BarChart.new(recent))
		blocks.append(_section("近期走势", chart_card))

	# 常用
	var fav_rows := []
	var fp := _most(Game.stats.get("papers", {}))
	var ff := _most(Game.stats.get("folds", {}))
	var fs := _most(Game.stats.get("stamps", {}))
	if fp != "" and Game.PAPERS.has(fp):
		fav_rows.append(_fav_row(Widgets.paper_swatch(fp, 56, true), "最常用的纸", Game.PAPERS[fp]["name"]))
	if ff != "" and Game.FOLDS.has(ff):
		fav_rows.append(_fav_row(Widgets.FoldIcon.new(ff, 56), "最常用的折法", Game.FOLDS[ff]["name"]))
	if fs != "" and Game.STAMPS.has(fs):
		fav_rows.append(_fav_row(Widgets.StampIcon.new(fs, 56, Ui.ACCENT), "最常用的纹样", Game.STAMPS[fs]["name"]))
	if not fav_rows.is_empty():
		blocks.append(_section("常用", Widgets.list_group(fav_rows)))

	# 个人纪录
	if n > 0:
		var recs := []
		var best_price := _best(works, func(w): return float(w["price"]))
		recs.append(_record_card("最贵的一件", "%d 铜钱" % best_price["price"], best_price))
		var tpl := works.filter(func(w): return w.get("mode", "") == "template")
		if not tpl.is_empty():
			var ba := _best(tpl, func(w): return float(w.get("accuracy", 0.0)))
			recs.append(_record_card("剪得最准", "吻合 %d%%" % int(round(ba["accuracy"] * 100.0)), ba))
		var bh := _best(works, func(w): return float(w.get("holes", 0)))
		if int(bh.get("holes", 0)) > 0:
			recs.append(_record_card("纹孔最多", "%d 个孔" % bh["holes"], bh))
		var bs := _best(works, func(w): return float(w["stars"]) * 10000.0 + float(w["price"]))
		recs.append(_record_card("评级最高", Ui.stars_text(bs["stars"]), bs))
		var hs := ScrollContainer.new()
		hs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		hs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		hs.custom_minimum_size = Vector2(0, 330)
		var hm := MarginContainer.new()
		hm.add_theme_constant_override("margin_bottom", 20)
		hm.add_theme_constant_override("margin_right", 8)
		hs.add_child(hm)
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 18)
		hm.add_child(hr)
		for r in recs:
			hr.add_child(r)
		hscrolls.append(hs)
		blocks.append(_section("个人纪录", hs))

	# 成交记录
	if n > 0:
		var rows := []
		for i in range(n - 1, -1, -1):
			rows.append(_work_row(works[i]))
		blocks.append(_section("成交记录", Widgets.list_group(rows)))
	else:
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", Ui.card_box(24, Ui.CARD, true, 40))
		var ev := VBoxContainer.new()
		ev.add_theme_constant_override("separation", 12)
		empty.add_child(ev)
		var ic := Icon.new("gavel", Ui.LABEL3, 80)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ev.add_child(ic)
		ev.add_child(Ui.label("还没有成交记录", Ui.T_HEAD, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER, 600))
		ev.add_child(Ui.label("剪一幅作品拿去拍卖，就会记在这里", Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER))
		blocks.append(empty)

	for b in blocks:
		v.add_child(b)
	Ui.appear(blocks, 0.06)
	TouchScroll.attach(_scroll, hscrolls)


func on_back() -> void:
	main.goto("menu", "pop")


func _section(title: String, body: Control) -> VBoxContainer:
	var s := VBoxContainer.new()
	s.add_theme_constant_override("separation", 12)
	s.add_child(Ui.title(title, Ui.T_HEAD))
	s.add_child(body)
	return s


static func _most(d) -> String:
	var best := ""
	var bv := 0
	if typeof(d) != TYPE_DICTIONARY:
		return ""
	for k in d:
		if int(d[k]) > bv:
			bv = int(d[k])
			best = str(k)
	return best


static func _best(list: Array, key: Callable) -> Dictionary:
	var best: Dictionary = list[0]
	for w in list:
		if key.call(w) > key.call(best):
			best = w
	return best


func _fav_row(icon: Control, title: String, value: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	m.add_child(h)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var t := Ui.label(title, Ui.T_BODY, Ui.LABEL)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(Ui.label(value, Ui.T_BODY, Ui.LABEL2))
	return m


func _thumb(w: Dictionary, d: float) -> Control:
	var tex: Texture2D = Game.work_photo(w)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Ui.card_box(16, Color("efe7da"), false, 0))
	box.custom_minimum_size = Vector2(d, d)
	box.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	else:
		var ic := Widgets.FoldIcon.new(w["fold"], d * 0.7)
		ic.tint = Game.PAPERS[w["paper"]]["color"]
		box.add_child(ic)
	return box


func _record_card(title: String, value: String, w: Dictionary) -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", Ui.card_box(24, Ui.CARD, true, 16))
	c.custom_minimum_size = Vector2(230, 0)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	v.add_child(_thumb(w, 198))
	v.add_child(Ui.label(title, Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500))
	v.add_child(Ui.label(value, Ui.T_HEAD, Ui.ACCENT if title == "最贵的一件" else Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 700))
	Ui.press_fx(c, 0.96)
	c.gui_input.connect(_on_tap.bind(w))
	return c


func _work_row(w: Dictionary) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	h.add_child(_thumb(w, 88))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(Ui.label(w["name"], Ui.T_BODY, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600))
	var who: String = w["buyer"] + (" ✦" if w.get("hidden", false) else "")
	v.add_child(Ui.label("%s · %s" % [who, Works.date_text(w["time"])], Ui.T_FOOT, Ui.LABEL2))
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rv)
	rv.add_child(Ui.label("%d" % w["price"], Ui.T_HEAD, Ui.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, 700))
	rv.add_child(Ui.label(Ui.stars_text(w["stars"]), Ui.T_CAP, Ui.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	m.gui_input.connect(_on_tap.bind(w))
	return m


func _on_tap(e: InputEvent, w: Dictionary) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if e.pressed:
		_tap = [e.global_position, _scroll.scroll_vertical]
		return
	if _tap == null:
		return
	var ok: bool = e.global_position.distance_to(_tap[0]) < TouchScroll.SLOP and absi(_scroll.scroll_vertical - _tap[1]) < 4
	_tap = null
	if ok:
		Works.open_work_sheet(main, w)
