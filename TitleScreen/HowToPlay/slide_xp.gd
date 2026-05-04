## slide_xp.gd
## Diorama: Projectile hits a kobold, kobold fades, XP gem curves to player,
## XP bar fills. 2s pause then reset.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX := "res://Textures/Enemy/kolbold_weak.png"
const GEM_TEX    := "res://Textures/Items/Gems/Gem_green.png"
const SPEAR_TEX  := "res://Textures/Items/Weapons/ice_spear.png"
const SHADOW_TEX := "res://Textures/GUI/blob_shadow.png"

const PLAYER_POS := Vector2(430, 180)
const KOBOLD_POS := Vector2(210, 180)

var _bg:       Node
var _player:   Sprite2D
var _kobold:   Sprite2D
var _k_shadow: Sprite2D
var _gem:      Sprite2D
var _xp_bar:   TextureProgressBar

var _looping:  bool = false
var _walk_time: float = 0.0

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	_k_shadow = Sprite2D.new()
	_k_shadow.texture = load(SHADOW_TEX)
	_k_shadow.position = KOBOLD_POS + Vector2(0, 8)
	add_child(_k_shadow)

	_kobold = Sprite2D.new()
	_kobold.texture = load(KOBOLD_TEX)
	_kobold.hframes = 2
	_kobold.frame   = 0
	_kobold.position = KOBOLD_POS
	add_child(_kobold)

	var p_shadow = Sprite2D.new()
	p_shadow.texture = load(SHADOW_TEX)
	p_shadow.position = PLAYER_POS + Vector2(0, 8)
	add_child(p_shadow)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.position = PLAYER_POS
	_player.flip_h  = false # Faces left towards kobold
	add_child(_player)

	# Gem
	_gem = Sprite2D.new()
	_gem.texture  = load(GEM_TEX)
	_gem.position = KOBOLD_POS
	_gem.visible  = false
	add_child(_gem)

	# XP bar at bottom
	_xp_bar = TextureProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = 100
	_xp_bar.value     = 30
	_xp_bar.size      = Vector2(640, 14)
	_xp_bar.position  = Vector2(0, 346)
	_xp_bar.texture_under = load("res://Textures/GUI/exp_background.png")
	_xp_bar.texture_progress = load("res://Textures/GUI/exp_progress_alt2.png")
	_xp_bar.nine_patch_stretch = true
	add_child(_xp_bar)

func _process(delta: float) -> void:
	if not _looping: return
	_walk_time += delta
	if _walk_time > 0.3:
		_walk_time -= 0.3
		_player.frame = 1 if _player.frame == 0 else 0
		if _kobold.visible:
			_kobold.frame = _player.frame

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

		# Ice Spear Attack
		var spear := Sprite2D.new()
		spear.texture  = load(SPEAR_TEX)
		spear.scale    = Vector2(0.8, 0.8)
		spear.position = PLAYER_POS
		spear.rotation = PLAYER_POS.angle_to_point(KOBOLD_POS) + deg_to_rad(135)
		add_child(spear)

		var tw := create_tween()
		tw.tween_property(spear, "position", KOBOLD_POS, 0.22).set_ease(Tween.EASE_IN)
		await tw.finished
		spear.queue_free()

		if not _looping: return

		# Kobold flash & death
		var flash := create_tween()
		flash.tween_property(_kobold, "modulate", Color(1, 0.3, 0.3), 0.07)
		flash.tween_property(_kobold, "modulate", Color.WHITE,         0.07)
		await flash.finished
		
		var fade := create_tween().set_parallel(true)
		fade.tween_property(_kobold,   "modulate:a", 0.0, 0.3)
		fade.tween_property(_k_shadow, "modulate:a", 0.0, 0.3)
		await fade.finished
		_kobold.visible   = false
		_k_shadow.visible = false

		if not _looping: return

		# Gem spawns and flies to player
		_gem.visible  = true
		_gem.position = KOBOLD_POS
		_gem.modulate = Color.WHITE

		var gem_tw := create_tween()
		gem_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		gem_tw.tween_property(_gem, "position", PLAYER_POS, 0.55)
		await gem_tw.finished
		_gem.visible = false

		if not _looping: return

		# XP bar fills
		var bar_tw := create_tween()
		bar_tw.tween_property(_xp_bar, "value", 65.0, 0.4)
		await bar_tw.finished

		await get_tree().create_timer(2.0).timeout

func _reset_state() -> void:
	_kobold.visible   = true
	_kobold.modulate  = Color.WHITE
	_k_shadow.visible = true
	_k_shadow.modulate = Color.WHITE
	_gem.visible      = false
	_xp_bar.value     = 30.0
