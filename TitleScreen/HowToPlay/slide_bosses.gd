## slide_bosses.gd
## Diorama: Player centre, Cyclops left (dim, frozen), Boss right.
## Boss dissolves, teleports near cyclops with telegraph, reappears dealing AOE.
## Player dodges. Cyclops caught in AOE fades. 3s pause then reset.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const CYCLOPS_TEX := "res://Textures/Enemy/cyclops.png"
const BOSS_TEX    := "res://Textures/Enemy/giant_amoeba_new.png"
const SPEAR_TEX   := "res://Textures/Items/Weapons/ice_spear.png"
const SHADOW_TEX  := "res://Textures/GUI/blob_shadow.png"
const HEALTH_UNDER := "res://Textures/GUI/healthcircleunderlay.png"
const HEALTH_PROG  := "res://Textures/GUI/healthcircle.png"

const PLAYER_START  := Vector2(320, 180)
const PLAYER_DODGE  := Vector2(480, 180)   # dodge RIGHT away from telegraph
const CYCLOPS_POS   := Vector2(150, 180)
const BOSS_POS      := Vector2(500, 180)
const TELEGRAPH_RAD := 60.0

var _bg:      Node
var _player:  Sprite2D
var _cyclops: Sprite2D
var _cy_shadow: Sprite2D
var _boss:    Sprite2D
var _boss_shadow: Sprite2D

var _boss_bar: TextureProgressBar

var _hp_under: TextureProgressBar

var _tel_ring: Node2D
var _tel_fill: float = 0.0
var _looping:  bool  = false
var _walk_time: float = 0.0
var _player_moving: bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	# ── Boss bar at top ─────────────────────────────────────────────────────
	_boss_bar = TextureProgressBar.new()
	_boss_bar.min_value          = 0
	_boss_bar.max_value          = 100
	_boss_bar.value              = 100
	_boss_bar.size               = Vector2(640, 14)
	_boss_bar.position           = Vector2(0, 0)
	_boss_bar.texture_under      = load("res://Textures/GUI/exp_background.png")
	_boss_bar.texture_progress   = load("res://Textures/GUI/exp_progress_alt2.png")
	_boss_bar.tint_progress      = Color(0.8, 0.0, 0.0, 1.0)
	_boss_bar.nine_patch_stretch = true
	add_child(_boss_bar)

	var boss_lbl := Label.new()
	boss_lbl.text = tr("boss_name_super")
	boss_lbl.add_theme_font_size_override("font_size", 8)
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.size     = Vector2(640, 14)
	boss_lbl.position = Vector2(0, 0)
	add_child(boss_lbl)

	# ── Cyclops (dim — "frozen") ────────────────────────────────────────────
	_cy_shadow = Sprite2D.new()
	_cy_shadow.texture  = load(SHADOW_TEX)
	_cy_shadow.position = CYCLOPS_POS + Vector2(0, 8)
	add_child(_cy_shadow)

	_cyclops = Sprite2D.new()
	_cyclops.texture  = load(CYCLOPS_TEX)
	_cyclops.hframes  = 2
	_cyclops.frame    = 0
	_cyclops.position = CYCLOPS_POS
	_cyclops.modulate = Color(1, 1, 1, 0.5)
	add_child(_cyclops)

	# ── Player HP circle ────────────────────────────────────────────────────
	_hp_under = TextureProgressBar.new()
	_hp_under.min_value          = 0
	_hp_under.max_value          = 100
	_hp_under.value              = 100
	_hp_under.fill_mode          = 5
	_hp_under.texture_under      = load(HEALTH_UNDER)
	_hp_under.texture_progress   = load(HEALTH_PROG)
	_hp_under.texture_filter     = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_under.z_index            = -1
	_hp_under.self_modulate      = Color(1, 1, 1, 0.39)
	_hp_under.size               = Vector2(40, 40)
	add_child(_hp_under)

	# ── Player ──────────────────────────────────────────────────────────────
	var p_shadow = Sprite2D.new()
	p_shadow.texture  = load(SHADOW_TEX)
	p_shadow.position = PLAYER_START + Vector2(0, 8)
	add_child(p_shadow)

	_player = Sprite2D.new()
	_player.texture  = load(PLAYER_TEX)
	_player.hframes  = 2
	_player.frame    = 0
	_player.position = PLAYER_START
	add_child(_player)

	_update_hp_circle(PLAYER_START)

	# ── Boss ────────────────────────────────────────────────────────────────
	_boss_shadow = Sprite2D.new()
	_boss_shadow.texture  = load(SHADOW_TEX)
	_boss_shadow.scale    = Vector2(1.4, 1.4)
	_boss_shadow.position = BOSS_POS + Vector2(0, 12)
	add_child(_boss_shadow)

	_boss = Sprite2D.new()
	_boss.texture  = load(BOSS_TEX)
	_boss.hframes  = 1
	_boss.frame    = 0
	_boss.scale    = Vector2(1.4, 1.4)
	_boss.position = BOSS_POS
	add_child(_boss)

	# ── Telegraph ring ──────────────────────────────────────────────────────
	_tel_ring = Node2D.new()
	_tel_ring.position = CYCLOPS_POS
	_tel_ring.visible  = false
	_tel_ring.draw.connect(_draw_telegraph)
	add_child(_tel_ring)

func _update_hp_circle(pos: Vector2) -> void:
	_hp_under.position = pos - Vector2(36, 36)

func _draw_telegraph() -> void:
	_tel_ring.draw_circle(Vector2.ZERO, TELEGRAPH_RAD, Color(0.9, 0.1, 0.1, 0.18 * _tel_fill))
	_tel_ring.draw_arc(Vector2.ZERO, TELEGRAPH_RAD, 0.0, TAU * _tel_fill, 48,
		Color(1.0, 0.15, 0.15, 0.85), 3.5)

func _process(delta: float) -> void:
	if not _looping: return
	_walk_time += delta
	if _walk_time > 0.3:
		_walk_time -= 0.3
		if _player_moving:
			_player.frame = 1 if _player.frame == 0 else 0

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

		# Ice spear plinks the boss
		for _i in 3:
			if not _looping: return
			await _fire_spear()
			await get_tree().create_timer(0.45).timeout

		if not _looping: return

		# Boss dissolves (shrinks to nothing) — matches real DISSOLVING state
		var dissolve := create_tween()
		dissolve.tween_property(_boss, "scale", Vector2(0.1, 0.1), 1.0)
		await dissolve.finished
		_boss.visible = false
		_boss_shadow.visible = false

		if not _looping: return

		# Boss teleports to cyclops position — telegraph appears
		_tel_ring.position = CYCLOPS_POS
		_tel_ring.visible = true
		_tel_fill = 0.0
		var tel_tw := create_tween()
		tel_tw.tween_method(func(v: float):
			_tel_fill = v
			_tel_ring.queue_redraw(), 0.0, 1.0, 1.4)
		await tel_tw.finished

		if not _looping: return

		# Player dodges RIGHT
		_player_moving = true
		_player.flip_h = true   # facing right
		var dodge_tw := create_tween()
		dodge_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		dodge_tw.tween_method(func(pos: Vector2):
			_player.position = pos
			_update_hp_circle(pos),
			PLAYER_START, PLAYER_DODGE, 0.4)
		await dodge_tw.finished
		_player_moving = false

		if not _looping: return

		# Boss reappears at telegraph position (grows from small) — matches REAPPEARING
		_boss.position = CYCLOPS_POS
		_boss_shadow.position = CYCLOPS_POS + Vector2(0, 12)
		_boss.visible = true
		_boss_shadow.visible = true
		_boss.scale = Vector2(0.1, 0.1)
		var reappear := create_tween()
		reappear.tween_property(_boss, "scale", Vector2(1.4, 1.4), 1.0)
		await reappear.finished

		if not _looping: return

		# Telegraph flashes (AOE damage)
		var flash := create_tween()
		flash.tween_property(_tel_ring, "modulate", Color(2.0, 0.5, 0.5, 1.0), 0.08)
		flash.tween_property(_tel_ring, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.18)
		await flash.finished
		_tel_ring.visible = false

		# Cyclops caught in AOE — fades
		var cy_fade := create_tween().set_parallel(true)
		cy_fade.tween_property(_cyclops,  "modulate:a", 0.0, 0.35)
		cy_fade.tween_property(_cy_shadow,"modulate:a", 0.0, 0.35)
		await cy_fade.finished

		await get_tree().create_timer(3.0).timeout

func _fire_spear() -> void:
	var spear := Sprite2D.new()
	spear.texture  = load(SPEAR_TEX)
	spear.scale    = Vector2(0.8, 0.8)
	spear.position = PLAYER_START
	spear.rotation = PLAYER_START.angle_to_point(BOSS_POS) + deg_to_rad(135)
	add_child(spear)
	var tw := create_tween()
	tw.tween_property(spear, "position", BOSS_POS, 0.2).set_ease(Tween.EASE_IN)
	await tw.finished
	spear.queue_free()
	var bar_tw := create_tween()
	bar_tw.tween_property(_boss_bar, "value", _boss_bar.value - 10.0, 0.12)

func _reset_state() -> void:
	_player.position  = PLAYER_START
	_player.flip_h    = false
	_player.frame     = 0
	_player_moving    = false
	_update_hp_circle(PLAYER_START)
	_cyclops.visible  = true
	_cyclops.modulate = Color(1, 1, 1, 0.5)
	_cy_shadow.visible = true
	_cy_shadow.modulate = Color.WHITE
	_tel_ring.visible = false
	_tel_ring.modulate = Color.WHITE
	_tel_fill         = 0.0
	_boss.position    = BOSS_POS
	_boss.scale       = Vector2(1.4, 1.4)
	_boss.visible     = true
	_boss_shadow.position = BOSS_POS + Vector2(0, 12)
	_boss_shadow.visible = true
	_boss_bar.value   = 100.0
	_hp_under.value   = 100.0
