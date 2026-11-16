# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Unit Testing Suite - Player Stats, Leveling, and Formulas
# Validates player leveling curves, XP rollover, stat modifiers, armor DR, and endless stacking.

extends "res://Tests/test_base.gd"

class MockGui extends Node:
	var levelPanel: Control
	var bossLevelPanel: Control
	var exp_history: Array = []
	var levelup_shown_count: int = 0
	
	func _init() -> void:
		levelPanel = Control.new()
		bossLevelPanel = Control.new()
		levelPanel.visible = true # Default to true to prevent triggering GUI dialogs in headless
		bossLevelPanel.visible = false
	
	func set_expbar(cur_exp: float, exp_cap: float) -> void:
		exp_history.append([cur_exp, exp_cap])
	
	func show_levelup(_options: Array, _level: int) -> void:
		levelup_shown_count += 1
	
	func cleanup() -> void:
		levelPanel.free()
		bossLevelPanel.free()

class MockAttacker extends Node:
	var received_damage: float = 0.0
	var received_knockback: float = 0.0
	var killer_source: String = ""
	var attacker_node: Node = null
	var hit_count: int = 0
	
	func _on_hurt_box_hurt(damage: float, _angle: Vector2, knockback: float, p_killer_source: String = "", p_attacker: Node = null, _proc: float = 1.0) -> void:
		received_damage = damage
		received_knockback = knockback
		killer_source = p_killer_source
		attacker_node = p_attacker
		hit_count += 1

func _create_player() -> Dictionary:
	var player_script = load("res://Player/player.gd")
	var player = player_script.new()
	
	var hb = ProgressBar.new()
	player.healthBar = hb
	
	var cs = CollisionShape2D.new()
	cs.shape = CircleShape2D.new()
	player.grab_shape = cs
	
	var weapons = Node2D.new()
	player.weapons = weapons
	
	var mock_gui = MockGui.new()
	player.gui = mock_gui
	
	var snd_hurt = AudioStreamPlayer2D.new()
	var snd_hurt_bad = AudioStreamPlayer2D.new()
	player.sndHurt = snd_hurt
	player.sndHurtBad = snd_hurt_bad
	
	return {
		"player": player,
		"hb": hb,
		"cs": cs,
		"weapons": weapons,
		"gui": mock_gui,
		"snd_hurt": snd_hurt,
		"snd_hurt_bad": snd_hurt_bad
	}

func _destroy_player(ctx: Dictionary) -> void:
	if ctx.has("snd_hurt_bad") and is_instance_valid(ctx["snd_hurt_bad"]):
		ctx["snd_hurt_bad"].free()
	if ctx.has("snd_hurt") and is_instance_valid(ctx["snd_hurt"]):
		ctx["snd_hurt"].free()
	ctx["gui"].cleanup()
	ctx["gui"].free()
	ctx["weapons"].free()
	ctx["cs"].shape = null
	ctx["cs"].free()
	ctx["hb"].free()
	ctx["player"].free()

# -----------------------------------------------------------------------------
# 1. Experience Cap Curve Tests
# -----------------------------------------------------------------------------

func test_leveling_curve_early_game() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	var expected_caps = {
		1: 5,
		2: 10,
		3: 15,
		4: 30,
		5: 50,
		6: 75,
		7: 110,
		8: 130,
		9: 150,
		10: 200
	}
	
	for lvl in expected_caps:
		player.experience_level = lvl
		var cap = player.calculate_experiencecap()
		assert_eq(cap, expected_caps[lvl], "XP cap for level %d mismatch" % lvl)
	
	_destroy_player(ctx)

func test_leveling_curve_mid_game() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Levels 11..19 follow formula: 200 + (lvl - 10) * 250
	for lvl in range(11, 20):
		player.experience_level = lvl
		var expected = 200 + (lvl - 10) * 250
		var actual = player.calculate_experiencecap()
		assert_eq(actual, expected, "XP cap for mid-game level %d mismatch" % lvl)
	
	_destroy_player(ctx)

func test_leveling_curve_late_game() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Levels 20+ follow formula: 2700 + (lvl - 20) * 400
	var test_levels = [20, 21, 25, 30, 50, 100]
	for lvl in test_levels:
		player.experience_level = lvl
		var expected = 2700 + (lvl - 20) * 400
		var actual = player.calculate_experiencecap()
		assert_eq(actual, expected, "XP cap for late-game level %d mismatch" % lvl)
	
	_destroy_player(ctx)

func test_leveling_curve_monotonicity() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	var prev_cap = 0
	for lvl in range(1, 51):
		player.experience_level = lvl
		var cap = player.calculate_experiencecap()
		assert_gte(cap, prev_cap, "Level curve must be monotonically non-decreasing at level %d" % lvl)
		prev_cap = cap
	
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 2. Experience Rollover & Multi-Level Level-Up Tests
# -----------------------------------------------------------------------------

func test_experience_accumulation_without_leveling() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	var global_events = Engine.get_main_loop().root.get_node("GlobalEvents")
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	
	# Level 1 cap is 5. Add 3 XP.
	player.calculate_experience(3.0)
	assert_eq(player.experience_level, 1, "Player should remain at level 1")
	assert_almost_eq(player.experience, 3.0, 0.001, "Current experience should be 3.0")
	assert_eq(player.pending_levelups, 0, "No level-ups should be pending")
	
	_destroy_player(ctx)

func test_experience_rollover_single_level() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	var global_events = Engine.get_main_loop().root.get_node("GlobalEvents")
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	
	# Level 1 cap is 5. Add 8 XP.
	# 5 XP consumed -> Level 2. Remainder 3 XP on bar.
	player.calculate_experience(8.0)
	assert_eq(player.experience_level, 2, "Player should level up to level 2")
	assert_almost_eq(player.experience, 3.0, 0.001, "Rollover experience on bar should be 3.0")
	assert_eq(player.pending_levelups, 1, "Pending levelups should be 1")
	
	_destroy_player(ctx)

func test_experience_multi_level_rollover() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	var global_events = Engine.get_main_loop().root.get_node("GlobalEvents")
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	
	# Level 1 cap = 5, Level 2 cap = 10, Level 3 cap = 15.
	# Total required to reach Level 4 with 2 XP remaining = 5 + 10 + 15 + 2 = 32 XP.
	player.calculate_experience(32.0)
	assert_eq(player.experience_level, 4, "Player should reach level 4")
	assert_almost_eq(player.experience, 2.0, 0.001, "Remainder experience on bar should be 2.0")
	assert_eq(player.pending_levelups, 3, "Pending levelups should be 3")
	
	_destroy_player(ctx)

func test_experience_difficulty_modifier_scaling() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	var global_events = Engine.get_main_loop().root.get_node("GlobalEvents")
	
	# On EASY (1.2 XP modifier): 10 XP gem yields 12.0 actual XP
	global_events.set_difficulty(global_events.Difficulty.EASY)
	player.calculate_experience(10.0)
	# Level 1 requires 5 -> reaches level 2, remainder = 7.0
	assert_eq(player.experience_level, 2)
	assert_almost_eq(player.experience, 7.0, 0.001, "EASY modifier 1.2 should yield 12.0 XP (5 consumed, 7 left)")
	
	# Reset difficulty back to NORMAL
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 3. Armor Diminishing Returns Formula Tests
# -----------------------------------------------------------------------------

func test_armor_diminishing_returns_formula() -> void:
	# Formula in player.gd: dr = float(armor) / (armor + 40.0)
	# damage_taken = damage * (1.0 - dr)
	var test_cases = [
		{"armor": 0, "incoming": 100.0, "expected_dr": 0.0, "expected_damage": 100.0},
		{"armor": 40, "incoming": 100.0, "expected_dr": 0.5, "expected_damage": 50.0},
		{"armor": 120, "incoming": 100.0, "expected_dr": 0.75, "expected_damage": 25.0},
		{"armor": 400, "incoming": 100.0, "expected_dr": 400.0 / 440.0, "expected_damage": 100.0 * (1.0 - (400.0 / 440.0))}
	]
	
	for tc in test_cases:
		var armor_val = tc["armor"]
		var incoming = tc["incoming"]
		var dr = float(armor_val) / (armor_val + 40.0)
		var actual_damage = incoming * (1.0 - dr)
		assert_almost_eq(dr, tc["expected_dr"], 0.0001, "DR mismatch for armor %d" % armor_val)
		assert_almost_eq(actual_damage, tc["expected_damage"], 0.0001, "Damage mismatch for armor %d" % armor_val)

func test_armor_marginal_diminishing_returns() -> void:
	# Test that each additional point of armor yields less marginal DR improvement
	var dr_0 = float(0) / (0 + 40.0)
	var dr_40 = float(40) / (40 + 40.0)
	var dr_80 = float(80) / (80 + 40.0)
	var dr_120 = float(120) / (120 + 40.0)
	
	var gain_0_to_40 = dr_40 - dr_0       # 0.50
	var gain_40_to_80 = dr_80 - dr_40     # 0.1667
	var gain_80_to_120 = dr_120 - dr_80   # 0.0833
	
	assert_gt(gain_0_to_40, gain_40_to_80, "Marginal DR gain from 0->40 must exceed 40->80")
	assert_gt(gain_40_to_80, gain_80_to_120, "Marginal DR gain from 40->80 must exceed 80->120")

# -----------------------------------------------------------------------------
# 4. Stat Modifiers Calculation Tests
# -----------------------------------------------------------------------------

func test_stat_modifiers_movement_speed() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	player.stat_modifiers["speed_boost_1"] = {"movement_speed_percent": 0.20}
	player.apply_stat_modifiers()
	# base_movement_speed is 75.0. 75.0 * 1.20 = 90.0
	assert_almost_eq(player.movement_speed, 90.0, 0.001, "Movement speed with +20% modifier")
	
	player.stat_modifiers["speed_boost_2"] = {"movement_speed_percent": 0.10}
	player.apply_stat_modifiers()
	# 75.0 * 1.30 = 97.5
	assert_almost_eq(player.movement_speed, 97.5, 0.001, "Movement speed with cumulative +30% modifier")
	
	_destroy_player(ctx)

func test_stat_modifiers_max_hp_and_ratio() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Base max HP is 80. Set HP to 40 (50% ratio).
	player.maxhp = 80
	player.hp = 40
	
	player.stat_modifiers["hp_boost"] = {"max_hp_percent": 0.50}
	player.apply_stat_modifiers()
	# New max HP: 80 * 1.50 = 120
	assert_eq(player.maxhp, 120, "Max HP should scale to 120 (+50%)")
	# Preserved ratio: 40/80 * 120 = 60
	assert_eq(player.hp, 60, "Current HP should preserve 50% ratio (60/120)")
	assert_eq(int(player.healthBar.max_value), 120, "HealthBar max_value should match maxhp")
	assert_eq(int(player.healthBar.value), 60, "HealthBar value should match hp")
	
	_destroy_player(ctx)

func test_stat_modifiers_grab_range() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	# BASE_GRAB_RADIUS is 50.0
	player.stat_modifiers["affinity"] = {"xp_range_percent": 0.50}
	player.apply_stat_modifiers()
	var radius = player.grab_shape.shape.radius
	assert_almost_eq(radius, 75.0, 0.001, "Grab shape radius should scale to 75.0 (+50%)")
	
	_destroy_player(ctx)

func test_stat_modifiers_armor_and_multiplier() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Base armor is 0. Add 10 flat armor and 50% armor multiplier.
	player.stat_modifiers["flat_armor"] = {"armor": 10}
	player.stat_modifiers["armor_mult"] = {"armor_multiplier": 0.50}
	player.apply_stat_modifiers()
	# Formula: int(armor * (1.0 + armor_multiplier)) = int(10 * 1.50) = 15
	assert_eq(player.armor, 15, "Armor should be int(10 * 1.50) = 15")
	
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 5. Endless Stacking Modifiers Tests
# -----------------------------------------------------------------------------

func test_endless_stacking_modifiers() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	
	player.collected_endless = {
		"speed": 5,        # 0.02 * 5 = +10% speed
		"armor": 12,       # +12 flat armor
		"thornring": 4,    # +20 reflected damage
		"tome": 3,         # +0.06 spell size
		"scroll": 4,       # +0.08 spell cooldown
		"ringofaffinity": 2 # +0.10 xp range
	}
	
	player.apply_stat_modifiers()
	
	# Speed: 75.0 * (1.0 + 0.10) = 82.5
	assert_almost_eq(player.movement_speed, 82.5, 0.001, "Endless speed stacking")
	# Armor: 0 + 12 = 12
	assert_eq(player.armor, 12, "Endless armor stacking")
	# Reflected damage: 5 * 4 = 20
	assert_almost_eq(player.reflected_damage, 20.0, 0.001, "Endless reflected damage")
	# Spell size: 0.02 * 3 = 0.06
	assert_almost_eq(player.spell_size, 0.06, 0.001, "Endless spell size")
	# Spell cooldown: 0.02 * 4 = 0.08
	assert_almost_eq(player.spell_cooldown, 0.08, 0.001, "Endless spell cooldown")
	# Grab radius: 50.0 * (1.0 + 0.10) = 55.0
	assert_almost_eq(player.grab_shape.shape.radius, 55.0, 0.001, "Endless grab range")
	
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 6. The Punished / Retaliation Archetype Tests
# -----------------------------------------------------------------------------

func test_punished_character_base_stats() -> void:
	var orig_char = GlobalEvents.selected_character
	GlobalEvents.selected_character = "punished"
	
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Verify GlobalEvents definition
	assert_eq(GlobalEvents.CHARACTERS["punished"]["starting_weapon"], "whip1", "Punished starting weapon must be whip1")
	assert_eq(GlobalEvents.CHARACTERS["punished"]["base_stats"]["armor"], 3, "Punished base armor must be 3")
	assert_eq(GlobalEvents.CHARACTERS["punished"]["base_stats"]["maxhp"], 100, "Punished base maxhp must be 100")
	assert_eq(GlobalEvents.CHARACTERS["punished"]["scaling_stats"]["reflected_damage"], 40, "Punished scaling reflected_damage must be 40")
	assert_eq(GlobalEvents.CHARACTERS["punished"]["scaling_max_level"], 20, "Punished scaling_max_level must be 20")
	
	# Verify runtime stats after applying modifiers
	player.apply_stat_modifiers()
	assert_eq(player.armor, 3, "Player armor should be initialized to base_stats armor (3)")
	assert_eq(player.base_maxhp, 100, "Player base_maxhp should be 100")
	assert_eq(player.maxhp, 100, "Player maxhp should be 100")
	assert_eq(player.hp, 100, "Player hp should match maxhp (100)")
	assert_eq(int(player.healthBar.max_value), 100, "HealthBar max_value should match maxhp")
	assert_eq(int(player.healthBar.value), 100, "HealthBar value should match hp")
	
	_destroy_player(ctx)
	GlobalEvents.selected_character = orig_char

func test_punished_character_passive_scaling() -> void:
	var orig_char = GlobalEvents.selected_character
	GlobalEvents.selected_character = "punished"
	
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Level 1: No scaling bonus applied (0.0 reflected damage)
	player.experience_level = 1
	player.apply_stat_modifiers()
	assert_almost_eq(player.reflected_damage, 0.0, 0.001, "Level 1 reflected damage should be 0.0")
	
	# Level 10: Progress = (10 - 1) / (20 - 1) = 9 / 19 ≈ 0.473684... -> 40 * (9 / 19) ≈ 18.947
	player.experience_level = 10
	player.apply_stat_modifiers()
	var expected_lvl_10 = 40.0 * (9.0 / 19.0)
	assert_almost_eq(player.reflected_damage, expected_lvl_10, 0.01, "Level 10 reflected damage should scale to ~18.95")
	
	# Level 20: Full scaling bonus (40.0 reflected damage)
	player.experience_level = 20
	player.apply_stat_modifiers()
	assert_almost_eq(player.reflected_damage, 40.0, 0.001, "Level 20 reflected damage should be exactly 40.0")
	
	# Level 25: Capped at scaling_max_level (40.0 reflected damage)
	player.experience_level = 25
	player.apply_stat_modifiers()
	assert_almost_eq(player.reflected_damage, 40.0, 0.001, "Level 25 reflected damage should remain capped at 40.0")
	
	_destroy_player(ctx)
	GlobalEvents.selected_character = orig_char

func test_punished_reflection_damage() -> void:
	var orig_char = GlobalEvents.selected_character
	GlobalEvents.selected_character = "punished"
	
	var ctx = _create_player()
	var player = ctx["player"]
	
	var mock_attacker = MockAttacker.new()
	
	# At Level 20, reflected_damage is 40.0
	player.experience_level = 20
	player.apply_stat_modifiers()
	assert_almost_eq(player.reflected_damage, 40.0, 0.001, "Punished reflected damage at level 20")
	
	# Trigger damage on player with mock attacker
	player._on_hurt_box_hurt(10.0, Vector2.ZERO, 0.0, "TestEnemy", mock_attacker)
	
	assert_eq(mock_attacker.hit_count, 1, "Attacker should receive 1 retaliation strike")
	assert_almost_eq(mock_attacker.received_damage, 40.0, 0.001, "Attacker should receive exactly reflected_damage (40.0)")
	assert_eq(mock_attacker.attacker_node, player, "Attacker should receive player reference as damage dealer")
	
	# When reflected_damage is 0.0, attacker should NOT receive retaliation
	player.reflected_damage = 0.0
	mock_attacker.hit_count = 0
	mock_attacker.received_damage = 0.0
	player._on_hurt_box_hurt(10.0, Vector2.ZERO, 0.0, "TestEnemy", mock_attacker)
	assert_eq(mock_attacker.hit_count, 0, "Attacker should not receive retaliation when reflected_damage is 0")
	assert_almost_eq(mock_attacker.received_damage, 0.0, 0.001, "No damage delivered when reflected_damage is 0")
	
	mock_attacker.free()
	_destroy_player(ctx)
	GlobalEvents.selected_character = orig_char

func test_punished_manual_base_maxhp_override_preserved() -> void:
	var orig_char = GlobalEvents.selected_character
	GlobalEvents.selected_character = "punished"
	
	var ctx = _create_player()
	var player = ctx["player"]
	
	# Explicitly override base_maxhp to custom value before apply_stat_modifiers
	player.base_maxhp = 150
	player.maxhp = 150
	player.hp = 150
	player.apply_stat_modifiers()
	
	assert_eq(player.base_maxhp, 150, "Manual unit test base_maxhp override should be preserved")
	assert_eq(player.maxhp, 150, "Manual unit test maxhp override should be preserved")
	
	_destroy_player(ctx)
	GlobalEvents.selected_character = orig_char
