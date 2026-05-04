## slide_attacks.gd
## Diorama: Player in centre, 3 strong kobolds in a triangle.
## Ice Spear fires at each kobold in sequence; kobold flashes red then fades.
## After all 3 die, 2s pause, all reset and loop.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX  := "res://Textures/Enemy/kolbold_strong.png"
const SPEAR_TEX   := "res://Textures/Items/Weapons/ice_spear.png"
const SHADOW_TEX  := "res://Textures/GUI/blob_shadow.png"

const CENTER      := Vector2(320, 180)   # centre of 640x360
const RADIUS      := 120.0
const RESET_DELAY := 2.0

var _bg: Node
var _player:  Sprite2D
var _kobolds: Array[Sprite2D] = []
var _kob_shadows: Array[Sprite2D] = []

var _looping: bool = false
var _walk_time: float = 0.0

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	var p_shadow = _make_shadow(CENTER)
	add_child(p_shadow)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.position = CENTER
	add_child(_player)

	var kobold_tex = load(KOBOLD_TEX)
	for i in 3:
		var angle := (-PI / 2.0) + (TAU / 3.0) * i
		var pos = CENTER + Vector2(cos(angle), sin(angle)) * RADIUS

		var k_shadow = _make_shadow(pos)
		add_child(k_shadow)
		_kob_shadows.append(k_shadow)

		var kob := Sprite2D.new()
		kob.texture  = kobold_tex
		kob.hframes  = 2
		kob.frame    = 0
		kob.position = pos
		kob.flip_h   = cos(angle) > 0
		add_child(kob)
		_kobolds.append(kob)

func _make_shadow(pos: Vector2) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture  = load(SHADOW_TEX)
	s.position = pos + Vector2(0, 8)
	return s

func _process(delta: float) -> void:
	if not _looping: return
	_walk_time += delta
	if _walk_time > 0.3:
		_walk_time -= 0.3
		_player.frame = 1 if _player.frame == 0 else 0
		for kob in _kobolds:
			if kob.visible:
				kob.frame = _player.frame

func start_loop() -> void:
	_looping = true
	_attack_loop()

func stop_loop() -> void:
	_looping = false

func _attack_loop() -> void:
	while _looping:
		# Reset
		for i in _kobolds.size():
			_kobolds[i].visible      = true
			_kobolds[i].modulate     = Color.WHITE
			_kob_shadows[i].visible  = true
			_kob_shadows[i].modulate = Color.WHITE

		var alive := [0, 1, 2]
		alive.shuffle()
		for idx in alive:
			if not _looping: return
			await _fire_spear(idx)
			await get_tree().create_timer(0.3).timeout

		await get_tree().create_timer(RESET_DELAY).timeout

func _fire_spear(kob_idx: int) -> void:
	var kob := _kobolds[kob_idx]
	var start_pos := CENTER
	var end_pos   := kob.position

	var spear := Sprite2D.new()
	spear.texture  = load(SPEAR_TEX)
	spear.scale    = Vector2(0.8, 0.8)
	spear.position = start_pos
	spear.rotation = start_pos.angle_to_point(end_pos) + deg_to_rad(135)
	add_child(spear)

	var tw := create_tween()
	tw.tween_property(spear, "position", end_pos, 0.22).set_ease(Tween.EASE_IN)
	await tw.finished
	spear.queue_free()

	var flash := create_tween()
	flash.tween_property(kob, "modulate", Color(1, 0.3, 0.3), 0.07)
	flash.tween_property(kob, "modulate", Color.WHITE,         0.07)
	await flash.finished

	# Fade out — also fade shadow
	var fade := create_tween().set_parallel(true)
	fade.tween_property(kob,                         "modulate:a", 0.0, 0.25)
	fade.tween_property(_kob_shadows[kob_idx],        "modulate:a", 0.0, 0.25)
	await fade.finished
	kob.visible                    = false
	_kob_shadows[kob_idx].visible  = false
