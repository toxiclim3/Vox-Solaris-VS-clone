## slide_difficulty.gd
## Phase A (Easy): player chases lone weak kobold, full HP.
## Phase B (Hard): player flees from juggernaut + cyclops, low HP.
## Cycles every ~3s.
extends Node2D

const BG_COLOR      := Color(0.08, 0.06, 0.12)
const PLAYER_TEX    := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX    := "res://Textures/Enemy/kolbold_weak.png"
const JUG_TEX       := "res://Textures/Enemy/juggernaut.png"
const CYCLOPS_TEX   := "res://Textures/Enemy/cyclops.png"
const SCALE         := Vector2(2, 2)

var _player:    Sprite2D
var _kobold:    Sprite2D
var _juggernaut:Sprite2D
var _cyclops:   Sprite2D
var _hp_bar:    ProgressBar
var _diff_lbl:  Label
var _looping:   bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(320, 180)
	add_child(bg)

	# HP bar at top-left
	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value     = 100
	_hp_bar.size      = Vector2(60, 7)
	_hp_bar.position  = Vector2(8, 8)
	_hp_bar.show_percentage = false
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = Color(0.2, 0.85, 0.35)
	_hp_bar.add_theme_stylebox_override("fill", fill_s)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.05, 0.05, 0.05)
	_hp_bar.add_theme_stylebox_override("background", bg_s)
	add_child(_hp_bar)

	var hp_icon := Label.new()
	hp_icon.text = "HP"
	hp_icon.add_theme_font_size_override("font_size", 7)
	hp_icon.position = Vector2(8, 0)
	add_child(hp_icon)

	_diff_lbl = Label.new()
	_diff_lbl.text = "EASY"
	_diff_lbl.add_theme_font_size_override("font_size", 14)
	_diff_lbl.modulate = Color(0.4, 1.0, 0.5)
	_diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_lbl.size = Vector2(320, 20)
	_diff_lbl.position = Vector2(0, 155)
	add_child(_diff_lbl)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.scale   = SCALE
	add_child(_player)

	_kobold = Sprite2D.new()
	_kobold.texture = load(KOBOLD_TEX)
	_kobold.hframes = 2
	_kobold.frame   = 0
	_kobold.scale   = SCALE
	add_child(_kobold)

	_juggernaut = Sprite2D.new()
	_juggernaut.texture = load(JUG_TEX)
	_juggernaut.hframes = 2
	_juggernaut.frame   = 0
	_juggernaut.scale   = SCALE * 1.2
	_juggernaut.visible = false
	add_child(_juggernaut)

	_cyclops = Sprite2D.new()
	_cyclops.texture = load(CYCLOPS_TEX)
	_cyclops.hframes = 2
	_cyclops.frame   = 0
	_cyclops.scale   = SCALE
	_cyclops.visible = false
	add_child(_cyclops)

func start_loop() -> void:
	_looping = true
	_diff_loop()

func stop_loop() -> void:
	_looping = false

func _diff_loop() -> void:
	while _looping:
		# Phase A: Easy
		await _phase_easy()
		if not _looping: return
		await get_tree().create_timer(0.5).timeout
		# Phase B: Hard
		await _phase_hard()
		if not _looping: return
		await get_tree().create_timer(0.5).timeout

func _phase_easy() -> void:
	# Setup
	_kobold.visible    = true
	_juggernaut.visible= false
	_cyclops.visible   = false
	_player.flip_h     = false

	_diff_lbl.text    = "EASY"
	_diff_lbl.modulate = Color(0.4, 1.0, 0.5)

	_player.position  = Vector2(-20, 90)
	_kobold.position  = Vector2(250, 90)

	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = Color(0.2, 0.85, 0.35)
	_hp_bar.add_theme_stylebox_override("fill", fill_s)

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(_player, "position", Vector2(220, 90), 2.5)
	tw.tween_property(_kobold, "position", Vector2(290, 90), 2.5)
	tw.tween_property(_hp_bar, "value", 100.0, 0.3)
	await tw.finished

func _phase_hard() -> void:
	# Setup
	_kobold.visible    = false
	_juggernaut.visible= true
	_cyclops.visible   = true
	_player.flip_h     = true   # facing left (fleeing right-to-left)

	_diff_lbl.text    = "HARD"
	_diff_lbl.modulate = Color(1.0, 0.3, 0.3)

	_player.position     = Vector2(340, 90)
	_juggernaut.position = Vector2(390, 90)
	_cyclops.position    = Vector2(420, 110)

	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = Color(0.85, 0.2, 0.2)
	_hp_bar.add_theme_stylebox_override("fill", fill_s)
	_hp_bar.value = 25.0

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(_player,     "position", Vector2(50,  90),  2.5)
	tw.tween_property(_juggernaut, "position", Vector2(120, 90),  2.5)
	tw.tween_property(_cyclops,    "position", Vector2(150, 110), 2.5)
	await tw.finished
