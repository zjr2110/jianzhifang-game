# 剪纸坊
# touch_scroll.gd - 触摸拖动滚动
extends Node

const SLOP := 14.0

var sc: ScrollContainer
var horizontals: Array = []

var _down := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _last_t := 0
var _axis := ""
var _target: ScrollContainer = null
var _vel := 0.0
var _fling := false


static func attach(scroll: ScrollContainer, hs: Array = []) -> Node:
	var n = load("res://scripts/ui/touch_scroll.gd").new()
	n.sc = scroll
	n.horizontals = hs
	scroll.scroll_deadzone = 1 << 20
	for h in hs:
		h.scroll_deadzone = 1 << 20
	scroll.add_child(n)
	return n


func _input(e: InputEvent) -> void:
	if sc == null or not sc.is_visible_in_tree():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if not sc.get_global_rect().has_point(e.position):
				return
			_down = true
			_fling = false
			_start = e.position
			_last = e.position
			_last_t = Time.get_ticks_msec()
			_axis = ""
			_vel = 0.0
			_target = null
		elif _down:
			_down = false
			_fling = _axis != "" and _axis != "-" and absf(_vel) > 60.0
	elif e is InputEventMouseMotion and _down:
		var d: Vector2 = e.position - _start
		if _axis == "":
			if d.length() < SLOP:
				return
			if absf(d.x) > absf(d.y) * 1.2:
				_target = _horizontal_at(_start)
				_axis = "x" if _target else "-"
			else:
				_target = sc
				_axis = "y"
			_last = e.position
		if _axis == "-":
			return
		var step: Vector2 = e.position - _last
		var now := Time.get_ticks_msec()
		var dt := maxf(0.001, (now - _last_t) / 1000.0)
		var amount := step.y if _axis == "y" else step.x
		_vel = lerpf(_vel, -amount / dt, 0.35)
		_last = e.position
		_last_t = now
		if _axis == "y":
			sc.scroll_vertical -= int(round(step.y))
		else:
			_target.scroll_horizontal -= int(round(step.x))
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _fling or _target == null:
		return
	_vel *= pow(0.04, delta)
	if absf(_vel) < 30.0:
		_fling = false
		return
	var mv := int(round(_vel * delta))
	if _axis == "y":
		var before := _target.scroll_vertical
		_target.scroll_vertical += mv
		if _target.scroll_vertical == before:
			_fling = false
	else:
		var before_h := _target.scroll_horizontal
		_target.scroll_horizontal += mv
		if _target.scroll_horizontal == before_h:
			_fling = false


func _horizontal_at(p: Vector2) -> ScrollContainer:
	for h in horizontals:
		if is_instance_valid(h) and h.is_visible_in_tree() and h.get_global_rect().has_point(p):
			return h
	return null
