# SPDX-License-Identifier: GPL-3.0-or-later
# Standalone Headless Verification Script for Health Items
extends SceneTree

var _has_run: bool = false
var passes: int = 0
var failures: int = 0

class MockGui extends Node:
	var levelPanel: Control
	var bossLevelPanel: Control
	var deathPanel: Control
	func _init():
		levelPanel = Control.new()
		bossLevelPanel = Control.new()
		deathPanel = Control.new()
		deathPanel.visible = false
	func set_expbar(_c, _m): pass
	func show_levelup(_o, _l): pass
	func hide_level_panels(): pass
	func adjust_gui_collection(_u): pass
	func show_death_panel(_w): pass
	func cleanup():
		levelPanel.free()
		bossLevelPanel.free()
		deathPanel.free()

func _create_player() -> Dictionary:
	var player_script = load("res://Player/player.gd")
	var player = player_script.new()
	player.base_maxhp = 100
	player.maxhp = 100
	player.hp = 100
	var hb = ProgressBar.new()
	player.healthBar = hb
	var cs = CollisionShape2D.new()
	cs.shape = CircleShape2D.new()
	player.grab_shape = cs
	var weapons = Node2D.new()
	player.weapons = weapons
	var mock_gui = MockGui.new()
	player.gui = mock_gui
	return {"player": player, "hb": hb, "cs": cs, "weapons": weapons, "gui": mock_gui}

func _destroy_player(ctx: Dictionary) -> void:
	ctx["gui"].cleanup()
	ctx["gui"].free()
	ctx["weapons"].free()
	ctx["cs"].shape = null
	ctx["cs"].free()
	ctx["hb"].free()
	ctx["player"].free()

func assert_true(cond: bool, msg: String = ""):
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: ", msg)

func assert_false(cond: bool, msg: String = ""):
	assert_true(not cond, msg)

func assert_eq(a, b, msg: String = ""):
	if a == b:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: ", msg, " Expected: ", b, " Got: ", a)

func assert_almost_eq(a: float, b: float, tol: float = 0.001, msg: String = ""):
	if abs(a - b) <= tol:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: ", msg, " Expected: ", b, " Got: ", a)

func _process(_delta: float) -> bool:
	if _has_run: return false
	_has_run = true
	run_all_tests()
	print("\n--- HEALTH ITEMS VERIFICATION SUMMARY ---")
	print("Passed: %d, Failed: %d" % [passes, failures])
	quit(0 if failures == 0 else 1)
	return true

func run_all_tests() -> void:
	test_tc01_glass_talisman_db_schema()
	test_tc02_glass_talisman_tier_damage_scaling()
	test_tc03_glass_talisman_boundary_active_at_95_percent()
	test_tc04_glass_talisman_boundary_inactive_below_95_percent()
	test_tc05_glass_talisman_dynamic_toggling_on_damage_and_heal()
	test_tc06_glass_talisman_endless_stacking()
	test_tc07_warding_brooch_db_schema()
	test_tc08_warding_brooch_damage_absorption_within_5_percent()
	test_tc09_warding_brooch_damage_spillover_exceeding_5_percent()
	test_tc10_warding_brooch_recharge_requires_10s_and_90_percent_hp()
	test_tc11_warding_brooch_tier_2_movement_speed_boost_on_break()
	test_tc12_frenzy_charm_db_schema()
	test_tc13_frenzy_charm_boundary_inactive_at_30_percent_hp()
	test_tc14_frenzy_charm_boundary_active_below_30_percent_hp()
	test_tc15_frenzy_charm_dynamic_toggling_on_heal()
	test_tc16_frenzy_charm_cooldown_safety_floor_enforcement()
	test_tc17_impact_buckler_db_schema()
	test_tc18_impact_buckler_triggers_when_dropping_below_20_percent()
	test_tc19_impact_buckler_does_not_trigger_above_20_percent()
	test_tc20_impact_buckler_cooldown_enforcement_by_tier()
	test_tc21_impact_buckler_rearm_after_cooldown_expiry()
	test_tc22_impact_buckler_boss_displacement_immunity()

func test_tc01_glass_talisman_db_schema():
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("glasstalisman1"), "TC01: glasstalisman1 exists")
	assert_true(udb.has("glasstalisman2"), "TC01: glasstalisman2 exists")
	assert_true(udb.has("glasstalisman3"), "TC01: glasstalisman3 exists")
	assert_true(udb.has("glasstalisman4"), "TC01: glasstalisman4 exists")
	assert_true(udb.has("glasstalisman_endless"), "TC01: glasstalisman_endless exists")
	assert_eq(udb["glasstalisman1"]["prerequisite"], [], "TC01: tier 1 prereq empty")
	assert_eq(udb["glasstalisman2"]["prerequisite"], ["glasstalisman1"], "TC01: tier 2 prereq")
	assert_eq(udb["glasstalisman3"]["prerequisite"], ["glasstalisman2"], "TC01: tier 3 prereq")
	assert_eq(udb["glasstalisman4"]["prerequisite"], ["glasstalisman3"], "TC01: tier 4 prereq")
	assert_eq(udb["glasstalisman_endless"]["prerequisite"], ["glasstalisman4"], "TC01: endless prereq")
	assert_eq(udb["glasstalisman_endless"]["type"], "endless", "TC01: endless type")
	assert_almost_eq(udb["glasstalisman_endless"]["stat_modifiers"]["damage"], 0.02, 0.001, "TC01: endless damage mod")

func test_tc02_glass_talisman_tier_damage_scaling():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player._set_hp(100)
	
	player.upgrade_character("glasstalisman1")
	assert_almost_eq(player.get_damage_bonus(), 0.05, 0.001, "TC02: Tier 1 is +5%")
	player.upgrade_character("glasstalisman2")
	assert_almost_eq(player.get_damage_bonus(), 0.10, 0.001, "TC02: Tier 2 is +10%")
	player.upgrade_character("glasstalisman3")
	assert_almost_eq(player.get_damage_bonus(), 0.15, 0.001, "TC02: Tier 3 is +15%")
	player.upgrade_character("glasstalisman4")
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "TC02: Tier 4 is +25%")
	_destroy_player(ctx)

func test_tc03_glass_talisman_boundary_active_at_95_percent():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	
	player._set_hp(100.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "TC03: 100% HP has bonus")
	player._set_hp(95.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "TC03: Exact 95% HP has bonus")
	_destroy_player(ctx)

func test_tc04_glass_talisman_boundary_inactive_below_95_percent():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	
	player._set_hp(94.9)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "TC04: 94.9% HP has 0 bonus")
	player._set_hp(90.0)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "TC04: 90% HP has 0 bonus")
	_destroy_player(ctx)

func test_tc05_glass_talisman_dynamic_toggling_on_damage_and_heal():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	player._set_hp(100.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "TC05: Starts active at 100 HP")
	
	player._set_hp(90.0)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "TC05: Drops to 0 at 90 HP")
	
	player._set_hp(95.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "TC05: Reactivates at 95 HP")
	_destroy_player(ctx)

func test_tc06_glass_talisman_endless_stacking():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	for i in range(5):
		player.upgrade_character("glasstalisman_endless")
	
	player._set_hp(100.0)
	# 0.25 + 5 * 0.02 = 0.35
	assert_almost_eq(player.get_damage_bonus(), 0.35, 0.001, "TC06: Tier 4 + 5 endless stacks is +35%")
	player._set_hp(90.0)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "TC06: Endless bonus inactive below 95% HP")
	_destroy_player(ctx)

func test_tc07_warding_brooch_db_schema():
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("wardingbrooch1"), "TC07: wardingbrooch1 exists")
	assert_true(udb.has("wardingbrooch2"), "TC07: wardingbrooch2 exists")
	assert_false(udb.has("wardingbrooch_endless"), "TC07: wardingbrooch_endless does NOT exist")

func test_tc08_warding_brooch_damage_absorption_within_5_percent():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = true
	
	var res = player.absorb_warding_damage(4.0)
	assert_almost_eq(res["absorbed"], 4.0, 0.001, "TC08: 4.0 damage absorbed")
	assert_almost_eq(res["spillover"], 0.0, 0.001, "TC08: 0.0 spillover")
	assert_false(player.warding_brooch_charge, "TC08: Charge consumed")
	_destroy_player(ctx)

func test_tc09_warding_brooch_damage_spillover_exceeding_5_percent():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = true
	
	var res = player.absorb_warding_damage(12.0)
	assert_almost_eq(res["absorbed"], 5.0, 0.001, "TC09: 5.0 max HP capacity absorbed")
	assert_almost_eq(res["spillover"], 7.0, 0.001, "TC09: 7.0 spills over")
	assert_false(player.warding_brooch_charge, "TC09: Charge consumed")
	_destroy_player(ctx)

func test_tc10_warding_brooch_recharge_requires_10s_and_90_percent_hp():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = false
	player.warding_brooch_timer = 0.0
	
	# Advance 9.9s at 100% HP -> no charge
	player.update_health_items(9.9)
	assert_false(player.warding_brooch_charge, "TC10: No charge at 9.9s")
	
	# Advance another 0.2s -> 10.1s at >= 90% HP -> charge gained
	player.update_health_items(0.2)
	assert_true(player.warding_brooch_charge, "TC10: Charge gained after 10s at >= 90% HP")
	
	# Take hit and drop to 85% HP (< 90%)
	player.absorb_warding_damage(10.0)
	player._set_hp(85.0)
	assert_false(player.warding_brooch_charge, "TC10: Charge broken")
	assert_almost_eq(player.warding_brooch_timer, 0.0, 0.001, "TC10: Timer reset on damage")
	
	# Advance 15.0s while HP is 85% (< 90%) -> no charge
	player.update_health_items(15.0)
	assert_false(player.warding_brooch_charge, "TC10: No charge gained while HP < 90%")
	
	# Heal to 92% (>= 90%) after 15s out of combat -> charge immediately gained
	player._set_hp(92.0)
	assert_true(player.warding_brooch_charge, "TC10: Charge gained once healed >= 90% HP")
	_destroy_player(ctx)

func test_tc11_warding_brooch_tier_2_movement_speed_boost_on_break():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.base_movement_speed = 75.0
	player.movement_speed = 75.0
	player.upgrade_character("wardingbrooch1")
	player.upgrade_character("wardingbrooch2")
	player.warding_brooch_charge = true
	
	# Break charge
	player.absorb_warding_damage(5.0)
	# 75.0 * 1.15 = 86.25
	assert_almost_eq(player.movement_speed, 86.25, 0.01, "TC11: Speed increased by +15% on break")
	
	# Advance 2.0s -> speed still boosted
	player.update_health_items(2.0)
	assert_almost_eq(player.movement_speed, 86.25, 0.01, "TC11: Speed boost persists at 2s")
	
	# Advance remaining 1.1s -> speed returns to 75.0
	player.update_health_items(1.1)
	assert_almost_eq(player.movement_speed, 75.0, 0.01, "TC11: Speed returns to normal after 3s")
	_destroy_player(ctx)

func test_tc12_frenzy_charm_db_schema():
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("frenzycharm1"), "TC12: frenzycharm1 exists")
	assert_true(udb.has("frenzycharm2"), "TC12: frenzycharm2 exists")
	assert_true(udb.has("frenzycharm3"), "TC12: frenzycharm3 exists")
	assert_false(udb.has("frenzycharm_endless"), "TC12: frenzycharm_endless does NOT exist")

func test_tc13_frenzy_charm_boundary_inactive_at_30_percent_hp():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	
	player._set_hp(50.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.001, "TC13: 50% HP has 0 attack speed bonus")
	player._set_hp(30.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.001, "TC13: Exact 30% boundary has 0 bonus")
	_destroy_player(ctx)

func test_tc14_frenzy_charm_boundary_active_below_30_percent_hp():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm1")
	player._set_hp(20.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.10, 0.001, "TC14: Tier 1 gives +10%")
	
	player.upgrade_character("frenzycharm2")
	assert_almost_eq(player.get_attack_speed_bonus(), 0.20, 0.001, "TC14: Tier 2 gives +20%")
	
	player.upgrade_character("frenzycharm3")
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.001, "TC14: Tier 3 gives +30%")
	
	player._set_hp(29.9)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.001, "TC14: 29.9% HP is active")
	_destroy_player(ctx)

func test_tc15_frenzy_charm_dynamic_toggling_on_heal():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	player._set_hp(20.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.001, "TC15: Active at 20 HP")
	
	player._set_hp(35.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.001, "TC15: Inactive when healed to 35 HP")
	_destroy_player(ctx)

func test_tc16_frenzy_charm_cooldown_safety_floor_enforcement():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	player._set_hp(20.0)
	# Frenzy charm gives +30% attack speed -> spell_cooldown = 0.30
	# Base interval 0.06s * (1.0 - 0.30) = 0.042s
	# Safety floor guarantees max(0.05, 0.042) = 0.05s
	var calculated_cooldown = player.calculate_cooldown(0.06)
	assert_almost_eq(calculated_cooldown, 0.05, 0.0001, "TC16: 0.06s base clamped to safety floor 0.05s")
	_destroy_player(ctx)

func test_tc17_impact_buckler_db_schema():
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("impactbuckler1"), "TC17: impactbuckler1 exists")
	assert_true(udb.has("impactbuckler2"), "TC17: impactbuckler2 exists")
	assert_true(udb.has("impactbuckler3"), "TC17: impactbuckler3 exists")
	assert_false(udb.has("impactbuckler_endless"), "TC17: impactbuckler_endless does NOT exist")

func test_tc18_impact_buckler_triggers_when_dropping_below_20_percent():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player.buckler_triggered = false
	
	# Drop from 50 to 15 (< 20%)
	player._set_hp(15.0)
	assert_true(player.buckler_triggered, "TC18: Buckler triggers on dropping below 20%")
	assert_almost_eq(player.impact_buckler_cooldown, 60.0, 0.001, "TC18: Cooldown starts at 60s")
	_destroy_player(ctx)

func test_tc19_impact_buckler_does_not_trigger_above_20_percent():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player.buckler_triggered = false
	
	# Drop from 50 to 25 (>= 20%)
	player._set_hp(25.0)
	assert_false(player.buckler_triggered, "TC19: Buckler does not trigger at >= 20% HP")
	_destroy_player(ctx)

func test_tc20_impact_buckler_cooldown_enforcement_by_tier():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player._set_hp(15.0) # Triggers
	assert_true(player.buckler_triggered, "TC20: Triggered first time")
	player.buckler_triggered = false
	
	# Advance 15s (45s cooldown remaining)
	player.update_health_items(15.0)
	player._set_hp(10.0) # Further HP drop during cooldown
	assert_false(player.buckler_triggered, "TC20: Does not trigger again while on cooldown")
	_destroy_player(ctx)

func test_tc21_impact_buckler_rearm_after_cooldown_expiry():
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player._set_hp(15.0) # 1st trigger
	assert_eq(player.buckler_trigger_count, 1, "TC21: 1st trigger counted")
	
	# Advance 60.1s -> cooldown expires
	player.update_health_items(60.1)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "TC21: Cooldown expired")
	
	# Heal to 25 HP and drop to 15 HP again
	player._set_hp(25.0)
	player._set_hp(15.0)
	assert_eq(player.buckler_trigger_count, 2, "TC21: 2nd trigger successful after rearm")
	_destroy_player(ctx)

func test_tc22_impact_buckler_boss_displacement_immunity():
	var enemy_script = load("res://Enemy/Base/enemy_body.gd")
	var normal_enemy = enemy_script.new()
	normal_enemy.isBoss = 0
	normal_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_almost_eq(normal_enemy.knockback.x, 400.0, 0.001, "TC22: Normal enemy knocked back")
	
	var boss_enemy = enemy_script.new()
	boss_enemy.isBoss = 1
	boss_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_eq(boss_enemy.knockback, Vector2.ZERO, "TC22: Boss immune to displacement (Vector2.ZERO)")
	
	normal_enemy.free()
	boss_enemy.free()
