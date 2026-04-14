## slide_bosses.gd
## Diorama: Player centre, Cyclops left (dim, frozen), Boss right.
## Ice Spear plinks the boss. Boss telegraphs a red circle aimed at the cyclops
## position. Player moves away. Cyclops does NOT. Arc fires — cyclops fades.
## 3s pause then reset.
extends Node2D

const BG_COLOR    := Color(0.08, 0.06, 0.12)
const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const CYCLOPS_TEX := "res://Textures/Enemy/cyclops.png"
const BOSS_TEX    := "res://Textures/Enemy/giant_amoeba_new.png"
const SPEAR_TEX   := "res://Textures/Items/Weapons/ice_spear.png"
const SCALE       := Vector2(2, 2)

const PLAYER_START  := Vector2(155, 90)
const CYCLOPS_POS   := Vector2(55,  90)
const BOSS_POS      := Vector2(260, 90)
const PLAYER_DODGE  := Vector2(155, 148)  # where player runs to dodge
const TELEGRAPH_RAD := 28.0

var _player:  Sprite2D
var _cyclops: Sprite2D
var _boss:    Sprite2D
var _boss_hp: ProgressBar
var _tel_ring: Node2D     # telegraph circle drawn via _draw()
var _tel_fill: float = 0.0
var _looping:  bool  = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(320, 180)
	add_child(bg)

	# Boss HP bar at top
	_boss_hp = ProgressBar.new()
	_boss_hp.min_value = 0
	_boss_hp.max_value = 100
	_boss_hp.value     = 100
	_boss_hp.size      = Vector2(100, 7)
	_boss_hp.position  = Vector2(210, 8)
	_boss_hp.show_percentage = false
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = Color(0.85, 0.2, 0.2)
	_boss_hp.add_theme_stylebox_override("fill", fill_s)
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.05, 0.05, 0.05)
	_boss_hp.add_theme_stylebox_override("background", bg_s)
	add_child(_boss_hp)

	var boss_lbl := Label.new()
	boss_lbl.text = "Boss"
	boss_lbl.add_theme_font_size_override("font_size", 8)
	boss_lbl.position = Vector2(210, 0)
	add_child(boss_lbl)

	_cyclops = Sprite2D.new()
	_cyclops.texture  = load(CYCLOPS_TEX)
	_cyclops.hframes  = 2
	_cyclops.frame    = 0
	_cyclops.scale    = SCALE
	_cyclops.position = CYCLOPS_POS
	_cyclops.modulate = Color(1, 1, 1, 0.5)   # dim — "frozen"
	add_child(_cyclops)

	_player = Sprite2D.new()
	_player.texture  = load(PLAYER_TEX)
	_player.hframes  = 2
	_player.frame    = 0
	_player.scale    = SCALE
	_player.position = PLAYER_START
	add_child(_player)

	_boss = Sprite2D.new()
	_boss.texture  = load(BOSS_TEX)
	_boss.hframes  = 2
	_boss.frame    = 0
	_boss.scale    = SCALE * 1.2
	_boss.position = BOSS_POS
	add_child(_boss)

	# Telegraph ring (custom draw node)
	_tel_ring = Node2D.new()
	_tel_ring.position = CYCLOPS_POS
	_tel_ring.visible  = false
	_tel_ring.draw.connect(_draw_telegraph)
	add_child(_tel_ring)

func _draw_telegraph() -> void:
	_tel_ring.draw_arc(
		Vector2.ZERO,
		TELEGRAPH_RAD,
		0, TAU * _tel_fill,
		32,
		Color(0.9, 0.2, 0.2, 0.75),
		3.5
	)
	_tel_ring.draw_circle(Vector2.ZERO, TELEGRAPH_RAD, Color(0.9, 0.2, 0.2, 0.15 * _tel_fill))

func start_loop() -> void:
	_looping = true
	_boss_loop()

func stop_loop() -> void:
	_looping = false

func _boss_loop() -> void:
	while _looping:
		_reset_state()
		await get_tree().create_timer(0.5).timeout
		if not _looping: return

		# Fire 3 ice spears at the boss
		for _i in 3:
			if not _looping: return
			await _fire_spear()
			await get_tree().create_timer(0.45).timeout

		# Boss wobble
		var wobble := create_tween().set_loops(3)
		wobble.tween_property(_boss, "position", BOSS_POS + Vector2(4, 0), 0.06)
		wobble.tween_property(_boss, "position", BOSS_POS - Vector2(4, 0), 0.06)
		wobble.tween_property(_boss, "position", BOSS_POS,                 0.06)
		await wobble.finished

		# Telegraph appears over cyclops position
		_tel_ring.visible = true
		_tel_fill = 0.0
		var tel_tw := create_tween()
		tel_tw.tween_method(func(v: float):
			_tel_fill = v
			_tel_ring.queue_redraw(), 0.0, 1.0, 1.2)
		await tel_tw.finished

		# Player dodges down
		var dodge_tw := create_tween()
		dodge_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		dodge_tw.tween_property(_player, "position", PLAYER_DODGE, 0.4)
		await dodge_tw.finished

		# Flash & cyclops dies
		var flash := create_tween()
		flash.tween_property(_tel_ring, "modulate", Color(1, 1, 1, 1.5), 0.08)
		flash.tween_property(_tel_ring, "modulate", Color(1, 1, 1, 0.0), 0.15)
		await flash.finished
		_tel_ring.visible = false

		var cy_fade := create_tween()
		cy_fade.tween_property(_cyclops, "modulate:a", 0.0, 0.35)
		await cy_fade.finished

		await get_tree().create_timer(3.0).timeout

func _fire_spear() -> void:
	var spear := Sprite2D.new()
	spear.texture  = load(SPEAR_TEX)
	spear.scale    = SCALE * 0.8
	spear.position = PLAYER_START
	spear.rotation = PLAYER_START.angle_to_point(BOSS_POS)
	add_child(spear)
	var tw := create_tween()
	tw.tween_property(spear, "position", BOSS_POS, 0.2)
	await tw.finished
	spear.queue_free()
	# Boss HP chunks down
	var bar_tw := create_tween()
	bar_tw.tween_property(_boss_hp, "value", _boss_hp.value - 10.0, 0.1)

func _reset_state() -> void:
	_player.position  = PLAYER_START
	_cyclops.visible  = true
	_cyclops.modulate = Color(1, 1, 1, 0.5)
	_tel_ring.visible = false
	_tel_ring.modulate = Color.WHITE
	_tel_fill         = 0.0
	_boss.position    = BOSS_POS
	_boss_hp.value    = 100.0
