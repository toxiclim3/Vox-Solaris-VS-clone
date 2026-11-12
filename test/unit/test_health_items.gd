# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Unit Testing Suite - Health Items & Mechanics
# Validates Glass Talisman, Warding Brooch, Frenzy Charm, and Impact Buckler.

extends "res://Tests/test_base.gd"

class MockGui extends Node:
	var levelPanel: Control
	var bossLevelPanel: Control
	var deathPanel: Control
	var exp_history: Array = []
	var levelup_shown_count: int = 0
	
	func _init() -> void:
		levelPanel = Control.new()
		bossLevelPanel = Control.new()
		deathPanel = Control.new()
		levelPanel.visible = true
		bossLevelPanel.visible = false
		deathPanel.visible = false
	
	func set_expbar(_c: float, _m: float) -> void:
		pass
	
	func show_levelup(_options: Array, _level: int) -> void:
		levelup_shown_count += 1
		
	func hide_level_panels() -> void:
		pass
		
	func adjust_gui_collection(_upgrade: String) -> void:
		pass
		
	func show_death_panel(_win: bool) -> void:
		pass
	
	func cleanup() -> void:
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
	ctx["snd_hurt_bad"].free()
	ctx["snd_hurt"].free()
	ctx["gui"].cleanup()
	ctx["gui"].free()
	ctx["weapons"].free()
	ctx["cs"].shape = null
	ctx["cs"].free()
	ctx["hb"].free()
	ctx["player"].free()

# -----------------------------------------------------------------------------
# 1. Database Integrity (UpgradeDb Registrations & DAG)
# -----------------------------------------------------------------------------

func test_glass_talisman_db_schema() -> void:
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("glasstalisman1"), "glasstalisman1 exists")
	assert_true(udb.has("glasstalisman2"), "glasstalisman2 exists")
	assert_true(udb.has("glasstalisman3"), "glasstalisman3 exists")
	assert_true(udb.has("glasstalisman4"), "glasstalisman4 exists")
	assert_true(udb.has("glasstalisman_endless"), "glasstalisman_endless exists")
	
	assert_eq(udb["glasstalisman1"]["prerequisite"], [], "glasstalisman1 prereq empty")
	assert_eq(udb["glasstalisman2"]["prerequisite"], ["glasstalisman1"], "glasstalisman2 prereq is glasstalisman1")
	assert_eq(udb["glasstalisman3"]["prerequisite"], ["glasstalisman2"], "glasstalisman3 prereq is glasstalisman2")
	assert_eq(udb["glasstalisman4"]["prerequisite"], ["glasstalisman3"], "glasstalisman4 prereq is glasstalisman3")
	assert_eq(udb["glasstalisman_endless"]["prerequisite"], ["glasstalisman4"], "glasstalisman_endless prereq is glasstalisman4")
	
	assert_eq(udb["glasstalisman1"]["type"], "upgrade", "glasstalisman1 is upgrade type")
	assert_eq(udb["glasstalisman_endless"]["type"], "endless", "glasstalisman_endless is endless type")
	assert_almost_eq(udb["glasstalisman_endless"]["stat_modifiers"]["damage"], 0.02, 0.001, "Endless tier adds +2% damage per stack")

func test_warding_brooch_db_schema() -> void:
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("wardingbrooch1"), "wardingbrooch1 exists")
	assert_true(udb.has("wardingbrooch2"), "wardingbrooch2 exists")
	assert_false(udb.has("wardingbrooch_endless"), "wardingbrooch_endless must NOT exist (hard-capped)")
	
	assert_eq(udb["wardingbrooch1"]["prerequisite"], [], "wardingbrooch1 prereq empty")
	assert_eq(udb["wardingbrooch2"]["prerequisite"], ["wardingbrooch1"], "wardingbrooch2 prereq is wardingbrooch1")
	assert_eq(udb["wardingbrooch1"]["type"], "upgrade", "wardingbrooch1 is upgrade type")
	assert_eq(udb["wardingbrooch2"]["type"], "upgrade", "wardingbrooch2 is upgrade type")

func test_frenzy_charm_db_schema() -> void:
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("frenzycharm1"), "frenzycharm1 exists")
	assert_true(udb.has("frenzycharm2"), "frenzycharm2 exists")
	assert_true(udb.has("frenzycharm3"), "frenzycharm3 exists")
	assert_false(udb.has("frenzycharm_endless"), "frenzycharm_endless must NOT exist")
	
	assert_eq(udb["frenzycharm1"]["prerequisite"], [], "frenzycharm1 prereq empty")
	assert_eq(udb["frenzycharm2"]["prerequisite"], ["frenzycharm1"], "frenzycharm2 prereq is frenzycharm1")
	assert_eq(udb["frenzycharm3"]["prerequisite"], ["frenzycharm2"], "frenzycharm3 prereq is frenzycharm2")
	assert_eq(udb["frenzycharm1"]["type"], "upgrade", "frenzycharm1 is upgrade type")

func test_impact_buckler_db_schema() -> void:
	var udb = load("res://Utility/upgrade_db.gd").UPGRADES
	assert_true(udb.has("impactbuckler1"), "impactbuckler1 exists")
	assert_true(udb.has("impactbuckler2"), "impactbuckler2 exists")
	assert_true(udb.has("impactbuckler3"), "impactbuckler3 exists")
	assert_false(udb.has("impactbuckler_endless"), "impactbuckler_endless must NOT exist")
	
	assert_eq(udb["impactbuckler1"]["prerequisite"], [], "impactbuckler1 prereq empty")
	assert_eq(udb["impactbuckler2"]["prerequisite"], ["impactbuckler1"], "impactbuckler2 prereq is impactbuckler1")
	assert_eq(udb["impactbuckler3"]["prerequisite"], ["impactbuckler2"], "impactbuckler3 prereq is impactbuckler2")
	assert_eq(udb["impactbuckler1"]["type"], "upgrade", "impactbuckler1 is upgrade type")

# -----------------------------------------------------------------------------
# 2. Glass Talisman Mechanics
# -----------------------------------------------------------------------------

func test_glass_talisman_tier_damage_scaling() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player._set_hp(100)
	
	player.upgrade_character("glasstalisman1")
	assert_almost_eq(player.get_damage_bonus(), 0.05, 0.001, "Tier 1 bonus is +5%")
	assert_almost_eq(player.get_damage_modifier(), 1.05, 0.001, "Tier 1 modifier is 1.05")
	
	player.upgrade_character("glasstalisman2")
	assert_almost_eq(player.get_damage_bonus(), 0.10, 0.001, "Tier 2 bonus is +10%")
	assert_almost_eq(player.get_damage_modifier(), 1.10, 0.001, "Tier 2 modifier is 1.10")
	
	player.upgrade_character("glasstalisman3")
	assert_almost_eq(player.get_damage_bonus(), 0.15, 0.001, "Tier 3 bonus is +15%")
	assert_almost_eq(player.get_damage_modifier(), 1.15, 0.001, "Tier 3 modifier is 1.15")
	
	player.upgrade_character("glasstalisman4")
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "Tier 4 bonus is +25%")
	assert_almost_eq(player.get_damage_modifier(), 1.25, 0.001, "Tier 4 modifier is 1.25")
	
	_destroy_player(ctx)

func test_glass_talisman_boundary_active_at_95_percent() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	
	player._set_hp(100.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "100% HP has active bonus")
	
	player._set_hp(95.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "Exact 95% HP boundary has active bonus")
	assert_almost_eq(player.get_damage_modifier(), 1.25, 0.001, "Exact 95% HP damage modifier is 1.25")
	
	_destroy_player(ctx)

func test_glass_talisman_boundary_inactive_below_95_percent() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	
	player._set_hp(94.9)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "94.9% HP (<95%) has 0 bonus")
	assert_almost_eq(player.get_damage_modifier(), 1.0, 0.001, "94.9% HP damage modifier is 1.0")
	
	player._set_hp(90.0)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "90% HP has 0 bonus")
	assert_almost_eq(player.get_damage_modifier(), 1.0, 0.001, "90% HP damage modifier is 1.0")
	
	_destroy_player(ctx)

func test_glass_talisman_dynamic_toggling_on_damage_and_heal() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	player._set_hp(100.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "Starts active at 100 HP")
	
	player._set_hp(90.0)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "Drops to 0 on taking damage to 90 HP")
	
	player._set_hp(95.0)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.001, "Reactivates immediately when healed back to 95 HP")
	
	_destroy_player(ctx)

func test_glass_talisman_endless_stacking() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("glasstalisman4")
	for i in range(5):
		player.upgrade_character("glasstalisman_endless")
	
	player._set_hp(100.0)
	# 0.25 + 5 * 0.02 = 0.35 (+35%)
	assert_almost_eq(player.get_damage_bonus(), 0.35, 0.001, "Tier 4 + 5 endless stacks is +35% damage")
	assert_almost_eq(player.get_damage_modifier(), 1.35, 0.001, "Damage modifier is 1.35")
	
	player._set_hp(90.0)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.001, "Endless bonus inactive below 95% HP")
	assert_almost_eq(player.get_damage_modifier(), 1.0, 0.001, "Damage modifier inactive below 95% HP")
	
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 3. Warding Brooch Mechanics
# -----------------------------------------------------------------------------

func test_warding_brooch_damage_absorption_within_5_percent() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = true
	
	var res = player.absorb_warding_damage(4.0)
	assert_almost_eq(res["absorbed"], 4.0, 0.001, "4.0 damage absorbed within 5% max HP capacity")
	assert_almost_eq(res["spillover"], 0.0, 0.001, "0.0 spillover")
	assert_false(player.warding_brooch_charge, "Charge consumed upon absorbing damage")
	
	# Verify integration with _on_hurt_box_hurt
	player._set_hp(100.0)
	player.warding_brooch_charge = true
	player.armor = 0
	player._on_hurt_box_hurt(4.0, Vector2.ZERO, 0.0, "test")
	assert_almost_eq(player.hp, 100.0, 0.001, "Player HP remains at 100 after 4 damage absorbed")
	assert_false(player.warding_brooch_charge, "Charge consumed after hit")
	
	_destroy_player(ctx)

func test_warding_brooch_damage_spillover_exceeding_5_percent() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = true
	
	var res = player.absorb_warding_damage(12.0)
	assert_almost_eq(res["absorbed"], 5.0, 0.001, "5.0 max HP capacity absorbed")
	assert_almost_eq(res["spillover"], 7.0, 0.001, "7.0 excess spills over")
	assert_false(player.warding_brooch_charge, "Charge consumed upon absorbing damage")
	
	# Verify integration with _on_hurt_box_hurt
	player._set_hp(100.0)
	player.warding_brooch_charge = true
	player.armor = 0
	player._on_hurt_box_hurt(12.0, Vector2.ZERO, 0.0, "test")
	assert_almost_eq(player.hp, 93.0, 0.001, "Player HP drops by spillover amount (100 - 7 = 93)")
	assert_false(player.warding_brooch_charge, "Charge consumed after hit")
	
	_destroy_player(ctx)

func test_warding_brooch_recharge_requires_10s_and_90_percent_hp() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = false
	player.warding_brooch_timer = 0.0
	
	# Advance 9.9s at 100% HP -> no charge yet
	player.update_health_items(9.9)
	assert_false(player.warding_brooch_charge, "No charge at 9.9s out of combat")
	
	# Advance another 0.2s -> 10.1s total at >= 90% HP -> charge gained
	player.update_health_items(0.2)
	assert_true(player.warding_brooch_charge, "Charge gained after 10s out of combat at >= 90% HP")
	
	# Take hit and drop to 85% HP (< 90%)
	player.absorb_warding_damage(10.0)
	player._set_hp(85.0)
	assert_false(player.warding_brooch_charge, "Charge broken after damage")
	assert_almost_eq(player.warding_brooch_timer, 0.0, 0.001, "Timer reset on damage")
	
	# Advance 15.0s while HP is 85% (< 90%) -> no charge gained
	player.update_health_items(15.0)
	assert_false(player.warding_brooch_charge, "No charge gained while HP < 90%")
	
	# Heal to 92% (>= 90%) after 15s out of combat -> charge immediately gained
	player._set_hp(92.0)
	assert_true(player.warding_brooch_charge, "Charge immediately gained once healed to >= 90% HP")
	
	_destroy_player(ctx)

func test_warding_brooch_tier_2_movement_speed_boost_on_break() -> void:
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
	# 75.0 * 1.15 = 86.25 (+15% speed)
	assert_almost_eq(player.movement_speed, 86.25, 0.01, "Speed increased by +15% on break (75 -> 86.25)")
	
	# Advance 2.0s -> speed boost remains active
	player.update_health_items(2.0)
	assert_almost_eq(player.movement_speed, 86.25, 0.01, "Speed boost persists at 2.0s")
	
	# Advance remaining 1.1s (total 3.1s > 3.0s duration) -> speed returns to base
	player.update_health_items(1.1)
	assert_almost_eq(player.movement_speed, 75.0, 0.01, "Speed returns to 75.0 after 3.0s duration expires")
	
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 4. Frenzy Charm Mechanics
# -----------------------------------------------------------------------------

func test_frenzy_charm_boundary_inactive_at_30_percent_hp() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	
	player._set_hp(50.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.001, "50% HP has 0 attack speed bonus")
	assert_false(player.frenzy_charm_active, "Frenzy Charm inactive at 50% HP")
	
	player._set_hp(30.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.001, "Exact 30% boundary has 0 bonus (strictly < 30%)")
	assert_false(player.frenzy_charm_active, "Frenzy Charm inactive at 30% HP")
	
	_destroy_player(ctx)

func test_frenzy_charm_boundary_active_below_30_percent_hp() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	
	player._set_hp(29.9)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.001, "29.9% HP (<30%) has full +30% bonus")
	assert_true(player.frenzy_charm_active, "Frenzy Charm active at 29.9% HP")
	
	player._set_hp(20.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.001, "20.0% HP has full +30% bonus")
	assert_true(player.frenzy_charm_active, "Frenzy Charm active at 20.0% HP")
	
	_destroy_player(ctx)

func test_frenzy_charm_dynamic_toggling_on_heal() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	player._set_hp(20.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.001, "Active +30% at 20 HP")
	assert_true(player.frenzy_charm_active, "Frenzy Charm active at 20 HP")
	
	player._set_hp(35.0)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.001, "Bonus immediately deactivates when healed to 35 HP")
	assert_false(player.frenzy_charm_active, "Frenzy Charm inactive at 35 HP")
	
	_destroy_player(ctx)

func test_frenzy_charm_cooldown_safety_floor_enforcement() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("frenzycharm3")
	player._set_hp(20.0)
	# Frenzy charm gives +30% attack speed -> spell_cooldown = 0.30
	# Base interval 0.06s * (1.0 - 0.30) = 0.042s
	# Safety floor guarantees max(0.05, 0.042) = 0.05s
	var calculated_cooldown = player.calculate_cooldown(0.06)
	assert_almost_eq(calculated_cooldown, 0.05, 0.0001, "0.06s base clamped to safety floor 0.05s")
	
	var weapon_cooldown = player.calculate_weapon_cooldown(0.06)
	assert_almost_eq(weapon_cooldown, 0.05, 0.0001, "calculate_weapon_cooldown clamps to 0.05s")
	
	# Extreme base interval 0.01s clamped to 0.05s
	var extreme_cooldown = player.calculate_cooldown(0.01)
	assert_almost_eq(extreme_cooldown, 0.05, 0.0001, "Extreme 0.01s base clamped to safety floor 0.05s")
	
	# Normal interval 1.0s * (1.0 - 0.30) = 0.70s (> 0.05s)
	var normal_cooldown = player.calculate_cooldown(1.0)
	assert_almost_eq(normal_cooldown, 0.70, 0.0001, "Normal 1.0s base scales properly to 0.70s")
	
	_destroy_player(ctx)

# -----------------------------------------------------------------------------
# 5. Impact Buckler Mechanics
# -----------------------------------------------------------------------------

func test_impact_buckler_triggers_when_dropping_below_20_percent() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player.buckler_triggered = false
	
	# Drop from 50 to 15 (< 20%)
	player._set_hp(15.0)
	assert_true(player.buckler_triggered, "Buckler triggers on dropping below 20% HP")
	assert_almost_eq(player.impact_buckler_cooldown, 60.0, 0.001, "Tier 1 cooldown starts at 60s")
	
	_destroy_player(ctx)

func test_impact_buckler_does_not_trigger_above_20_percent() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player.buckler_triggered = false
	
	# Drop from 50 to 25 (>= 20%)
	player._set_hp(25.0)
	assert_false(player.buckler_triggered, "Buckler does not trigger at >= 20% HP")
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown remains at 0")
	
	_destroy_player(ctx)

func test_impact_buckler_cooldown_enforcement_by_tier() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	
	# Tier 1: 60s cooldown
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player._set_hp(15.0) # Triggers Tier 1
	assert_true(player.buckler_triggered, "Tier 1 triggered first time")
	assert_almost_eq(player.impact_buckler_cooldown, 60.0, 0.001, "Tier 1 cooldown set to 60s")
	player.buckler_triggered = false
	
	# Advance 15s (45s cooldown remaining)
	player.update_health_items(15.0)
	player._set_hp(10.0) # Further HP drop during cooldown
	assert_false(player.buckler_triggered, "Does not trigger again while on cooldown")
	
	# Expire cooldown
	player.update_health_items(50.0)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown expired")
	
	# Tier 2: 40s cooldown
	player.upgrade_character("impactbuckler2")
	player._set_hp(25.0)
	player.buckler_triggered = false
	player._set_hp(15.0) # Triggers Tier 2
	assert_true(player.buckler_triggered, "Tier 2 triggered")
	assert_almost_eq(player.impact_buckler_cooldown, 40.0, 0.001, "Tier 2 cooldown set to 40s")
	
	# Expire Tier 2 cooldown
	player.update_health_items(45.0)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Tier 2 cooldown expired")
	
	# Tier 3: 20s cooldown
	player.upgrade_character("impactbuckler3")
	player._set_hp(25.0)
	player.buckler_triggered = false
	player._set_hp(15.0) # Triggers Tier 3
	assert_true(player.buckler_triggered, "Tier 3 triggered")
	assert_almost_eq(player.impact_buckler_cooldown, 20.0, 0.001, "Tier 3 cooldown set to 20s")
	
	_destroy_player(ctx)

func test_impact_buckler_rearm_after_cooldown_expiry() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.upgrade_character("impactbuckler1")
	player._set_hp(50.0)
	player._set_hp(15.0) # 1st trigger
	assert_eq(player.buckler_trigger_count, 1, "1st trigger counted")
	
	# Advance 60.1s -> cooldown expires
	player.update_health_items(60.1)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown fully expired")
	
	# Heal to 25 HP and drop to 15 HP again
	player._set_hp(25.0)
	player._set_hp(15.0)
	assert_eq(player.buckler_trigger_count, 2, "2nd trigger successful after rearm")
	
	_destroy_player(ctx)

func test_impact_buckler_boss_displacement_immunity() -> void:
	var enemy_script = load("res://Enemy/Base/enemy_body.gd")
	
	var normal_enemy = enemy_script.new()
	normal_enemy.isBoss = 0
	normal_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_almost_eq(normal_enemy.knockback.x, 400.0, 0.001, "Normal enemy knocked back by shockwave")
	
	var boss_enemy = enemy_script.new()
	boss_enemy.isBoss = 1
	boss_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_eq(boss_enemy.knockback, Vector2.ZERO, "Boss (isBoss=1) immune to displacement")
	
	var boss_group_enemy = enemy_script.new()
	boss_group_enemy.isBoss = 0
	boss_group_enemy.add_to_group("boss")
	boss_group_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_eq(boss_group_enemy.knockback, Vector2.ZERO, "Boss in 'boss' group immune to displacement")
	
	normal_enemy.free()
	boss_enemy.free()
	boss_group_enemy.free()

func test_impact_buckler_shockwave_on_real_enemy_scene() -> void:
	var sw_scene = load("res://Player/Attack/impact_buckler/impact_buckler_shockwave.tscn")
	var sw = sw_scene.instantiate()
	var cyclops_scene = load("res://Enemy/Minions/enemy_cyclops.tscn")
	var cyclops = cyclops_scene.instantiate()
	var hurtbox = cyclops.get_node("EnemyBase/HurtBox")
	
	sw.global_position = Vector2(0, 0)
	cyclops.global_position = Vector2(50, 0)
	cyclops.knockback = Vector2.ZERO
	
	sw._on_area_entered(hurtbox)
	assert_almost_eq(cyclops.knockback.x, 400.0, 0.001, "Instantiated enemy receives knockback when shockwave hits HurtBox")
	
	sw.free()
	cyclops.free()

func test_warding_brooch_timer_reset_only_on_positive_damage() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_timer = 5.0
	
	# Zero damage hit: timer is not reset
	player._on_hurt_box_hurt(0.0, Vector2.ZERO, 0.0, "test")
	assert_almost_eq(player.warding_brooch_timer, 5.0, 0.001, "Timer does not reset on zero damage hit")
	
	# Positive damage hit: timer resets to 0
	player.armor = 0
	player._on_hurt_box_hurt(2.0, Vector2.ZERO, 0.0, "test")
	assert_almost_eq(player.warding_brooch_timer, 0.0, 0.001, "Timer resets to 0 on positive damage hit")
	
	_destroy_player(ctx)

func test_swarm_manager_glass_talisman_damage_scaling() -> void:
	var ctx = _create_player()
	var player = ctx["player"]
	player.maxhp = 100
	player.hp = 100
	player.upgrade_character("glasstalisman4") # +25% damage
	assert_almost_eq(player.get_damage_modifier(), 1.25, 0.001, "Glass talisman provides 1.25x modifier")
	
	var swarm_mgr_scene = load("res://Utility/swarm_manager.tscn")
	var sm = swarm_mgr_scene.instantiate()
	sm.player = player
	
	# Register a dummy texture enemy type
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)
	
	# Add swarm enemy using correct add_enemy method signature:
	sm.add_enemy(Vector2(100, 100), 100.0, 100.0, 50.0, 1, 1, type_id)
	assert_eq(sm.swarm_data.size(), 1, "Swarm enemy spawned")
	var enemy = sm.swarm_data[0]
	assert_almost_eq(enemy.hp, 100.0, 0.001, "Enemy initial HP is 100")
	
	# Scripted Area2D attack with declared damage property
	var atk_script = GDScript.new()
	atk_script.source_code = "extends Area2D\nvar damage: float = 20.0\nvar knockback_amount: float = 10.0\nvar hit_once_array: Array = []\n"
	atk_script.reload()
	var atk_node = Area2D.new()
	atk_node.set_script(atk_script)
	atk_node.damage = 20.0
	atk_node.knockback_amount = 10.0
	atk_node.add_to_group("attack")
	atk_node.collision_layer = 4
	
	var cs = CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	cs.shape = circle
	atk_node.add_child(cs)
	atk_node.global_position = Vector2(100, 100)
	
	# Mount to active scene tree so get_tree() resolves during _physics_process
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)
	test_root.add_child(sm)
	test_root.add_child(atk_node)
	sm.player = player
	
	# Simulate physics process
	sm._physics_process(0.016)
	
	# Expected damage: 20 * 1.0 (no curse) * 1.0 (GlobalEvents diff) * 1.25 (Glass Talisman) = 25.0
	# HP should be 100.0 - 25.0 = 75.0
	assert_almost_eq(enemy.hp, 75.0, 0.01, "Swarm enemy takes scaled damage from Glass Talisman (100 - 25 = 75)")
	
	test_root.free()
	_destroy_player(ctx)



