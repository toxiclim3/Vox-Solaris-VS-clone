## slide_levelup.gd
## Same as XP but XP bar overflows, flashes, then 3 item cards pop up.
## After 2s the cards shrink back and loop.
extends Node2D

const BG_COLOR   := Color(0.08, 0.06, 0.12)
const PLAYER_TEX := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX := "res://Textures/Enemy/kolbold_weak.png"
const GEM_TEX    := "res://Textures/Items/XPOrb.png"
const SCALE      := Vector2(2, 2)
const PLAYER_POS := Vector2(230, 80)
const KOBOLD_POS := Vector2(80,  80)

# Three item cards: (icon_path, label)
const CARD_DATA: Array = [
	["res://Textures/Items/Weapons/javelin_3_new_attack.png", "Javelin"],
	["res://Textures/Items/Weapons/ice_spear.png",            "Ice Spear"],
	["res://Textures/Items/Weapons/tornado.png",              "Tornado"],
]
const CARD_WIDTH  := 70.0
const CARD_HEIGHT := 52.0

var _player:  Sprite2D
var _kobold:  Sprite2D
var _gem:     Sprite2D
var _xp_bar:  ProgressBar
var _cards:   Array[Control] = []
var _looping: bool = false

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

	# XP bar
	_xp_bar = ProgressBar.new()
	_xp_bar.min_value = 0
	_xp_bar.max_value = 100
	_xp_bar.value     = 75
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

	# Build cards (hidden initially)
	var total_w := CARD_DATA.size() * CARD_WIDTH + (CARD_DATA.size() - 1) * 5
	var start_x := (320 - total_w) / 2.0
	for i in CARD_DATA.size():
		var card := _make_card(CARD_DATA[i][0], CARD_DATA[i][1])
		card.position = Vector2(start_x + i * (CARD_WIDTH + 5), 100)
		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
		card.scale  = Vector2.ZERO
		card.visible = false
		add_child(card)
		_cards.append(card)

func _make_card(icon_path: String, label_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.15, 0.12, 0.22)
	style.border_color = Color(0.55, 0.35, 0.9)
	style.border_width_bottom = 2
	style.border_width_top    = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture      = load(icon_path)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 30)
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	return panel

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

		# Whip
		var whip := Line2D.new()
		whip.width = 3.0
		whip.default_color = Color(0.9, 0.75, 0.4)
		whip.add_point(PLAYER_POS)
		whip.add_point(KOBOLD_POS)
		add_child(whip)
		await get_tree().create_timer(0.12).timeout
		whip.queue_free()

		# Kobold death
		var fade := create_tween()
		fade.tween_property(_kobold, "modulate:a", 0.0, 0.3)
		await fade.finished
		_kobold.visible = false

		# Gem flies to player
		_gem.visible  = true
		_gem.position = KOBOLD_POS
		var gem_tw := create_tween()
		gem_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		gem_tw.tween_property(_gem, "position", PLAYER_POS, 0.5)
		await gem_tw.finished
		_gem.visible = false

		# XP bar fills and overflows
		var fill_tw := create_tween()
		fill_tw.tween_property(_xp_bar, "value", 100.0, 0.35)
		await fill_tw.finished

		# Bar flash
		var bar_fill := StyleBoxFlat.new()
		for _n in 3:
			bar_fill.bg_color = Color(1.0, 1.0, 0.4)
			_xp_bar.add_theme_stylebox_override("fill", bar_fill)
			await get_tree().create_timer(0.12).timeout
			bar_fill.bg_color = Color(0.2, 0.85, 0.35)
			_xp_bar.add_theme_stylebox_override("fill", bar_fill)
			await get_tree().create_timer(0.10).timeout

		# Cards pop up
		for card in _cards:
			card.visible = true
			card.scale   = Vector2.ZERO
		var pop_tw := create_tween().set_parallel(true)
		pop_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in _cards.size():
			pop_tw.tween_property(_cards[i], "scale", Vector2.ONE, 0.3).set_delay(i * 0.08)
		await pop_tw.finished

		await get_tree().create_timer(2.0).timeout

		# Cards pop away
		var away_tw := create_tween().set_parallel(true)
		away_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		for card in _cards:
			away_tw.tween_property(card, "scale", Vector2.ZERO, 0.2)
		await away_tw.finished
		for card in _cards:
			card.visible = false

		await get_tree().create_timer(0.3).timeout

func _reset_state() -> void:
	_kobold.visible  = true
	_kobold.modulate = Color.WHITE
	_gem.visible     = false
	_xp_bar.value    = 75.0
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.2, 0.85, 0.35)
	_xp_bar.add_theme_stylebox_override("fill", s)
	for card in _cards:
		card.visible = false
		card.scale   = Vector2.ZERO
