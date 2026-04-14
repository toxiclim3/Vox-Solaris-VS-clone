## slide_xp.gd
## Diorama: Whip lash hits a kobold, kobold fades, XP gem curves to player,
## XP bar fills. 2s pause then reset.
extends Node2D

const BG_COLOR   := Color(0.08, 0.06, 0.12)
const PLAYER_TEX := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX := "res://Textures/Enemy/kolbold_weak.png"
const GEM_TEX    := "res://Textures/Items/XPOrb.png"
const SCALE      := Vector2(2, 2)
const PLAYER_POS := Vector2(230, 90)
const KOBOLD_POS := Vector2(80,  90)

var _player:   Sprite2D
var _kobold:   Sprite2D
var _gem:      Sprite2D
var _xp_bar:   ProgressBar
var _looping:  bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(320, 180)
	add_child(bg)

	_kobold = Sprite2D.new()
	_kobold.texture = load(KOBOLD_TEX)
	_kobold.hframes = 2
	_kobold.frame   = 0
	_kobold.scale   = SCALE
	_kobold.position = KOBOLD_POS
	add_child(_kobold)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.scale   = SCALE
	_player.position = PLAYER_POS
	add_child(_player)

	_gem = Sprite2D.new()
	_gem.texture  = load(GEM_TEX)
	_gem.scale    = Vector2(1.2, 1.2)
	_gem.position = KOBOLD_POS
	_gem.visible  = false
	add_child(_gem)

	# XP bar at bottom
	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = 100
	_xp_bar.value     = 30
	_xp_bar.size      = Vector2(280, 8)
	_xp_bar.position  = Vector2(20, 165)
	_xp_bar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.85, 0.35)
	_xp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.05)
	_xp_bar.add_theme_stylebox_override("background", bg_style)
	add_child(_xp_bar)

func start_loop() -> void:
	_looping = true
	_xp_loop()

func stop_loop() -> void:
	_looping = false

func _xp_loop() -> void:
	while _looping:
		_reset_state()
		await get_tree().create_timer(0.6).timeout
		if not _looping: return

		# Whip lash: Line2D from player toward kobold, then disappears
		var whip := Line2D.new()
		whip.width        = 3.0
		whip.default_color = Color(0.9, 0.75, 0.4)
		whip.add_point(PLAYER_POS)
		whip.add_point(KOBOLD_POS)
		add_child(whip)

		await get_tree().create_timer(0.12).timeout
		whip.queue_free()

		# Kobold flash & death
		var flash := create_tween()
		flash.tween_property(_kobold, "modulate", Color(1, 0.3, 0.3), 0.07)
		flash.tween_property(_kobold, "modulate", Color.WHITE,         0.07)
		await flash.finished
		var fade := create_tween()
		fade.tween_property(_kobold, "modulate:a", 0.0, 0.3)
		await fade.finished
		_kobold.visible = false

		# Gem spawns and flies to player
		_gem.visible  = true
		_gem.position = KOBOLD_POS
		_gem.modulate = Color.WHITE

		var gem_tw := create_tween()
		gem_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		gem_tw.tween_property(_gem, "position", PLAYER_POS, 0.55)
		await gem_tw.finished
		_gem.visible = false

		# XP bar fills
		var bar_tw := create_tween()
		bar_tw.tween_property(_xp_bar, "value", 65.0, 0.4)
		await bar_tw.finished

		await get_tree().create_timer(2.0).timeout

func _reset_state() -> void:
	_kobold.visible  = true
	_kobold.modulate = Color.WHITE
	_gem.visible     = false
	var bar_tw := create_tween()
	bar_tw.tween_property(_xp_bar, "value", 30.0, 0.0)
