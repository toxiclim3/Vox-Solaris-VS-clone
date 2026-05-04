## slide_levelup.gd
## Same as XP but XP bar overflows, flashes, then 3 item cards pop up.
## After 2s the cards shrink back and loop.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX := "res://Textures/Enemy/kolbold_weak.png"
const GEM_TEX    := "res://Textures/Items/Gems/Gem_green.png"
const SPEAR_TEX  := "res://Textures/Items/Weapons/ice_spear.png"
const SHADOW_TEX := "res://Textures/GUI/blob_shadow.png"
const PLAYER_POS := Vector2(430, 170)
const KOBOLD_POS := Vector2(210, 170)

# Three item cards using real icon paths
const CARD_DATA: Array = [
	["res://Textures/Items/Weapons/javelin_3_new_attack.png", "Javelin"],
	["res://Textures/Items/Weapons/ice_spear.png",            "Ice Spear"],
	["res://Textures/Items/Weapons/tornado.png",              "Tornado"],
]
const CARD_WIDTH  := 74.0
const CARD_HEIGHT := 56.0

var _bg:      Node
var _player:  Sprite2D
var _kobold:  Sprite2D
var _k_shadow: Sprite2D
var _gem:     Sprite2D
var _xp_bar:  TextureProgressBar
var _cards:   Array[Control] = []
var _looping: bool = false
var _walk_time: float = 0.0

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	_k_shadow = Sprite2D.new()
	_k_shadow.texture  = load(SHADOW_TEX)
	_k_shadow.position = KOBOLD_POS + Vector2(0, 8)
	add_child(_k_shadow)

	_kobold = Sprite2D.new()
	_kobold.texture  = load(KOBOLD_TEX)
	_kobold.hframes  = 2
	_kobold.frame    = 0
	_kobold.position = KOBOLD_POS
	add_child(_kobold)

	var p_shadow = Sprite2D.new()
	p_shadow.texture  = load(SHADOW_TEX)
	p_shadow.position = PLAYER_POS + Vector2(0, 8)
	add_child(p_shadow)

	_player = Sprite2D.new()
	_player.texture  = load(PLAYER_TEX)
	_player.hframes  = 2
	_player.frame    = 0
	_player.position = PLAYER_POS
	add_child(_player)

	_gem = Sprite2D.new()
	_gem.texture  = load(GEM_TEX)
	_gem.position = KOBOLD_POS
	_gem.visible  = false
	add_child(_gem)

	_xp_bar = TextureProgressBar.new()
	_xp_bar.min_value          = 0
	_xp_bar.max_value          = 100
	_xp_bar.value              = 75
	_xp_bar.size               = Vector2(640, 14)
	_xp_bar.position           = Vector2(0, 346)
	_xp_bar.texture_under      = load("res://Textures/GUI/exp_background.png")
	_xp_bar.texture_progress   = load("res://Textures/GUI/exp_progress_alt2.png")
	_xp_bar.nine_patch_stretch = true
	add_child(_xp_bar)

	# Item Cards (hidden initially)
	var total_w := CARD_DATA.size() * CARD_WIDTH + (CARD_DATA.size() - 1) * 6.0
	var start_x := (640.0 - total_w) / 2.0

	for i in CARD_DATA.size():
		var card = _make_card(CARD_DATA[i][0], CARD_DATA[i][1])
		card.position     = Vector2(start_x + i * (CARD_WIDTH + 6), 150)
		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
		card.scale        = Vector2.ZERO
		card.visible      = false
		add_child(card)
		_cards.append(card)

func _make_card(icon_path: String, label_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.12, 0.10, 0.20)
	style.border_color               = Color(0.5, 0.3, 0.9)
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		style.set_border_width(side, 2)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture                = load(icon_path)
	icon.expand_mode            = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode           = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size    = Vector2(32, 32)
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text                    = label_text
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	return panel

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
	_levelup_loop()

func stop_loop() -> void:
	_looping = false

func _levelup_loop() -> void:
	while _looping:
		_reset_state()
		await get_tree().create_timer(0.6).timeout
		if not _looping: return

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

		var flash := create_tween()
		flash.tween_property(_kobold, "modulate", Color(1, 0.3, 0.3), 0.07)
		flash.tween_property(_kobold, "modulate", Color.WHITE,         0.07)
		await flash.finished
		
		# Fade out shadow as well
		var fade := create_tween().set_parallel(true)
		fade.tween_property(_kobold,   "modulate:a", 0.0, 0.3)
		fade.tween_property(_k_shadow, "modulate:a", 0.0, 0.3)
		await fade.finished
		_kobold.visible   = false
		_k_shadow.visible = false

		if not _looping: return

		_gem.visible  = true
		_gem.position = KOBOLD_POS
		var gem_tw := create_tween()
		gem_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		gem_tw.tween_property(_gem, "position", PLAYER_POS, 0.5)
		await gem_tw.finished
		_gem.visible = false

		if not _looping: return

		var fill_tw := create_tween()
		fill_tw.tween_property(_xp_bar, "value", 100.0, 0.35)
		await fill_tw.finished

		for _n in 3:
			var flash2 := create_tween()
			flash2.tween_property(_xp_bar, "modulate", Color(1.4, 1.4, 0.4), 0.1)
			flash2.tween_property(_xp_bar, "modulate", Color.WHITE,            0.1)
			await flash2.finished

		if not _looping: return

		for card in _cards:
			card.visible = true
			card.scale   = Vector2.ZERO
		var pop_tw := create_tween().set_parallel(true)
		pop_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in _cards.size():
			pop_tw.tween_property(_cards[i], "scale", Vector2.ONE, 0.3).set_delay(i * 0.08)
		await pop_tw.finished

		await get_tree().create_timer(2.0).timeout

		if not _looping: return

		var away_tw := create_tween().set_parallel(true)
		away_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		for card in _cards:
			away_tw.tween_property(card, "scale", Vector2.ZERO, 0.2)
		await away_tw.finished
		for card in _cards:
			card.visible = false

		await get_tree().create_timer(0.3).timeout

func _reset_state() -> void:
	_kobold.visible   = true
	_kobold.modulate  = Color.WHITE
	_k_shadow.visible = true
	_k_shadow.modulate = Color.WHITE
	_gem.visible      = false
	_xp_bar.value     = 75.0
	_xp_bar.modulate  = Color.WHITE
	for card in _cards:
		card.visible = false
		card.scale   = Vector2.ZERO
