# SPDX-License-Identifier: GPL-3.0-or-later
## diorama_studio.gd
## Playable staging sandbox and sprite state recorder for How To Play dioramas.
## Can be run standalone directly via F6.
## Allows manual player control (WASD), staging dummy enemies, attacks, and drops,
## recording 20 FPS visual sprite snapshots to JSON under res://TitleScreen/HowToPlay/recordings/,
## and previewing recorded playback directly in-studio.
extends Node2D

const RECORD_FPS: float = 20.0
const FRAME_INTERVAL: float = 1.0 / RECORD_FPS
const STAGE_WIDTH: float = 640.0
const STAGE_HEIGHT: float = 360.0
const RECORDINGS_DIR: String = "res://TitleScreen/HowToPlay/recordings"

# Textures
const TEX_PLAYER: String = "res://Textures/Player/player_sprite.png"
const TEX_SHADOW: String = "res://Textures/GUI/blob_shadow.png"
const TEX_KOBOLD_WEAK: String = "res://Textures/Enemy/kolbold_weak.png"
const TEX_KOBOLD_STRONG: String = "res://Textures/Enemy/kolbold_strong.png"
const TEX_CYCLOPS: String = "res://Textures/Enemy/cyclops.png"
const TEX_JUGGERNAUT: String = "res://Textures/Enemy/juggernaut.png"
const TEX_ICE_SPEAR: String = "res://Textures/Items/Weapons/ice_spear.png"
const TEX_JAVELIN: String = "res://Textures/Items/Weapons/javelin_3_new_attack.png"
const TEX_WHIP: String = "res://Textures/Items/Weapons/Leather_Whip_(projectile).webp"
const TEX_LIGHTNING: String = "res://Textures/Items/Weapons/rod_6_new.png"
const TEX_TORNADO: String = "res://Textures/Items/Weapons/tornado.png"
const TEX_GEM_GREEN: String = "res://Textures/Items/Gems/Gem_green.png"
const TEX_GEM_BLUE: String = "res://Textures/Items/Gems/Gem_blue.png"
const TEX_GEM_RED: String = "res://Textures/Items/Gems/Gem_red.png"
const TEX_MAGNET: String = "res://Textures/Items/XPOrb.png"
const TEX_AMOEBA: String = "res://Textures/Enemy/giant_amoeba_new.png"
const TEX_TELEGRAPH_RING: String = "res://Textures/Effects/telegraph_ring.png"
const TEX_TELEGRAPH_FILL: String = "res://Textures/Effects/telegraph_fill.png"
const TEX_EXPLOSION: String = "res://Textures/Enemy/explosion_pixelfied.png"

# Staging Containers
@onready var _stage: Node2D = %Stage
@onready var _actors: Node2D = %Actors
@onready var _enemies_container: Node2D = %Enemies
@onready var _projectiles_container: Node2D = %Projectiles
@onready var _drops_container: Node2D = %Drops
@onready var _player_node: Node2D = %PlayerDummy
@onready var _player_sprite: Sprite2D = %PlayerSprite
@onready var _player_shadow: Sprite2D = %PlayerShadow

# Preview Player
@onready var _preview_container: Node2D = %PreviewContainer
@onready var _preview_player: Node = %PreviewPlayer

# UI Nodes
@onready var _ui_root: CanvasLayer = %UI
@onready var _side_panel: Control = %SidePanel
@onready var _status_label: Label = %StatusLabel
@onready var _btn_record: Button = %BtnRecord
@onready var _btn_stop: Button = %BtnStop
@onready var _btn_preview: Button = %BtnPreview
@onready var _btn_tools_toggle: Button = %BtnToolsToggle
@onready var _clip_name_edit: LineEdit = %ClipNameEdit
@onready var _duration_option: OptionButton = %DurationOption
@onready var _ai_mode_btn: Button = %BtnAiMode
@onready var _preview_overlay: Control = %PreviewOverlay
@onready var _preview_status_label: Label = %PreviewStatusLabel
@onready var _preview_scrubber: HSlider = %PreviewScrubber
@onready var _preview_frame_label: Label = %PreviewFrameLabel
@onready var _btn_play_pause: Button = %BtnPlayPause
@onready var _recordings_option: OptionButton = %RecordingsOption
@onready var _btn_amoeba: Button = %BtnAmoeba
@onready var _btn_amoeba_attack: Button = %BtnAmoebaAttack
@onready var _check_spawn_on_cursor: CheckBox = %CheckSpawnOnCursor

# Player State
var _player_pos: Vector2 = Vector2(320.0, 180.0)
var _player_speed: float = 75.0
var _player_walk_time: float = 0.0
var _player_facing_right: bool = true

# AI State
var _ai_modes: Array[String] = ["chase", "idle", "circle"]
var _current_ai_mode_idx: int = 0 # default: chase

# Cursor Spawning State
var _spawn_on_cursor: bool = false
var _last_valid_stage_pos: Vector2 = Vector2.ZERO

# Recorder State
var _is_recording: bool = false
var _record_accumulator: float = 0.0
var _record_elapsed: float = 0.0
var _target_duration: float = 4.0
var _recorded_frames: Array = []
var _last_saved_filename: String = ""

# Preview State
var _in_preview_mode: bool = false

func _ready() -> void:
	_ensure_recordings_dir()
	_setup_background()
	_setup_ui_events()
	_reset_player()
	_refresh_recordings_list()
	if _recordings_option.item_count > 0 and _last_saved_filename == "":
		_last_saved_filename = _recordings_option.get_item_text(0)
	_set_status("Ready. WASD to move. Hotkeys: 1-4/9 spawn, Q/E/F/T/R attacks, G telegraph, 5-8 drops, C cursor, Space REC.")

func _ensure_recordings_dir() -> void:
	if not DirAccess.dir_exists_absolute(RECORDINGS_DIR):
		DirAccess.make_dir_recursive_absolute(RECORDINGS_DIR)

func _setup_background() -> void:
	var bg_scene = preload("res://World/background.tscn")
	if bg_scene:
		var bg = bg_scene.instantiate()
		if "pixel_scale" in bg:
			bg.pixel_scale = 1.0
		bg.z_index = -100
		_stage.add_child(bg)
		_stage.move_child(bg, 0)

func _setup_ui_events() -> void:
	# Duration option
	_duration_option.clear()
	_duration_option.add_item("3.0 s", 0)
	_duration_option.add_item("4.0 s", 1)
	_duration_option.add_item("5.0 s", 2)
	_duration_option.add_item("6.0 s", 3)
	_duration_option.select(1) # Default 4.0s
	_target_duration = 4.0
	_duration_option.item_selected.connect(_on_duration_selected)

	# Main recording buttons
	_btn_record.pressed.connect(start_recording)
	_btn_stop.pressed.connect(stop_recording)
	_btn_preview.pressed.connect(toggle_preview)
	_btn_tools_toggle.pressed.connect(_toggle_side_panel)

	# Staging buttons
	%BtnKoboldW.pressed.connect(func(): spawn_enemy("kobold_weak"))
	%BtnKoboldS.pressed.connect(func(): spawn_enemy("kobold_strong"))
	%BtnCyclops.pressed.connect(func(): spawn_enemy("cyclops"))
	%BtnJuggernaut.pressed.connect(func(): spawn_enemy("juggernaut"))
	if has_node("%BtnAmoeba"):
		%BtnAmoeba.pressed.connect(func(): spawn_enemy("amoeba"))

	%BtnGemGreen.pressed.connect(func(): spawn_drop("gem_green"))
	%BtnGemBlue.pressed.connect(func(): spawn_drop("gem_blue"))
	%BtnGemRed.pressed.connect(func(): spawn_drop("gem_red"))
	%BtnMagnet.pressed.connect(func(): spawn_drop("magnet"))

	%BtnSpear.pressed.connect(func(): trigger_attack("ice_spear"))
	%BtnJavelin.pressed.connect(func(): trigger_attack("javelin"))
	%BtnWhip.pressed.connect(func(): trigger_attack("whip"))
	%BtnLightning.pressed.connect(func(): trigger_attack("lightning"))
	%BtnTornado.pressed.connect(func(): trigger_attack("tornado"))
	if has_node("%BtnAmoebaAttack"):
		%BtnAmoebaAttack.pressed.connect(func(): trigger_amoeba_attack())

	if has_node("%CheckSpawnOnCursor"):
		%CheckSpawnOnCursor.toggled.connect(set_spawn_on_cursor)

	_ai_mode_btn.pressed.connect(_cycle_ai_mode)
	%BtnHurt.pressed.connect(hurt_nearest_enemy)
	%BtnKill.pressed.connect(kill_nearest_enemy)
	%BtnClear.pressed.connect(clear_stage)
	%BtnResetPlayer.pressed.connect(_reset_player)

	# Preview controls
	%BtnExitPreview.pressed.connect(func(): set_preview_mode(false))
	_btn_play_pause.pressed.connect(_toggle_preview_playback)
	_preview_scrubber.value_changed.connect(_on_scrubber_changed)
	_preview_player.frame_changed.connect(_on_preview_frame_changed)

	# Recordings dropdown & Load button
	%BtnLoadClip.pressed.connect(_load_selected_recording)

	# Ensure all UI buttons have focus_mode = FOCUS_NONE to not steal WASD input
	_prevent_focus_hijack(_ui_root)

func _prevent_focus_hijack(node: Node) -> void:
	if node is Control:
		if node is Button:
			node.focus_mode = Control.FOCUS_NONE
		elif node is Slider:
			node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_prevent_focus_hijack(child)

func _on_duration_selected(index: int) -> void:
	match index:
		0: _target_duration = 3.0
		1: _target_duration = 4.0
		2: _target_duration = 5.0
		3: _target_duration = 6.0

func _toggle_side_panel() -> void:
	_side_panel.visible = not _side_panel.visible

func _set_status(msg: String) -> void:
	_status_label.text = msg

# ── Staging Input & Process ───────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _in_preview_mode:
		return

	var mouse_g := get_global_mouse_position()
	var mouse_l := _stage.to_local(mouse_g)
	if _is_point_in_stage(mouse_l) and not _is_mouse_over_ui(mouse_g):
		_last_valid_stage_pos = mouse_l

	_process_player_movement(delta)
	_process_enemies(delta)
	_process_projectiles(delta)
	_process_drops(delta)

	if _is_recording:
		_process_recording(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _clip_name_edit and _clip_name_edit.has_focus():
		return

	if _in_preview_mode:
		var exit_preview = false
		if event.is_action_pressed("ui_cancel"):
			exit_preview = true
		elif event is InputEventKey and event.pressed:
			var pk = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if pk == KEY_P or pk == KEY_ESCAPE:
				exit_preview = true
		if exit_preview:
			set_preview_mode(false)
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode

	match code:
		KEY_SPACE:
			if _is_recording:
				stop_recording()
			else:
				start_recording()
			get_viewport().set_input_as_handled()
		KEY_P:
			toggle_preview()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_toggle_side_panel()
			get_viewport().set_input_as_handled()
		KEY_1:
			spawn_enemy("kobold_weak")
			get_viewport().set_input_as_handled()
		KEY_2:
			spawn_enemy("kobold_strong")
			get_viewport().set_input_as_handled()
		KEY_3:
			spawn_enemy("cyclops")
			get_viewport().set_input_as_handled()
		KEY_4:
			spawn_enemy("juggernaut")
			get_viewport().set_input_as_handled()
		KEY_9:
			spawn_enemy("amoeba")
			get_viewport().set_input_as_handled()
		KEY_5:
			spawn_drop("gem_green")
			get_viewport().set_input_as_handled()
		KEY_6:
			spawn_drop("gem_blue")
			get_viewport().set_input_as_handled()
		KEY_7:
			spawn_drop("gem_red")
			get_viewport().set_input_as_handled()
		KEY_8:
			spawn_drop("magnet")
			get_viewport().set_input_as_handled()
		KEY_Q:
			trigger_attack("ice_spear")
			get_viewport().set_input_as_handled()
		KEY_E:
			trigger_attack("javelin")
			get_viewport().set_input_as_handled()
		KEY_F:
			trigger_attack("whip")
			get_viewport().set_input_as_handled()
		KEY_T:
			trigger_attack("lightning")
			get_viewport().set_input_as_handled()
		KEY_R:
			trigger_attack("tornado")
			get_viewport().set_input_as_handled()
		KEY_G:
			trigger_amoeba_attack()
			get_viewport().set_input_as_handled()
		KEY_C:
			toggle_spawn_on_cursor()
			get_viewport().set_input_as_handled()
		KEY_B:
			_cycle_ai_mode()
			get_viewport().set_input_as_handled()
		KEY_H:
			hurt_nearest_enemy()
			get_viewport().set_input_as_handled()
		KEY_K:
			kill_nearest_enemy()
			get_viewport().set_input_as_handled()
		KEY_X:
			clear_stage()
			get_viewport().set_input_as_handled()
		KEY_Z:
			_reset_player()
			get_viewport().set_input_as_handled()

func _process_player_movement(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("right") or Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("left") or Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("down") or Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_action_pressed("up") or Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0

	dir = dir.normalized()

	if dir != Vector2.ZERO:
		_player_pos += dir * _player_speed * delta
		_player_pos.x = clamp(_player_pos.x, 24.0, STAGE_WIDTH - 24.0)
		_player_pos.y = clamp(_player_pos.y, 24.0, STAGE_HEIGHT - 24.0)
		_player_node.position = _player_pos

		if dir.x > 0.05:
			_player_facing_right = true
		elif dir.x < -0.05:
			_player_facing_right = false
		_player_sprite.flip_h = not _player_facing_right # false = faces right in this sprite asset

		_player_walk_time += delta
		if _player_walk_time >= 0.15:
			_player_walk_time = 0.0
			_player_sprite.frame = 1 if _player_sprite.frame == 0 else 0
	else:
		_player_sprite.frame = 0

func _reset_player() -> void:
	_player_pos = Vector2(STAGE_WIDTH * 0.5, STAGE_HEIGHT * 0.5)
	_player_node.position = _player_pos
	_player_sprite.frame = 0
	_player_sprite.flip_h = false
	_player_facing_right = true

func _hurt_player(amount: int = 1) -> void:
	if not _player_sprite:
		return
	var tween = _player_node.create_tween()
	_player_sprite.modulate = Color(2.5, 0.3, 0.3, 1.0)
	tween.tween_property(_player_sprite, "modulate", Color.WHITE, 0.2)

func _is_mouse_over_ui(global_pos: Vector2) -> bool:
	if _side_panel and _side_panel.visible:
		if _side_panel.get_global_rect().has_point(global_pos):
			return true
	var top_bar = _ui_root.get_node_or_null("TopBar") as Control
	if top_bar and top_bar.visible:
		if top_bar.get_global_rect().has_point(global_pos):
			return true
	return false

func _is_point_in_stage(local_pos: Vector2) -> bool:
	return local_pos.x >= 0.0 and local_pos.x <= STAGE_WIDTH and local_pos.y >= 0.0 and local_pos.y <= STAGE_HEIGHT

func _clamp_to_stage(pos: Vector2, margin: float = 24.0) -> Vector2:
	return Vector2(
		clamp(pos.x, margin, STAGE_WIDTH - margin),
		clamp(pos.y, margin, STAGE_HEIGHT - margin)
	)

func _get_player_spawn_offset(dist: float = 80.0) -> Vector2:
	var offset = Vector2.RIGHT * dist if _player_facing_right else Vector2.LEFT * dist
	return _clamp_to_stage(_player_pos + offset)

func _resolve_spawn_pos(explicit_pos: Vector2 = Vector2.ZERO, default_dist: float = 80.0) -> Vector2:
	if explicit_pos != Vector2.ZERO:
		return _clamp_to_stage(explicit_pos)

	var mouse_global := get_global_mouse_position()
	var mouse_local := _stage.to_local(mouse_global)
	var in_stage := _is_point_in_stage(mouse_local)
	var over_ui := _is_mouse_over_ui(mouse_global)

	if _spawn_on_cursor:
		if in_stage and not over_ui:
			return _clamp_to_stage(mouse_local)
		elif _last_valid_stage_pos != Vector2.ZERO:
			return _clamp_to_stage(_last_valid_stage_pos)
		else:
			return _get_player_spawn_offset(default_dist)
	else:
		return _get_player_spawn_offset(default_dist)

func set_spawn_on_cursor(enabled: bool) -> void:
	_spawn_on_cursor = enabled
	if _check_spawn_on_cursor and _check_spawn_on_cursor.button_pressed != enabled:
		_check_spawn_on_cursor.button_pressed = enabled
	_set_status("Spawn mode: %s" % ("ON CURSOR" if _spawn_on_cursor else "FRONT OF PLAYER"))

func toggle_spawn_on_cursor() -> void:
	set_spawn_on_cursor(not _spawn_on_cursor)

# ── Staging Entities & Actions ────────────────────────────────────────────────

func spawn_enemy(type: String, at_pos: Vector2 = Vector2.ZERO) -> Node2D:
	at_pos = _resolve_spawn_pos(at_pos, 80.0)

	var enemy := Node2D.new()
	enemy.position = at_pos
	enemy.set_meta("enemy_type", type)
	enemy.set_meta("is_dead", false)
	enemy.set_meta("walk_timer", 0.0)

	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = load(TEX_SHADOW)
	shadow.position = Vector2(0, 8)
	shadow.z_index = -1
	enemy.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.name = "Body"
	sprite.hframes = 2
	sprite.frame = 0

	var speed := 40.0
	var max_hp := 3

	match type:
		"kobold_weak":
			sprite.texture = load(TEX_KOBOLD_WEAK)
			speed = 38.0
			max_hp = 2
		"kobold_strong":
			sprite.texture = load(TEX_KOBOLD_STRONG)
			speed = 48.0
			max_hp = 4
		"cyclops":
			sprite.texture = load(TEX_CYCLOPS)
			speed = 32.0
			max_hp = 8
		"juggernaut":
			sprite.texture = load(TEX_JUGGERNAUT)
			speed = 28.0
			max_hp = 12
		"amoeba", "giant_amoeba":
			sprite.texture = load(TEX_AMOEBA)
			sprite.hframes = 1
			sprite.scale = Vector2(2.0, 2.0)
			shadow.scale = Vector2(2.0, 2.0)
			shadow.position = Vector2(0, 16)
			speed = 34.0
			max_hp = 50
			enemy.set_meta("is_boss", true)
			enemy.set_meta("boss_state", "chase")
			enemy.set_meta("ability_timer", 8.0)
			enemy.set_meta("state_timer", 0.0)
			enemy.set_meta("target_teleport", Vector2.ZERO)
			enemy.set_meta("telegraph_node", null)
			enemy.set_meta("is_reappearing", false)

	enemy.set_meta("speed", speed)
	enemy.set_meta("hp", max_hp)
	enemy.add_child(sprite)

	_enemies_container.add_child(enemy)
	_set_status("Spawned %s at (%.0f, %.0f)" % [type, at_pos.x, at_pos.y])
	return enemy

func _cycle_ai_mode() -> void:
	_current_ai_mode_idx = (_current_ai_mode_idx + 1) % _ai_modes.size()
	var mode = _ai_modes[_current_ai_mode_idx]
	_ai_mode_btn.text = "AI: %s [B]" % mode.capitalize()
	_set_status("Enemy AI mode set to: %s" % mode.to_upper())

func _process_enemies(delta: float) -> void:
	var mode = _ai_modes[_current_ai_mode_idx]
	for enemy in _enemies_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get_meta("is_dead", false):
			continue

		var spr = enemy.get_node_or_null("Body") as Sprite2D
		if not spr:
			continue

		if enemy.get_meta("is_boss", false) or enemy.get_meta("enemy_type", "") in ["amoeba", "giant_amoeba"]:
			_process_amoeba_boss(enemy, delta, mode)
			continue

		var speed = float(enemy.get_meta("speed", 40.0))
		var move_dir := Vector2.ZERO

		match mode:
			"chase":
				move_dir = enemy.position.direction_to(_player_pos)
			"circle":
				var to_player = enemy.position - _player_pos
				var tangent = Vector2(-to_player.y, to_player.x).normalized()
				move_dir = tangent
			"idle":
				move_dir = Vector2.ZERO

		if move_dir != Vector2.ZERO:
			enemy.position += move_dir * speed * delta
			enemy.position.x = clamp(enemy.position.x, 20.0, STAGE_WIDTH - 20.0)
			enemy.position.y = clamp(enemy.position.y, 20.0, STAGE_HEIGHT - 20.0)
			spr.flip_h = move_dir.x < 0.0

			var wt = float(enemy.get_meta("walk_timer", 0.0)) + delta
			if wt >= 0.2:
				wt = 0.0
				spr.frame = 1 if spr.frame == 0 else 0
			enemy.set_meta("walk_timer", wt)
		else:
			spr.frame = 0

func _process_amoeba_boss(enemy: Node2D, delta: float, ai_mode: String) -> void:
	var spr = enemy.get_node_or_null("Body") as Sprite2D
	var shadow = enemy.get_node_or_null("Shadow") as Sprite2D
	if not spr:
		return

	var bstate = enemy.get_meta("boss_state", "chase")
	var speed = float(enemy.get_meta("speed", 34.0))

	match bstate:
		"chase":
			var move_dir := Vector2.ZERO
			match ai_mode:
				"chase":
					move_dir = enemy.position.direction_to(_player_pos)
				"circle":
					var to_player = enemy.position - _player_pos
					var tangent = Vector2(-to_player.y, to_player.x).normalized()
					move_dir = tangent
				"idle":
					move_dir = Vector2.ZERO

			if move_dir != Vector2.ZERO:
				enemy.position += move_dir * speed * delta
				enemy.position.x = clamp(enemy.position.x, 24.0, STAGE_WIDTH - 24.0)
				enemy.position.y = clamp(enemy.position.y, 24.0, STAGE_HEIGHT - 24.0)
				spr.flip_h = move_dir.x < 0.0

			var wt = float(enemy.get_meta("walk_timer", 0.0)) + delta
			enemy.set_meta("walk_timer", wt)
			var wobble = sin(wt * 6.0) * 0.12
			spr.scale = Vector2(2.0 + wobble, 2.0 - wobble)
			if shadow:
				shadow.scale = Vector2(2.0 + wobble * 0.5, 2.0 - wobble * 0.5)

			var cd = float(enemy.get_meta("ability_timer", 8.0)) - delta
			enemy.set_meta("ability_timer", cd)
			if cd <= 0.0:
				start_amoeba_telegraph(enemy)

		"dissolving":
			var timer = float(enemy.get_meta("state_timer", 0.7)) - delta
			enemy.set_meta("state_timer", timer)
			var dissolve_dur = 0.7
			var ratio = clamp(timer / dissolve_dur, 0.05, 1.0)
			spr.scale = Vector2(2.0, 2.0) * ratio
			if shadow:
				shadow.scale = Vector2(2.0, 2.0) * ratio

			if timer <= 0.0:
				spr.visible = false
				if shadow:
					shadow.visible = false
				enemy.set_meta("boss_state", "telegraphing")
				enemy.set_meta("state_timer", 2.0)
				enemy.set_meta("is_reappearing", false)
				var t_target: Vector2 = enemy.get_meta("target_teleport", _player_pos)
				enemy.position = t_target
				_spawn_amoeba_telegraph(enemy, t_target, 100.0, 2.0)
				_set_status("Amoeba telegraphing! Dodge the circle!")

		"telegraphing":
			var timer = float(enemy.get_meta("state_timer", 2.0)) - delta
			enemy.set_meta("state_timer", timer)
			var tele_dur = 2.0
			var reap_dur = 0.8
			var t_target: Vector2 = enemy.get_meta("target_teleport", enemy.position)
			var telegraph = enemy.get_meta("telegraph_node", null) as Node2D

			var progress = clamp(1.0 - (timer / tele_dur), 0.0, 1.0)
			if is_instance_valid(telegraph):
				var fill = telegraph.get_node_or_null("Fill") as Sprite2D
				var ring = telegraph.get_node_or_null("Ring") as Sprite2D
				if fill:
					var target_scale = (100.0 / 60.0) * progress
					fill.scale = Vector2(target_scale, target_scale)
					fill.modulate = Color(1.0, 0.15 + 0.25 * progress, 0.15, 0.25 + 0.35 * progress)
				if ring:
					ring.modulate = Color(1.0, 0.2, 0.2, 0.7 + 0.25 * sin(timer * 18.0))

			if timer <= reap_dur:
				if not enemy.get_meta("is_reappearing", false):
					enemy.set_meta("is_reappearing", true)
					spr.visible = true
					if shadow:
						shadow.visible = true
					spr.scale = Vector2(0.1, 0.1)
				var reap_prog = clamp(1.0 - (timer / reap_dur), 0.1, 1.0)
				spr.scale = Vector2(2.0, 2.0) * reap_prog
				if shadow:
					shadow.scale = Vector2(2.0, 2.0) * reap_prog

			if timer <= 0.0:
				_execute_amoeba_burst(enemy, telegraph, t_target, 100.0)

func start_amoeba_telegraph(enemy: Node2D, target_pos: Vector2 = Vector2.ZERO) -> void:
	if not enemy or enemy.get_meta("is_dead", false):
		return
	if target_pos == Vector2.ZERO:
		target_pos = _player_pos
	target_pos.x = clamp(target_pos.x, 30.0, STAGE_WIDTH - 30.0)
	target_pos.y = clamp(target_pos.y, 30.0, STAGE_HEIGHT - 30.0)

	# Clean up any active telegraph node to prevent orphaned leaks
	if enemy.has_meta("telegraph_node"):
		var old_tele = enemy.get_meta("telegraph_node") as Node2D
		if is_instance_valid(old_tele):
			old_tele.queue_free()
		enemy.set_meta("telegraph_node", null)

	enemy.set_meta("boss_state", "dissolving")
	enemy.set_meta("state_timer", 0.7)
	enemy.set_meta("target_teleport", target_pos)
	enemy.set_meta("is_reappearing", false)
	_set_status("Amoeba dissolving... Prepare to dodge!")

func _spawn_amoeba_telegraph(enemy: Node2D, at_pos: Vector2, radius: float, _duration: float) -> Node2D:
	var tele := Node2D.new()
	tele.name = "AmoebaTelegraph"
	tele.position = at_pos
	tele.z_index = -1

	var ring := Sprite2D.new()
	ring.name = "Ring"
	ring.texture = load(TEX_TELEGRAPH_RING)
	var ring_scale = radius / 60.0
	ring.scale = Vector2(ring_scale, ring_scale)
	ring.modulate = Color(1.0, 0.2, 0.2, 0.8)
	ring.z_index = 0
	tele.add_child(ring)

	var fill := Sprite2D.new()
	fill.name = "Fill"
	fill.texture = load(TEX_TELEGRAPH_FILL)
	fill.scale = Vector2(0.01, 0.01)
	fill.modulate = Color(1.0, 0.15, 0.15, 0.3)
	fill.z_index = -1
	tele.add_child(fill)

	_projectiles_container.add_child(tele)
	enemy.set_meta("telegraph_node", tele)
	return tele

func _execute_amoeba_burst(enemy: Node2D, telegraph: Node2D, burst_pos: Vector2, radius: float) -> void:
	if is_instance_valid(enemy):
		var spr = enemy.get_node_or_null("Body") as Sprite2D
		var shadow = enemy.get_node_or_null("Shadow") as Sprite2D

		enemy.set_meta("boss_state", "chase")
		enemy.set_meta("state_timer", 0.0)
		enemy.set_meta("ability_timer", 8.0)
		enemy.set_meta("is_reappearing", false)
		enemy.set_meta("telegraph_node", null)

		if spr:
			spr.visible = true
			spr.scale = Vector2(2.0, 2.0)
		if shadow:
			shadow.visible = true
			shadow.scale = Vector2(2.0, 2.0)

	if is_instance_valid(telegraph):
		var fill = telegraph.get_node_or_null("Fill") as Sprite2D
		var ring = telegraph.get_node_or_null("Ring") as Sprite2D
		if fill:
			fill.scale = Vector2(radius / 60.0, radius / 60.0)
			fill.modulate = Color(2.5, 0.5, 0.5, 0.95)
		if ring:
			ring.scale = Vector2((radius / 60.0) * 1.12, (radius / 60.0) * 1.12)
			ring.modulate = Color(2.5, 0.8, 0.8, 1.0)
		var t_tween = telegraph.create_tween()
		t_tween.tween_property(telegraph, "modulate:a", 0.0, 0.22)
		t_tween.tween_callback(telegraph.queue_free)

	var exp := Node2D.new()
	exp.position = burst_pos
	var exp_spr := Sprite2D.new()
	exp_spr.name = "Explosion"
	exp_spr.texture = load(TEX_EXPLOSION)
	exp_spr.scale = Vector2(1.0, 1.0)
	exp_spr.modulate = Color(2.0, 0.4, 0.4, 0.9)
	exp.add_child(exp_spr)
	_projectiles_container.add_child(exp)

	var exp_tween = exp.create_tween()
	exp_tween.tween_property(exp_spr, "scale", Vector2(2.4, 2.4), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exp_tween.parallel().tween_property(exp_spr, "modulate:a", 0.0, 0.25)
	exp_tween.tween_callback(exp.queue_free)

	var player_dist = _player_pos.distance_to(burst_pos)
	if player_dist <= radius:
		_hurt_player(2)
		_set_status("Amoeba BURST hit player! (%.0f px <= %.0f px)" % [player_dist, radius])
	else:
		_set_status("Amoeba BURST dodged! (%.0f px > %.0f px)" % [player_dist, radius])

	for other in _enemies_container.get_children():
		if other != enemy and not other.get_meta("is_dead", false):
			if other.position.distance_to(burst_pos) <= radius:
				hurt_enemy(other, 8)

func trigger_amoeba_attack(target_pos: Vector2 = Vector2.ZERO) -> Node2D:
	if target_pos == Vector2.ZERO:
		if _spawn_on_cursor:
			target_pos = _resolve_spawn_pos()
		else:
			target_pos = _player_pos

	var amoeba: Node2D = null
	var fallback_amoeba: Node2D = null
	for enemy in _enemies_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get_meta("is_dead", false):
			continue
		if enemy.get_meta("enemy_type", "") in ["amoeba", "giant_amoeba"] or enemy.get_meta("is_boss", false):
			if fallback_amoeba == null:
				fallback_amoeba = enemy
			if enemy.get_meta("boss_state", "chase") == "chase":
				amoeba = enemy
				break

	if amoeba == null:
		amoeba = fallback_amoeba

	if amoeba == null:
		var spawn_pos = _player_pos + (Vector2.LEFT * 120.0 if _player_facing_right else Vector2.RIGHT * 120.0)
		amoeba = spawn_enemy("amoeba", spawn_pos)

	start_amoeba_telegraph(amoeba, target_pos)
	return amoeba

func hurt_enemy(enemy: Node2D, amount: int = 1) -> void:
	if not enemy or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get_meta("is_dead", false):
		return
	var hp = int(enemy.get_meta("hp", 1)) - amount
	enemy.set_meta("hp", hp)

	# Flash effect
	var tween = enemy.create_tween()
	enemy.modulate = Color(2.0, 0.4, 0.4, 1.0)
	tween.tween_property(enemy, "modulate", Color.WHITE, 0.18)

	if hp <= 0:
		kill_enemy(enemy)

func kill_enemy(enemy: Node2D) -> void:
	if not enemy or not is_instance_valid(enemy) or (enemy.has_meta("is_dead") and enemy.get_meta("is_dead")):
		return
	enemy.set_meta("is_dead", true)

	if enemy.has_meta("telegraph_node"):
		var tele = enemy.get_meta("telegraph_node") as Node2D
		if is_instance_valid(tele):
			tele.queue_free()
		enemy.set_meta("telegraph_node", null)

	# Drop XP gem on death
	var death_pos = enemy.position
	var is_boss = (enemy.has_meta("is_boss") and enemy.get_meta("is_boss")) or (enemy.has_meta("enemy_type") and enemy.get_meta("enemy_type") in ["amoeba", "giant_amoeba"])
	var gem_type = "gem_red" if is_boss else "gem_green"
	spawn_drop(gem_type, death_pos)

	# Fade out & free
	var tween = enemy.create_tween()
	tween.tween_property(enemy, "modulate:a", 0.0, 0.25)
	tween.tween_callback(enemy.queue_free)

func hurt_nearest_enemy() -> void:
	var nearest = _get_nearest_enemy(_player_pos)
	if nearest:
		hurt_enemy(nearest, 1)
		_set_status("Hurt nearest enemy!")

func kill_nearest_enemy() -> void:
	var nearest = _get_nearest_enemy(_player_pos)
	if nearest:
		kill_enemy(nearest)
		_set_status("Killed nearest enemy!")

func _get_nearest_enemy(from_pos: Vector2) -> Node2D:
	var best_dist := 999999.0
	var best_node: Node2D = null
	for enemy in _enemies_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get_meta("is_dead", false):
			continue
		if enemy.get_meta("is_boss", false):
			var bstate = enemy.get_meta("boss_state", "chase")
			if bstate == "dissolving" or (bstate == "telegraphing" and not enemy.get_meta("is_reappearing", false)):
				continue
		var d = from_pos.distance_squared_to(enemy.position)
		if d < best_dist:
			best_dist = d
			best_node = enemy
	return best_node

func clear_stage() -> void:
	for child in _enemies_container.get_children():
		if child.has_meta("telegraph_node"):
			var tele = child.get_meta("telegraph_node") as Node2D
			if is_instance_valid(tele):
				tele.queue_free()
			child.set_meta("telegraph_node", null)
		child.queue_free()
	for child in _projectiles_container.get_children():
		child.queue_free()
	for child in _drops_container.get_children():
		child.queue_free()
	_set_status("Stage cleared.")

# ── Attacks ───────────────────────────────────────────────────────────────────

func trigger_attack(attack_type: String, target_pos: Vector2 = Vector2.ZERO) -> void:
	if attack_type in ["amoeba_slam", "telegraph", "boss_telegraph"]:
		trigger_amoeba_attack(target_pos)
		return

	if target_pos == Vector2.ZERO:
		if _spawn_on_cursor:
			target_pos = _resolve_spawn_pos(target_pos, 120.0)
		else:
			target_pos = _player_pos + (Vector2.RIGHT * 120.0 if _player_facing_right else Vector2.LEFT * 120.0)

	match attack_type:
		"ice_spear":
			_spawn_ice_spear(target_pos)
		"javelin":
			_spawn_javelin(target_pos)
		"whip":
			_spawn_whip()
		"lightning":
			_spawn_lightning(target_pos)
		"tornado":
			_spawn_tornado(target_pos)

	_set_status("Triggered attack: %s" % attack_type.capitalize())

func _spawn_ice_spear(target_pos: Vector2) -> void:
	var spear := Node2D.new()
	spear.position = _player_pos

	var dir = _player_pos.direction_to(target_pos)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if _player_facing_right else Vector2.LEFT

	var spr := Sprite2D.new()
	spr.texture = load(TEX_ICE_SPEAR)
	spr.rotation = dir.angle() + deg_to_rad(135)
	spear.add_child(spr)

	spear.set_meta("dir", dir)
	spear.set_meta("speed", 240.0)
	spear.set_meta("life", 1.8)
	spear.set_meta("pierce", 1)
	spear.set_meta("hit_enemies", [])
	spear.set_meta("is_projectile", true)
	spear.set_meta("damage", 2)

	_projectiles_container.add_child(spear)

func _spawn_javelin(target_pos: Vector2) -> void:
	var javelin := Node2D.new()
	javelin.position = _player_pos

	var dir = _player_pos.direction_to(target_pos)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if _player_facing_right else Vector2.LEFT

	var spr := Sprite2D.new()
	spr.texture = load(TEX_JAVELIN)
	javelin.add_child(spr)

	javelin.set_meta("dir", dir)
	javelin.set_meta("speed", 200.0)
	javelin.set_meta("spin", 15.0)
	javelin.set_meta("life", 2.2)
	javelin.set_meta("pierce", 99)
	javelin.set_meta("hit_enemies", [])
	javelin.set_meta("is_projectile", true)
	javelin.set_meta("damage", 3)

	_projectiles_container.add_child(javelin)

func _spawn_whip() -> void:
	var whip := Node2D.new()
	var offset = Vector2(36.0, 0.0) if _player_facing_right else Vector2(-36.0, 0.0)
	whip.position = _player_pos + offset

	var spr := Sprite2D.new()
	spr.texture = load(TEX_WHIP)
	spr.flip_h = not _player_facing_right
	spr.scale = Vector2(0.4, 0.4)
	whip.add_child(spr)

	# Whip slash animation
	var tween = whip.create_tween()
	tween.tween_property(spr, "scale", Vector2(1.2, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(spr, "modulate:a", 0.0, 0.15)
	tween.tween_callback(whip.queue_free)

	_projectiles_container.add_child(whip)

	# Damage enemies in whip area
	for enemy in _enemies_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get_meta("is_dead", false):
			continue
		if enemy.get_meta("is_boss", false):
			var bstate = enemy.get_meta("boss_state", "chase")
			if bstate == "dissolving" or (bstate == "telegraphing" and not enemy.get_meta("is_reappearing", false)):
				continue
		if enemy.position.distance_to(whip.position) < 55.0:
			hurt_enemy(enemy, 3)

func _spawn_lightning(target_pos: Vector2) -> void:
	# Strike target pos or nearest enemy
	var strike_pos = target_pos
	var nearest = _get_nearest_enemy(target_pos)
	if nearest and nearest.position.distance_to(target_pos) < 80.0:
		strike_pos = nearest.position

	var bolt := Node2D.new()
	bolt.position = strike_pos

	var spr := Sprite2D.new()
	spr.texture = load(TEX_LIGHTNING)
	spr.scale = Vector2(1.0, 2.0)
	spr.modulate = Color(1.5, 1.5, 0.8, 1.0)
	bolt.add_child(spr)

	var tween = bolt.create_tween()
	tween.tween_property(spr, "modulate:a", 0.0, 0.22)
	tween.tween_callback(bolt.queue_free)

	_projectiles_container.add_child(bolt)

	# Hurt enemies nearby strike
	for enemy in _enemies_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get_meta("is_dead", false):
			continue
		if enemy.get_meta("is_boss", false):
			var bstate = enemy.get_meta("boss_state", "chase")
			if bstate == "dissolving" or (bstate == "telegraphing" and not enemy.get_meta("is_reappearing", false)):
				continue
		if enemy.position.distance_to(strike_pos) < 35.0:
			hurt_enemy(enemy, 4)

func _spawn_tornado(target_pos: Vector2) -> void:
	var tornado := Node2D.new()
	tornado.position = _player_pos

	var dir = _player_pos.direction_to(target_pos)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if _player_facing_right else Vector2.LEFT

	var spr := Sprite2D.new()
	spr.texture = load(TEX_TORNADO)
	tornado.add_child(spr)

	tornado.set_meta("dir", dir)
	tornado.set_meta("speed", 120.0)
	tornado.set_meta("spin", 12.0)
	tornado.set_meta("life", 3.0)
	tornado.set_meta("pierce", 99)
	tornado.set_meta("hit_enemies", [])
	tornado.set_meta("is_projectile", true)
	tornado.set_meta("damage", 1)

	_projectiles_container.add_child(tornado)

func _process_projectiles(delta: float) -> void:
	for proj in _projectiles_container.get_children():
		if not proj.get_meta("is_projectile", false):
			continue

		var dir: Vector2 = proj.get_meta("dir", Vector2.ZERO)
		var speed: float = float(proj.get_meta("speed", 0.0))
		var spin: float = float(proj.get_meta("spin", 0.0))
		var life: float = float(proj.get_meta("life", 1.0)) - delta
		proj.set_meta("life", life)

		proj.position += dir * speed * delta

		var spr: Sprite2D = proj.get_child(0) as Sprite2D if proj.get_child_count() > 0 else null
		if spr and spin != 0.0:
			spr.rotation += spin * delta

		# Collision with dummy enemies
		var dmg = int(proj.get_meta("damage", 1))
		var pierce = int(proj.get_meta("pierce", 1))
		var hit_enemies: Array = proj.get_meta("hit_enemies", [])
		for enemy in _enemies_container.get_children():
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			if enemy.get_meta("is_dead", false):
				continue
			if hit_enemies.has(enemy):
				continue
			if enemy.get_meta("is_boss", false):
				var bstate = enemy.get_meta("boss_state", "chase")
				if bstate == "dissolving" or (bstate == "telegraphing" and not enemy.get_meta("is_reappearing", false)):
					continue
			if enemy.position.distance_to(proj.position) < 22.0:
				hurt_enemy(enemy, dmg)
				hit_enemies.append(enemy)
				pierce -= 1
				proj.set_meta("pierce", pierce)
				proj.set_meta("hit_enemies", hit_enemies)
				if pierce <= 0:
					life = 0.0
					break

		if life <= 0.0 or proj.position.x < -40.0 or proj.position.x > STAGE_WIDTH + 40.0 or proj.position.y < -40.0 or proj.position.y > STAGE_HEIGHT + 40.0:
			proj.queue_free()

# ── Drops & Magnetism ─────────────────────────────────────────────────────────

func spawn_drop(drop_type: String, at_pos: Vector2 = Vector2.ZERO) -> Node2D:
	at_pos = _resolve_spawn_pos(at_pos, 50.0)

	var drop := Node2D.new()
	drop.position = at_pos
	drop.set_meta("drop_type", drop_type)
	drop.set_meta("collected", false)
	drop.set_meta("speed", 0.0)

	var spr := Sprite2D.new()
	spr.name = "Gem"

	match drop_type:
		"gem_green":
			spr.texture = load(TEX_GEM_GREEN)
			spr.scale = Vector2(0.6, 0.6)
		"gem_blue":
			spr.texture = load(TEX_GEM_BLUE)
			spr.scale = Vector2(0.65, 0.65)
		"gem_red":
			spr.texture = load(TEX_GEM_RED)
			spr.scale = Vector2(0.7, 0.7)
		"magnet":
			spr.texture = load(TEX_MAGNET)
			spr.scale = Vector2(0.6, 0.6)

	drop.add_child(spr)

	# Small spawn bounce tween
	var tween = drop.create_tween()
	spr.scale = Vector2(0.2, 0.2)
	tween.tween_property(spr, "scale", Vector2(0.65, 0.65), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_drops_container.add_child(drop)
	_set_status("Spawned drop %s at (%.0f, %.0f)" % [drop_type, at_pos.x, at_pos.y])
	return drop

func _process_drops(delta: float) -> void:
	for drop in _drops_container.get_children():
		if drop.get_meta("collected", false):
			continue

		var dist = drop.position.distance_to(_player_pos)

		# Magnetism trigger radius (60px)
		if dist < 65.0:
			var sp = float(drop.get_meta("speed", 0.0)) + 300.0 * delta
			drop.set_meta("speed", sp)
			drop.position = drop.position.move_toward(_player_pos, sp * delta)

			# Collect radius (12px)
			if dist < 12.0:
				_collect_drop(drop)

func _collect_drop(drop: Node2D) -> void:
	drop.set_meta("collected", true)
	var drop_type = drop.get_meta("drop_type", "gem_green")

	if drop_type == "magnet":
		# Pull all remaining drops towards player
		for other in _drops_container.get_children():
			if not other.get_meta("collected", false):
				other.set_meta("speed", 180.0)

	var spr = drop.get_node_or_null("Gem") as Sprite2D
	if spr:
		var tween = drop.create_tween()
		tween.tween_property(spr, "scale", Vector2(0.1, 0.1), 0.15)
		tween.tween_property(spr, "modulate:a", 0.0, 0.1)
		tween.tween_callback(drop.queue_free)
	else:
		drop.queue_free()

# ── Recorder Engine (20 FPS Snapshotting) ────────────────────────────────────

func start_recording() -> void:
	if _is_recording or _in_preview_mode:
		return

	_is_recording = true
	_record_accumulator = 0.0
	_record_elapsed = 0.0
	_recorded_frames.clear()

	_btn_record.disabled = true
	_btn_stop.disabled = false
	_btn_preview.disabled = true

	# Capture initial frame immediately
	_capture_frame()
	_update_record_status()

func stop_recording() -> void:
	if not _is_recording:
		return

	_is_recording = false
	_btn_record.disabled = false
	_btn_stop.disabled = true
	_btn_preview.disabled = false

	if _recorded_frames.is_empty():
		_set_status("Recording stopped: No frames captured.")
		return

	var clip_name = _clip_name_edit.text.strip_edges()
	if clip_name.is_empty():
		clip_name = "recording_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	if not clip_name.ends_with(".json"):
		clip_name += ".json"

	var saved_path = _save_recording_json(clip_name)
	_last_saved_filename = clip_name
	_refresh_recordings_list()
	_set_status("Saved %d frames (%.1fs) to %s" % [_recorded_frames.size(), _record_elapsed, clip_name])

func _process_recording(delta: float) -> void:
	_record_elapsed += delta
	_record_accumulator += delta

	while _record_accumulator >= FRAME_INTERVAL:
		_record_accumulator -= FRAME_INTERVAL
		_capture_frame()

	_update_record_status()

	if _record_elapsed >= _target_duration:
		stop_recording()

func _update_record_status() -> void:
	_set_status("● REC [%.1fs / %.1fs] (%d frames)" % [_record_elapsed, _target_duration, _recorded_frames.size()])

func _capture_frame() -> void:
	var frame_sprites: Array = []
	_collect_active_sprites(_actors, frame_sprites)
	_recorded_frames.append(frame_sprites)

func _collect_active_sprites(parent: Node, out_list: Array) -> void:
	for child in parent.get_children():
		if child is Sprite2D:
			var spr := child as Sprite2D
			if spr.visible and spr.is_visible_in_tree() and spr.texture != null:
				var path := spr.texture.resource_path
				if path != "":
					var eff_mod := _get_effective_modulate(spr)
					if eff_mod.a > 0.005:
						var local_pos := _stage.to_local(spr.global_position)
						out_list.append({
							"texture": path,
							"pos": [snapped(local_pos.x, 0.1), snapped(local_pos.y, 0.1)],
							"rotation": snapped(spr.global_rotation, 0.001),
							"scale": [snapped(spr.global_scale.x, 0.01), snapped(spr.global_scale.y, 0.01)],
							"frame": spr.frame,
							"hframes": spr.hframes,
							"vframes": spr.vframes,
							"flip_h": spr.flip_h,
							"flip_v": spr.flip_v,
							"modulate": [snapped(eff_mod.r, 0.01), snapped(eff_mod.g, 0.01), snapped(eff_mod.b, 0.01), snapped(eff_mod.a, 0.01)],
							"z_index": _get_effective_z_index(spr)
						})
		# Recursively search child nodes (e.g. enemy containers)
		if child.get_child_count() > 0:
			_collect_active_sprites(child, out_list)

func _get_effective_modulate(item: CanvasItem) -> Color:
	var color := item.modulate * item.self_modulate
	var cur: Node = item.get_parent()
	while cur and cur != _stage and cur != self:
		if cur is CanvasItem:
			color *= cur.modulate
		cur = cur.get_parent()
	return color

func _get_effective_z_index(item: CanvasItem) -> int:
	var z: int = item.z_index
	if not item.z_as_relative:
		return z
	var cur: Node = item.get_parent()
	while cur and cur != _stage and cur != self:
		if cur is CanvasItem:
			var c_item := cur as CanvasItem
			z += c_item.z_index
			if not c_item.z_as_relative:
				break
		cur = cur.get_parent()
	return z

func _save_recording_json(filename: String) -> String:
	_ensure_recordings_dir()
	var file_path = RECORDINGS_DIR.path_join(filename)

	var payload := {
		"version": 1,
		"fps": RECORD_FPS,
		"duration": snapped(_record_elapsed, 0.01),
		"frame_count": _recorded_frames.size(),
		"stage_size": [int(STAGE_WIDTH), int(STAGE_HEIGHT)],
		"frames": _recorded_frames
	}

	var json_str = JSON.stringify(payload, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
	else:
		push_error("DioramaStudio: failed to write recording to: %s" % file_path)

	return file_path

# ── Preview Playback Mode ────────────────────────────────────────────────────

func toggle_preview() -> void:
	set_preview_mode(not _in_preview_mode)

func set_preview_mode(active: bool) -> void:
	if active == _in_preview_mode:
		return

	if active:
		# If no frames captured in memory, try loading last saved or selected file
		if _recorded_frames.is_empty():
			if _last_saved_filename == "" and _recordings_option.item_count > 0:
				_last_saved_filename = _recordings_option.get_item_text(_recordings_option.selected)
			if _last_saved_filename != "":
				var p = RECORDINGS_DIR.path_join(_last_saved_filename)
				if FileAccess.file_exists(p):
					_preview_player.load_recording(p)
			if _preview_player.get_frame_count() == 0:
				_set_status("No recording to preview. Record a clip first [Space] or load from disk.")
				return

		_in_preview_mode = true
		_actors.visible = false
		_preview_container.visible = true
		_preview_overlay.visible = true

		if not _recorded_frames.is_empty():
			var payload := {
				"version": 1,
				"fps": RECORD_FPS,
				"duration": snapped(_record_elapsed, 0.01),
				"frame_count": _recorded_frames.size(),
				"stage_size": [int(STAGE_WIDTH), int(STAGE_HEIGHT)],
				"frames": _recorded_frames
			}
			_preview_player.load_recording_data(payload)

		_preview_scrubber.max_value = max(1, _preview_player.get_frame_count() - 1)
		_preview_player.loop = true
		_preview_player.loop_delay = 1.0
		_preview_player.start_loop()
		_btn_play_pause.text = "Pause"
		_set_status("In Preview Mode. Replaying diorama loop. Press [P] or Exit to return.")
	else:
		_in_preview_mode = false
		_preview_player.stop_loop()
		_preview_container.visible = false
		_preview_overlay.visible = false
		_actors.visible = true
		_set_status("Exited Preview. Staging active.")

func _toggle_preview_playback() -> void:
	if _preview_player.is_playing():
		_preview_player.pause()
		_btn_play_pause.text = "Play"
	else:
		_preview_player.play()
		_btn_play_pause.text = "Pause"

func _on_scrubber_changed(val: float) -> void:
	if not _preview_player.is_playing():
		_preview_player.seek_frame(int(val))

func _on_preview_frame_changed(curr: int, total: int) -> void:
	_preview_scrubber.set_value_no_signal(curr)
	_preview_frame_label.text = "%d / %d" % [curr + 1, total]

# ── Load Existing Recordings ─────────────────────────────────────────────────

func _refresh_recordings_list() -> void:
	_recordings_option.clear()
	var dir = DirAccess.open(RECORDINGS_DIR)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_recordings_option.add_item(file_name, count)
			if file_name == _last_saved_filename:
				_recordings_option.select(count)
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_selected_recording() -> void:
	if _recordings_option.item_count == 0:
		_set_status("No recordings available to load.")
		return

	var selected_name = _recordings_option.get_item_text(_recordings_option.selected)
	var full_path = RECORDINGS_DIR.path_join(selected_name)
	_last_saved_filename = selected_name
	_clip_name_edit.text = selected_name.replace(".json", "")

	set_preview_mode(true)
	_preview_player.load_recording(full_path)
	_preview_scrubber.max_value = max(1, _preview_player.get_frame_count() - 1)
	_preview_player.start_loop()
	_set_status("Loaded & previewing: %s" % selected_name)
