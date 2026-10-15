# 剪纸坊
# photo_sheet.gd - 照片变样稿界面
extends RefCounted

const Ui = preload("res://scripts/ui_style.gd")
const Icon = preload("res://scripts/ui/icon.gd")
const Widgets = preload("res://scripts/widgets.gd")
const PaperStage = preload("res://scripts/ui/paper_stage.gd")
const PaperModel = preload("res://scripts/paper_model.gd")
const Templates = preload("res://scripts/templates.gd")
const PhotoTemplate = preload("res://scripts/photo_template.gd")
const Sfx = preload("res://scripts/sfx.gd")
const FoldFacts = preload("res://scripts/fold_facts.gd")
const PhotoProcess = preload("res://scripts/ui/photo_process.gd")

const SAMPLES := ["res://assets/samples/sample_flower.jpg", "res://assets/samples/sample_snow.jpg",
		"res://assets/samples/sample_plum.jpg"]

static var _busy := false


# 选图面板
static func open_picker(main) -> void:
	var sh = main.sheet("照片变样稿")
	var c: VBoxContainer = sh.content
	c.add_child(Ui.wrap(Ui.label("选一张剪纸照片，程序会分析它的对称性，判断是用哪种折法剪的，再变成能照着剪的样稿。背景越干净越准。", Ui.T_SUB, Ui.LABEL2), 300))
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var pick := Ui.filled_button("从相册 / 文件里选一张", Ui.T_HEAD, "image")
		pick.custom_minimum_size = Vector2(0, 96)
		pick.pressed.connect(func():
			sh.close()
			_native_pick(main))
		c.add_child(pick)
	c.add_child(Ui.label("或者用示例照片试试", Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for path in SAMPLES:
		var tex: Texture2D = load(path)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Ui.card_box(20, Ui.CARD, true, 0))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size = Vector2(0, 200)
		box.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
		Ui.press_fx(box, 0.95)
		box.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
				sh.close()
				process_image(main, tex.get_image()))
		row.add_child(box)
	c.add_child(row)
	if not OS.has_feature("mobile"):
		c.add_child(Ui.label("电脑上也可以把图片直接拖进游戏窗口", Ui.T_CAP, Ui.LABEL3, HORIZONTAL_ALIGNMENT_CENTER))
	sh.open()


static func _native_pick(main) -> void:
	var cb := func(ok: bool, paths: PackedStringArray, _idx: int):
		if ok and paths.size() > 0:
			_open_path.call_deferred(main, paths[0])
	var err := DisplayServer.file_dialog_show("选择一张剪纸照片", "", "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"]), cb)
	if err != OK:
		main.toast("这台设备打不开文件选择，先用示例照片试试")


static func _open_path(main, path: String) -> void:
	process_path(main, path)


static func process_path(main, path: String) -> void:
	var img := PhotoTemplate.load_photo(path)
	if img == null:
		main.toast("这张图片读不出来，换一张试试")
		return
	process_image(main, img)


# 后台识别
static func process_image(main, img: Image) -> void:
	if _busy or img == null:
		return
	_busy = true
	main.toast("正在分析对称性，识别折法…", 1.4, "sparkle")
	var holder := {}
	var task := WorkerThreadPool.add_task(func(): holder["an"] = PhotoTemplate.analyze(img))
	var tree: SceneTree = main.get_tree()
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	_busy = false
	var an: Dictionary = holder.get("an", {"error": "识别失败"})
	if an.has("error"):
		main.dialog("没认出来", an["error"], [["好", Callable()]])
		return
	await play_process(main, an)
	Sfx.play("coin", -8.0, 1.3)
	var view := ResultView.new()
	view.main = main
	view.an = an
	view.photo = ImageTexture.create_from_image(an["preview"])
	var sh = main.sheet("识别结果")
	view.sheet = sh
	sh.content.add_child(view)
	sh.open()


# 识别过程
static func play_process(main, an: Dictionary) -> void:
	var pv := PhotoProcess.new()
	pv.an = an
	var quick := PhotoTemplate.make_template(an, an["best"], "")
	pv.preview_tpl = PhotoProcess.tpl_texture(quick["image"])
	var sh = main.sheet("识别过程")
	sh.content.add_child(pv)
	sh.open()
	var state := {"done": false}
	pv.finished.connect(func(): state["done"] = true)
	sh.closed.connect(func(): state["done"] = true)
	var tree: SceneTree = main.get_tree()
	while not state["done"]:
		await tree.process_frame
	if is_instance_valid(sh):
		sh.close()
		await tree.create_timer(0.25).timeout


# 识别结果面板
class ResultView extends VBoxContainer:
	var main
	var an: Dictionary
	var photo: Texture2D
	var sheet
	var fold := "none"
	var _stage
	var _title: Label
	var _sub: Label
	var _rows: VBoxContainer
	var _tpl := {}
	var _name_edit: LineEdit
	var _fact: Label
	var _making := false

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		fold = an["best"]
		var pics := HBoxContainer.new()
		pics.add_theme_constant_override("separation", 10)
		pics.custom_minimum_size = Vector2(0, 230)
		add_child(pics)
		var a := PanelContainer.new()
		a.add_theme_stylebox_override("panel", Ui.card_box(20, Ui.CARD, false, 0))
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		var tr := TextureRect.new()
		tr.texture = photo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		a.add_child(tr)
		pics.add_child(a)
		var arrow := Icon.new("arrow_right", Ui.LABEL3, 34)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pics.add_child(arrow)
		var b := PanelContainer.new()
		b.add_theme_stylebox_override("panel", Ui.card_box(20, Color("efe7da"), false, 0))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pics.add_child(b)
		_stage = PaperStage.new(true)
		_stage.margin = 22
		b.add_child(_stage)

		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 2)
		_title = Ui.title("", Ui.T_TITLE3)
		tv.add_child(_title)
		_sub = Ui.label("", Ui.T_FOOT, Ui.LABEL2)
		tv.add_child(_sub)
		_fact = Ui.label("", Ui.T_FOOT, Color("8a6416"), HORIZONTAL_ALIGNMENT_LEFT, 600)
		tv.add_child(_fact)
		add_child(tv)

		var lh := HBoxContainer.new()
		var lt := Ui.label("各折法的对称度（点一下可改用别的折法）", Ui.T_FOOT, Ui.LABEL2, HORIZONTAL_ALIGNMENT_LEFT, 500)
		lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(lt)
		var replay := Ui.tinted_button("看识别过程", Ui.T_FOOT, "film")
		replay.custom_minimum_size = Vector2(0, 56)
		replay.pressed.connect(func(): load("res://scripts/ui/photo_sheet.gd").play_process(main, an))
		lh.add_child(replay)
		add_child(lh)
		_rows = VBoxContainer.new()
		_rows.add_theme_constant_override("separation", 8)
		add_child(_rows)

		var bottom := HBoxContainer.new()
		bottom.add_theme_constant_override("separation", 12)
		add_child(bottom)
		_name_edit = Ui.line_edit("我的样稿 %d" % (Templates.user_count() + 1), "给样稿起个名字")
		_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_edit.add_theme_font_size_override("font_size", Ui.T_BODY)
		bottom.add_child(_name_edit)
		var go := Ui.filled_button("就剪这张", Ui.T_HEAD, "scissors")
		go.custom_minimum_size = Vector2(250, 88)
		go.pressed.connect(_go)
		bottom.add_child(go)
		_apply()

	func _apply() -> void:
		var nm := "我的样稿 %d" % (Templates.user_count() + 1)
		_tpl = PhotoTemplate.make_template(an, fold, nm)
		var m = PaperModel.new(fold)
		var tg := Templates.build_target(m, _tpl["image"], false)
		m.set_mask(Templates.target_mask(m, _tpl["image"], tg))
		_stage.set_model(m, _tpl["paper"])
		Ui.pop(_stage, 0.85, 0.45)
		var layers := 1
		var score := 1.0
		for r in an["scores"]:
			if r["fold"] == fold:
				layers = r["layers"]
				score = r["score"]
		if fold == "none":
			_title.text = "识别为：不折（单层刻纸）"
			_sub.text = "没找到明显的对称，按不折处理 · %s · 难度 %s" % [Game.PAPERS[_tpl["paper"]]["name"], Ui.stars_text(_tpl["difficulty"])]
		else:
			_title.text = "识别为：%s · %d 层" % [Game.FOLDS[fold]["name"], layers]
			_sub.text = "对称度 %d%% · 建议用%s · 难度 %s" % [int(round(score * 100.0)), Game.PAPERS[_tpl["paper"]]["name"], Ui.stars_text(_tpl["difficulty"])]
		_fact.text = FoldFacts.math(fold)
		_build_rows()

	func _build_rows() -> void:
		for c in _rows.get_children():
			c.queue_free()
		var list: Array = an["scores"].slice(0, 3)
		list.append({"fold": "none", "score": -1.0, "layers": 1})
		for r in list:
			_rows.add_child(_row(r))

	func _row(r: Dictionary) -> Control:
		var sel: bool = r["fold"] == fold
		var p := PanelContainer.new()
		var st := Ui.card_box(18, Ui.CARD, false, 12)
		if sel:
			st.border_color = Ui.ACCENT
			st.set_border_width_all(3)
		p.add_theme_stylebox_override("panel", st)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(h)
		var ic := Widgets.FoldIcon.new(r["fold"], 52)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var lab := Ui.label("%s · %d 层" % [Game.FOLDS[r["fold"]]["name"], r["layers"]], Ui.T_BODY, Ui.LABEL, HORIZONTAL_ALIGNMENT_LEFT, 600 if sel else 400)
		lab.custom_minimum_size = Vector2(230, 0)
		h.add_child(lab)
		var bar := Bar.new()
		bar.value = maxf(0.0, r["score"])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.visible = r["score"] >= 0.0
		h.add_child(bar)
		var pct := Ui.label("%d%%" % int(round(r["score"] * 100.0)) if r["score"] >= 0.0 else "—", Ui.T_SUB, Ui.ACCENT if sel else Ui.LABEL2, HORIZONTAL_ALIGNMENT_RIGHT, 700)
		pct.custom_minimum_size = Vector2(80, 0)
		if r["score"] < 0.0:
			pct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(pct)
		var f: String = r["fold"]
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and f != fold:
				fold = f
				_apply())
		return p

	func _go() -> void:
		if _making:
			return
		_making = true
		var nm := _name_edit.text.strip_edges()
		if nm == "":
			nm = _tpl["name"]
		main.toast("正在生成高清样稿…", 1.2, "sparkle")
		var holder := {}
		var a := an
		var f := fold
		var task := WorkerThreadPool.add_task(func(): holder["t"] = PhotoTemplate.make_template(a, f, nm, true))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		_making = false
		if holder.has("t"):
			_tpl = holder["t"]
			_tpl["texture"] = ImageTexture.create_from_image(_tpl["image"])
		_tpl["name"] = nm
		Templates.add_user(_tpl)
		Game.mode = "template"
		Game.current_template = _tpl
		Game.cut_paper = _tpl["paper"]
		Game.cut_fold = _tpl["fold"]
		sheet.close()
		main.goto("cut")


class Bar extends Control:
	var value := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(80, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(0, (size.y - 12) * 0.5), Vector2(size.x, 12))
		draw_style_box(Ui.card_box(6, Ui.FILL, false, 0), r)
		if value > 0.01:
			draw_style_box(Ui.card_box(6, Ui.ACCENT if value >= 0.62 else Color("c9b9a6"), false, 0),
					Rect2(r.position, Vector2(maxf(12.0, r.size.x * value), 12)))
