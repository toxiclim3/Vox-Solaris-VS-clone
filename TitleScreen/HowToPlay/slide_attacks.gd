## slide_attacks.gd
## Diorama: Player in centre, 3 strong kobolds in a triangle.
## Ice Spear fires at each kobold in sequence; kobold flashes red then fades.
## After all 3 die, 2s pause, all reset and loop.
extends Node2D

const BG_COLOR    := Color(0.08, 0.06, 0.12)
const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX  := "res://Textures/Enemy/kolbold_strong.png"
const SPEAR_TEX   := "res://Textures/Items/Weapons/ice_spear.png"
const SCALE       := Vector2(2, 2)
const CENTER      := Vector2(160, 95)
const RADIUS      := 60.0
const RESET_DELAY := 2.0

var _player:  Sprite2D
var _kobolds: Array[Sprite2D] = []
var _looping: bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(320, 180)
	add_child(bg)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.scale   = SCALE
	_player.position = CENTER
	add_child(_player)

	# Three kobolds in a triangle
	var kobold_tex = load(KOBOLD_TEX)
	for i in 3:
		var angle := (-PI / 2.0) + (TAU / 3.0) * i
		var kob := Sprite2D.new()
		kob.texture  = kobold_tex
		kob.hframes  = 2
		kob.frame    = 0
		kob.scale    = SCALE
		kob.position = CENTER + Vector2(cos(angle), sin(angle)) * RADIUS
		add_child(kob)
		_kobolds.append(kob)

func start_loop() -> void:
	_looping = true
	_attack_loop()

func stop_loop() -> void:
	_looping = false

func _attack_loop() -> void:
	while _looping:
		# Reset kobolds
		for kob in _kobolds:
			kob.visible  = true
			kob.modulate = Color.WHITE
			kob.scale    = SCALE

		# Attack each kobold in sequence
		var alive := [0, 1, 2]
		alive.shuffle()
		for idx in alive:
			if not _looping: return
			await _fire_spear(idx)
			await get_tree().create_timer(0.3).timeout

		# Pause before reset
		await get_tree().create_timer(RESET_DELAY).timeout

func _fire_spear(kob_idx: int) -> void:
	var kob := _kobolds[kob_idx]
	var start_pos := CENTER
	var end_pos   := kob.position

	# Spear sprite
	var spear := Sprite2D.new()
	spear.texture  = load(SPEAR_TEX)
	spear.scale    = SCALE * 0.8
	spear.position = start_pos
	spear.rotation = start_pos.angle_to_point(end_pos)
	add_child(spear)

	# Fly to kobold
	var tw := create_tween()
	tw.tween_property(spear, "position", end_pos, 0.22).set_ease(Tween.EASE_IN)
	await tw.finished
	spear.queue_free()

	# Hit flash
	var flash := create_tween()
	flash.tween_property(kob, "modulate", Color(1, 0.3, 0.3), 0.07)
	flash.tween_property(kob, "modulate", Color.WHITE,         0.07)
	await flash.finished

	# Fade out (death)
	var fade := create_tween()
	fade.tween_property(kob, "modulate:a", 0.0, 0.25)
	await fade.finished
	kob.visible = false
