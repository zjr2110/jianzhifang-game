# 剪纸坊
# setup_screen.gd - 自由创作选纸页
extends Control

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const PaperModel = preload("res://scripts/paper_model.gd")
const PaperStage = preload("res://scripts/ui/paper_stage.gd")
const Stamps = preload("res://scripts/stamps.gd")

var main = null
var backdrop := "paper"

static var _demo_cache := {}

var _scroll: ScrollContainer
var _stage_box: PanelContainer
var _stage
var _name: Label
var _desc: Label
var _price: Label
var _paper_row: HBoxContainer
var _fold_row: HBoxContainer
var _paper_scroll: ScrollContainer
var _fold_scroll: ScrollContainer
var _tap = null


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_top", int(main.safe_top + 12))
	m.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	m.add_child(v)

	var nav := _pad(_back_button(), 18, 32)
	v.add_child(nav)
	v.add_child(_pad(Ui.title("自由创作", Ui.T_TITLE), 32, 32))

	# 预览
	_stage_box = PanelContainer.new()
	_stage_box.add_theme_stylebox_override("panel", Ui.card_box(32, Ui.CARD, true, 0))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	_stage_box.add_child(sv)
	var holder := PanelContainer.new()
	var hst := Ui.card_box(32, Color("efe7da"), false, 0)
	hst.corner_radius_bottom_left = 0
	hst.corner_radius_bottom_right = 0
	holder.add_theme_stylebox_override("panel", hst)
	holder.custom_minimum_size = Vector2(0, 400)
	sv.add_child(holder)
	_stage = PaperStage.new(true)
	_stage.margin = 40
	holder.add_child(_stage)
	var cap := MarginContainer.new()
	for side in ["left", "right"]:
		cap.add_theme_constant_override("margin_" + side, 26)
	cap.add_theme_constant_override("margin_top", 18)
	cap.add_theme_constant_override("margin_bottom", 20)
	sv.add_child(cap)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cap.add_child(cv)
	_name = Ui.title("", Ui.T_HEAD)
	cv.add_child(_name)
	_desc = Ui.wrap(Ui.label("", Ui.T_FOOT, Ui.LABEL2), 200)
	cv.add_child(_desc)
	_price = Ui.label("", Ui.T_CAP, Ui.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 500)
	cv.add_child(_price)
	v.add_child(_pad(_stage_box, 32, 32))

	v.add_child(_pad(Ui.title("纸张", Ui.T_HEAD), 32, 32))
	_paper_scroll = _hscroll()
	_paper_row = _paper_scroll.get_child(0).get_child(0)
	v.add_child(_paper_scroll)
	v.add_child(_pad(Ui.title("折法", Ui.T_HEAD), 32, 32))
	_fold_scroll = _hscroll()
	_fold_row = _fold_scroll.get_child(0).get_child(0)
	v.add_child(_fold_scroll)

	var bottom := PanelContainer.new()
	var bst := StyleBoxFlat.new()
	bst.bg_color = Ui.BG
	bottom.add_theme_stylebox_override("panel", bst)
	var bm := _pad(null, 32, 32)
	bm.add_theme_constant_override("margin_top", 12)
	bm.add_theme_constant_override("margin_bottom", int(main.safe_bottom + 24))
	bottom.add_child(bm)
	var go := Ui.filled_button("开始剪纸", Ui.T_HEAD, "scissors")
	go.custom_minimum_size = Vector2(0, 100)
	go.pressed.connect(_on_start)
	bm.add_child(go)
	root.add_child(bottom)

	_build_rows()
	_update_preview(false)
	Ui.appear(v.get_children(), 0.05)


func on_back() -> void:
	main.goto("menu", "pop")


func hero_target() -> Rect2:
	return Rect2()


func _back_button() -> Button:
	var b := Ui.plain_button("首页", Ui.T_BODY, Ui.ACCENT, 500)
	b.text = ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(Icon.new("back", Ui.ACCENT, 36))
	row.add_child(Ui.label("首页", Ui.T_BODY, Ui.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 500))
	b.add_child(row)
	b.custom_minimum_size = Vector2(130, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(on_back)
	return b


static func _pad(c: Control, l: int, r: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_right", r)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if c:
		m.add_child(c)
	return m


func _hscroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	s.custom_minimum_size = Vector2(0, 230)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 32)
	m.add_theme_constant_override("margin_right", 32)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 18)
	s.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	m.add_child(h)
	return s


func _build_rows() -> void:
	for c in _paper_row.get_children():
		c.queue_free()
	for c in _fold_row.get_children():
		c.queue_free()
	for id in Game.PAPER_ORDER:
		_paper_row.add_child(_paper_item(id))
	for id in Game.FOLD_ORDER:
		_fold_row.add_child(_fold_item(id))


func _price_short(id: String) -> String:
	var p := Game.price_of(id)
	if p == 0:
		return "基础款"
	if Game.TEST_MODE:
		return "原价 %d" % p
	return "已拥有" if Game.owned.get(id, false) else "%d 铜钱" % p


func _paper_item(id: String) -> Control:
	var sel := Game.selected_paper == id
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(118, 0)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var ring := PanelContainer.new()
	var rst := Ui.card_box(60, Color(0, 0, 0, 0), false, 6)
	if sel:
		rst.border_color = Ui.ACCENT
		rst.set_border_width_all(4)
	ring.add_theme_stylebox_override("panel", rst)
	ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sw := Widgets.paper_swatch(id, 96, true)
	ring.add_child(sw)
	v.add_child(ring)
	v.add_child(Ui.label(Game.PAPERS[id]["name"], Ui.T_FOOT, Ui.LABEL if sel else Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER, 600 if sel else 400))
	v.add_child(Ui.label(_price_short(id), Ui.T_CAP, Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER))
	Ui.press_fx(v, 0.93)
	v.gui_input.connect(_on_item.bind(id, true, _paper_scroll))
	return v


func _fold_item(id: String) -> Control:
	var sel := Game.selected_fold == id
	var c := PanelContainer.new()
	var st := Ui.card_box(24, Ui.CARD, true, 14)
	if sel:
		st.border_color = Ui.ACCENT
		st.set_border_width_all(4)
	c.add_theme_stylebox_override("panel", st)
	c.custom_minimum_size = Vector2(150, 0)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var icon := Widgets.FoldIcon.new(id, 84)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	v.add_child(Ui.label(Game.FOLDS[id]["name"], Ui.T_FOOT, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER, 600 if sel else 500))
	v.add_child(Ui.label(_price_short(id), Ui.T_CAP, Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER))
	Ui.press_fx(c, 0.94)
	c.gui_input.connect(_on_item.bind(id, false, _fold_scroll))
	return c


func _on_item(e: InputEvent, id: String, is_paper: bool, hs: ScrollContainer) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if e.pressed:
		_tap = [e.global_position, hs.scroll_horizontal, _scroll.scroll_vertical]
		return
	if _tap == null:
		return
	var ok: bool = e.global_position.distance_to(_tap[0]) < 14.0 and absi(hs.scroll_horizontal - _tap[1]) < 4 \
			and absi(_scroll.scroll_vertical - _tap[2]) < 4
	_tap = null
	if not ok:
		return
	if not Game.is_owned(id):
		if Game.buy(id):
			main.toast("解锁了「%s」" % Game.item_info(id)["name"], 1.6, "check")
		else:
			main.toast("铜钱不够，还差 %d 铜钱" % (Game.price_of(id) - Game.coins))
			return
	if is_paper:
		if Game.selected_paper == id:
			return
		Game.selected_paper = id
	else:
		if Game.selected_fold == id:
			return
		Game.selected_fold = id
	Game.save_game()
	var keep_p := _paper_scroll.scroll_horizontal
	var keep_f := _fold_scroll.scroll_horizontal
	_build_rows()
	await get_tree().process_frame
	_paper_scroll.scroll_horizontal = keep_p
	_fold_scroll.scroll_horizontal = keep_f
	_update_preview(true)


func _update_preview(animate: bool) -> void:
	_stage.set_model(demo_model(Game.selected_fold), Game.selected_paper)
	var p: Dictionary = Game.PAPERS[Game.selected_paper]
	var f: Dictionary = Game.FOLDS[Game.selected_fold]
	_name.text = "%s · %s" % [p["name"], f["name"]]
	_desc.text = "%s；%s" % [p["desc"], f["desc"]]
	var parts := []
	for id in [Game.selected_paper, Game.selected_fold]:
		if Game.price_of(id) > 0:
			parts.append(Game.price_text(id))
	_price.text = "  ".join(parts) if not parts.is_empty() else "基础款"
	if animate:
		Ui.pop(_stage, 0.85, 0.5)


# 示范作品
static func demo_model(fold: String):
	if _demo_cache.has(fold):
		return _demo_cache[fold]
	var m = PaperModel.new(fold)
	var w: PackedVector2Array = m.wedge
	var wb: Rect2 = m.wedge_bounds
	var sz := minf(wb.size.x, wb.size.y)
	var c := Vector2.ZERO
	for p in w:
		c += p
	c /= w.size()
	var far := w[1] if w.size() >= 3 else wb.end
	var a := (far - c).angle()
	var polys := []
	polys.append_array(Stamps.placed("hole", c, 0.0, sz * 0.2))
	polys.append_array(Stamps.placed("drop", c + (far - c) * 0.55, a + PI, sz * 0.28))
	polys.append_array(Stamps.placed("moon", c + (w[0] - c) * 0.55, a, sz * 0.2))
	var e1: Vector2 = w[1]
	var e2: Vector2 = w[2] if w.size() > 2 else w[0]
	var mid := (e1 + e2) * 0.5
	polys.append_array(Stamps.placed("saw", mid + (c - mid).normalized() * sz * 0.08, (e2 - e1).angle(), sz * 0.4))
	m.cut_region(polys, "demo")
	_demo_cache[fold] = m
	return m


func _on_start() -> void:
	Game.mode = "free"
	Game.current_template = {}
	Game.cut_paper = Game.selected_paper
	Game.cut_fold = Game.selected_fold
	var r := Rect2(_stage_box.global_position - global_position, Vector2(_stage_box.size.x, 400))
	main.goto("cut", "push", r)
