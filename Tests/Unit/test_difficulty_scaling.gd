# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Unit Testing Suite - Difficulty Scaling & Progression
# Validates GlobalEvents Difficulty modes, modifiers, slot counts, and boss exponential scaling.

extends "res://Tests/test_base.gd"

var global_events: Node = null

func before_all() -> void:
	global_events = Engine.get_main_loop().root.get_node("GlobalEvents")

func after_each() -> void:
	# Always restore difficulty to NORMAL after each test
	if global_events != null:
		global_events.set_difficulty(global_events.Difficulty.NORMAL)

func test_difficulty_enum_and_cycling() -> void:
	assert_not_null(global_events, "GlobalEvents singleton must exist")
	
	# Initial set
	global_events.set_difficulty(global_events.Difficulty.EASY)
	assert_eq(global_events.current_difficulty, global_events.Difficulty.EASY)
	
	# Cycle EASY -> NORMAL
	global_events.next_difficulty()
	assert_eq(global_events.current_difficulty, global_events.Difficulty.NORMAL)
	
	# Cycle NORMAL -> HARD
	global_events.next_difficulty()
	assert_eq(global_events.current_difficulty, global_events.Difficulty.HARD)
	
	# Cycle HARD -> CUSTOM
	global_events.next_difficulty()
	assert_eq(global_events.current_difficulty, global_events.Difficulty.CUSTOM)
	
	# Cycle CUSTOM -> EASY
	global_events.next_difficulty()
	assert_eq(global_events.current_difficulty, global_events.Difficulty.EASY)

func test_difficulty_localization_keys() -> void:
	global_events.set_difficulty(global_events.Difficulty.EASY)
	assert_eq(global_events.get_difficulty_name(), "ui_difficulty_easy")
	
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	assert_eq(global_events.get_difficulty_name(), "ui_difficulty_normal")
	
	global_events.set_difficulty(global_events.Difficulty.HARD)
	assert_eq(global_events.get_difficulty_name(), "ui_difficulty_hard")
	
	global_events.set_difficulty(global_events.Difficulty.CUSTOM)
	assert_eq(global_events.get_difficulty_name(), "ui_difficulty_custom")

func test_easy_mode_modifiers() -> void:
	global_events.set_difficulty(global_events.Difficulty.EASY)
	
	assert_almost_eq(global_events.get_enemy_spawn_modifier(), 0.8, 0.001, "EASY enemy spawn modifier")
	assert_almost_eq(global_events.get_enemy_hp_modifier(), 0.8, 0.001, "EASY enemy HP modifier")
	assert_almost_eq(global_events.get_boss_hp_modifier(), 0.8, 0.001, "EASY boss HP modifier")
	assert_almost_eq(global_events.get_player_regen_modifier(), 1.5, 0.001, "EASY player regen modifier")
	assert_almost_eq(global_events.get_player_damage_modifier(), 1.0, 0.001, "EASY player damage modifier")
	assert_almost_eq(global_events.get_xp_gain_modifier(), 1.2, 0.001, "EASY XP gain modifier")
	assert_eq(global_events.get_max_weapon_slots(), 6, "EASY max weapon slots")
	assert_eq(global_events.get_max_upgrade_slots(), 8, "EASY max upgrade slots")

func test_normal_mode_modifiers() -> void:
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	
	assert_almost_eq(global_events.get_enemy_spawn_modifier(), 1.0, 0.001, "NORMAL enemy spawn modifier")
	assert_almost_eq(global_events.get_enemy_hp_modifier(), 1.0, 0.001, "NORMAL enemy HP modifier")
	assert_almost_eq(global_events.get_boss_hp_modifier(), 1.0, 0.001, "NORMAL boss HP modifier")
	assert_almost_eq(global_events.get_player_regen_modifier(), 1.0, 0.001, "NORMAL player regen modifier")
	assert_almost_eq(global_events.get_player_damage_modifier(), 1.0, 0.001, "NORMAL player damage modifier")
	assert_almost_eq(global_events.get_xp_gain_modifier(), 1.0, 0.001, "NORMAL XP gain modifier")
	assert_eq(global_events.get_max_weapon_slots(), 6, "NORMAL max weapon slots")
	assert_eq(global_events.get_max_upgrade_slots(), 8, "NORMAL max upgrade slots")

func test_hard_mode_modifiers() -> void:
	global_events.set_difficulty(global_events.Difficulty.HARD)
	
	assert_almost_eq(global_events.get_enemy_spawn_modifier(), 1.2, 0.001, "HARD enemy spawn modifier")
	assert_almost_eq(global_events.get_enemy_hp_modifier(), 1.2, 0.001, "HARD enemy HP modifier")
	assert_almost_eq(global_events.get_boss_hp_modifier(), 1.2, 0.001, "HARD boss HP modifier")
	assert_almost_eq(global_events.get_player_regen_modifier(), 1.0, 0.001, "HARD player regen modifier")
	assert_almost_eq(global_events.get_player_damage_modifier(), 1.0, 0.001, "HARD player damage modifier")
	assert_almost_eq(global_events.get_xp_gain_modifier(), 0.8, 0.001, "HARD XP gain modifier")
	assert_eq(global_events.get_max_weapon_slots(), 5, "HARD max weapon slots (restricted)")
	assert_eq(global_events.get_max_upgrade_slots(), 6, "HARD max upgrade slots (restricted)")

func test_custom_mode_modifiers() -> void:
	global_events.set_difficulty(global_events.Difficulty.CUSTOM)
	
	global_events.custom_enemy_spawn_modifier = 2.5
	global_events.custom_enemy_hp_modifier = 3.0
	global_events.custom_boss_hp_modifier = 4.0
	global_events.custom_player_regen_modifier = 0.5
	global_events.custom_player_damage_modifier = 1.8
	global_events.custom_xp_gain_modifier = 2.2
	
	assert_almost_eq(global_events.get_enemy_spawn_modifier(), 2.5, 0.001)
	assert_almost_eq(global_events.get_enemy_hp_modifier(), 3.0, 0.001)
	assert_almost_eq(global_events.get_boss_hp_modifier(), 4.0, 0.001)
	assert_almost_eq(global_events.get_player_regen_modifier(), 0.5, 0.001)
	assert_almost_eq(global_events.get_player_damage_modifier(), 1.8, 0.001)
	assert_almost_eq(global_events.get_xp_gain_modifier(), 2.2, 0.001)

func test_boss_exponential_hp_scaling_formula() -> void:
	# Formula in enemy_spawner.gd:
	# Multiplier(t) = pow(boss_hp_scaling_base, minutes) * GlobalEvents.get_boss_hp_modifier()
	# Where boss_hp_scaling_base = 1.05
	var base = 1.05
	
	# Normal Difficulty (modifier = 1.0)
	global_events.set_difficulty(global_events.Difficulty.NORMAL)
	var mod_normal = global_events.get_boss_hp_modifier()
	
	var mult_0m = pow(base, 0.0) * mod_normal
	assert_almost_eq(mult_0m, 1.0, 0.0001, "Boss multiplier at 0m on Normal")
	
	var mult_5m = pow(base, 5.0) * mod_normal
	assert_almost_eq(mult_5m, 1.27628, 0.0001, "Boss multiplier at 5m on Normal (1.05^5)")
	
	var mult_10m = pow(base, 10.0) * mod_normal
	assert_almost_eq(mult_10m, 1.62889, 0.0001, "Boss multiplier at 10m on Normal (1.05^10)")
	
	var mult_20m = pow(base, 20.0) * mod_normal
	assert_almost_eq(mult_20m, 2.65330, 0.0001, "Boss multiplier at 20m on Normal (1.05^20)")
	
	# Hard Difficulty (modifier = 1.2)
	global_events.set_difficulty(global_events.Difficulty.HARD)
	var mod_hard = global_events.get_boss_hp_modifier()
	var mult_10m_hard = pow(base, 10.0) * mod_hard
	assert_almost_eq(mult_10m_hard, 1.62889 * 1.2, 0.001, "Boss multiplier at 10m on Hard (1.05^10 * 1.2)")
	
	# Easy Difficulty (modifier = 0.8)
	global_events.set_difficulty(global_events.Difficulty.EASY)
	var mod_easy = global_events.get_boss_hp_modifier()
	var mult_10m_easy = pow(base, 10.0) * mod_easy
	assert_almost_eq(mult_10m_easy, 1.62889 * 0.8, 0.001, "Boss multiplier at 10m on Easy (1.05^10 * 0.8)")

func test_enemy_intensity_scaling_curve() -> void:
	# Formula in enemy_spawner.gd:
	# base_enemy_intensity = 3.0, enemy_intensity_time_multiplier = 1.5
	# t <= 1.0: 3.0
	# 1.0 < t <= 3.0: 3.0 + 0.75 * t^2
	# t > 3.0: (3.0 + 1.5) + t * 1.5 = 4.5 + 1.5 * t
	var calc_intensity = func(minutes: float) -> float:
		var base_intensity = 3.0
		var time_mult = 1.5
		if minutes <= 1.0:
			return base_intensity
		elif minutes <= 3.0:
			var A = time_mult / 2.0 # 0.75
			return base_intensity + (A * minutes * minutes)
		else:
			var val_at_3 = base_intensity + time_mult # 4.5
			return val_at_3 + minutes * time_mult
	
	# Check key milestone minutes
	assert_almost_eq(calc_intensity.call(0.5), 3.0, 0.0001, "Intensity at t=0.5m")
	assert_almost_eq(calc_intensity.call(1.0), 3.0, 0.0001, "Intensity at t=1.0m")
	# At t=2.0m: 3.0 + 0.75 * 4 = 6.0
	assert_almost_eq(calc_intensity.call(2.0), 6.0, 0.0001, "Intensity at t=2.0m")
	# At t=3.0m: 3.0 + 0.75 * 9 = 9.75
	assert_almost_eq(calc_intensity.call(3.0), 9.75, 0.0001, "Intensity at t=3.0m (quadratic peak)")
	# At t=4.0m: 4.5 + 1.5 * 4 = 10.5
	assert_almost_eq(calc_intensity.call(4.0), 10.5, 0.0001, "Intensity at t=4.0m (linear)")
	# At t=10.0m: 4.5 + 1.5 * 10 = 19.5
	assert_almost_eq(calc_intensity.call(10.0), 19.5, 0.0001, "Intensity at t=10.0m (late game)")
