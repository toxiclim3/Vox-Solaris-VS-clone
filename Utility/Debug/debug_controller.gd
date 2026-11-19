class_name DebugController
extends Node

const PRESET_SAVE_PATH := "user://debug_presets.cfg"
const TIME_SCALES := [0.25, 0.5, 1.0, 2.0, 4.0]

var telemetry: PanelContainer = null
var visualizer: Node2D = null
var workbench: PanelContainer = null
var switcher: PanelContainer = null

var gui_ref: Node = null
var world_ref: Node = null

var is_frozen_by_debug: bool = false
var _waiting_for_step: bool = false
var _step_physics_ran: bool = false

func _init() -> void:
	name = "DebugController"
	process_mode = Node.PROCESS_MODE_ALWAYS

func attach(gui_root: Node, world_root: Node = null) -> void:
	gui_ref = gui_root
	world_ref = world_root

	if telemetry == null or not is_instance_valid(telemetry):
		telemetry = load("res://Utility/Debug/debug_telemetry.gd").new()
		var t_parent := gui_root if gui_root and is_instance_valid(gui_root) else self
		t_parent.add_child(telemetry)

	if workbench == null or not is_instance_valid(workbench):
		workbench = load("res://Utility/Debug/debug_workbench.gd").new()
		var w_parent := gui_root if gui_root and is_instance_valid(gui_root) else self
		w_parent.add_child(workbench)
		workbench.setup(self)

	if visualizer == null or not is_instance_valid(visualizer):
		visualizer = load("res://Utility/Debug/debug_visualizer.gd").new()
		var v_parent := world_root
		if v_parent == null or not is_instance_valid(v_parent):
			var p := _get_player()
			if p and p.get_parent():
				v_parent = p.get_parent()
			elif get_tree() and get_tree().current_scene:
				v_parent = get_tree().current_scene
			else:
				v_parent = self
		v_parent.add_child(visualizer)

func _physics_process(_delta: float) -> void:
	if _waiting_for_step:
		_step_physics_ran = true

func _process(_delta: float) -> void:
	if _waiting_for_step and _step_physics_ran:
		_waiting_for_step = false
		_step_physics_ran = false
		if get_tree():
			get_tree().paused = true
		if telemetry and telemetry.visible:
			telemetry.refresh_now()

func _get_player() -> Node:
	if world_ref and is_instance_valid(world_ref) and not world_ref.is_queued_for_deletion():
		var wp := world_ref.get_node_or_null("Player")
		if wp and is_instance_valid(wp) and not wp.is_queued_for_deletion():
			return wp
	if not get_tree():
		return null
	for p in get_tree().get_nodes_in_group("player"):
		if p and is_instance_valid(p) and not p.is_queued_for_deletion():
			return p
	return null

func _get_spawner() -> Node:
	if not get_tree():
		return null
	var sp := get_tree().get_first_node_in_group("spawner")
	if sp == null and world_ref and is_instance_valid(world_ref):
		sp = world_ref.get_node_or_null("EnemySpawner")
	return sp

func _get_swarm_manager() -> Node:
	if not get_tree():
		return null
	var sm := get_tree().get_first_node_in_group("swarm_manager")
	if sm == null:
		var sp := _get_spawner()
		if sp:
			sm = sp.get("swarm_manager")
	return sm

func _get_world_root() -> Node:
	if world_ref and is_instance_valid(world_ref):
		return world_ref
	var p := _get_player()
	if p and p.get_parent():
		return p.get_parent()
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	return get_parent()

func _taint() -> void:
	StatsManager.mark_run_tainted()

static func get_effective_keycode(kev: InputEventKey) -> int:
	var code: int = kev.physical_keycode if kev.physical_keycode != 0 else kev.keycode
	match code:
		KEY_KP_0: return KEY_0
		KEY_KP_1: return KEY_1
		KEY_KP_2: return KEY_2
		KEY_KP_3: return KEY_3
		KEY_KP_4: return KEY_4
		KEY_KP_5: return KEY_5
		KEY_KP_6: return KEY_6
		KEY_KP_7: return KEY_7
		KEY_KP_8: return KEY_8
		KEY_KP_9: return KEY_9
		KEY_KP_ADD: return KEY_EQUAL
		KEY_KP_SUBTRACT: return KEY_MINUS
	return code

func handle_key_event(event: InputEvent) -> bool:
	if not SettingsManager.is_debug_enabled():
		return false
	if event is InputEventMouseButton:
		var mev := event as InputEventMouseButton
		if mev.pressed and mev.button_index == MOUSE_BUTTON_XBUTTON2:
			toggle_freeze()
			return true
		return false
	if not (event is InputEventKey):
		return false
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return false

	match get_effective_keycode(kev):
		KEY_F1:
			toggle_workbench()
			return true
		KEY_F2:
			toggle_telemetry()
			return true
		KEY_F3:
			toggle_visualizer()
			return true
		KEY_F4:
			toggle_freeze()
			return true
		KEY_F5:
			toggle_switcher()
			return true
		KEY_PERIOD:
			var focus := get_viewport().gui_get_focus_owner() if get_viewport() else null
			if focus is LineEdit or focus is TextEdit:
				return false
			var is_paused := (get_tree() and get_tree().paused) or is_frozen_by_debug
			if not is_paused:
				return false
			step_one_physics_frame()
			return true
	return false

# --- Overlay / Modal Controls ---

func toggle_switcher() -> void:
	if switcher == null or not is_instance_valid(switcher):
		switcher = load("res://Tools/TestRooms/test_room_switcher.gd").new()
		var s_parent := gui_ref if gui_ref and is_instance_valid(gui_ref) else self
		s_parent.add_child(switcher)
	_taint()
	switcher.toggle_modal()

func toggle_workbench() -> void:
	if workbench == null or not is_instance_valid(workbench):
		return
	_taint()
	workbench.toggle_modal()

func open_workbench_tab(tab_idx: int) -> void:
	if workbench == null or not is_instance_valid(workbench):
		return
	_taint()
	workbench.open_modal()
	workbench.switch_tab(tab_idx)

func toggle_telemetry() -> void:
	if telemetry == null or not is_instance_valid(telemetry):
		return
	telemetry.visible = not telemetry.visible
	if telemetry.visible:
		telemetry.refresh_now()

func toggle_visualizer() -> void:
	if visualizer == null or not is_instance_valid(visualizer):
		return
	visualizer.set_visualizer_enabled(not visualizer.visible)

func reset_dps_meter() -> void:
	if telemetry and is_instance_valid(telemetry):
		telemetry.reset_meter()

# --- Simulation / Time / Freeze Controls ---

func set_time_scale(scale_val: float) -> void:
	_taint()
	Engine.time_scale = clampf(scale_val, 0.1, 10.0)
	if telemetry and telemetry.visible:
		telemetry.refresh_now()

func advance_time_synced(seconds: int, spawn_crossed_bosses: bool = true) -> void:
	_taint()
	var prev_time: int = int(GlobalEvents.time)
	var new_time: int = max(0, prev_time + seconds)
	GlobalEvents.time = new_time

	var p := _get_player()
	if p and is_instance_valid(p):
		p.set("time", new_time)
	if gui_ref and is_instance_valid(gui_ref) and gui_ref.has_method("update_timer"):
		gui_ref.update_timer(new_time)

	var bg_int: int = max(1, int(GlobalEvents.backgroundInterval))
	var prev_bg := int(floor(float(prev_time) / float(bg_int)))
	var new_bg := int(floor(float(new_time) / float(bg_int)))
	if new_bg > prev_bg:
		GlobalEvents.advanceBackground.emit()

	var spawner := _get_spawner()
	if spawner and is_instance_valid(spawner):
		spawner.emit_signal("changetime", new_time)
		if spawn_crossed_bosses:
			var b_int: int = int(spawner.get("boss_spawn_interval")) if spawner.get("boss_spawn_interval") != null else int(GlobalEvents.bossInterval)
			if b_int > 0:
				var prev_bosses := int(floor(float(prev_time) / float(b_int)))
				var new_bosses := int(floor(float(new_time) / float(b_int)))
				for _b in range(max(0, new_bosses - prev_bosses)):
					if spawner.has_method("force_queue_boss"):
						spawner.force_queue_boss()

func toggle_freeze() -> void:
	_taint()
	_waiting_for_step = false
	_step_physics_ran = false
	is_frozen_by_debug = not get_tree().paused if get_tree() else not is_frozen_by_debug
	if get_tree():
		get_tree().paused = is_frozen_by_debug
	if telemetry and telemetry.visible:
		telemetry.refresh_now()

func step_one_physics_frame() -> void:
	_taint()
	is_frozen_by_debug = true
	_step_physics_ran = false
	_waiting_for_step = true
	if get_tree():
		get_tree().paused = false

# --- Player State & Progression Actions ---

func toggle_godmode() -> void:
	var p := _get_player()
	if p and is_instance_valid(p):
		set_godmode(not bool(p.get("godmode")))

func set_godmode(enabled: bool) -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p):
		p.set("godmode", enabled)

func toggle_spawns() -> void:
	var spawner := _get_spawner()
	if spawner and is_instance_valid(spawner):
		set_spawns_active(not bool(spawner.get("isSpawningActive")))

func set_spawns_active(enabled: bool) -> void:
	_taint()
	if enabled:
		GlobalEvents.enableSpawns.emit()
	else:
		GlobalEvents.disableSpawns.emit()

func give_xp(amount: int = 1000) -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p) and p.has_method("calculate_experience"):
		p.calculate_experience(amount)

func give_level() -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p) and p.has_method("calculate_experiencecap") and p.has_method("calculate_experience"):
		var cap: int = int(p.calculate_experiencecap())
		var cur: int = int(p.get("experience"))
		var needed: int = max(1, cap - cur)
		p.calculate_experience(needed)

func set_hp_percent(pct: float) -> void:
	_taint()
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	var ratio := pct / 100.0 if pct > 1.0 else pct
	ratio = clampf(ratio, 0.0, 1.0)
	var mhp := float(p.get("maxhp"))
	var target_hp := 0.0 if ratio <= 0.0 else maxf(1.0, mhp * ratio)
	if p.has_method("_set_hp"):
		p._set_hp(target_hp)
	else:
		p.set("hp", target_hp)

func trigger_attacker_self_damage(dmg: float = 10.0) -> void:
	_taint()
	var p := _get_player() as Node2D
	if p == null or not is_instance_valid(p):
		return

	var best_attacker: Node = null
	var best_dist_sq := INF
	if get_tree():
		for e in get_tree().get_nodes_in_group("enemy"):
			if e == null or not is_instance_valid(e) or e.is_queued_for_deletion():
				continue
			if e.get("is_dying") == true:
				continue
			if e is Node2D:
				var dsq := p.global_position.distance_squared_to((e as Node2D).global_position)
				if dsq < best_dist_sq:
					best_dist_sq = dsq
					best_attacker = e

	if best_attacker == null:
		best_attacker = spawn_target_dummy(false, p.global_position + Vector2(64.0, 0.0))

	var dir := Vector2.LEFT
	if best_attacker is Node2D:
		dir = (best_attacker as Node2D).global_position.direction_to(p.global_position)
		if dir == Vector2.ZERO:
			dir = Vector2.LEFT

	if p.has_method("_on_hurt_box_hurt"):
		p._on_hurt_box_hurt(dmg, dir, 60.0, "DebugAttacker", best_attacker, 1.0)

func reset_item_cooldowns() -> void:
	_taint()
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	p.set("warding_brooch_timer", 0.0)
	if int(p.get("warding_brooch_level")) > 0:
		p.set("warding_brooch_charge", true)
	p.set("impact_buckler_cooldown", 0.0)
	p.set("buckler_triggered", false)
	if p.get("mobility_cooldown") != null:
		p.set("mobility_cooldown", 0.0)
	if p.get("rock_stance_burst_icd") != null:
		p.set("rock_stance_burst_icd", 0.0)

	var hurt_box := p.get_node_or_null("HurtBox")
	if hurt_box:
		var dt := hurt_box.get_node_or_null("DisableTimer") as Timer
		if dt:
			dt.stop()
			hurt_box.call_deferred("set", "monitoring", true)

func set_item_tier(base_name: String, tier: int) -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p) and p.has_method("set_item_tier"):
		p.set_item_tier(base_name, tier)

func adjust_endless_stacks(base_name: String, delta: int) -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p) and p.has_method("set_endless_stacks"):
		var cur := int(p.collected_endless.get(base_name, 0)) if p.get("collected_endless") is Dictionary else 0
		p.set_endless_stacks(base_name, max(0, cur + delta))

func max_all_equipped() -> void:
	_taint()
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	var max_tiers: Dictionary = {}
	for uid in UpgradeDb.UPGRADES.keys():
		var data: Dictionary = UpgradeDb.UPGRADES[uid]
		if data.get("type", "") in ["item", "endless"]:
			continue
		var base: String = uid.rstrip("0123456789")
		var t: int = int(uid.right(uid.length() - base.length())) if uid.length() > base.length() else 1
		max_tiers[base] = maxi(int(max_tiers.get(base, 0)), t)

	var owned_bases: Array[String] = []
	for uid in p.get("collected_upgrades"):
		var b: String = uid.trim_suffix("_endless").rstrip("0123456789")
		if not owned_bases.has(b):
			owned_bases.append(b)
	for b in owned_bases:
		if max_tiers.has(b) and p.has_method("set_item_tier"):
			p.set_item_tier(b, int(max_tiers[b]))

func reset_all_upgrades() -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p) and p.has_method("reset_all_upgrades"):
		p.reset_all_upgrades()

func switch_character(char_id: String, grant_starter: bool = true) -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p) and p.has_method("switch_character_mid_run"):
		p.switch_character_mid_run(char_id, grant_starter)

func set_camera_zoom(zoom_val: float) -> void:
	var p := _get_player()
	if p and is_instance_valid(p):
		var cam := p.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.zoom = Vector2(zoom_val, zoom_val)

func set_movement_coupled(enabled: bool) -> void:
	_taint()
	GlobalEvents.set_movement_coupled(enabled)
	if telemetry and telemetry.visible:
		telemetry.refresh_now()

func set_movement_config_value(key: String, value: Variant) -> void:
	_taint()
	GlobalEvents.set_movement_config_value(key, value)
	if key == "base_movement_speed":
		var p := _get_player()
		if p and is_instance_valid(p):
			p.set("base_movement_speed", float(value))
			if p.has_method("apply_stat_modifiers"):
				p.apply_stat_modifiers()
	if telemetry and telemetry.visible:
		telemetry.refresh_now()

func reset_movement_config() -> void:
	_taint()
	GlobalEvents.reset_movement_config()
	var p := _get_player()
	if p and is_instance_valid(p):
		p.set("base_movement_speed", float(GlobalEvents.MOVEMENT_CONFIG.get("base_movement_speed", 85.0)))
		if p.has_method("apply_stat_modifiers"):
			p.apply_stat_modifiers()
	if telemetry and telemetry.visible:
		telemetry.refresh_now()

# --- Sandbox Entities & World Actions ---

func spawn_target_dummy(retaliating: bool = false, custom_pos: Vector2 = Vector2(INF, INF)) -> EnemyBody:
	_taint()
	var p := _get_player() as Node2D
	var world := _get_world_root()
	if world == null:
		return null

	var dummy: EnemyBody = load("res://Utility/Debug/target_dummy.gd").new()
	dummy.retaliate_enabled = retaliating
	if custom_pos.x < INF:
		dummy.global_position = custom_pos
	elif p and is_instance_valid(p):
		var count_existing := get_tree().get_node_count_in_group("target_dummy") if get_tree() else 0
		var angle := float(count_existing) * 0.85
		dummy.global_position = p.global_position + Vector2.RIGHT.rotated(angle) * 72.0
	world.add_child(dummy)
	return dummy

func clear_target_dummies() -> void:
	if not get_tree():
		return
	for d in get_tree().get_nodes_in_group("target_dummy"):
		if d and is_instance_valid(d):
			d.queue_free()

func spawn_boss_now(boss_path: String = "") -> void:
	_taint()
	if boss_path == "":
		var sp := _get_spawner()
		if sp and sp.get("spawns_super") is Array and sp.spawns_super.size() > 0:
			var info = sp.spawns_super[0]
			if info and info.get("enemy"):
				boss_path = info.enemy.resource_path
		if boss_path == "":
			boss_path = "res://Enemy/Boss/enemy_super.tscn"
	GlobalEvents.queue_boss.emit(boss_path)

func show_boss_warning() -> void:
	GlobalEvents.emit_signal("show_boss_warning", GlobalEvents.boss_warnings.get("generic", "warning_boss_generic"))

func spawn_debug_wave(pool_type: String = "normal", count: int = 25, formation: String = "ring") -> void:
	_taint()
	var spawner := _get_spawner()
	var p := _get_player() as Node2D
	if spawner == null or not is_instance_valid(spawner) or p == null or not is_instance_valid(p):
		return

	var pool: Array = []
	match pool_type:
		"easy": pool = spawner.get("spawns_easy")
		"hard": pool = spawner.get("spawns_hard")
		_: pool = spawner.get("spawns_normal")
	if not (pool is Array) or pool.is_empty():
		return
	var enemy_info = pool.pick_random()
	if enemy_info == null or enemy_info.get("enemy") == null:
		return

	var positions: Array[Vector2] = []
	var forward: Vector2 = p.get("last_movement") if p.get("last_movement") is Vector2 and p.get("last_movement") != Vector2.ZERO else Vector2.RIGHT
	var base_ang := forward.angle()
	for i in range(max(1, count)):
		var offset := Vector2.ZERO
		match formation:
			"front":
				var ang := base_ang + randf_range(-0.65, 0.65)
				offset = Vector2.RIGHT.rotated(ang) * randf_range(105.0, 175.0)
			"surround":
				var ang := (float(i) / float(max(1, count))) * TAU + randf_range(-0.08, 0.08)
				offset = Vector2.RIGHT.rotated(ang) * randf_range(75.0, 110.0)
			_:
				var ang := (float(i) / float(max(1, count))) * TAU + randf_range(-0.1, 0.1)
				offset = Vector2.RIGHT.rotated(ang) * randf_range(160.0, 220.0)
		positions.append(p.global_position + offset)

	var sm := _get_swarm_manager()
	var is_swarm := (pool_type == "easy" or pool_type == "normal") and sm != null
	if is_swarm:
		var template: Node = enemy_info.enemy.instantiate()
		var p_sprite := template.get_node_or_null("EnemyBase/Sprite2D") as Sprite2D
		var tex: Texture2D = p_sprite.texture if p_sprite else null
		var hframes: int = p_sprite.hframes if p_sprite else 1
		var vframes: int = p_sprite.vframes if p_sprite else 1
		var type_id: int = sm.register_enemy_type(tex, 12.0, hframes, vframes)
		var final_hp: int = max(1, int(float(template.hp) * GlobalEvents.get_enemy_hp_modifier()))
		var spd: float = float(template.get("movement_speed"))
		if spd <= 0.0:
			spd = 45.0
		var exp_val: int = int(template.experience)
		var dmg_val: int = int(template.enemy_damage)
		template.queue_free()
		for pos in positions:
			sm.add_enemy(pos, final_hp, final_hp, spd, exp_val, dmg_val, type_id)
	else:
		var hp_mod := GlobalEvents.get_enemy_hp_modifier()
		for pos in positions:
			var enemy_inst: Node2D = enemy_info.enemy.instantiate()
			if hp_mod != 1.0 and enemy_inst.get("hp") != null:
				enemy_inst.hp = max(1, int(float(enemy_inst.hp) * hp_mod))
			enemy_inst.global_position = pos
			spawner.add_child(enemy_inst)

func clear_all_enemies() -> void:
	_taint()
	var sm := _get_swarm_manager()
	if sm and is_instance_valid(sm):
		if sm.get("swarm_data") is Array:
			sm.swarm_data.clear()
		if sm.get("spatial_grid") is Dictionary:
			sm.spatial_grid.clear()
		if sm.has_method("_update_multimeshes"):
			sm._update_multimeshes()
	if get_tree():
		for e in get_tree().get_nodes_in_group("enemy"):
			if e == null or not is_instance_valid(e):
				continue
			if e.is_in_group("target_dummy"):
				continue
			e.queue_free()

func magnet_all_gems() -> void:
	_taint()
	var p := _get_player()
	if p == null or not is_instance_valid(p) or not get_tree():
		return
	for item in get_tree().get_nodes_in_group("loot"):
		if item and is_instance_valid(item):
			if "target" in item:
				item.target = p
			for ch in item.get_children():
				if ch and is_instance_valid(ch) and "target" in ch:
					ch.target = p

# --- Audio & Run Flow Actions ---

func next_normal_track() -> void:
	if MusicController.is_audio_functional:
		MusicController.unlockMusic()
		MusicController.playNext(MusicController.MusicType.NORMAL)

func next_boss_track() -> void:
	if MusicController.is_audio_functional:
		MusicController.playNext(MusicController.MusicType.BOSS)

func pause_music() -> void:
	if MusicController.is_audio_functional:
		MusicController.fadeOutToSilence()

func unpause_music() -> void:
	if MusicController.is_audio_functional:
		MusicController.fadeInFromSilence()

func kill_player() -> void:
	_taint()
	var p := _get_player()
	if p and is_instance_valid(p):
		p.set("godmode", false)
		if p.has_method("death"):
			p.death()

func end_run_to_menu() -> void:
	_taint()
	Engine.time_scale = 1.0
	if gui_ref and is_instance_valid(gui_ref) and gui_ref.has_method("_on_btn_end_run_click_end"):
		gui_ref._on_btn_end_run_click_end()

func exit_game() -> void:
	if get_tree():
		get_tree().quit()

# --- Presets (Built-in & Custom Config Slots) ---

func _apply_item_map(items: Dictionary, endless_map: Dictionary = {}) -> void:
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	if p.has_method("reset_all_upgrades"):
		p.reset_all_upgrades()
	for base_name in items.keys():
		if p.has_method("set_item_tier"):
			p.set_item_tier(base_name, int(items[base_name]))
	for base_name in endless_map.keys():
		if p.has_method("set_endless_stacks"):
			p.set_endless_stacks(base_name, int(endless_map[base_name]))

func _set_player_level_direct(target_lvl: int) -> void:
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	p.set("experience_level", max(1, target_lvl))
	p.set("experience", 0)
	if p.has_method("apply_stat_modifiers"):
		p.apply_stat_modifiers()
	if gui_ref and is_instance_valid(gui_ref):
		if gui_ref.has_method("set_level_text"):
			gui_ref.set_level_text(p.get("experience_level"))
		if gui_ref.has_method("set_expbar") and p.has_method("calculate_experiencecap"):
			gui_ref.set_expbar(p.get("experience"), p.calculate_experiencecap())

func _set_time_exact(target_seconds: int) -> void:
	var delta_t: int = target_seconds - int(GlobalEvents.time)
	advance_time_synced(delta_t, false)

func apply_preset(preset_id: String) -> void:
	_taint()
	match preset_id:
		"early_min5":
			_set_time_exact(300)
			_apply_item_map({
				"icespear": 4,
				"tome": 2,
				"speed": 2,
			})
			_set_player_level_direct(12)
		"mid_min10":
			_set_time_exact(600)
			_apply_item_map({
				"icespear": 4,
				"tornado": 4,
				"lightningrod": 3,
				"tome": 4,
				"armor": 2,
				"speed": 2,
			})
			_set_player_level_direct(25)
		"endgame_min15":
			_set_time_exact(900)
			_apply_item_map({
				"icespear": 4,
				"tornado": 4,
				"lightningrod": 4,
				"poisonbottle": 4,
				"ritualcircle": 4,
				"whip": 4,
				"tome": 4,
				"scroll": 4,
				"armor": 4,
				"ringofaffinity": 4,
				"glasstalisman": 4,
				"wardingbrooch": 3,
			}, {"icespear": 3})
			_set_player_level_direct(45)
		"punished_tank":
			switch_character("punished", false)
			_set_time_exact(420)
			_apply_item_map({
				"whip": 4,
				"armor": 4,
				"impactbuckler": 3,
				"wardingbrooch": 3,
				"frenzycharm": 3,
				"ringofaffinity": 3,
			})
			_set_player_level_direct(20)

func save_custom_preset(slot: int, save_path: String = PRESET_SAVE_PATH) -> void:
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	var sec := "slot_%d" % slot
	cfg.set_value(sec, "character", GlobalEvents.selected_character)
	cfg.set_value(sec, "time", int(GlobalEvents.time))
	cfg.set_value(sec, "level", int(p.get("experience_level")))
	cfg.set_value(sec, "collected_upgrades", p.get("collected_upgrades").duplicate())
	cfg.set_value(sec, "collected_endless", p.get("collected_endless").duplicate())
	cfg.save(save_path)

func load_custom_preset(slot: int, save_path: String = PRESET_SAVE_PATH) -> bool:
	var p := _get_player()
	if p == null or not is_instance_valid(p):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return false
	var sec := "slot_%d" % slot
	if not cfg.has_section(sec):
		return false

	_taint()
	var s_char := str(cfg.get_value(sec, "character", GlobalEvents.selected_character))
	if s_char != GlobalEvents.selected_character:
		switch_character(s_char, false)

	var s_time := int(cfg.get_value(sec, "time", 0))
	_set_time_exact(s_time)

	var tiers: Dictionary = {}
	var saved_upgrades: Array = cfg.get_value(sec, "collected_upgrades", [])
	for uid in saved_upgrades:
		var uid_str := str(uid)
		if uid_str.ends_with("_endless"):
			continue
		var base := uid_str.rstrip("0123456789")
		var lvl := int(uid_str.right(uid_str.length() - base.length())) if uid_str.length() > base.length() else 1
		tiers[base] = maxi(int(tiers.get(base, 0)), lvl)

	var saved_endless: Dictionary = cfg.get_value(sec, "collected_endless", {})
	_apply_item_map(tiers, saved_endless)

	var s_lvl := int(cfg.get_value(sec, "level", 1))
	_set_player_level_direct(s_lvl)
	return true
