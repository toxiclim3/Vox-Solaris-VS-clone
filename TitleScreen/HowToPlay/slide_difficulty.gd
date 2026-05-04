## slide_difficulty.gd
## Phase A (Easy): player chases lone weak kobold, full HP.
## Phase B (Hard): player flees from juggernaut + cyclops, low HP.
## Cycles every ~3s.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX    := "res://Textures/Player/player_sprite.png"
const KOBOLD_TEX    := "res://Textures/Enemy/kolbold_weak.png"
const JUG_TEX       := "res://Textures/Enemy/juggernaut.png"
const CYCLOPS_TEX   := "res://Textures/Enemy/cyclops.png"
const SHADOW_TEX    := "res://Textures/GUI/blob_shadow.png"
const HEALTH_UNDER  := "res://Textures/GUI/healthcircleunderlay.png"
const HEALTH_PROG   := "res://Textures/GUI/healthcircle.png"

var _bg:         Node
var _player:     Sprite2D
var _p_shadow:   Sprite2D
var _kobold:     Sprite2D
var _juggernaut: Sprite2D
var _cyclops:    Sprite2D
var _hp_circle:  TextureProgressBar
var _diff_lbl:   Label
var _looping:    bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	_diff_lbl = Label.new()
	_diff_lbl.text = "EASY"
	_diff_lbl.add_theme_font_size_override("font_size", 14)
	_diff_lbl.modulate = Color(0.4, 1.0, 0.5)
	_diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_lbl.size = Vector2(640, 20)
	_diff_lbl.position = Vector2(0, 330)
	add_child(_diff_lbl)

	# Health circle (matches real game)
	_hp_circle = TextureProgressBar.new()
	_hp_circle.min_value          = 0
	_hp_circle.max_value          = 100
	_hp_circle.value              = 100
	_hp_circle.fill_mode          = 5
	_hp_circle.texture_under      = load(HEALTH_UNDER)
	_hp_circle.texture_progress   = load(HEALTH_PROG)
	_hp_circle.texture_filter     = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_circle.z_index            = -1
	_hp_circle.self_modulate      = Color(1, 1, 1, 0.39)
	_hp_circle.size               = Vector2(40, 40)
	add_child(_hp_circle)

	_p_shadow = Sprite2D.new()
	_p_shadow.texture = load(SHADOW_TEX)
	add_child(_p_shadow)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	add_child(_player)

	_kobold = Sprite2D.new()
	_kobold.texture = load(KOBOLD_TEX)
	_kobold.hframes = 2
	_kobold.frame   = 0
	add_child(_kobold)

	_juggernaut = Sprite2D.new()
	_juggernaut.texture = load(JUG_TEX)
	_juggernaut.hframes = 2
	_juggernaut.frame   = 0
	_juggernaut.scale   = Vector2(1.2, 1.2)
	_juggernaut.visible = false
	add_child(_juggernaut)

	_cyclops = Sprite2D.new()
	_cyclops.texture = load(CYCLOPS_TEX)
	_cyclops.hframes = 2
	_cyclops.frame   = 0
	_cyclops.visible = false
	add_child(_cyclops)

func _update_player_pos(pos: Vector2) -> void:
	_player.position = pos
	_p_shadow.position = pos + Vector2(0, 8)
	_hp_circle.position = pos - Vector2(36, 36)

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
	_player.flip_h     = true  # facing right (chasing)

	_diff_lbl.text    = "EASY"
	_diff_lbl.modulate = Color(0.4, 1.0, 0.5)

	_update_player_pos(Vector2(80, 180))
	_kobold.position  = Vector2(460, 180)

	_hp_circle.value = 100

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_method(_update_player_pos, Vector2(80, 180), Vector2(380, 180), 2.5)
	tw.tween_property(_kobold, "position", Vector2(560, 180), 2.5)
	await tw.finished

func _phase_hard() -> void:
	# Setup
	_kobold.visible    = false
	_juggernaut.visible= true
	_cyclops.visible   = true
	_player.flip_h     = false   # facing left (fleeing right-to-left)

	_diff_lbl.text    = "HARD"
	_diff_lbl.modulate = Color(1.0, 0.3, 0.3)

	_update_player_pos(Vector2(560, 180))
	_juggernaut.position = Vector2(600, 180)
	_cyclops.position    = Vector2(630, 200)

	_hp_circle.value = 25

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_LINEAR)
	tw.tween_method(_update_player_pos, Vector2(560, 180), Vector2(180, 180), 2.5)
	tw.tween_property(_juggernaut, "position", Vector2(260, 180), 2.5)
	tw.tween_property(_cyclops,    "position", Vector2(290, 200), 2.5)
	await tw.finished
