# 剪纸坊
# auction_screen.gd - 庙会拍卖页
extends Control

signal event_happened(name: String)

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const PaperStage = preload("res://scripts/ui/paper_stage.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
const Sfx = preload("res://scripts/sfx.gd")

const BUYERS := [
	{"name": "王奶奶", "seal": "王", "color": "e8875b", "line": "图个喜庆，贴窗户上好看", "likes": "red"},
	{"name": "李掌柜", "seal": "李", "color": "7c8b9c", "line": "收去铺子里卖，价钱得合适", "likes": "stingy"},
	{"name": "周先生", "seal": "周", "color": "4f7a63", "line": "藏家只看刀工", "likes": "quality"},
	{"name": "陈姑娘", "seal": "陈", "color": "d9668b", "line": "新房要贴窗花，越繁复越好", "likes": "layers"},
	{"name": "外地游客", "seal": "游", "color": "3b82f6", "line": "带回去当伴手礼，金灿灿的最好", "likes": "shiny"},
	{"name": "赵老师", "seal": "赵", "color": "8b6bd1", "line": "给学生当范本，要剪得规整", "likes": "template"},
	{"name": "孙阿姨", "seal": "孙", "color": "e0a100", "line": "店里挂一串拉花，热闹", "likes": "accordion"},
	{"name": "钱老板", "seal": "钱", "color": "b0413e", "line": "看对眼了，钱不是问题", "likes": "whim"},
]
const HIDDEN := [
	{"name": "京城大掌柜", "seal": "京", "line": "且慢！这幅我要了！"},
	{"name": "海外藏家", "seal": "藏", "line": "这件作品，我出高价！"},
	{"name": "博物馆馆长", "seal": "馆", "line": "这幅作品该进展柜，我们收了！"},
]

var main = null
var backdrop := "paper"

var _result := {}
var _buyers := []
var _avatars := []
var _coin
var _frame: PanelContainer
var _stage
var _price: Label
var _price_caption: Label
var _avatar_row: HBoxContainer
var _chat_scroll: ScrollContainer
var _chat: VBoxContainer
var _seal: PanelContainer
var _done_btn: Button
var _cur_price := 0
var _sold_hidden := false
var tutorial = null
var force_hidden := false


class Avatar extends Control:
	var seal := ""
	var color := Color.GRAY
	var gold := false
	var lit := false:
		set(v):
			lit = v
			queue_redraw()

	func _init(s: String, c: Color, d := 88.0, p_gold := false) -> void:
		seal = s
		color = c
		gold = p_gold
		custom_minimum_size = Vector2(d, d)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if lit:
			draw_circle(c, r, Color(color.r, color.g, color.b, 0.25))
		draw_circle(c, r * 0.86, Color("d4a73c") if gold else color)
		if gold:
			draw_arc(c, r * 0.86, 0, TAU, 48, Color(1, 0.92, 0.6), 3.0, true)
		var font := Ui.font(700)
		var fs := int(r * 0.8)
		var ts := font.get_string_size(seal, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.3), seal, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _ready() -> void:
	_result = Game.current_result
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	var m := MarginContainer.new()
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 32)
	m.add_theme_constant_override("margin_right", 32)
	m.add_theme_constant_override("margin_top", int(main.safe_top + 20))
	m.add_theme_constant_override("margin_bottom", int(main.safe_bottom + 24))
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)

	var head := HBoxContainer.new()
	var t := Ui.title("庙会拍卖", Ui.T_TITLE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_coin = Widgets.CoinPill.new(Game.coins)
	_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_coin)
	v.add_child(head)

	# 作品框
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", Ui.card_box(30, Ui.CARD, true, 16))
	v.add_child(_frame)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", Ui.card_box(20, Color("efe7da"), false, 0))
	inner.custom_minimum_size = Vector2(0, 360)
	_frame.add_child(inner)
	_stage = PaperStage.new(false)
	_stage.margin = 26
	inner.add_child(_stage)
	_stage.set_model(Game.current_model, _result.get("paper", "red"))
	_seal = PanelContainer.new()
	var sst := Ui.card_box(10, Color(1, 1, 1, 0.92), true, 0)
	sst.border_color = Ui.ACCENT
	sst.set_border_width_all(6)
	sst.content_margin_left = 34
	sst.content_margin_right = 34
	sst.content_margin_top = 6
	sst.content_margin_bottom = 6
	_seal.add_theme_stylebox_override("panel", sst)
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.add_child(Ui.title("成 交", 80, Ui.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_seal.visible = false
	add_child(_seal)

	# 出价
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	_price_caption = Ui.label("起拍价", Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER, 500)
	pv.add_child(_price_caption)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 12)
	prow.add_child(Widgets.CoinIcon.new(48))
	_price = Ui.title("—", Ui.T_LARGE, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER)
	prow.add_child(_price)
	pv.add_child(prow)
	v.add_child(pv)

	_avatar_row = HBoxContainer.new()
	_avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_avatar_row.add_theme_constant_override("separation", 34)
	v.add_child(_avatar_row)

	# 对话区
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	v.add_child(_chat_scroll)
	_chat = VBoxContainer.new()
	_chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat.add_theme_constant_override("separation", 12)
	_chat_scroll.add_child(_chat)

	_done_btn = Ui.filled_button("收下铜钱", Ui.T_HEAD, "coin")
	_done_btn.custom_minimum_size = Vector2(0, 100)
	_done_btn.visible = false
	_done_btn.pressed.connect(_finish)
	v.add_child(_done_btn)

	_buyers = _pick_buyers()
	for b in _buyers:
		_add_avatar(b, false)

	if Game.tutorial_active:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.start_auction(self)

	await get_tree().process_frame
	await get_tree().process_frame
	if tutorial:
		tutorial.refresh()
		while is_instance_valid(tutorial) and tutorial.visible:
			await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_run()


func hero_target() -> Rect2:
	return Rect2(_stage.global_position - global_position, _stage.size).grow(-26)


func on_back() -> void:
	if _done_btn.visible:
		_finish()
	else:
		main.toast("拍卖进行中，稍等一下")


func rect_of(name: String) -> Rect2:
	if name == "done" and _done_btn and _done_btn.visible:
		return Rect2(_done_btn.global_position - global_position, _done_btn.size).grow(8)
	return Rect2()


func _finish() -> void:
	event_happened.emit("done")
	Game.tutorial_active = false
	Game.save_game()
	main.goto("menu", "fade")


func _add_avatar(b: Dictionary, gold: bool) -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	var av := Avatar.new(b["seal"], Color(b.get("color", "b8860b")), 88, gold)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(av)
	col.add_child(Ui.label(b["name"], Ui.T_FOOT, Ui.GOLD if gold else Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER, 600 if gold else 400))
	_avatar_row.add_child(col)
	_avatars.append(av)


# 对话气泡

func _system(text: String) -> void:
	var l := Ui.label(text, Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size.x = 200
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_push(l)


func _bubble(idx: int, text: String, strong := false) -> void:
	var b: Dictionary = _buyers[idx]
	var gold: bool = b.get("hidden", false)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var av := Avatar.new(b["seal"], Color(b.get("color", "b8860b")), 58, gold)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(av)
	var p := PanelContainer.new()
	var st := Ui.card_box(24, Color("fff4d6") if gold else Ui.CARD, true, 18)
	st.corner_radius_top_left = 6
	st.shadow_size = 8
	p.add_theme_stylebox_override("panel", st)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	p.add_child(bv)
	bv.add_child(Ui.label(b["name"], Ui.T_CAP, Ui.GOLD if gold else Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 600))
	var tl := Ui.label(text, Ui.T_BODY, Ui.ACCENT if strong else Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 700 if strong else 400)
	tl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var tf: Font = tl.get_theme_font("font")
	var tw: float = tf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tl.get_theme_font_size("font_size")).x
	tl.custom_minimum_size.x = clampf(tw + 6.0, 60.0, 420.0)
	bv.add_child(tl)
	h.add_child(p)
	_push(h)


func _push(c: Control) -> void:
	_chat.add_child(c)
	c.modulate.a = 0.0
	c.scale = Vector2(0.85, 0.85)
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	c.pivot_offset = Vector2(0, c.size.y)
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	var sb := _chat_scroll.get_v_scroll_bar()
	create_tween().tween_property(_chat_scroll, "scroll_vertical", int(sb.max_value), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_price(p: int, caption := "当前出价") -> void:
	Ui.count_to(_price, _cur_price, p, 0.35)
	_cur_price = p
	_price_caption.text = caption
	_price.pivot_offset = _price.size * 0.5
	_price.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(_price, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _light(idx: int) -> void:
	for i in _avatars.size():
		var av: Avatar = _avatars[i]
		av.lit = i == idx
		av.pivot_offset = av.size * 0.5
		create_tween().tween_property(av, "scale", Vector2(1.12, 1.12) if i == idx else Vector2.ONE, 0.3).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


# 买家与出价

func _pref(likes: String) -> float:
	var r := _result
	var paper: String = r.get("paper", "red")
	var fold: String = r.get("fold", "eight")
	match likes:
		"red":
			return 1.15 if paper in ["red", "peach", "wannian", "gold", "glossy"] else 0.92
		"stingy":
			return 0.86
		"quality":
			return 0.72 + 0.12 * r["stars"]
		"layers":
			return 1.25 if fold in ["twelve", "sixteen", "five", "eight"] else 0.92
		"shiny":
			return 1.35 if paper in ["gold", "foil", "glossy"] else 0.9
		"template":
			return 0.8 + 0.5 * r.get("accuracy", 0.4) if r.get("mode", "free") == "template" else 0.95
		"accordion":
			return 1.3 if fold == "accordion" else 0.95
		"whim":
			return randf_range(0.8, 1.45)
	return 1.0


func _pick_buyers() -> Array:
	var pool := BUYERS.duplicate()
	pool.shuffle()
	var value: float = _result["value"]
	var out := []
	for i in 3:
		var b: Dictionary = pool[i].duplicate()
		b["max"] = value * _pref(b["likes"]) * randf_range(0.82, 1.25)
		out.append(b)
	return out


static func _eager(max_price: float, price: int) -> float:
	return clampf(0.3 + 0.6 * (max_price - price) / maxf(1.0, max_price), 0.12, 0.85)


func _bid(idx: int, price: int, text := "") -> void:
	Sfx.play("tick", -2.0, randf_range(0.9, 1.1))
	_light(idx)
	_bubble(idx, text if text != "" else "我出 %d！" % price, true)
	_set_price(price)


func _run() -> void:
	var value: float = _result["value"]
	var step := maxi(2, int(round(value * 0.07)))
	var price := maxi(5, int(round(value * 0.5)))
	var top_max := 0.0
	for b in _buyers:
		top_max = maxf(top_max, b["max"])
	price = mini(price, maxi(5, int(top_max * 0.85)))

	var what: String
	if _result.get("mode", "free") == "template":
		what = "照样剪「%s」" % _result.get("template", "")
	else:
		what = "%s · %s" % [Game.PAPERS[_result["paper"]]["name"], Game.FOLDS[_result["fold"]]["name"]]
	_system("今日拍品：%s，%s" % [what, Ui.stars_text(_result["stars"])])
	_set_price(price, "起拍价")
	await _wait(1.1)
	for i in _buyers.size():
		_light(i)
		_bubble(i, _buyers[i]["line"])
		await _wait(0.85)
	_light(-1)

	var opening := []
	for i in _buyers.size():
		if _buyers[i]["max"] >= price:
			opening.append(i)
	var leader: int = opening.pick_random() if not opening.is_empty() else 0
	_bid(leader, price)
	await _wait(0.8)

	var resets := 0
	while true:
		var quiet := false
		while not quiet:
			var order := range(_buyers.size())
			order.shuffle()
			quiet = true
			for i in order:
				if i == leader or _buyers[i]["max"] < price + step:
					continue
				if randf() < _eager(_buyers[i]["max"], price):
					price += step * (2 if randf() < 0.25 and _buyers[i]["max"] >= price + step * 2 else 1)
					leader = i
					_bid(i, price)
					quiet = false
					await _wait(0.75)
					break
		var interrupted := false
		for beat in ["一次", "两次"]:
			_system("还有没有更高的？……%s……" % beat)
			await _wait(1.15)
			if resets >= 3:
				continue
			var late := []
			for i in _buyers.size():
				if i != leader and _buyers[i]["max"] >= price + step:
					late.append(i)
			late.shuffle()
			for i in late:
				if randf() < 0.32 * _eager(_buyers[i]["max"], price) / 0.6:
					price += step
					leader = i
					_bid(i, price, "且慢！我加到 %d！" % price)
					resets += 1
					interrupted = true
					await _wait(1.0)
					break
			if interrupted:
				break
		if not interrupted:
			break

	if force_hidden or randf() < _hidden_chance():
		await _hidden_entrance()
		price = int(round(price * randf_range(1.5, 3.0)))
		leader = _buyers.size() - 1
		_bid(leader, price, "%s 出价 %d！" % [_buyers[leader]["line"], price])
		_sold_hidden = true
		await _wait(1.6)
		_system("……一次……两次……")
		await _wait(1.2)

	_system("成交！恭喜 %s 以 %d 铜钱拍得" % [_buyers[leader]["name"], price])
	_light(leader)
	_price_caption.text = "成交价"
	_price.add_theme_color_override("font_color", Ui.ACCENT)
	await _save_work(price, _buyers[leader]["name"])

	# 盖章
	await get_tree().process_frame
	_seal.reset_size()
	var fr := Rect2(_frame.global_position - global_position, _frame.size)
	_seal.position = fr.get_center() - _seal.size * 0.5
	_seal.pivot_offset = _seal.size * 0.5
	_seal.visible = true
	_seal.scale = Vector2(2.4, 2.4)
	_seal.modulate.a = 0.0
	_seal.rotation = -0.14
	var tw := create_tween().set_parallel()
	tw.tween_property(_seal, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_seal, "modulate:a", 0.95, 0.15)
	Sfx.play("gavel")
	await tw.finished
	_shake(_frame)
	Sfx.play("coin", -3.0)
	_coin.set_value(Game.coins)
	_done_btn.visible = true
	Ui.pop(_done_btn, 0.8, 0.5)
	event_happened.emit("sold")


# 成交保存
func _save_work(price: int, buyer: String) -> void:
	await RenderingServer.frame_post_draw
	var photo: Image = null
	var img := get_viewport().get_texture().get_image()
	if img:
		var k := Vector2(img.get_width(), img.get_height()) / get_viewport_rect().size
		var r := Rect2(_stage.global_position, _stage.size)
		var side := minf(r.size.x, r.size.y)
		var sq := Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
		var pr := Rect2i(Vector2i(sq.position * k), Vector2i(sq.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if pr.has_area():
			photo = img.get_region(pr)
			photo.resize(320, 320, Image.INTERPOLATE_LANCZOS)
	Game.record_sale(price)
	Game.record_work(_result, Game.current_model, price, buyer, _sold_hidden, photo)


func _shake(c: Control) -> void:
	var x0 := c.position.x
	var tw := create_tween()
	for d in [10.0, -8.0, 5.0, -3.0, 0.0]:
		tw.tween_property(c, "position:x", x0 + d, 0.05)


func _hidden_chance() -> float:
	var c := 0.05 + 0.03 * (int(_result["stars"]) - 3)
	var paper: Dictionary = Game.PAPERS.get(_result.get("paper", "red"), {})
	var fold: Dictionary = Game.FOLDS.get(_result.get("fold", "eight"), {})
	if float(paper.get("value", 1.0)) >= 1.6 or float(fold.get("value", 1.0)) >= 1.3:
		c += 0.04
	if _result.get("accuracy", 0.0) >= 0.9:
		c += 0.03
	return clampf(c, 0.03, 0.2)


# 隐藏买家登场
func _hidden_entrance() -> void:
	Sfx.play("whoosh", -3.0)
	var h: Dictionary = HIDDEN.pick_random().duplicate()
	h["max"] = INF
	h["hidden"] = true
	h["color"] = "d4a73c"
	_buyers.append(h)
	_system("……")
	await _wait(0.5)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card_box(30, Color("fff4d6"), true, 24))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	row.add_child(Avatar.new(h["seal"], Color("d4a73c"), 96, true))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.add_child(Ui.label("隐藏买家现身", Ui.T_FOOT, Ui.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 700))
	cv.add_child(Ui.title(h["name"], Ui.T_TITLE3))
	row.add_child(cv)
	add_child(card)
	await get_tree().process_frame
	card.reset_size()
	card.size.x = size.x - 64.0
	var y: float = main.safe_top + 20.0
	card.position = Vector2(32, -card.size.y - 20.0)
	var tw := create_tween()
	tw.tween_property(card, "position:y", y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(card, "position:y", -card.size.y - 20.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)
	await _wait(0.6)
	_add_avatar(h, true)
	var av: Control = _avatars[_avatars.size() - 1]
	Ui.pop(av.get_parent(), 0.3, 0.5)
	await _wait(1.2)
