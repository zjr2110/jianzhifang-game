# 剪纸坊
# ledger_sheet.gd - 铜钱明细面板
extends RefCounted

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const Works = preload("res://scripts/ui/works.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")

const KIND_ICON := {"sale": ["gavel", Color("c8102e")], "buy": ["paper", Color("c9962b")], "init": ["coin", Color("8a8a8e")]}


static func open(main) -> void:
	var sh = main.sheet("铜钱明细")
	var c: VBoxContainer = sh.content

	# 余额
	var income := 0
	var spend := 0
	for e in Game.ledger:
		if int(e["amount"]) >= 0:
			income += int(e["amount"])
		else:
			spend -= int(e["amount"])
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card_box(24, Ui.CARD, false, 26))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	cv.add_child(Ui.label("当前余额", Ui.T_FOOT, Ui.LABEL2))
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	bh.add_child(Widgets.CoinIcon.new(46))
	bh.add_child(Ui.label(str(Game.coins), Ui.T_LARGE, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 800))
	cv.add_child(bh)
	cv.add_child(Ui.label("累计收入 %d · 累计支出 %d · 共 %d 笔" % [income, spend, Game.ledger.size()], Ui.T_FOOT, Ui.LABEL2))
	c.add_child(card)

	if Game.ledger.is_empty():
		var empty := Ui.label("还没有收支。剪一幅作品拿去拍卖，就会记在这里。", Ui.T_SUB, Ui.LABEL2)
		c.add_child(Ui.wrap(empty, 300))
		sh.open()
		return

	# 明细列表
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var rows_h := minf(Game.ledger.size() * 113.0, main.size.y * 0.52)
	sc.custom_minimum_size = Vector2(0, rows_h)
	var list := PanelContainer.new()
	list.add_theme_stylebox_override("panel", Ui.card_box(22, Ui.CARD, false, 0))
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	list.add_child(lv)
	var n: int = Game.ledger.size()
	for i in range(n - 1, -1, -1):
		if i < n - 1:
			var sep := ColorRect.new()
			sep.color = Ui.SEP
			sep.custom_minimum_size = Vector2(0, 1)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lv.add_child(sep)
		lv.add_child(_row(main, sh, Game.ledger[i]))
	c.add_child(sc)
	TouchScroll.attach(sc)
	sh.open()


static func _row(main, sh, e: Dictionary) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 18)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var kind: String = e.get("kind", "init")
	var ki: Array = KIND_ICON.get(kind, KIND_ICON["init"])
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", Ui.card_box(16, Color(ki[1], 0.12), false, 0))
	badge.custom_minimum_size = Vector2(64, 64)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icon.new(ki[0], ki[1], 38)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(ic)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var title := Ui.label(str(e.get("title", "")), Ui.T_BODY, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 500)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title.custom_minimum_size = Vector2(120, 0)
	v.add_child(title)
	v.add_child(Ui.label(Works.date_text(int(e["t"])), Ui.T_FOOT, Ui.LABEL2))
	var amt: int = int(e["amount"])
	var al := Ui.label(("+%d" % amt) if amt >= 0 else str(amt), Ui.T_HEAD, Ui.ACCENT if amt >= 0 else Ui.LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 700)
	al.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(al)
	h.add_child(Icon.new("chevron", Ui.LABEL3, 28))
	var tap := {}
	m.gui_input.connect(func(ev):
		if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		if ev.pressed:
			tap["p"] = ev.global_position
		elif tap.has("p"):
			var ok: bool = ev.global_position.distance_to(tap["p"]) < TouchScroll.SLOP
			tap.erase("p")
			if ok:
				_open_entry(main, e))
	Ui.press_fx(m, 0.98)
	return m


static func _open_entry(main, e: Dictionary) -> void:
	var kind: String = e.get("kind", "")
	if kind == "sale" and e.has("work"):
		var w := Game.work_by_id(int(e["work"]))
		if not w.is_empty():
			Works.open_work_sheet(main, w)
			return
	var sh = main.sheet("收支详情")
	var c: VBoxContainer = sh.content
	var amt: int = int(e["amount"])
	var big := Ui.label(("+%d 铜钱" % amt) if amt >= 0 else ("%d 铜钱" % amt), Ui.T_TITLE, Ui.ACCENT if amt >= 0 else Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 800)
	c.add_child(big)
	var rows := []
	match kind:
		"sale":
			rows.append(["类型", "拍卖成交"])
			rows.append(["作品", str(e.get("title", "")).trim_prefix("拍卖成交 · ")])
			if e.get("buyer", "") != "":
				rows.append(["买家", str(e["buyer"])])
			rows.append(["说明", "作品记录已不在作品集中"])
		"buy":
			var id: String = str(e.get("item", ""))
			rows.append(["类型", "解锁"])
			rows.append(["内容", Game.item_name(id)])
			rows.append(["类别", Game.item_kind(id)])
		_:
			rows.append(["类型", "更早的收支"])
			rows.append(["说明", "开始记明细之前的铜钱变动合计"])
	rows.append(["时间", Works.date_text(int(e["t"]))])
	c.add_child(Works.info_group(rows))
	sh.open()
