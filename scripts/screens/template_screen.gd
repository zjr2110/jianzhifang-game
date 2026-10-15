# 剪纸坊
# template_screen.gd - 照样剪纸样稿页
extends Control

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const Templates = preload("res://scripts/templates.gd")
const PhotoSheet = preload("res://scripts/ui/photo_sheet.gd")

const FILTERS := [["全部", 1, 5], ["生肖", 1, 5, "zodiac_"], ["入门", 1, 2], ["进阶", 3, 3], ["挑战", 4, 5]]

var main = null
var backdrop := "paper"

var _scroll: ScrollContainer
var _grid: GridContainer
var _chips: HBoxContainer
var _filter := 0
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

	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tv.add_child(Ui.title("照样剪纸", Ui.T_TITLE))
	tv.add_child(Ui.label("沿虚线剪下去，剪得越准，作品越值钱", Ui.T_SUB, Ui.LABEL2))
	v.add_child(tv)

	v.add_child(_photo_card())

	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 12)
	v.add_child(_chips)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 20)
	v.add_child(_grid)
	_build_chips()
	_build_grid()


# 照片变样稿入口
func _photo_card() -> PanelContainer:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", Ui.card_box(26, Ui.CARD, true, 22))
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(h)
	var circle := PanelContainer.new()
	circle.add_theme_stylebox_override("panel", Ui.card_box(40, Ui.ACCENT_TINT, false, 16))
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(Icon.new("image", Ui.ACCENT, 46))
	h.add_child(circle)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(Ui.title("照片变样稿", Ui.T_HEAD))
	tv.add_child(Ui.wrap(Ui.label("拍一张剪纸，自动识别折法，变成能剪的关卡", Ui.T_FOOT, Ui.LABEL2), 300))
	h.add_child(tv)
	var ar := Icon.new("arrow_right", Ui.LABEL3, 30)
	ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ar)
	Ui.press_fx(c, 0.97)
	c.gui_input.connect(func(e):
		if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
			return
		if e.pressed:
			_tap = [e.global_position, _scroll.scroll_vertical]
		elif _tap != null:
			var ok: bool = e.global_position.distance_to(_tap[0]) < 14.0 and absi(_scroll.scroll_vertical - _tap[1]) < 4
			_tap = null
			if ok:
				PhotoSheet.open_picker(main))
	return c


# 改名与删除
func _edit_user(t: Dictionary) -> void:
	var sh = main.sheet("样稿设置")
	var c: VBoxContainer = sh.content
	c.add_child(Ui.label("名字", Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500))
	var ed := Ui.line_edit(t["name"], "给这张样稿起个名字")
	c.add_child(ed)
	var save := Ui.filled_button("保存名字", Ui.T_HEAD, "pencil")
	save.custom_minimum_size = Vector2(0, 92)
	save.pressed.connect(func():
		var nm := ed.text.strip_edges()
		if nm == "":
			main.toast("名字不能为空")
			return
		Templates.rename_user(t["id"], nm)
		sh.close()
		_build_grid()
		main.toast("已改名为「%s」" % nm, 1.4, "check"))
	c.add_child(save)
	var del := Ui.tinted_button("删除这张样稿", Ui.T_BODY, "trash")
	del.custom_minimum_size = Vector2(0, 88)
	del.pressed.connect(func():
		sh.close()
		main.dialog("删除样稿？", "「%s」会从样稿列表里删除，已经卖出的作品不受影响。" % t["name"], [
			["删除", func():
				Templates.delete_user(t["id"])
				_build_grid()
				main.toast("已删除", 1.2, "check")],
			["取消", Callable(), "ghost"],
		]))
	c.add_child(del)
	sh.open()


func on_back() -> void:
	main.goto("menu", "pop")


func _build_chips() -> void:
	for c in _chips.get_children():
		c.queue_free()
	for i in FILTERS.size():
		var b: Button = Ui.filled_button(FILTERS[i][0], Ui.T_SUB) if i == _filter else Ui.gray_button(FILTERS[i][0], Ui.T_SUB)
		b.custom_minimum_size = Vector2(100, 60)
		b.pressed.connect(func():
			if _filter != i:
				_filter = i
				_build_chips()
				_build_grid())
		_chips.add_child(b)


func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var f: Array = FILTERS[_filter]
	var cards := []
	for t in Templates.all():
		if t["difficulty"] < f[1] or t["difficulty"] > f[2]:
			continue
		if f.size() > 3 and not str(t["id"]).begins_with(f[3]):
			continue
		var c := _card(t)
		_grid.add_child(c)
		cards.append(c)
	if cards.is_empty():
		_grid.add_child(Ui.label("这一档还没有样稿", Ui.T_BODY, Ui.LABEL2))
	Ui.appear(cards, 0.04)


func _card(t: Dictionary) -> PanelContainer:
	var id := "tpl:" + str(t["id"])
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_stylebox_override("panel", Ui.card_box(26, Ui.CARD, true, 0))
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var thumb_bg := PanelContainer.new()
	var st := Ui.card_box(26, Color("efe7da"), false, 18)
	st.corner_radius_bottom_left = 0
	st.corner_radius_bottom_right = 0
	thumb_bg.add_theme_stylebox_override("panel", st)
	thumb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Widgets.template_thumb(t, 220)
	th.name = "Thumb"
	thumb_bg.add_child(th)
	if t.get("user", false):
		var more := Ui.icon_button("more", 56, Ui.LABEL, Color(1, 1, 1, 0.9))
		more.size_flags_horizontal = Control.SIZE_SHRINK_END
		more.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		more.pressed.connect(_edit_user.bind(t))
		thumb_bg.add_child(more)
	v.add_child(thumb_bg)
	var info := MarginContainer.new()
	for side in ["left", "right"]:
		info.add_theme_constant_override("margin_" + side, 20)
	info.add_theme_constant_override("margin_top", 14)
	info.add_theme_constant_override("margin_bottom", 18)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 2)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(iv)
	iv.add_child(Ui.title(t["name"], Ui.T_HEAD))
	iv.add_child(Ui.label("%s · %s" % [Game.FOLDS[t["fold"]]["name"], Ui.stars_text(t["difficulty"])], Ui.T_FOOT, Ui.LABEL2))
	var p := Game.price_of(id)
	var ptxt := "基础款" if p == 0 else ("原价 %d 铜钱" % p if Game.TEST_MODE else Game.price_text(id))
	iv.add_child(Ui.label(ptxt, Ui.T_CAP, Ui.LABEL3))
	Ui.press_fx(c, 0.96)
	c.gui_input.connect(_on_card.bind(t, thumb_bg))
	return c


func _on_card(e: InputEvent, t: Dictionary, thumb: Control) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if e.pressed:
		_tap = [e.global_position, _scroll.scroll_vertical]
		return
	if _tap == null:
		return
	var ok: bool = e.global_position.distance_to(_tap[0]) < 14.0 and absi(_scroll.scroll_vertical - _tap[1]) < 4
	_tap = null
	if not ok:
		return
	var id := "tpl:" + str(t["id"])
	if not Game.is_owned(id):
		if Game.buy(id):
			main.toast("解锁了样稿「%s」" % t["name"], 1.6, "check")
		else:
			main.toast("铜钱不够，还差 %d 铜钱" % (Game.price_of(id) - Game.coins))
			return
	Game.mode = "template"
	Game.current_template = t
	Game.cut_paper = t["paper"] if Game.is_owned(t["paper"]) else "red"
	Game.cut_fold = t["fold"]
	var r := Rect2(thumb.global_position - global_position, thumb.size).grow(-12)
	main.goto("cut", "push", r)
