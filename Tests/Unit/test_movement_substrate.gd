# SPDX-License-Identifier: GPL-3.0-or-later
# Unit Tests for Milestone M1: Movement Substrate, Character Mobility & Debug Controls

extends "res://Tests/test_base.gd"

const DebugControllerScript = preload("res://Utility/Debug/debug_controller.gd")

class MockMoveGui extends Node:
	var levelPanel: Control
	var bossLevelPanel: Control
	var deathPanel: Control
	var collectedWeapons: Node
	var collectedUpgrades: Node
	var collectedBossItems: Node

	func _init() -> void:
		levelPanel = Control.new()
		bossLevelPanel = Control.new()
		deathPanel = Control.new()
		levelPanel.visible = false
		bossLevelPanel.visible = false
		deathPanel.visible = false
		collectedWeapons = HBoxContainer.new()
		collectedUpgrades = HBoxContainer.new()
		collectedBossItems = HBoxContainer.new()
		add_child(levelPanel)
		add_child(bossLevelPanel)
		add_child(deathPanel)
		add_child(collectedWeapons)
		add_child(collectedUpgrades)
		add_child(collectedBossItems)

	func set_expbar(_cur_exp: float, _exp_cap: float) -> void:
		pass

	func set_level_text(_lvl: int) -> void:
		pass

	func update_timer(_t: int) -> void:
		pass

	func hide_level_panels() -> void:
		levelPanel.visible = false
		bossLevelPanel.visible = false

	func adjust_gui_collection(_uid: String) -> void:
		pass

	func refresh_gui_collection() -> void:
		pass

	func show_levelup(_options: Array, _level: int) -> void:
		pass

	func show_boss_levelup(_options: Array) -> void:
		pass

class MockAttacker extends Node:
	var hit_count: int = 0
	var last_damage: float = 0.0

	func _on_hurt_box_hurt(damage: float, _angle: Vector2, _knockback: float, _killer_source: String = "", _attacker: Node = null, _proc: float = 1.0) -> void:
		hit_count += 1
		last_damage = damage

class MockWeapon extends Node2D:
	var timer: Timer
	var attackTimer: Timer

	func _init() -> void:
		timer = Timer.new()
		timer.wait_time = 0.01
		add_child(timer)
		attackTimer = Timer.new()
		attackTimer.wait_time = 0.02
		add_child(attackTimer)

	func attack() -> void:
		timer.wait_time = 0.01
		attackTimer.wait_time = 0.02

var _hosts: Array[Node] = []
var _orig_char: String = "mage"
var _orig_mouse_control: bool = false
var _orig_time: int = 0
var _orig_time_scale: float = 1.0
var _orig_debug_unlocked: bool = true

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _release_all_inputs() -> void:
	for act in ["up", "down", "left", "right", "click", "mobility"]:
		if InputMap.has_action(act):
			Input.action_release(act)

func before_each() -> void:
	_orig_char = GlobalEvents.selected_character
	_orig_mouse_control = SettingsManager.mouse_control
	_orig_time = int(GlobalEvents.time)
	_orig_time_scale = Engine.time_scale
	_orig_debug_unlocked = SettingsManager.debug_unlocked

	GlobalEvents.selected_character = "mage"
	GlobalEvents.reset_movement_config()
	SettingsManager.mouse_control = false
	Engine.time_scale = 1.0
	StatsManager.clear_run_taint()
	_release_all_inputs()
	if _tree():
		_tree().paused = false

func after_each() -> void:
	_release_all_inputs()
	for h in _hosts:
		if h and is_instance_valid(h):
			if h.get_parent():
				h.get_parent().remove_child(h)
			h.free()
	_hosts.clear()

	GlobalEvents.selected_character = _orig_char
	GlobalEvents.time = _orig_time
	GlobalEvents.reset_movement_config()
	SettingsManager.mouse_control = _orig_mouse_control
	Engine.time_scale = _orig_time_scale
	SettingsManager.debug_unlocked = _orig_debug_unlocked
	StatsManager.clear_run_taint()
	if _tree():
		_tree().paused = false

func _create_env() -> Dictionary:
	var host := Node2D.new()
	host.name = "MovementTestHost"
	host.position = Vector2(50000.0, 50000.0)
	_tree().root.add_child(host)
	_hosts.append(host)

	var mock_gui := MockMoveGui.new()
	mock_gui.add_to_group("gui")
	mock_gui.add_to_group("gui_layer")
	host.add_child(mock_gui)

	var player_scene: PackedScene = preload("res://Player/player.tscn")
	var player = player_scene.instantiate()
	host.add_child(player)
	player.gui = mock_gui
	player.position = Vector2.ZERO
	player.reset_all_upgrades()
	player.apply_stat_modifiers()
	player._set_hp(player.maxhp)

	return {
		"host": host,
		"gui": mock_gui,
		"player": player,
	}

func test_base_movement_speed_is_85() -> void:
	var env := _create_env()
	var player = env["player"]
	assert_almost_eq(float(GlobalEvents.MOVEMENT_CONFIG["base_movement_speed"]), 85.0, 0.001, "Config base speed is 85.0")
	assert_almost_eq(float(player.base_movement_speed), 85.0, 0.001, "Player base_movement_speed is 85.0")
	assert_almost_eq(float(player.movement_speed), 85.0, 0.001, "Player movement_speed is 85.0")

func test_stride_real_velocity_and_blocked_wall_zero_gain() -> void:
	var env := _create_env()
	var host: Node2D = env["host"]
	var player = env["player"]

	# Unblocked movement
	Input.action_press("right")
	for _i in range(6):
		player._physics_process(1.0 / 60.0)
	assert_gt(player.get_real_velocity().length(), 80.0, "Unblocked real velocity should exceed 80 px/s")
	assert_gt(player.stride_step_delta, 0.0, "Unblocked stride_step_delta > 0")
	assert_gt(player.stride_distance_total, 0.0, "Unblocked stride_distance_total > 0")
	Input.action_release("right")

	# Wall-blocked movement
	player.position = Vector2.ZERO
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 1
	var wall_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20.0, 80.0)
	wall_shape.shape = rect
	wall.add_child(wall_shape)
	# Player collider has center (1, 3) radius 10 -> right edge at x=11. Place wall left edge at x=11 (center x=21).
	wall.position = Vector2(21.0, 0.0)
	host.add_child(wall)
	wall.force_update_transform()
	player.force_update_transform()

	# Seat flush against the wall within CharacterBody2D safe_margin until real velocity & step delta converge to 0
	Input.action_press("right")
	var settled_steps: int = 0
	for _i in range(60):
		player._physics_process(1.0 / 60.0)
		if player.get_real_velocity().length() < 0.01 and player.stride_step_delta <= 0.0001:
			settled_steps += 1
			if settled_steps >= 3:
				break
		else:
			settled_steps = 0
	assert_gte(settled_steps, 3, "Player must seat flush against wall within 60 steps")
	player.stride_distance_total = 0.0
	player.stride_step_delta = 0.0

	for _i in range(6):
		player._physics_process(1.0 / 60.0)
	assert_lt(player.get_real_velocity().length(), 0.1, "Wall-blocked real velocity must be ~0")
	assert_almost_eq(player.stride_step_delta, 0.0, 0.001, "Wall-blocked stride_step_delta must be 0")
	assert_almost_eq(player.stride_distance_total, 0.0, 0.001, "Wall-blocked stride_distance_total must stay 0")
	Input.action_release("right")

	# Stride passive helpers (Speed / Scroll)
	player.set_item_tier("speed", 2)
	player.set_item_tier("scroll", 3)
	assert_almost_eq(player.get_stride_efficiency(), 1.10, 0.001, "Speed T2 gives 1.10 stride efficiency")
	assert_almost_eq(player.get_stride_threshold_mult(), 0.85, 0.001, "Scroll T3 gives 0.85 threshold mult")

func test_bastion_charge_asymmetric_ramps_and_mouse_brake() -> void:
	var env := _create_env()
	var player = env["player"]

	# Ramp-in (0.45s): 15 steps * 0.015s = 0.225s -> ~0.5
	for _i in range(15):
		player._physics_process(0.015)
	assert_true(player.is_anchored, "Stationary player should be anchored")
	assert_gt(player.bastion_charge, 0.45, "bastion_charge at 0.225s should be > 0.45")
	assert_lt(player.bastion_charge, 0.55, "bastion_charge at 0.225s should be < 0.55")

	for _i in range(15):
		player._physics_process(0.015)
	assert_almost_eq(player.bastion_charge, 1.0, 0.001, "bastion_charge should cap at 1.0 at 0.45s")

	# Ramp-out (0.20s): 10 steps * 0.010s = 0.10s -> ~0.5
	Input.action_press("right")
	for _i in range(10):
		player._physics_process(0.010)
	assert_false(player.is_anchored, "Moving player should not be anchored")
	assert_gt(player.bastion_charge, 0.45, "bastion_charge after 0.10s moving should be > 0.45")
	assert_lt(player.bastion_charge, 0.55, "bastion_charge after 0.10s moving should be < 0.55")

	for _i in range(10):
		player._physics_process(0.010)
	assert_almost_eq(player.bastion_charge, 0.0, 0.001, "bastion_charge should decay to 0.0 at 0.20s")
	Input.action_release("right")

	# Mouse brake anchoring
	SettingsManager.mouse_control = true
	Input.action_press("click")
	for _i in range(30):
		player._physics_process(0.015)
	assert_eq(player.velocity, Vector2.ZERO, "Mouse brake stops velocity")
	assert_true(player.is_anchored, "Mouse brake sets is_anchored = true")
	assert_almost_eq(player.bastion_charge, 1.0, 0.001, "Mouse brake ramps bastion_charge to 1.0")

func test_cooldown_floor_005s() -> void:
	var env := _create_env()
	var player = env["player"]

	assert_almost_eq(player.calculate_cooldown(0.01), 0.05, 0.0001, "calculate_cooldown clamps at 0.05s")
	player.spell_cooldown = 0.90
	assert_almost_eq(player.calculate_weapon_cooldown(0.10, 0.25), 0.05, 0.0001, "calculate_weapon_cooldown clamps at 0.05s")

	var mock_w := MockWeapon.new()
	player.weapons.add_child(mock_w)
	player.attack()
	assert_almost_eq(mock_w.timer.wait_time, 0.05, 0.0001, "attack() clamps weapon timer to 0.05s")
	assert_almost_eq(mock_w.attackTimer.wait_time, 0.05, 0.0001, "attack() clamps weapon attackTimer to 0.05s")

func test_evaluate_heading_dot() -> void:
	var env := _create_env()
	var player = env["player"]
	player.last_movement = Vector2.RIGHT

	assert_almost_eq(player.evaluate_heading_dot(Vector2(100, 0)), 0.0, 0.001, "Stationary heading dot is 0.0")

	Input.action_press("right")
	player._physics_process(1.0 / 60.0)
	var pos: Vector2 = player.global_position
	assert_almost_eq(player.evaluate_heading_dot(pos + Vector2(100, 0)), 1.0, 0.001, "Advancing target gives +1.0")
	assert_almost_eq(player.evaluate_heading_dot(pos + Vector2(-100, 0)), -1.0, 0.001, "Retreating target gives -1.0")
	assert_almost_eq(player.evaluate_heading_dot(pos + Vector2(0, 100)), 0.0, 0.001, "Strafing target gives 0.0")
	assert_almost_eq(player.evaluate_heading_dot(pos), 0.0, 0.001, "Coincident target gives 0.0")
	assert_almost_eq(player.evaluate_heading_dot(Vector2.INF), 0.0, 0.001, "Vector2.INF target gives 0.0")

func test_mobility_action_registered_and_mage_sidestep_iframes() -> void:
	assert_true(InputMap.has_action("mobility"), "InputMap must define 'mobility'")
	var has_space := false
	for ev in InputMap.action_get_events("mobility"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_SPACE:
			has_space = true
	assert_true(has_space, "'mobility' action must bind Spacebar (physical_keycode 32)")

	var env := _create_env()
	var host: Node2D = env["host"]
	var player = env["player"]
	player.switch_character_mid_run("mage", false)
	assert_eq(GlobalEvents.CHARACTERS["mage"]["mobility_type"], "sidestep")

	var emitted := []
	player.mobility_triggered.connect(func(mtype: String, dir: Vector2): emitted.append([mtype, dir]))

	Input.action_press("right")
	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	Input.action_release("mobility")
	Input.action_release("right")

	assert_eq(emitted.size(), 1, "Sidestep should emit mobility_triggered once")
	assert_eq(emitted[0][0], "sidestep")
	assert_almost_eq((emitted[0][1] as Vector2).x, 1.0, 0.001)
	assert_true(player.is_swarm_push_immune(), "Sidestep grants swarm push immunity during i-frames")
	assert_false(player.trigger_mobility(Vector2.LEFT), "Sidestep cooldown blocks immediate re-trigger")

	var attacker := MockAttacker.new()
	host.add_child(attacker)
	player.reflected_damage = 25.0
	player._on_hurt_box_hurt(20.0, Vector2.LEFT, 0.0, "Swarm", attacker)
	assert_eq(float(player.hp), float(player.maxhp), "Sidestep i-frames block damage")
	assert_eq(attacker.hit_count, 0, "Sidestep i-frames skip Thorn Ring reflection")

	# Advance past 0.12s i-frame window
	for _i in range(10):
		player._physics_process(0.015)
	assert_false(player.is_swarm_push_immune(), "Swarm push immunity ends after i-frames")
	player._on_hurt_box_hurt(10.0, Vector2.LEFT, 0.0, "Swarm", attacker)
	assert_lt(float(player.hp), float(player.maxhp), "Damage applies after i-frames expire")

	# Verify sidestep_timer and sidestep_iframe_timer align on Spacebar sidestep (dt = 0.02 -> 6 frames = 0.12s)
	player.mobility_cooldown = 0.0
	Input.action_press("right")
	Input.action_press("mobility")
	player._physics_process(0.02)
	Input.action_release("mobility")
	Input.action_release("right")
	assert_almost_eq(player.sidestep_timer, 0.10, 0.0001, "Spacebar sidestep Frame 1 timer should be 0.10s")
	assert_almost_eq(player.sidestep_iframe_timer, player.sidestep_timer, 0.0001, "Spacebar sidestep_iframe_timer must equal sidestep_timer")
	for _i in range(4):
		player._physics_process(0.02)
	assert_almost_eq(player.sidestep_iframe_timer, player.sidestep_timer, 0.0001, "Mid-sidestep timers stay equal")
	assert_gt(player.sidestep_iframe_timer, 0.0, "i-frames still active after 5 frames (0.10s)")
	player._physics_process(0.02)
	assert_almost_eq(player.sidestep_timer, 0.0, 0.0001, "sidestep_timer ends at 0.12s (Frame 6)")
	assert_almost_eq(player.sidestep_iframe_timer, 0.0, 0.0001, "sidestep_iframe_timer ends at 0.12s (Frame 6)")

func test_plague_doctor_forward_dash_no_iframes_and_stride_credit() -> void:
	var env := _create_env()
	var player = env["player"]
	player.switch_character_mid_run("plague_doctor", false)
	assert_eq(GlobalEvents.CHARACTERS["plague_doctor"]["mobility_type"], "forward_dash")

	var primes := []
	player.movement_prime_ready.connect(func(src: String): primes.append(src))

	player.stride_distance_total = 0.0
	player.last_movement = Vector2.RIGHT
	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	Input.action_release("mobility")

	var hp_before := float(player.hp)
	player._on_hurt_box_hurt(10.0, Vector2.LEFT, 0.0, "Swarm", null)
	assert_lt(float(player.hp), hp_before, "forward_dash must NOT grant i-frames")

	for _i in range(15):
		player._physics_process(0.02)
	assert_gte(player.stride_distance_total, 120.0, "forward_dash grants instant stride credit on land")
	assert_true(player.impulse_primed, "forward_dash primes impulse on land")
	assert_has(primes, "impulse", "forward_dash emits movement_prime_ready('impulse')")

func test_rock_stance_occultist_punished_turn_in_place_and_icd_burst() -> void:
	assert_eq(GlobalEvents.CHARACTERS["occultist"]["mobility_type"], "rock_stance")
	assert_eq(GlobalEvents.CHARACTERS["punished"]["mobility_type"], "rock_stance")

	var env := _create_env()
	var player = env["player"]
	player.switch_character_mid_run("occultist", false)

	var bursts := []
	player.rock_stance_burst_started.connect(func(dur: float): bursts.append(dur))

	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	assert_eq(player.velocity, Vector2.ZERO, "Rock stance zeroes velocity immediately")
	assert_true(player.is_anchored, "Rock stance locks is_anchored immediately")
	assert_true(player.rock_stance_active, "Rock stance sets rock_stance_active")
	assert_true(player.is_swarm_push_immune(), "Rock stance grants swarm push immunity")
	assert_gte(player.armor, 4, "Rock stance grants armor bonus")
	assert_gt(player.rock_stance_burst_timer, 0.0, "Rock stance starts burst timer")
	assert_eq(bursts.size(), 1, "Rock stance emits burst signal")
	assert_lt(player.calculate_weapon_cooldown(1.0), 1.0, "Rock stance burst reduces weapon cooldown")

	# Turn-in-place while rooted
	var rooted_pos: Vector2 = player.global_position
	Input.action_press("left")
	player._physics_process(1.0 / 60.0)
	Input.action_release("left")
	assert_eq(player.global_position, rooted_pos, "Player stays rooted while turning left")
	assert_lt(player.last_movement.x, 0.0, "Facing updates left")
	assert_false(player.sprite.flip_h, "Sprite flips left")

	Input.action_press("right")
	player._physics_process(1.0 / 60.0)
	Input.action_release("right")
	assert_eq(player.global_position, rooted_pos, "Player stays rooted while turning right")
	assert_gt(player.last_movement.x, 0.0, "Facing updates right")
	assert_true(player.sprite.flip_h, "Sprite flips right")

	# Release, wait past burst (1.6s) while still inside 4.0s ICD, re-enter -> no new burst
	Input.action_release("mobility")
	for _i in range(16):
		player._physics_process(0.1)
	assert_false(player.rock_stance_active)
	assert_almost_eq(player.rock_stance_burst_timer, 0.0, 0.001)

	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	assert_true(player.rock_stance_active, "Rock stance can re-enter anytime")
	assert_almost_eq(player.rock_stance_burst_timer, 0.0, 0.001, "Local ICD blocks burst spam")
	Input.action_release("mobility")

	# Step 3.0s more past 4.0s ICD, re-enter -> burst triggers again
	for _i in range(30):
		player._physics_process(0.1)
	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	assert_gt(player.rock_stance_burst_timer, 0.0, "Burst triggers again after 4.0s ICD")

func test_mage_spell_cooldown_sign_fix() -> void:
	assert_almost_eq(float(GlobalEvents.CHARACTERS["mage"]["scaling_stats"]["spell_cooldown"]), 0.15, 0.0001, "Mage scaling spell_cooldown must be +0.15")

	var env := _create_env()
	var player = env["player"]
	player.switch_character_mid_run("mage", false)
	player.experience_level = 20
	player.apply_stat_modifiers()

	assert_almost_eq(float(player.spell_cooldown), 0.15, 0.0001, "Mage at lvl 20 gets +0.15 spell_cooldown")
	assert_almost_eq(player.calculate_cooldown(1.0), 0.85, 0.0001, "Mage at lvl 20 reduces 1.0s cooldown to 0.85s")

func test_switch_character_mid_run_syncs_mobility_and_clears_stance() -> void:
	var env := _create_env()
	var player = env["player"]
	player.switch_character_mid_run("occultist", false)

	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	Input.action_release("mobility")
	assert_true(player.rock_stance_active)

	var emitted := []
	player.mobility_triggered.connect(func(mtype: String, _dir: Vector2): emitted.append(mtype))

	player.switch_character_mid_run("mage", false)
	assert_eq(GlobalEvents.selected_character, "mage")
	assert_false(player.rock_stance_active, "Switching character clears active rock stance")
	assert_eq(player.mobility_type, "sidestep")

	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	Input.action_release("mobility")
	assert_eq(emitted.back(), "sidestep")

	player.switch_character_mid_run("plague_doctor", false)
	assert_eq(player.mobility_type, "forward_dash")
	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	Input.action_release("mobility")
	assert_eq(emitted.back(), "forward_dash")

func test_movement_config_ab_toggle_and_workbench() -> void:
	var env := _create_env()
	var host: Node2D = env["host"]
	var gui = env["gui"]
	var player = env["player"]

	var ctrl := DebugControllerScript.new()
	host.add_child(ctrl)
	ctrl.attach(gui, host)

	assert_true(GlobalEvents.is_movement_coupled(), "Movement coupling enabled by default")
	var sig_hits := [0]
	var cb := func(): sig_hits[0] += 1
	GlobalEvents.movement_config_changed.connect(cb)

	ctrl.workbench.switch_tab(4)
	ctrl.workbench.move_btn_vanilla.emit_signal("pressed")
	assert_false(GlobalEvents.is_movement_coupled(), "Vanilla Timers button disables movement coupling")
	assert_gte(sig_hits[0], 1, "Toggling mode emits movement_config_changed")
	assert_almost_eq(player.calculate_weapon_cooldown(1.0, 0.5), 1.0, 0.0001, "Vanilla mode ignores movement_cd_mult")

	for _i in range(20):
		player._physics_process(0.03)
	assert_almost_eq(player.bastion_charge, 0.0, 0.0001, "Vanilla mode keeps bastion_charge at 0.0")

	GlobalEvents.reset_movement_config()
	assert_true(GlobalEvents.is_movement_coupled(), "reset_movement_config restores enabled=true")
	assert_almost_eq(float(GlobalEvents.MOVEMENT_CONFIG["base_movement_speed"]), 85.0, 0.001)
	GlobalEvents.movement_config_changed.disconnect(cb)

func test_ui_focus_hygiene_and_mobility_guard() -> void:
	var env := _create_env()
	var host: Node2D = env["host"]
	var gui = env["gui"]
	var player = env["player"]

	assert_true(player._can_process_mobility_input(), "Mobility input allowed during active unpaused play")

	# Paused tree blocks mobility
	_tree().paused = true
	assert_false(player._can_process_mobility_input(), "Paused tree blocks Spacebar mobility")
	_tree().paused = false

	# LevelUp / BossLevelUp / Death panels block mobility
	gui.levelPanel.visible = true
	assert_false(player._can_process_mobility_input(), "Visible levelPanel blocks Spacebar mobility")
	gui.levelPanel.visible = false
	gui.bossLevelPanel.visible = true
	assert_false(player._can_process_mobility_input(), "Visible bossLevelPanel blocks Spacebar mobility")
	gui.bossLevelPanel.visible = false
	gui.deathPanel.visible = true
	assert_false(player._can_process_mobility_input(), "Visible deathPanel blocks Spacebar mobility")
	gui.deathPanel.visible = false

	# Focused UI control blocks mobility, and DebugWorkbench.close_modal() releases child focus
	var ctrl := DebugControllerScript.new()
	host.add_child(ctrl)
	ctrl.attach(gui, host)
	ctrl.workbench.open_modal()
	_tree().paused = false
	var focus_btn := Button.new()
	ctrl.workbench.add_child(focus_btn)
	focus_btn.grab_focus()
	assert_false(player._can_process_mobility_input(), "Focused UI control blocks Spacebar mobility")
	ctrl.workbench.close_modal()
	assert_null(_tree().root.get_viewport().gui_get_focus_owner(), "Workbench close_modal releases child focus")
	assert_true(player._can_process_mobility_input(), "Mobility input allowed again after focus released")

func test_world_pause_menu_resume_and_settings_focus_release() -> void:
	var world_scene: PackedScene = preload("res://World/world.tscn")
	assert_not_null(world_scene, "World/world.tscn must load")
	var world := world_scene.instantiate()
	assert_not_null(world, "World/world.tscn must instantiate")
	_tree().root.add_child(world)
	_hosts.append(world)

	var gui = world.get_node_or_null("GUILayer/GUI")
	var player = world.get_node_or_null("Player")
	assert_not_null(gui, "World must expose GUILayer/GUI")
	assert_not_null(player, "World must expose Player")

	# 1. Pause -> focus btnResume -> Resume button handler unpauses, syncs is_menu_open, releases focus
	gui.open_pause_menu()
	assert_true(_tree().paused, "open_pause_menu pauses SceneTree")
	assert_true(gui.is_menu_open, "open_pause_menu syncs is_menu_open = true")
	gui.btnResume.grab_focus()
	assert_eq(_tree().root.get_viewport().gui_get_focus_owner(), gui.btnResume, "btnResume holds viewport focus")
	assert_false(player._can_process_mobility_input(), "Focused pause button blocks Spacebar mobility")

	gui._on_btn_resume_run_click_end()
	assert_false(_tree().paused, "Resume button must unpause SceneTree")
	assert_false(gui.is_menu_open, "Resume button must set is_menu_open = false")
	assert_null(_tree().root.get_viewport().gui_get_focus_owner(), "Resume must release btnResume focus")
	assert_true(player._can_process_mobility_input(), "Mobility input allowed again after resume")

	# 2. Settings (CanvasLayer) focus release via close_settings()
	gui.open_pause_menu()
	gui.open_settings()
	assert_true(gui.settings_menu.visible, "SettingsMenu visible after open_settings")
	gui.settings_menu.audio_btn.grab_focus()
	assert_eq(_tree().root.get_viewport().gui_get_focus_owner(), gui.settings_menu.audio_btn, "Settings audio_btn holds focus")
	gui.close_settings()
	assert_false(gui.settings_menu.visible, "close_settings hides SettingsMenu")
	assert_null(_tree().root.get_viewport().gui_get_focus_owner(), "close_settings releases CanvasLayer SettingsMenu focus")

	# 3. Settings (CanvasLayer) focus release via close_pause_menu()
	gui.open_settings()
	gui.settings_menu.audio_btn.grab_focus()
	gui.close_pause_menu()
	assert_false(_tree().paused, "close_pause_menu unpauses SceneTree even when SettingsMenu was open")
	assert_false(gui.is_menu_open, "close_pause_menu syncs is_menu_open = false")
	assert_false(gui.settings_menu.visible, "close_pause_menu hides SettingsMenu")
	assert_null(_tree().root.get_viewport().gui_get_focus_owner(), "close_pause_menu releases SettingsMenu focus without type error")
	assert_true(player._can_process_mobility_input(), "Mobility input allowed after closing pause+settings")

	# 4. show_death_panel cleans up open pause/settings menu without script error
	gui.open_pause_menu()
	gui.open_settings()
	gui.settings_menu.audio_btn.grab_focus()
	gui.show_death_panel(false)
	assert_true(_tree().paused, "show_death_panel keeps SceneTree paused")
	assert_true(gui.deathPanel.visible, "show_death_panel shows DeathPanel")
	assert_false(gui.is_menu_open, "show_death_panel closes pause menu and sets is_menu_open = false")
	assert_false(gui.settings_menu.visible, "show_death_panel hides SettingsMenu")
	assert_null(_tree().root.get_viewport().gui_get_focus_owner(), "show_death_panel releases SettingsMenu focus")

func test_switch_character_mid_run_clears_burst_icd_and_cooldown() -> void:
	var env := _create_env()
	var player = env["player"]

	player.switch_character_mid_run("punished", false)
	Input.action_press("mobility")
	player._physics_process(1.0 / 60.0)
	Input.action_release("mobility")
	assert_true(player.rock_stance_active, "Punished enters rock stance")
	assert_gt(player.rock_stance_burst_timer, 0.0, "Rock stance burst timer active")
	assert_gt(player.rock_stance_burst_icd, 0.0, "Rock stance burst ICD active")
	assert_lt(player.calculate_weapon_cooldown(1.0), 1.0, "Burst reduces cooldown before switch")

	player.switch_character_mid_run("mage", false)
	assert_false(player.rock_stance_active, "Switching from punished clears rock_stance_active")
	assert_almost_eq(player.rock_stance_burst_timer, 0.0, 0.0001, "Switching clears rock_stance_burst_timer")
	assert_almost_eq(player.rock_stance_burst_icd, 0.0, 0.0001, "Switching clears rock_stance_burst_icd")
	assert_almost_eq(player.mobility_cooldown, 0.0, 0.0001, "Switching clears mobility_cooldown")
	assert_almost_eq(player.calculate_weapon_cooldown(1.0), 1.0, 0.0001, "Burst cooldown mult clears on switch")

	assert_true(player.trigger_mobility(Vector2.RIGHT), "Mage sidestep triggers immediately")
	assert_gt(player.mobility_cooldown, 2.0, "Mage sidestep sets cooldown > 2.0s")
	player.switch_character_mid_run("plague_doctor", false)
	assert_almost_eq(player.mobility_cooldown, 0.0, 0.0001, "Switching to plague_doctor clears Mage mobility_cooldown")
	assert_true(player.trigger_mobility(Vector2.RIGHT), "Plague doctor forward_dash immediately usable after switch")
	assert_gt(player.mobility_cooldown, 3.0, "Plague doctor dash sets cooldown > 3.0s")

	player.switch_character_mid_run("occultist", false)
	assert_almost_eq(player.mobility_cooldown, 0.0, 0.0001, "Switching to occultist clears mobility_cooldown")
	assert_almost_eq(player.rock_stance_burst_icd, 0.0, 0.0001, "Switching to occultist keeps rock_stance_burst_icd at 0.0")

func test_cooldown_nan_and_non_finite_guard() -> void:
	var env := _create_env()
	var player = env["player"]

	var results: Array[float] = [
		player.calculate_weapon_cooldown(NAN, 1.0),
		player.calculate_weapon_cooldown(1.0, NAN),
		player.calculate_weapon_cooldown(INF, 1.0),
	]
	player.spell_cooldown = NAN
	results.append(player.calculate_weapon_cooldown(1.0, 1.0))

	player.spell_cooldown = 0.0
	GlobalEvents.set_movement_config_value("cooldown_floor", NAN)
	results.append(player.calculate_weapon_cooldown(1.0, 1.0))

	for r in results:
		assert_false(is_nan(r), "calculate_weapon_cooldown must never return NAN")
		assert_true(is_finite(r), "calculate_weapon_cooldown must always return finite float")
		assert_almost_eq(r, 0.05, 0.0001, "Non-finite cooldown inputs must clamp safely to 0.05s floor")
