## slide_tip_xporb.gd
## Several XP gems scattered on screen.
## XP magnet pickup appears right of player.
## Player walks toward it → overlap → all gems fly in simultaneously.
## Player flashes white. 2s pause, then reset.
extends Node2D

const BG_COLOR   := Color(0.08, 0.06, 0.12)
const PLAYER_TEX := "res://Textures/Player/player_sprite.png"
const GEM_TEX    := "res://Textures/Items/XPOrb.png"
const SCALE      := Vector2(2, 2)

const PLAYER_START := Vector2(110, 90)
const ORB_POS      := Vector2(210, 90)

# Pre-placed gem positions scattered around the scene
const GEM_POSITIONS: Array[Vector2] = [
	Vector2(30,  40),
	Vector2(60,  130),
	Vector2(95,  60),
	Vector2(240, 45),
	Vector2(275, 125),
	Vector2(295, 70),
	Vector2(155, 145),
	Vector2(50,  95),
]

var _player: Sprite2D
var _orb:    Sprite2D
var _gems:   Array[Sprite2D] = []
var _looping: bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(320, 180)
	add_child(bg)

	# Scattered gems
	var gem_tex = load(GEM_TEX)
	for pos in GEM_POSITIONS:
		var gem := Sprite2D.new()
		gem.texture   = gem_tex
		gem.scale     = Vector2(0.9, 0.9)
		gem.position  = pos
		gem.modulate  = Color(0.3, 1.0, 0.4)
		add_child(gem)
		_gems.append(gem)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.scale   = SCALE
	_player.position = PLAYER_START
	add_child(_player)

	# XP orb pickup (reuse XPOrb texture, tinted gold/magnet colour)
	_orb = Sprite2D.new()
	_orb.texture  = gem_tex
	_orb.scale    = Vector2(1.6, 1.6)
	_orb.position = ORB_POS
	_orb.modulate = Color(1.2, 0.9, 0.2)  # golden tint to distinguish it
	add_child(_orb)

	# Label under the orb
	var orb_lbl := Label.new()
	orb_lbl.text = "XP Orb"
	orb_lbl.add_theme_font_size_override("font_size", 8)
	orb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb_lbl.size = Vector2(50, 12)
	orb_lbl.position = ORB_POS + Vector2(-25, 12)
	add_child(orb_lbl)

func start_loop() -> void:
	_looping = true
	_orb_loop()

func stop_loop() -> void:
	_looping = false

func _orb_loop() -> void:
	while _looping:
		_reset_state()
		await get_tree().create_timer(0.5).timeout
		if not _looping: return

		# Player walks right toward the orb
		var walk := create_tween()
		walk.set_trans(Tween.TRANS_LINEAR)
		walk.tween_property(_player, "position", ORB_POS - Vector2(16, 0), 1.2)
		await walk.finished
		if not _looping: return

		# Orb collected
		var orb_pop := create_tween()
		orb_pop.tween_property(_orb, "scale", Vector2(2.4, 2.4), 0.08)
		orb_pop.tween_property(_orb, "modulate:a", 0.0, 0.15)
		await orb_pop.finished

		# All gems fly to player simultaneously
		var collect_tw := create_tween().set_parallel(true)
		collect_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		for gem in _gems:
			collect_tw.tween_property(gem, "position", _player.position, 0.5)
		await collect_tw.finished

		# Hide gems
		for gem in _gems:
			gem.visible = false

		# Player white flash
		var flash := create_tween()
		flash.tween_property(_player, "modulate", Color(2.0, 2.0, 2.0), 0.1)
		flash.tween_property(_player, "modulate", Color.WHITE,           0.2)
		await flash.finished

		await get_tree().create_timer(2.0).timeout

func _reset_state() -> void:
	_player.position = PLAYER_START
	_player.modulate = Color.WHITE
	_orb.position    = ORB_POS
	_orb.scale       = Vector2(1.6, 1.6)
	_orb.modulate    = Color(1.2, 0.9, 0.2)
	for i in _gems.size():
		_gems[i].position = GEM_POSITIONS[i]
		_gems[i].visible  = true
		_gems[i].modulate = Color(0.3, 1.0, 0.4)
