# SPDX-License-Identifier: GPL-3.0-or-later
# Unit Tests for the 4-Gear Developer & Designer Debug Suite

extends "res://Tests/test_base.gd"

const DebugControllerScript = preload("res://Utility/Debug/debug_controller.gd")
const DebugTelemetryScript = preload("res://Utility/Debug/debug_telemetry.gd")
const DebugVisualizerScript = preload("res://Utility/Debug/debug_visualizer.gd")

class MockDebugGui extends Node:
	var levelPanel: Control
	var bossLevelPanel: Control
	var collectedWeapons: Node
	var collectedUpgrades: Node
	var collectedBossItems: Node
	var last_timer: int = -1
	var last_level: int = 1
	var refresh_calls: int = 0

	func _init() -> void:
		levelPanel = Control.new()
		bossLevelPanel = Control.new()
		levelPanel.visible = true
		bossLevelPanel.visible = false
		collectedWeapons = HBoxContainer.new()
		collectedUpgrades = HBoxContainer.new()
		collectedBossItems = HBoxContainer.new()
		add_child(levelPanel)
		add_child(bossLevelPanel)
		add_child(collectedWeapons)
		add_child(collectedUpgrades)
		add_child(collectedBossItems)

	func set_expbar(_cur_exp: float, _exp_cap: float) -> void:
		pass

	func set_level_text(lvl: int) -> void:
		last_level = lvl

	func update_timer(t: int) -> void:
		last_timer = t

	func hide_level_panels() -> void:
		pass

	func adjust_gui_collection(_uid: String) -> void:
		pass

	func refresh_gui_collection() -> void:
		refresh_calls += 1

var _hosts: Array[Node] = []
var _orig_debug_unlocked: bool = true
var _orig_difficulty: int = 1
var _orig_char: String = "mage"
var _orig_time: int = 0
var _orig_time_scale: float = 1.0
var _orig_stats: Dictionary = {}

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func before_each() -> void:
	_orig_debug_unlocked = SettingsManager.debug_unlocked
	_orig_difficulty = GlobalEvents.current_difficulty
	_orig_char = GlobalEvents.selected_character
	_orig_time = int(GlobalEvents.time)
	_orig_time_scale = Engine.time_scale
	_orig_stats = {
		"enemy_kills": StatsManager.enemy_kills,
		"boss_kills": StatsManager.boss_kills,
		"total_deaths": StatsManager.total_deaths,
		"total_wins": StatsManager.total_wins,
		"best_run_level": StatsManager.best_run_level,
		"best_run_time": StatsManager.best_run_time,
	}
	StatsManager.clear_run_taint()
	StatsManager.allow_tainted_stats = false
	GlobalEvents.time = 0
	Engine.time_scale = 1.0
	if _tree():
		_tree().paused = false

func after_each() -> void:
	for h in _hosts:
		if h and is_instance_valid(h):
			if h.get_parent():
				h.get_parent().remove_child(h)
			h.free()
	_hosts.clear()

	SettingsManager.debug_unlocked = _orig_debug_unlocked
	GlobalEvents.current_difficulty = _orig_difficulty
	GlobalEvents.selected_character = _orig_char
	GlobalEvents.time = _orig_time
	Engine.time_scale = _orig_time_scale
	StatsManager.clear_run_taint()
	StatsManager.allow_tainted_stats = false

	# Restore StatsManager in memory (avoid persisting test mutations)
	StatsManager.enemy_kills = _orig_stats.get("enemy_kills", 0)
	StatsManager.boss_kills = _orig_stats.get("boss_kills", 0)
	StatsManager.total_deaths = _orig_stats.get("total_deaths", 0)
	StatsManager.total_wins = _orig_stats.get("total_wins", 0)
	StatsManager.best_run_level = _orig_stats.get("best_run_level", 0)
	StatsManager.best_run_time = _orig_stats.get("best_run_time", 0)

	if _tree():
		_tree().paused = false

	var test_cfg := "user://test_debug_presets.cfg"
	if FileAccess.file_exists(test_cfg):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg))

func _create_attached_env() -> Dictionary:
	var host := Node2D.new()
	host.name = "DebugTestHost"
	_tree().root.add_child(host)
	_hosts.append(host)

	var mock_gui := MockDebugGui.new()
	mock_gui.add_to_group("gui")
	mock_gui.add_to_group("gui_layer")
	host.add_child(mock_gui)

	var player_scene: PackedScene = preload("res://Player/player.tscn")
	var player = player_scene.instantiate()
	host.add_child(player)
	player.reset_all_upgrades()
	player.apply_stat_modifiers()
	player._set_hp(player.maxhp)

	var ctrl := DebugControllerScript.new()
	host.add_child(ctrl)
	ctrl.attach(mock_gui, host)

	return {
		"host": host,
		"player": player,
		"gui": mock_gui,
		"ctrl": ctrl,
	}

func test_secret_debug_keyword_toggle() -> void:
	SettingsManager.debug_unlocked = false
	var signaled: Array = []
	var cb := func(val: bool): signaled.append(val)
	SettingsManager.debug_mode_changed.connect(cb)

	SettingsManager.process_secret_keyword("debug")
	assert_true(SettingsManager.debug_unlocked, "Typing 'debug' should unlock debug tools")
	assert_true(SettingsManager.is_debug_enabled(), "is_debug_enabled should follow unlocked state")

	SettingsManager.process_secret_keyword("debug")
	if not OS.is_debug_build():
		assert_false(SettingsManager.debug_unlocked, "Second 'debug' should toggle off in release")
	assert_eq(signaled.size(), 2, "debug_mode_changed should fire on each toggle")

	SettingsManager.debug_mode_changed.disconnect(cb)

func test_stats_manager_taint_lock_and_override() -> void:
	StatsManager.clear_run_taint()
	var base_kills := StatsManager.enemy_kills
	StatsManager.mark_run_tainted()
	assert_true(StatsManager.is_run_tainted, "Run should be marked tainted")

	StatsManager.register_kill(false)
	StatsManager.update_best_run(999, 9999)
	assert_eq(StatsManager.enemy_kills, base_kills, "Tainted run must block register_kill by default")
	assert_eq(StatsManager.best_run_level, _orig_stats["best_run_level"], "Tainted run must block best run update")

	StatsManager.allow_tainted_stats = true
	StatsManager.register_kill(false)
	assert_eq(StatsManager.enemy_kills, base_kills + 1, "allow_tainted_stats override should allow kill tracking")

	StatsManager.clear_run_taint()
	assert_false(StatsManager.is_run_tainted, "clear_run_taint resets tainted flag")

func test_player_set_item_tier_and_rebuild() -> void:
	var env := _create_attached_env()
	var player = env["player"]

	player.set_item_tier("icespear", 3)
	assert_has_all(player.collected_upgrades, ["icespear1", "icespear2", "icespear3"], "Tier 3 should grant prereqs cleanly")
	var spawner = player.weapons.get_node_or_null("icespear")
	assert_not_null(spawner, "Ice spear spawner should exist at tier 3")
	assert_eq(int(spawner.level), 3, "Spawner level should equal 3")

	player.set_item_tier("icespear", 1)
	assert_has(player.collected_upgrades, "icespear1", "Downgrade to tier 1 keeps tier 1")
	assert_false(player.collected_upgrades.has("icespear2"), "Downgrade removes tier 2")
	assert_false(player.collected_upgrades.has("icespear3"), "Downgrade removes tier 3")
	spawner = player.weapons.get_node_or_null("icespear")
	assert_not_null(spawner, "Rebuilt spawner should exist immediately")
	assert_eq(int(spawner.level), 1, "Rebuilt spawner level should reset to 1")
	assert_eq(int(spawner.baseammo), 1, "Rebuilt spawner baseammo must match tier 1, not additive leftover")

	player.set_item_tier("icespear", 0)
	assert_false(player.collected_upgrades.has("icespear1"), "Tier 0 removes item completely")
	assert_null(player.weapons.get_node_or_null("icespear"), "Spawner node should be removed synchronously")

func test_player_endless_stacking_and_removal() -> void:
	var env := _create_attached_env()
	var player = env["player"]

	player.set_endless_stacks("icespear", 4)
	assert_eq(int(player.collected_endless.get("icespear", 0)), 4, "Should track 4 endless stacks")
	assert_has(player.collected_upgrades, "icespear4", "Endless prerequisite tier 4 must be granted")
	assert_has(player.collected_upgrades, "icespear_endless", "icespear_endless should appear once in collected_upgrades")
	var spawner = player.weapons.get_node_or_null("icespear")
	assert_not_null(spawner)
	assert_eq(int(spawner.endless_level), 4, "Spawner should apply 4 endless stacks")

	player.remove_upgrade("icespear_endless")
	assert_eq(int(player.collected_endless.get("icespear", 0)), 3, "Single removal decrements stack from 4 to 3")
	assert_has(player.collected_upgrades, "icespear_endless", "Still retains icespear_endless key at 3 stacks")

	player.set_endless_stacks("icespear", 0)
	assert_false(player.collected_endless.has("icespear"), "0 endless clears endless dictionary entry")
	assert_false(player.collected_upgrades.has("icespear_endless"), "0 endless removes _endless from collected_upgrades")

func test_player_special_items_and_relicdrone_sync() -> void:
	var env := _create_attached_env()
	var player = env["player"]

	player.set_item_tier("glasstalisman", 4)
	player.set_item_tier("wardingbrooch", 2)
	player.set_item_tier("frenzycharm", 3)
	player.set_item_tier("impactbuckler", 2)
	player.set_item_tier("willowisp", 3)
	player.set_item_tier("relicdrone", 2)

	assert_eq(player.glass_talisman_level, 4)
	assert_eq(player.warding_brooch_level, 2)
	assert_eq(player.frenzy_charm_level, 3)
	assert_eq(player.impact_buckler_level, 2)
	assert_eq(player.willowisp_level, 3)
	assert_not_null(player.relic_drone_node, "Relic drone companion should spawn")
	assert_eq(int(player.relic_drone_node.level), 2)

	player.set_item_tier("relicdrone", 1)
	assert_not_null(player.relic_drone_node, "Downgrading relicdrone preserves companion at tier 1")
	assert_eq(int(player.relic_drone_node.level), 1)

	player.reset_all_upgrades()
	assert_eq(player.collected_upgrades.size(), 0, "reset_all_upgrades clears all upgrades")
	assert_eq(player.glass_talisman_level, 0)
	assert_eq(player.warding_brooch_level, 0)
	assert_eq(player.frenzy_charm_level, 0)
	assert_eq(player.impact_buckler_level, 0)
	assert_eq(player.willowisp_level, 0)
	assert_null(player.relic_drone_node, "reset_all_upgrades removes companion drone")

func test_damage_source_inference_and_telemetry() -> void:
	var host := Node2D.new()
	_tree().root.add_child(host)
	_hosts.append(host)

	var tele = DebugTelemetryScript.new()
	host.add_child(tele)

	var vk: Node = preload("res://Player/Attack/vampireknives/vampireknife.tscn").instantiate()
	assert_eq(GlobalEvents.infer_attack_source(vk), "vampireknives", "Infers vampireknives from scene/script path")
	vk.free()

	assert_eq(GlobalEvents.normalize_damage_source("vampireknife"), "vampireknives", "Normalizes vampireknife to vampireknives")

	GlobalEvents.record_weapon_damage("poison_gas", 100.0, null)
	GlobalEvents.record_weapon_damage("icespear", 50.0, null)

	var ranked: Array = tele.get_ranked_sources()
	assert_eq(ranked.size(), 2, "Should track two normalized damage sources")
	assert_eq(ranked[0]["source"], "poisonbottle", "poison_gas normalizes cleanly to poisonbottle")
	assert_almost_eq(float(ranked[0]["total"]), 100.0, 0.01)
	assert_almost_eq(float(tele.get_source_dps("poisonbottle", 5.0)), 20.0, 0.01)
	assert_almost_eq(float(tele.get_total_dps(5.0)), 30.0, 0.01)

	var csv: String = tele.export_csv("")
	assert_has(csv, "poisonbottle,20.00,100.00", "CSV export contains ranked row")

	tele.reset_meter()
	assert_almost_eq(float(tele.get_total_dps(5.0)), 0.0, 0.001, "reset_meter clears all DPS stats")

func test_target_dummy_immortality_retaliation_and_dps() -> void:
	var env := _create_attached_env()
	var player = env["player"]
	var ctrl = env["ctrl"]

	player.set_item_tier("thornring", 1)
	var dummy = ctrl.spawn_target_dummy(true, player.global_position + Vector2(30, 0))
	assert_not_null(dummy, "Dummy should instantiate cleanly")
	assert_true(dummy.is_in_group("target_dummy"), "Dummy added to target_dummy group")
	assert_true(dummy.retaliate_enabled, "Retaliate flag enabled")

	dummy._on_hurt_box_hurt(250.0, Vector2.RIGHT, 100.0, "icespear", player, 1.0)
	assert_false(dummy.is_dying, "Immortal dummy must not die on large hit")
	assert_almost_eq(float(dummy.hp), float(dummy.max_hp), 0.01, "Immortal dummy restores full HP")
	assert_gt(dummy.total_damage_taken, 200.0, "Dummy logs cumulative damage taken")
	assert_gt(dummy.get_rolling_dps(5.0), 40.0, "Dummy calculates rolling 5s DPS")

	var hp_before := float(player.hp)
	dummy.perform_retaliation()
	assert_lt(float(player.hp), hp_before, "Retaliation dummy damages player")
	assert_gt(dummy.total_damage_taken, 250.0, "Thorn ring reflects retaliation back onto dummy")

func test_debug_controller_actions_and_presets() -> void:
	var env := _create_attached_env()
	var player = env["player"]
	var gui = env["gui"]
	var ctrl = env["ctrl"]

	player.set_item_tier("glasstalisman", 4)
	player.set_item_tier("frenzycharm", 3)
	player.set_item_tier("impactbuckler", 2)
	player.set_item_tier("wardingbrooch", 2)
	player.warding_brooch_charge = false
	player.warding_brooch_timer = 8.0
	player.impact_buckler_cooldown = 15.0

	ctrl.set_hp_percent(1.0)
	assert_gt(player.glass_talisman_damage_bonus, 0.2, "100% HP activates Glass Talisman")
	ctrl.set_hp_percent(0.94)
	assert_almost_eq(player.glass_talisman_damage_bonus, 0.0, 0.001, "94% HP deactivates Glass Talisman")
	ctrl.set_hp_percent(0.29)
	assert_true(player.frenzy_charm_active, "29% HP triggers Frenzy Charm")

	ctrl.reset_item_cooldowns()
	assert_true(player.warding_brooch_charge, "reset_item_cooldowns restores Brooch charge")
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "reset_item_cooldowns clears Buckler CD")

	ctrl.advance_time_synced(125, false)
	assert_eq(int(GlobalEvents.time), 125, "GlobalEvents.time updated synchronously")
	assert_eq(int(player.time), 125, "player.time synced")
	assert_eq(gui.last_timer, 125, "GUI timer updated synchronously")

	ctrl.apply_preset("early_min5")
	assert_eq(int(GlobalEvents.time), 300, "Preset sets run time to 5:00")
	assert_eq(int(player.experience_level), 12, "Preset sets level to 12")
	assert_has(player.collected_upgrades, "icespear4", "Preset builds tier 4 Ice Spear")

	var test_cfg := "user://test_debug_presets.cfg"
	ctrl.save_custom_preset(1, test_cfg)
	ctrl.reset_all_upgrades()
	assert_eq(player.collected_upgrades.size(), 0)
	assert_true(ctrl.load_custom_preset(1, test_cfg), "Custom preset loads cleanly")
	assert_has(player.collected_upgrades, "icespear4", "Loaded custom preset restores items")
	assert_true(StatsManager.is_run_tainted, "Debug actions taint the run")

func test_visualizer_compliance_audit() -> void:
	var host := Node2D.new()
	_tree().root.add_child(host)
	_hosts.append(host)

	var vis = DebugVisualizerScript.new()
	host.add_child(vis)

	var valid_atk := Area2D.new()
	valid_atk.name = "ValidSpear"
	valid_atk.add_to_group("attack")
	valid_atk.collision_layer = 4
	var vcs := CollisionShape2D.new()
	vcs.name = "CollisionShape2D"
	valid_atk.add_child(vcs)
	host.add_child(valid_atk)

	var enemy_hitbox := Area2D.new()
	enemy_hitbox.name = "HitBox"
	enemy_hitbox.add_to_group("attack")
	enemy_hitbox.collision_layer = 2
	host.add_child(enemy_hitbox)

	var bad_atk := Area2D.new()
	bad_atk.name = "BrokenProj"
	bad_atk.add_to_group("attack")
	bad_atk.collision_layer = 1
	host.add_child(bad_atk)

	var violations: Array = vis.audit_attack_compliance()
	assert_eq(violations.size(), 2, "Broken attack reports both Rule 16 & Rule 17, ignoring ValidSpear and enemy HitBox")

func test_world_scene_loads_cleanly() -> void:
	var packed: PackedScene = load("res://World/world.tscn")
	assert_not_null(packed, "World scene must load cleanly without parse errors")
	var inst := packed.instantiate()
	assert_not_null(inst, "World scene must instantiate cleanly")
	assert_not_null(inst.get_node_or_null("GUILayer/GUI/DebugMenu"), "New DebugMenu exists")
	assert_null(inst.get_node_or_null("GUILayer/GUI/GiveItemMenu"), "Legacy GiveItemMenu removed")
	assert_null(inst.get_node_or_null("GUILayer/GUI/RemoveItemMenu"), "Legacy RemoveItemMenu removed")
	assert_null(inst.get_node_or_null("GUILayer/GUI/SpawnBossMenu"), "Legacy SpawnBossMenu removed")
	inst.free()
