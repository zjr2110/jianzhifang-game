# 剪纸坊
# paper_stage.gd - 作品展示区
extends Control

const PaperView = preload("res://scripts/paper_view.gd")

var view = null
var sway := true
var margin := 16.0
var _t := 0.0


func _init(p_sway := true) -> void:
	sway = p_sway
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_model(model, paper_id: String) -> void:
	if view:
		view.queue_free()
	view = PaperView.new()
	add_child(view)
	view.setup(model, paper_id)
	view.mode = "full"
	_fit()
	if not resized.is_connected(_fit):
		resized.connect(_fit)


func _fit() -> void:
	if view == null or view.model == null:
		return
	var r := Rect2(-size * 0.5, size)
	var f := PaperView.fit(r, view.model.bounds, margin)
	view.position = size * 0.5
	view.set_view(f[0], f[1])


func _process(delta: float) -> void:
	if view and sway:
		_t += delta
		view.rotation = sin(_t * 0.5) * 0.045
