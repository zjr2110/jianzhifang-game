# 剪纸坊
# works.gd - 作品展示辅助
extends RefCounted

const Ui = preload("res://scripts/ui_style.gd")
const PaperModel = preload("res://scripts/paper_model.gd")
const PaperStage = preload("res://scripts/ui/paper_stage.gd")
const Templates = preload("res://scripts/templates.gd")
const PrintSheet = preload("res://scripts/print_sheet.gd")

static var _tpl_cache := {}


static func model_for_work(w: Dictionary):
	var img: Image = Game.work_mask(w)
	if img == null:
		return null
	var m = PaperModel.new(w["fold"])
	m.set_mask(img)
	return m


static func model_for_template(t: Dictionary):
	if _tpl_cache.has(t["id"]):
		return _tpl_cache[t["id"]]
	var m = PaperModel.new(t["fold"])
	var tg := Templates.build_target(m, t["image"], false)
	m.set_mask(Templates.target_mask(m, t["image"], tg))
	_tpl_cache[t["id"]] = m
	return m


static func date_text(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + _tz_offset())
	return "%d月%d日 %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# 作品详情
static func open_work_sheet(main, w: Dictionary) -> void:
	var sh = main.sheet(w["name"])
	var c: VBoxContainer = sh.content
	var stage_box := PanelContainer.new()
	stage_box.add_theme_stylebox_override("panel", Ui.card_box(26, Color("efe7da"), false, 0))
	stage_box.custom_minimum_size = Vector2(0, 520)
	c.add_child(stage_box)
	var model = model_for_work(w)
	if model:
		var st := PaperStage.new(true)
		st.margin = 34
		stage_box.add_child(st)
		st.set_model(model, w["paper"])
	else:
		var tex: Texture2D = Game.work_photo(w)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			stage_box.add_child(tr)
	var rows := [
		["成交价", "%d 铜钱" % w["price"]],
		["买家", w["buyer"] + ("（隐藏买家）" if w.get("hidden", false) else "")],
		["评级", Ui.stars_text(w["stars"])],
		["纸张 · 折法", "%s · %s" % [Game.PAPERS[w["paper"]]["name"], Game.FOLDS[w["fold"]]["name"]]],
	]
	if w.get("mode", "free") == "template" and w.get("accuracy", -1.0) >= 0.0:
		rows.append(["吻合度", "%d%%" % int(round(w["accuracy"] * 100.0))])
	rows.append(["成交时间", date_text(w["time"])])
	c.add_child(info_group(rows))
	if model:
		var pb := Ui.tinted_button("导出剪纸图纸", Ui.T_BODY, "print")
		pb.custom_minimum_size = Vector2(0, 88)
		pb.pressed.connect(func():
			sh.close()
			PrintSheet.open(main, model, w["paper"], w["name"]))
		c.add_child(pb)
	sh.open()


static func info_group(rows: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.card_box(22, Ui.CARD, false, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	for i in rows.size():
		if i > 0:
			var sep := ColorRect.new()
			sep.color = Ui.SEP
			sep.custom_minimum_size = Vector2(0, 1)
			v.add_child(sep)
		var m := MarginContainer.new()
		for side in ["left", "right"]:
			m.add_theme_constant_override("margin_" + side, 24)
		m.add_theme_constant_override("margin_top", 18)
		m.add_theme_constant_override("margin_bottom", 18)
		var h := HBoxContainer.new()
		var k := Ui.label(rows[i][0], Ui.T_BODY, Ui.LABEL2)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(Ui.label(rows[i][1], Ui.T_BODY, Ui.LABEL, HORIZONTAL_ALIGNMENT_RIGHT, 500))
		m.add_child(h)
		v.add_child(m)
	return p
