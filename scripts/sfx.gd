# 剪纸坊
# sfx.gd - 音效播放
extends RefCounted

static var _streams := {}


static func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not Game.sound_on:
		return
	var st: AudioStream = _streams.get(name)
	if st == null:
		var path := "res://assets/sfx/%s.wav" % name
		if not ResourceLoader.exists(path):
			return
		st = load(path)
		_streams[name] = st
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = pitch
	tree.root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
