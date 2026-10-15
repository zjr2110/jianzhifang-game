# 剪纸坊
# main.gd - 根节点与页面切换
extends Control

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Sheet = preload("res://scripts/ui/sheet.gd")
const WoodShader = preload("res://shaders/wood.gdshader")
const Splash = preload("res://scripts/ui/splash.gd")
const PhotoSheet = preload("res://scripts/ui/photo_sheet.gd")

const SCREENS := {
	"menu": preload("res://scripts/screens/menu_screen.gd"),
	"setup": preload("res://scripts/screens/setup_screen.gd"),
	"templates": preload("res://scripts/screens/template_screen.gd"),
	"records": preload("res://scripts/screens/records_screen.gd"),
	"cut": preload("res://scripts/screens/cut_screen.gd"),
	"result": preload("res://scripts/screens/result_screen.gd"),
	"auction": preload("res://scripts/screens/auction_screen.gd"),
}

# 安全区
var safe_top := 0.0
var safe_bottom := 0.0

var current_name := ""
var _bg: ColorRect
var _holder: Control
var _current: Control = null
var _toast: Control = null
var _dialogs: Array = []
var _last_back_ms := -100000
var _transitioning := false
var splashing := false


func _ready() -> void:
	get_tree().quit_on_go_back = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Ui.make_theme()
	_bg = ColorRect.new()
	_bg.color = Ui.BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	resized.connect(_update_safe)
	get_viewport().size_changed.connect(_update_safe)
	_update_safe()
	# 拖入图片识别
	get_window().files_dropped.connect(_on_files_dropped)
	# 冷启动播放开屏动画
	if Game.skip_splash or OS.get_cmdline_user_args().has("--no-splash"):
		goto("menu", "none")
	else:
		splashing = true
		var sp: Control = Splash.new()
		sp.main = self
		sp.finished.connect(func(): splashing = false)
		add_child(sp)


# 安全区

func _update_safe() -> void:
	var top := 0.0
	var bottom := 0.0
	var win := DisplayServer.window_get_size()
	if OS.has_feature("mobile") and win.y > 0 and size.y > 0:
		var sa := DisplayServer.get_display_safe_area()
		var k := size.y / float(win.y)
		top = float(sa.position.y) * k
		bottom = float(win.y - sa.end.y) * k
		# 安全区兜底
		top = maxf(top, 40.0)
		bottom = maxf(bottom, 16.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--safe-top="):
			top = float(a.get_slice("=", 1))
		elif a.begins_with("--safe-bottom="):
			bottom = float(a.get_slice("=", 1))
	safe_top = top
	safe_bottom = bottom


# 页面切换

func current() -> Control:
	return _current


func _status_scrim() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Ui.BG)
	g.set_color(1, Color(Ui.BG.r, Ui.BG.g, Ui.BG.b, 0.0))
	g.add_point(0.55, Color(Ui.BG.r, Ui.BG.g, Ui.BG.b, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	var t := TextureRect.new()
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.anchor_right = 1.0
	t.offset_bottom = safe_top + 14.0
	return t


func goto(screen_name: String, transition := "push", hero_rect := Rect2()) -> void:
	var hero: TextureRect = null
	if hero_rect.has_area():
		hero = _snapshot(hero_rect)
	var old := _current
	var s: Control = SCREENS[screen_name].new()
	s.set("main", self)
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgnode: Control
	if s.get("backdrop") == "desk":
		bgnode = make_desk()
	else:
		var c := ColorRect.new()
		c.color = Ui.BG
		bgnode = c
	bgnode.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgnode.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(s)
	s.add_child(bgnode)
	s.move_child(bgnode, 0)
	if s.get("backdrop") != "desk":
		s.add_child(_status_scrim())
	_current = s
	current_name = screen_name
	var w := size.x
	if old:
		old.mouse_filter = Control.MOUSE_FILTER_IGNORE
		old.set_process_input(false)
		old.set_process_unhandled_input(false)
		for c in old.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	match transition:
		"push", "pop":
			var pushing := transition == "push"
			if not pushing and old:
				_holder.move_child(old, -1)
			s.position.x = w if pushing else -w * 0.28
			var tw := create_tween().set_parallel()
			tw.tween_property(s, "position:x", 0.0, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			if old:
				var shade := ColorRect.new()
				shade.color = Color(0, 0, 0, 0)
				shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
				(old if pushing else s).add_child(shade)
				if pushing:
					tw.tween_property(old, "position:x", -w * 0.28, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
					tw.tween_property(shade, "color:a", 0.12, 0.42)
				else:
					shade.color.a = 0.12
					tw.tween_property(old, "position:x", w, 0.38).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
					tw.tween_property(shade, "color:a", 0.0, 0.38)
					tw.chain().tween_callback(shade.queue_free)
				tw.chain().tween_callback(old.queue_free)
		"fade":
			s.modulate.a = 0.0
			var tw2 := create_tween()
			tw2.tween_property(s, "modulate:a", 1.0, 0.3)
			if old:
				tw2.tween_callback(old.queue_free)
		_:
			if old:
				old.queue_free()
	if hero:
		_fly_hero(hero, s)


func _snapshot(r: Rect2) -> TextureRect:
	var img := get_viewport().get_texture().get_image()
	var k := Vector2(img.get_width(), img.get_height()) / size
	var pr := Rect2i(Vector2i(r.position * k), Vector2i(r.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if not pr.has_area():
		return null
	var crop := img.get_region(pr)
	var t := TextureRect.new()
	t.texture = ImageTexture.create_from_image(crop)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = r.position
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _fly_hero(hero: TextureRect, target_screen: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(hero):
		return
	var dst := Rect2(size * 0.5 - hero.size * 0.5, hero.size)
	if is_instance_valid(target_screen) and target_screen.has_method("hero_target"):
		var r: Rect2 = target_screen.hero_target()
		if r.has_area():
			var k := minf(r.size.x / hero.size.x, r.size.y / hero.size.y)
			var sz := hero.size * k
			dst = Rect2(r.get_center() - sz * 0.5, sz)
	var tw := create_tween().set_parallel()
	tw.tween_property(hero, "position", dst.position, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hero, "size", dst.size, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(hero, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(hero.queue_free)


static func make_desk() -> ColorRect:
	var d := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = WoodShader
	d.material = mat
	d.resized.connect(func(): mat.set_shader_parameter("rect_size", d.size))
	return d


# 返回键

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		handle_back()


# 返回键处理
func handle_back() -> void:
	if splashing:
		return
	while not _dialogs.is_empty() and not is_instance_valid(_dialogs[_dialogs.size() - 1]):
		_dialogs.pop_back()
	if not _dialogs.is_empty():
		var top: Control = _dialogs[_dialogs.size() - 1]
		if top.get_meta("closable", true):
			_dialogs.pop_back()
			if top.has_method("close"):
				top.close()
			else:
				_close_alert(top)
		return
	if _current and _current.has_method("on_back"):
		_current.on_back()
	else:
		goto("menu", "pop")


func _on_files_dropped(files: PackedStringArray) -> void:
	if splashing or files.is_empty():
		return
	for f in files:
		if f.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp"]:
			PhotoSheet.process_path(self, f)
			return
	toast("请拖入 png / jpg 图片")


func back_to_exit() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_back_ms < 2000:
		get_tree().quit()
		return
	_last_back_ms = now
	toast("再按一次返回键退出游戏", 1.6)


func has_dialog() -> bool:
	for d in _dialogs:
		if is_instance_valid(d):
			return true
	return false


# 顶部提示

func toast(text: String, seconds := 1.8, icon := "") -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.pill_box(Color(1, 1, 1, 0.97), 30, 16, true))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if icon != "":
		h.add_child(Icon.new(icon, Ui.ACCENT, 30))
	var l := Ui.label(text, Ui.T_SUB, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var tw_text: float = Ui.font(500).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.T_SUB).x + 6.0
	var max_w := size.x - 140.0 - (42.0 if icon != "" else 0.0)
	l.custom_minimum_size.x = minf(tw_text, max_w)
	l.size.x = l.custom_minimum_size.x
	h.add_child(l)
	add_child(p)
	_toast = p
	p.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.size = Vector2.ZERO
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.size = Vector2.ZERO
	p.modulate.a = 1.0
	var y := safe_top + 14.0
	p.position = Vector2((size.x - p.size.x) * 0.5, -p.size.y - 20.0)
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(p, "position:y", -p.size.y - 20.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)


# 提示框

func dialog(title: String, text: String, buttons: Array, closable := true) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.08, 0.05, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_meta("closable", closable)
	add_child(shade)
	_dialogs.append(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(size.x - 120.0, 560.0), 0)
	var st := Ui.card_box(30, Color(1, 1, 1, 0.98), true, 0)
	st.shadow_size = 40
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 36)
	body.add_theme_constant_override("margin_top", 34)
	body.add_theme_constant_override("margin_bottom", 30)
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	body.add_child(bv)
	if title != "":
		bv.add_child(Ui.title(title, Ui.T_HEAD, Ui.LABEL, HORIZONTAL_ALIGNMENT_CENTER))
	if text != "":
		var t := Ui.label(text, Ui.T_SUB, Ui.LABEL2, HORIZONTAL_ALIGNMENT_CENTER)
		t.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		t.custom_minimum_size = Vector2(380, 0)
		bv.add_child(t)
	bv.set_meta("body", true)
	shade.set_meta("body", bv)
	var horizontal := buttons.size() == 2
	var row: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for i in buttons.size():
		var b: Array = buttons[i]
		var sep := ColorRect.new()
		sep.color = Ui.SEP
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if horizontal and i > 0:
			sep.custom_minimum_size = Vector2(1, 0)
			row.add_child(sep)
		elif not horizontal:
			sep.custom_minimum_size = Vector2(0, 1)
			row.add_child(sep)
		var ghost: bool = b.size() >= 3 and b[2] == "ghost"
		var btn := Ui.plain_button(b[0], Ui.T_BODY, Ui.ACCENT, 400 if ghost else 700)
		btn.custom_minimum_size = Vector2(0, 92)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			_close_alert(shade)
			if b[1] is Callable and b[1].is_valid():
				b[1].call())
		row.add_child(btn)
	if horizontal:
		var top_sep := ColorRect.new()
		top_sep.color = Ui.SEP
		top_sep.custom_minimum_size = Vector2(0, 1)
		top_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top_sep)
	v.add_child(row)
	if closable:
		shade.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				_close_alert(shade))
	var tw := create_tween().set_parallel()
	tw.tween_property(shade, "color:a", 0.3, 0.22)
	panel.modulate.a = 0.0
	panel.scale = Vector2(1.12, 1.12)
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.pivot_offset = panel.size * 0.5
		var tw2 := panel.create_tween().set_parallel()
		tw2.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw2.tween_property(panel, "modulate:a", 1.0, 0.18)
	return shade


func _close_alert(shade: Control) -> void:
	if not is_instance_valid(shade) or shade.get_meta("closing", false):
		return
	shade.set_meta("closing", true)
	_dialogs.erase(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := shade.create_tween()
	tw.tween_property(shade, "modulate:a", 0.0, 0.18)
	tw.tween_callback(shade.queue_free)


# 底部面板

func sheet(title := "") -> Control:
	var s: Control = Sheet.new(title, safe_bottom)
	add_child(s)
	s.set_meta("closable", true)
	_dialogs.append(s)
	s.closed.connect(func(): _dialogs.erase(s))
	return s
