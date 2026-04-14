## slide_characters.gd
## Diorama: Player recolored through mage/plague_doctor/occultist with the
## recolor shader. Character name label cycles. Starting weapon icon shown right.
extends Node2D

const BG_COLOR    := Color(0.08, 0.06, 0.12)
const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const RECOLOR_SH  := "res://Utility/recolor.gdshader"
const DWELL_TIME  := 1.8
const SCALE       := Vector2(2, 2)

const CHARS: Array[Dictionary] = [
	{
		"name":       "Mage",
		"color":      Color(1.0, 1.0, 1.0),
		"mix_hue":    false,
		"weapon_tex": "res://Textures/Items/Weapons/ice_spear.png",
		"weapon_name":"Ice Spear"
	},
	{
		"name":       "Plague Doctor",
		"color":      Color(0.3, 0.9, 0.3),
		"mix_hue":    true,
		"weapon_tex": "res://Textures/Items/Weapons/poison_gas.png",
		"weapon_name":"Poison Bottle"
	},
	{
		"name":       "Occultist",
		"color":      Color(0.7, 0.3, 0.9),
		"mix_hue":    true,
		"weapon_tex": "res://Textures/Items/Weapons/ritual_chalk.png",
		"weapon_name":"Ritual Chalk"
	},
]

var _player:      Sprite2D
var _player_mat:  ShaderMaterial
var _char_lbl:    Label
var _weapon_icon: TextureRect
var _weapon_lbl:  Label
var _looping:     bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(320, 180)
	add_child(bg)

	# Player sprite with recolor shader
	_player_mat = ShaderMaterial.new()
	_player_mat.shader = load(RECOLOR_SH)
	_player_mat.set_shader_parameter("mix_hue",        false)
	_player_mat.set_shader_parameter("mix_saturation", false)
	_player_mat.set_shader_parameter("mix_value",      false)
	_player_mat.set_shader_parameter("target_color",   Color.WHITE)

	_player = Sprite2D.new()
	_player.texture  = load(PLAYER_TEX)
	_player.hframes  = 2
	_player.frame    = 0
	_player.scale    = SCALE * 1.5
	_player.position = Vector2(90, 90)
	_player.material = _player_mat
	add_child(_player)

	# Character name label
	_char_lbl = Label.new()
	_char_lbl.text = CHARS[0]["name"]
	_char_lbl.add_theme_font_size_override("font_size", 11)
	_char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_lbl.size = Vector2(120, 20)
	_char_lbl.position = Vector2(30, 140)
	add_child(_char_lbl)

	# Divider
	var div := ColorRect.new()
	div.color    = Color(1, 1, 1, 0.08)
	div.size     = Vector2(1, 150)
	div.position = Vector2(180, 15)
	add_child(div)

	# Weapon icon on right
	_weapon_icon = TextureRect.new()
	_weapon_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.custom_minimum_size = Vector2(50, 50)
	_weapon_icon.size     = Vector2(50, 50)
	_weapon_icon.position = Vector2(220, 50)
	_weapon_icon.texture  = load(CHARS[0]["weapon_tex"])
	add_child(_weapon_icon)

	_weapon_lbl = Label.new()
	_weapon_lbl.text = CHARS[0]["weapon_name"]
	_weapon_lbl.add_theme_font_size_override("font_size", 9)
	_weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_lbl.size     = Vector2(120, 20)
	_weapon_lbl.position = Vector2(190, 120)
	add_child(_weapon_lbl)

	# "Starting\nweapon" header
	var header := Label.new()
	header.text = "Starting weapon:"
	header.add_theme_font_size_override("font_size", 7)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size     = Vector2(120, 14)
	header.position = Vector2(190, 35)
	header.modulate = Color(0.7, 0.7, 0.7)
	add_child(header)

func start_loop() -> void:
	_looping = true
	_cycle_loop()

func stop_loop() -> void:
	_looping = false

func _cycle_loop() -> void:
	var idx := 0
	_apply_char(idx)
	while _looping:
		await get_tree().create_timer(DWELL_TIME).timeout
		if not _looping: return

		# Fade out
		var fade_out := create_tween().set_parallel(true)
		fade_out.tween_property(_player,      "modulate:a",      0.0, 0.25)
		fade_out.tween_property(_weapon_icon, "modulate:a",      0.0, 0.25)
		fade_out.tween_property(_char_lbl,    "modulate:a",      0.0, 0.25)
		fade_out.tween_property(_weapon_lbl,  "modulate:a",      0.0, 0.25)
		await fade_out.finished

		idx = (idx + 1) % CHARS.size()
		_apply_char(idx)

		# Fade in
		var fade_in := create_tween().set_parallel(true)
		fade_in.tween_property(_player,      "modulate:a",      1.0, 0.25)
		fade_in.tween_property(_weapon_icon, "modulate:a",      1.0, 0.25)
		fade_in.tween_property(_char_lbl,    "modulate:a",      1.0, 0.25)
		fade_in.tween_property(_weapon_lbl,  "modulate:a",      1.0, 0.25)
		await fade_in.finished

func _apply_char(idx: int) -> void:
	var data := CHARS[idx]
	_player_mat.set_shader_parameter("target_color", data["color"])
	_player_mat.set_shader_parameter("mix_hue",      data["mix_hue"])
	_char_lbl.text    = data["name"]
	_weapon_icon.texture = load(data["weapon_tex"])
	_weapon_lbl.text  = data["weapon_name"]
