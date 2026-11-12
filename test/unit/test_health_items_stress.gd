# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Adversarial Stress Test Suite - Health Items & Mechanics
# Authors: Empirical Challenger Subagent
# Stress tests mathematical edge cases, threshold transitions, and timers:
# 1. Glass Talisman: floating-point boundaries around 0.95, 10+ endless stacks, damage scaling formula.
# 2. Warding Brooch: exact 5% max HP capacity absorption, massive damage spillover (1000 dmg),
#    10s recharge timer interruption & <90% HP suppression, Tier 2 speed boost exact duration (3.0s).
# 3. Frenzy Charm: attack speed scaling at 29.9% vs 30.0% HP, cooldown safety floor (wait_time >= 0.05s).
# 4. Impact Buckler: low-HP trigger (<20%), cooldown lock against repeated hits, re-arm after cooldown,
#    continuous low-HP behavior, boss displacement immunity.

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

class WeaponMock extends Node2D:
	var timer: Timer

func _create_player(base_hp: float = 100.0) -> Dictionary:
	var player_script = load("res://Player/player.gd")
	var player = player_script.new()
	player.base_maxhp = int(base_hp)
	player.maxhp = int(base_hp)
	player.hp = base_hp
	
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

# =============================================================================
# 1. GLASS TALISMAN ADVERSARIAL STRESS TESTS
# =============================================================================

func test_glass_talisman_floating_point_boundaries_around_95_percent() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("glasstalisman4")
	
	# Sub-boundary: 94.99% HP -> must be strictly inactive (0.0 bonus, 1.0 modifier)
	player._set_hp(94.99)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.00001, "0.9499 ratio yields 0.0 bonus")
	assert_almost_eq(player.get_damage_modifier(), 1.0, 0.00001, "0.9499 ratio yields 1.0 modifier")
	
	# Exact boundary: 95.00% HP -> must be active (+25% bonus, 1.25 modifier)
	player._set_hp(95.00)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.00001, "0.9500 exact boundary yields 0.25 bonus")
	assert_almost_eq(player.get_damage_modifier(), 1.25, 0.00001, "0.9500 exact boundary yields 1.25 modifier")
	
	# Supra-boundary: 95.01% HP -> must be active (+25% bonus, 1.25 modifier)
	player._set_hp(95.01)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.00001, "0.9501 ratio yields 0.25 bonus")
	assert_almost_eq(player.get_damage_modifier(), 1.25, 0.00001, "0.9501 ratio yields 1.25 modifier")
	
	# Micro-precision sweep (1e-4 steps)
	player._set_hp(94.999)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.00001, "0.94999 ratio yields 0.0 bonus")
	
	player._set_hp(95.001)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.00001, "0.95001 ratio yields 0.25 bonus")
	
	_destroy_player(ctx)

func test_glass_talisman_non_100_maxhp_boundary_scaling() -> void:
	# Test with base maxhp = 80 (common non-100 baseline)
	# 95% of 80 = 76.0 exactly
	var ctx = _create_player(80.0)
	var player = ctx["player"]
	player.upgrade_character("glasstalisman4")
	
	player._set_hp(75.99)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.00001, "HP 75.99/80 (0.949875) inactive")
	
	player._set_hp(76.00)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.00001, "HP 76.00/80 (0.95) active")
	
	player._set_hp(76.01)
	assert_almost_eq(player.get_damage_bonus(), 0.25, 0.00001, "HP 76.01/80 (0.950125) active")
	
	_destroy_player(ctx)
	
	# Test with base maxhp = 137 (prime number)
	# 95% of 137 = 130.15
	var ctx2 = _create_player(137.0)
	var player2 = ctx2["player"]
	player2.upgrade_character("glasstalisman4")
	
	player2._set_hp(130.14)
	assert_almost_eq(player2.get_damage_bonus(), 0.0, 0.00001, "HP 130.14/137 (<0.95) inactive")
	
	player2._set_hp(130.15)
	assert_almost_eq(player2.get_damage_bonus(), 0.25, 0.00001, "HP 130.15/137 (>=0.95) active")
	
	_destroy_player(ctx2)

func test_glass_talisman_10_plus_endless_stacking_and_formula() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("glasstalisman1")
	player.upgrade_character("glasstalisman2")
	player.upgrade_character("glasstalisman3")
	player.upgrade_character("glasstalisman4")
	
	# Stack 10 endless tiers
	for i in range(10):
		player.upgrade_character("glasstalisman_endless")
	
	# 10 stacks: 0.25 + 10 * 0.02 = 0.45 (+45% bonus, 1.45 modifier)
	player._set_hp(100.0)
	assert_almost_eq(player.get_damage_bonus(), 0.45, 0.00001, "10 endless stacks: bonus is 0.45")
	assert_almost_eq(player.get_damage_modifier(), 1.45, 0.00001, "10 endless stacks: modifier is 1.45")
	
	# Stack 5 more (15 total): 0.25 + 15 * 0.02 = 0.55
	for i in range(5):
		player.upgrade_character("glasstalisman_endless")
	assert_almost_eq(player.get_damage_bonus(), 0.55, 0.00001, "15 endless stacks: bonus is 0.55")
	assert_almost_eq(player.get_damage_modifier(), 1.55, 0.00001, "15 endless stacks: modifier is 1.55")
	
	# Stack 10 more (25 total): 0.25 + 25 * 0.02 = 0.75
	for i in range(10):
		player.upgrade_character("glasstalisman_endless")
	assert_almost_eq(player.get_damage_bonus(), 0.75, 0.00001, "25 endless stacks: bonus is 0.75")
	assert_almost_eq(player.get_damage_modifier(), 1.75, 0.00001, "25 endless stacks: modifier is 1.75")
	
	# Stack 25 more (50 total): 0.25 + 50 * 0.02 = 1.25 (+125% bonus)
	for i in range(25):
		player.upgrade_character("glasstalisman_endless")
	assert_almost_eq(player.get_damage_bonus(), 1.25, 0.00001, "50 endless stacks: bonus is 1.25")
	assert_almost_eq(player.get_damage_modifier(), 2.25, 0.00001, "50 endless stacks: modifier is 2.25")
	
	# Verify complete deactivation below 95% HP even with 50 endless stacks
	player._set_hp(94.99)
	assert_almost_eq(player.get_damage_bonus(), 0.0, 0.00001, "Bonus strictly 0.0 when HP < 95% with 50 stacks")
	assert_almost_eq(player.get_damage_modifier(), 1.0, 0.00001, "Modifier strictly 1.0 when HP < 95% with 50 stacks")
	
	# Verify immediate re-activation when restored to 95% HP
	player._set_hp(95.00)
	assert_almost_eq(player.get_damage_bonus(), 1.25, 0.00001, "Full 50-stack bonus re-engages at exact 95% HP")
	assert_almost_eq(player.get_damage_modifier(), 2.25, 0.00001, "Full 50-stack modifier re-engages at exact 95% HP")
	
	_destroy_player(ctx)

# =============================================================================
# 2. WARDING BROOCH ADVERSARIAL STRESS TESTS
# =============================================================================

func test_warding_brooch_exact_5_percent_capacity_absorption() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = true
	
	# Exact 5% max HP damage (5.0 damage on 100 max HP)
	var res_exact = player.absorb_warding_damage(5.0)
	assert_almost_eq(res_exact["absorbed"], 5.0, 0.00001, "Absorbs exactly 5.0 on 100 max HP")
	assert_almost_eq(res_exact["spillover"], 0.0, 0.00001, "Spillover is exactly 0.0")
	assert_false(player.warding_brooch_charge, "Charge consumed")
	
	# Re-test with 250 max HP (5% capacity = 12.5)
	player.maxhp = 250
	player.hp = 250
	player.warding_brooch_charge = true
	
	# Exact boundary: 12.5 damage
	var res_250 = player.absorb_warding_damage(12.5)
	assert_almost_eq(res_250["absorbed"], 12.5, 0.00001, "Absorbs exactly 12.5 on 250 max HP")
	assert_almost_eq(res_250["spillover"], 0.0, 0.00001, "Zero spillover at exact capacity")
	
	# Boundary delta test: 12.5001 damage on 250 max HP
	player.warding_brooch_charge = true
	var res_delta = player.absorb_warding_damage(12.5001)
	assert_almost_eq(res_delta["absorbed"], 12.5, 0.00001, "Absorbed capped at 12.5")
	assert_almost_eq(res_delta["spillover"], 0.0001, 0.00001, "Excess 0.0001 spills over")
	
	_destroy_player(ctx)

func test_warding_brooch_massive_damage_spillover_1000() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.armor = 0
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = true
	
	# Direct absorption call with 1000.0 damage
	var res = player.absorb_warding_damage(1000.0)
	assert_almost_eq(res["absorbed"], 5.0, 0.00001, "Only 5.0 (5% max HP) absorbed from 1000 damage")
	assert_almost_eq(res["spillover"], 995.0, 0.00001, "Excess 995.0 spills over")
	assert_false(player.warding_brooch_charge, "Charge consumed on massive hit")
	assert_almost_eq(player.warding_brooch_timer, 0.0, 0.00001, "Out-of-combat timer reset to 0")
	
	# Test via full _on_hurt_box_hurt pipeline
	player._set_hp(100.0)
	player.warding_brooch_charge = true
	player.armor = 0
	ctx["gui"].deathPanel.visible = true # Guard against unparented get_tree() in death()
	# In player.gd: actual_damage is clamped to 999.0 by armor formula:
	# actual_damage = clamp(damage * (1 - dr), 0, 999) -> 999.0
	# Brooch absorbs 5.0, spillover = 994.0 -> HP drops by 994.0 -> clamps to 0
	player._on_hurt_box_hurt(1000.0, Vector2.ZERO, 0.0, "massive_boss_slam")
	assert_almost_eq(player.last_warding_absorbed, 5.0, 0.00001, "Brooch absorbed 5.0 during pipeline")
	assert_almost_eq(player.last_warding_spillover, 994.0, 0.00001, "Spillover 994.0 (999-5) during pipeline")
	assert_almost_eq(player.hp, 0.0, 0.00001, "Player killed by massive spillover")
	
	_destroy_player(ctx)

func test_warding_brooch_out_of_combat_recharge_and_interruption() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = false
	player.warding_brooch_timer = 0.0
	
	# Step 1: Wait 9.9s out of combat at 100% HP -> no charge
	player.update_health_items(9.9)
	assert_false(player.warding_brooch_charge, "No charge at 9.9s")
	assert_almost_eq(player.warding_brooch_timer, 9.9, 0.001, "Timer is 9.9s")
	
	# Step 2: Interruption! Take damage at 9.9s -> timer resets to 0.0
	player._on_hurt_box_hurt(2.0, Vector2.ZERO, 0.0, "interruption")
	assert_almost_eq(player.warding_brooch_timer, 0.0, 0.001, "Damage interrupts recharge and resets timer to 0")
	assert_false(player.warding_brooch_charge, "Still no charge after interruption")
	
	# Step 3: Advance 9.9s again -> still no charge
	player.update_health_items(9.9)
	assert_false(player.warding_brooch_charge, "Still no charge at 9.9s after reset")
	
	# Step 4: Advance another 0.11s (total 10.01s) at 98% HP (>=90%) -> charge gained
	player.update_health_items(0.11)
	assert_true(player.warding_brooch_charge, "Charge successfully gained after 10s uninterrupted out of combat")
	
	_destroy_player(ctx)

func test_warding_brooch_no_charge_gained_when_hp_below_90_percent() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("wardingbrooch1")
	player.warding_brooch_charge = false
	player.warding_brooch_timer = 0.0
	
	# Set HP to 89.9% (< 90%)
	player._set_hp(89.9)
	
	# Advance 10s out of combat
	player.update_health_items(10.0)
	assert_false(player.warding_brooch_charge, "No charge gained at 10s while HP is 89.9%")
	
	# Advance another 50s (total 60s out of combat) while HP < 90%
	player.update_health_items(50.0)
	assert_false(player.warding_brooch_charge, "No charge gained after 60s out of combat while HP < 90%")
	assert_almost_eq(player.warding_brooch_timer, 60.0, 0.01, "Timer tracked 60s out of combat")
	
	# Damage interruption while HP < 90%
	player._on_hurt_box_hurt(5.0, Vector2.ZERO, 0.0, "hit_while_low")
	assert_almost_eq(player.warding_brooch_timer, 0.0, 0.001, "Timer reset on hit even while HP < 90%")
	
	# Advance 15s out of combat at 84.9% HP
	player.update_health_items(15.0)
	assert_false(player.warding_brooch_charge, "No charge gained at 84.9% HP")
	
	# Heal to 90.0% HP -> should immediately trigger recharge because timer >= 10.0s
	player._set_hp(90.0)
	assert_true(player.warding_brooch_charge, "Charge triggers immediately upon healing to >= 90% after 15s out of combat")
	
	_destroy_player(ctx)

func test_warding_brooch_tier_2_speed_boost_duration_and_reversion() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.base_movement_speed = 100.0
	player.movement_speed = 100.0
	player.upgrade_character("wardingbrooch1")
	player.upgrade_character("wardingbrooch2")
	player.warding_brooch_charge = true
	
	# Break charge
	player.absorb_warding_damage(5.0)
	# 100.0 * 1.15 = 115.0 (+15% movement speed)
	assert_almost_eq(player.movement_speed, 115.0, 0.001, "Speed increased to 115.0 (+15%) on break")
	assert_almost_eq(player.warding_brooch_speed_timer, 3.0, 0.001, "Speed timer set to exactly 3.0s")
	
	# Advance 1.5s (midpoint)
	player.update_health_items(1.5)
	assert_almost_eq(player.movement_speed, 115.0, 0.001, "Speed remains boosted at t=1.5s")
	assert_almost_eq(player.warding_brooch_speed_timer, 1.5, 0.001, "Timer at 1.5s")
	
	# Advance to 2.99s (just before expiry)
	player.update_health_items(1.49)
	assert_almost_eq(player.movement_speed, 115.0, 0.001, "Speed remains boosted at t=2.99s")
	assert_almost_eq(player.warding_brooch_speed_timer, 0.01, 0.001, "Timer at 0.01s")
	
	# Advance remaining 0.02s (cumulative 3.01s > 3.0s expiry)
	player.update_health_items(0.02)
	assert_almost_eq(player.warding_brooch_speed_timer, 0.0, 0.001, "Timer reached 0.0s")
	assert_almost_eq(player.movement_speed, 100.0, 0.001, "Speed cleanly reverted to base 100.0 after 3.0s duration expires")
	
	# Verify Tier 1 does NOT grant speed boost on break
	player.warding_brooch_level = 1
	player.warding_brooch_charge = true
	player.absorb_warding_damage(5.0)
	assert_almost_eq(player.movement_speed, 100.0, 0.001, "Tier 1 grants no speed boost on break")
	assert_almost_eq(player.warding_brooch_speed_timer, 0.0, 0.001, "Tier 1 speed timer remains 0.0")
	
	_destroy_player(ctx)

# =============================================================================
# 3. FRENZY CHARM ADVERSARIAL STRESS TESTS
# =============================================================================

func test_frenzy_charm_attack_speed_scaling_at_30_percent_boundary() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("frenzycharm3")
	
	# Boundary: 30.0% HP -> must be strictly INACTIVE (0.0 bonus)
	player._set_hp(30.00)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.00001, "Exact 30.0% HP: bonus is 0.0")
	assert_false(player.frenzy_charm_active, "Exact 30.0% HP: frenzy_charm_active is false")
	
	# Supra-boundary: 30.01% HP -> INACTIVE
	player._set_hp(30.01)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.0, 0.00001, "30.01% HP: bonus is 0.0")
	assert_false(player.frenzy_charm_active, "30.01% HP: frenzy_charm_active is false")
	
	# Sub-boundary: 29.99% HP -> ACTIVE (+30% bonus at Tier 3)
	player._set_hp(29.99)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.00001, "29.99% HP: bonus is 0.30")
	assert_true(player.frenzy_charm_active, "29.99% HP: frenzy_charm_active is true")
	
	# Standard sub-boundary: 29.90% HP -> ACTIVE (+30% bonus at Tier 3)
	player._set_hp(29.90)
	assert_almost_eq(player.get_attack_speed_bonus(), 0.30, 0.00001, "29.90% HP: bonus is 0.30")
	assert_true(player.frenzy_charm_active, "29.90% HP: frenzy_charm_active is true")
	
	# Test Tier 1 (+10%) and Tier 2 (+20%) at 29.9% HP
	player.frenzy_charm_level = 1
	assert_almost_eq(player.get_attack_speed_bonus(), 0.10, 0.00001, "Tier 1 at 29.9% HP: bonus is 0.10")
	
	player.frenzy_charm_level = 2
	assert_almost_eq(player.get_attack_speed_bonus(), 0.20, 0.00001, "Tier 2 at 29.9% HP: bonus is 0.20")
	
	_destroy_player(ctx)

func test_frenzy_charm_cooldown_safety_floor_under_extreme_cdr() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("frenzycharm3")
	player._set_hp(20.0) # Activates Frenzy Charm (+30% attack speed)
	
	# Baseline test: base 0.06s * (1.0 - 0.30) = 0.042s -> clamped to 0.05s
	assert_almost_eq(player.calculate_cooldown(0.06), 0.05, 0.0001, "0.06s base clamped to 0.05s")
	assert_almost_eq(player.calculate_weapon_cooldown(0.06), 0.05, 0.0001, "calculate_weapon_cooldown clamped to 0.05s")
	
	# Extreme test 1: Tiny base wait time (0.01s)
	assert_almost_eq(player.calculate_cooldown(0.01), 0.05, 0.0001, "0.01s base clamped to 0.05s")
	
	# Extreme test 2: Infinitesimal base wait time (0.0001s)
	assert_almost_eq(player.calculate_cooldown(0.0001), 0.05, 0.0001, "0.0001s base clamped to 0.05s")
	
	# Extreme test 3: CDR = 0.99 (99% CDR from items + Frenzy)
	player.spell_cooldown = 0.99
	assert_almost_eq(player.calculate_cooldown(1.0), 0.05, 0.0001, "1.0s at 99% CDR clamped to 0.05s (1.0*0.01=0.01 -> 0.05)")
	
	# Extreme test 4: 100% CDR (spell_cooldown = 1.0) -> formula gives 0.0s -> clamped to 0.05s
	player.spell_cooldown = 1.0
	assert_almost_eq(player.calculate_cooldown(1.0), 0.05, 0.0001, "1.0s at 100% CDR clamped to 0.05s")
	assert_almost_eq(player.calculate_weapon_cooldown(1.0), 0.05, 0.0001, "calculate_weapon_cooldown at 100% CDR clamped to 0.05s")
	
	# Extreme test 5: Over-capped CDR (spell_cooldown = 1.50) -> formula gives negative value -> clamped to 0.05s
	player.spell_cooldown = 1.50
	assert_almost_eq(player.calculate_cooldown(1.0), 0.05, 0.0001, "Overcapped 150% CDR clamped to 0.05s")
	
	# Extreme test 6: Insane CDR (spell_cooldown = 10.0) -> clamped to 0.05s
	player.spell_cooldown = 10.0
	assert_almost_eq(player.calculate_cooldown(0.5), 0.05, 0.0001, "1000% CDR clamped to 0.05s")
	
	# Verify player.attack() clamps weapon timers below 0.05s
	var test_weapon = WeaponMock.new()
	var test_timer = Timer.new()
	test_timer.wait_time = 0.01 # Violates safety floor
	test_weapon.timer = test_timer
	test_weapon.add_child(test_timer)
	player.weapons.add_child(test_weapon)
	
	player.attack()
	assert_almost_eq(test_timer.wait_time, 0.05, 0.0001, "player.attack() enforces 0.05s safety floor on weapon timers")
	
	test_timer.free()
	test_weapon.free()
	_destroy_player(ctx)

# =============================================================================
# 4. IMPACT BUCKLER ADVERSARIAL STRESS TESTS
# =============================================================================

func test_impact_buckler_threshold_trigger_and_cooldown_lock() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("impactbuckler1") # Tier 1: 60s cooldown
	
	# Test boundary: Drop to exactly 20.0% HP -> must NOT trigger (strictly < 20%)
	player._set_hp(50.0)
	player.buckler_triggered = false
	player._set_hp(20.0)
	assert_false(player.buckler_triggered, "HP 20.0% (exact boundary) does not trigger buckler")
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown remains 0")
	
	# Test supra-boundary: Drop to 20.01% HP -> must NOT trigger
	player._set_hp(50.0)
	player.buckler_triggered = false
	player._set_hp(20.01)
	assert_false(player.buckler_triggered, "HP 20.01% does not trigger buckler")
	
	# Test sub-boundary: Drop from 50.0% to 19.99% HP -> TRIGGERS!
	player._set_hp(50.0)
	player.buckler_triggered = false
	player._set_hp(19.99)
	assert_true(player.buckler_triggered, "HP 19.99% (< 20%) successfully triggers buckler")
	assert_eq(player.buckler_trigger_count, 1, "Trigger count is 1")
	assert_almost_eq(player.impact_buckler_cooldown, 60.0, 0.001, "Tier 1 cooldown set to 60.0s")
	
	# Stress test cooldown lock: take multiple rapid hits during cooldown
	player.buckler_triggered = false
	player._set_hp(18.0) # hit 1
	assert_false(player.buckler_triggered, "Hit 1 at 18% during cooldown does not trigger")
	
	player.update_health_items(10.0) # 50s cooldown remaining
	player._set_hp(15.0) # hit 2
	assert_false(player.buckler_triggered, "Hit 2 at 15% during cooldown does not trigger")
	
	player.update_health_items(20.0) # 30s cooldown remaining
	player._set_hp(10.0) # hit 3
	assert_false(player.buckler_triggered, "Hit 3 at 10% during cooldown does not trigger")
	
	player.update_health_items(25.0) # 5s cooldown remaining
	player._set_hp(5.0) # hit 4
	assert_false(player.buckler_triggered, "Hit 4 at 5% during cooldown does not trigger")
	assert_eq(player.buckler_trigger_count, 1, "Total triggers remained strictly 1 throughout cooldown")
	
	_destroy_player(ctx)

func test_impact_buckler_rearm_after_cooldown_expiration() -> void:
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("impactbuckler3") # Tier 3: 20s cooldown
	
	# Trigger 1
	player._set_hp(50.0)
	player._set_hp(15.0)
	assert_eq(player.buckler_trigger_count, 1, "Trigger 1 executed")
	assert_almost_eq(player.impact_buckler_cooldown, 20.0, 0.001, "Cooldown is 20s")
	
	# Advance 20.05s -> cooldown fully expires
	player.update_health_items(20.05)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown is 0.0s")
	
	# Heal to 30% HP (>= 20%) to reset the threshold trigger condition
	player._set_hp(30.0)
	
	# Trigger 2: drop below 20% again
	player._set_hp(12.0)
	assert_eq(player.buckler_trigger_count, 2, "Trigger 2 executed cleanly after re-arm")
	assert_almost_eq(player.impact_buckler_cooldown, 20.0, 0.001, "Cooldown reset to 20s for Trigger 2")
	
	# Advance 20.1s -> cooldown fully expires again
	player.update_health_items(20.1)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown is 0.0s again")
	
	# Heal to 25% HP and trigger 3
	player._set_hp(25.0)
	player._set_hp(18.0)
	assert_eq(player.buckler_trigger_count, 3, "Trigger 3 executed cleanly after 2nd re-arm")
	
	_destroy_player(ctx)

func test_impact_buckler_continuous_low_hp_behavior_adversarial() -> void:
	# Adversarial edge case: What happens if player stays below 20% HP indefinitely?
	# When cooldown expires at 15% HP, if the player takes another hit (15% -> 10%),
	# does it trigger?
	# In player.gd: condition is (current_ratio < 0.20 and previous_ratio >= 0.20).
	# Since previous_ratio was 0.15 (< 0.20), it does NOT re-trigger without healing above 20%.
	# We verify this exact contractual behavior.
	var ctx = _create_player(100.0)
	var player = ctx["player"]
	player.upgrade_character("impactbuckler3") # 20s cooldown
	
	player._set_hp(50.0)
	player._set_hp(15.0) # Triggers
	assert_eq(player.buckler_trigger_count, 1, "Initial trigger at 15% HP")
	
	# Expire cooldown while still at 15% HP
	player.update_health_items(25.0)
	assert_almost_eq(player.impact_buckler_cooldown, 0.0, 0.001, "Cooldown expired")
	
	# Take damage from 15% to 10% HP WITHOUT healing above 20% first
	player.buckler_triggered = false
	player._set_hp(10.0)
	assert_false(player.buckler_triggered, "Does NOT re-trigger if previous ratio was already below 20% (threshold transition contract)")
	assert_eq(player.buckler_trigger_count, 1, "Trigger count remains 1")
	
	_destroy_player(ctx)

func test_impact_buckler_boss_displacement_immunity() -> void:
	var enemy_script = load("res://Enemy/Base/enemy_body.gd")
	
	# Standard enemy (isBoss = 0): receives full 400.0 knockback
	var normal_enemy = enemy_script.new()
	normal_enemy.isBoss = 0
	normal_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_almost_eq(normal_enemy.knockback.x, 400.0, 0.001, "Normal enemy displaced by 400.0")
	
	# Boss enemy with isBoss = 1: displacement immune
	var boss_enemy = enemy_script.new()
	boss_enemy.isBoss = 1
	boss_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_eq(boss_enemy.knockback, Vector2.ZERO, "Boss (isBoss=1) displacement immune (knockback is Vector2.ZERO)")
	
	# Boss enemy in 'boss' group: displacement immune
	var boss_group_enemy = enemy_script.new()
	boss_group_enemy.isBoss = 0
	boss_group_enemy.add_to_group("boss")
	boss_group_enemy._on_hurt_box_hurt(0.0, Vector2.RIGHT, 400.0, "impact_buckler")
	assert_eq(boss_group_enemy.knockback, Vector2.ZERO, "Boss in 'boss' group displacement immune")
	
	normal_enemy.free()
	boss_enemy.free()
	boss_group_enemy.free()
