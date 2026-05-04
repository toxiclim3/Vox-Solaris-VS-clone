## slide_tip_circles.gd
## Player orbits in a wide circle. 5 kobolds trail ~90° behind.
## Ice spear fires outward and kobolds die one by one.
## Gems fly to player. Each dead kobold respawns at the tail. Seamless loop.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX := "res://Textures/Enemy/kolbold_weak.png"
const SPEAR_TEX  := "res://Textures/Items/Weapons/ice_spear.png"
const GEM_TEX    := "res://Textures/Items/Gems/Gem_green.png"

const CENTER     := Vector2(320, 180)
const ORBT_RAD   := 120.0
const ORBT_SPD   := 0.9      # radians/s
const NUM_KOBS   := 5
const LAG_ANGLE  := PI / 2.0  # how far behind kobolds trail

var _bg:       Node
var _player:   Sprite2D
var _kobolds:  Array[Sprite2D] = []
var _looping:  bool  = false
var _player_angle: float = 0.0
var _kill_timer: float   = 0.0
var _kill_interval: float = 1.8

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	add_child(_player)

	var kob_tex = load(KOBOLD_TEX)
	for i in NUM_KOBS:
		var kob := Sprite2D.new()
		kob.texture = kob_tex
		kob.hframes = 2
		kob.frame   = 0
		kob.scale   = Vector2(0.85, 0.85)
		add_child(kob)
		_kobolds.append(kob)

func start_loop() -> void:
	_looping = true
	set_process(true)
	_kill_timer = _kill_interval

func stop_loop() -> void:
	_looping = false
	set_process(false)

func _process(delta: float) -> void:
	if not _looping:
		return

	_player_angle += ORBT_SPD * delta
	var px := CENTER.x + cos(_player_angle) * ORBT_RAD
	var py := CENTER.y + sin(_player_angle) * ORBT_RAD * 0.55  # slight oval
	_player.position = Vector2(px, py)
	_player.flip_h   = cos(_player_angle) < 0

	for i in NUM_KOBS:
		if not _kobolds[i].visible:
			continue
		var kangle := _player_angle - LAG_ANGLE - float(i) * (LAG_ANGLE / NUM_KOBS)
		_kobolds[i].position = Vector2(
			CENTER.x + cos(kangle) * ORBT_RAD,
			CENTER.y + sin(kangle) * ORBT_RAD * 0.55
		)

	_kill_timer -= delta
	if _kill_timer <= 0.0:
		_kill_timer = _kill_interval
		_kill_next_kobold()

func _kill_next_kobold() -> void:
	# Find the first visible kobold
	for i in NUM_KOBS:
		if _kobolds[i].visible:
			_do_kill(i)
			return
	# All dead → respawn all
	for kob in _kobolds:
		kob.visible  = true
		kob.modulate = Color.WHITE

func _do_kill(idx: int) -> void:
	var kob := _kobolds[idx]
	var kob_pos := kob.position

	# Quick fade
	var fade := create_tween()
	fade.tween_property(kob, "modulate:a", 0.0, 0.2)
	fade.tween_callback(func(): kob.visible = false)

	# Spear flies outward past the kobold
	var spear := Sprite2D.new()
	spear.texture  = load(SPEAR_TEX)
	spear.scale    = Vector2(0.7, 0.7)
	spear.position = _player.position
	spear.rotation = _player.position.angle_to_point(kob_pos)
	add_child(spear)
	var spear_tw := create_tween()
	var end_pos := kob_pos + (kob_pos - _player.position).normalized() * 30
	spear_tw.tween_property(spear, "position", end_pos, 0.2)
	spear_tw.tween_callback(spear.queue_free)

	# Gem flies to player
	var gem := Sprite2D.new()
	gem.texture  = load(GEM_TEX)
	gem.position = kob_pos
	add_child(gem)
	var gem_tw := create_tween()
	gem_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	gem_tw.tween_property(gem, "position", _player.position, 0.5)
	gem_tw.tween_callback(gem.queue_free)
