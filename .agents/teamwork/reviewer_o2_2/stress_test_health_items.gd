# SPDX-License-Identifier: GPL-3.0-or-later
# Adversarial Stress Testing Script for Health Items (Clean Fixture)
extends SceneTree

class MockGui extends Node:
	var levelPanel: Control
	var bossLevelPanel: Control
	var deathPanel: Control
	func _init() -> void:
		levelPanel = Control.new()
		bossLevelPanel = Control.new()
		deathPanel = Control.new()
	func adjust_gui_collection(_upgrade: String) -> void:
		pass
	func cleanup() -> void:
		levelPanel.free()
		bossLevelPanel.free()
		deathPanel.free()

func _process(_delta: float) -> bool:
	var passed = true
	var total_checks = 0
	var passed_checks = 0
	
	print("\n--- ADVERSARIAL STRESS TEST SUITE ---")
	
	var player_script = load("res://Player/player.gd")
	var enemy_script = load("res://Enemy/Base/enemy_body.gd")
	
	var p = player_script.new()
	p.base_maxhp = 100
	p.maxhp = 100
	p.hp = 100
	
	var cs = CollisionShape2D.new()
	cs.shape = CircleShape2D.new()
	p.grab_shape = cs
	
	var mock_gui = MockGui.new()
	p.gui = mock_gui
	
	# 1. Division by zero safety
	p.maxhp = 0
	p._set_hp(50.0)
	total_checks += 1
	if p.get_damage_bonus() == 0.0 and p.get_attack_speed_bonus() == 0.0:
		passed_checks += 1
		print("[PASS] Division by zero safety when maxhp == 0")
	else:
		print("[FAIL] Division by zero failure")
		passed = false
		
	# Restore maxhp
	p.maxhp = 100
	p._set_hp(100.0)
	
	# 2. Clamped HP bounds
	p._set_hp(-50.0)
	total_checks += 1
	if p.hp == 0.0:
		passed_checks += 1
		print("[PASS] Negative HP clamped to 0.0")
	else:
		print("[FAIL] Negative HP clamping failed")
		passed = false
		
	p._set_hp(200.0)
	total_checks += 1
	if p.hp == 100.0:
		passed_checks += 1
		print("[PASS] Over-max HP clamped to maxhp")
	else:
		print("[FAIL] Over-max HP clamping failed")
		passed = false
		
	# 3. High-precision float boundary tests
	p.upgrade_character("glasstalisman4")
	p.upgrade_character("frenzycharm3")
	
	# Glass Talisman 0.95 boundary
	p._set_hp(95.0)
	total_checks += 1
	if is_equal_approx(p.get_damage_bonus(), 0.25):
		passed_checks += 1
		print("[PASS] Glass Talisman active at exact 0.95 ratio")
	else:
		print("[FAIL] Glass Talisman inactive at 0.95")
		passed = false
		
	p._set_hp(94.999)
	total_checks += 1
	if is_equal_approx(p.get_damage_bonus(), 0.0):
		passed_checks += 1
		print("[PASS] Glass Talisman inactive at 0.94999 ratio")
	else:
		print("[FAIL] Glass Talisman active below 0.95")
		passed = false
		
	# Frenzy Charm 0.30 boundary
	p._set_hp(30.0)
	total_checks += 1
	if is_equal_approx(p.get_attack_speed_bonus(), 0.0):
		passed_checks += 1
		print("[PASS] Frenzy Charm inactive at exact 0.30 ratio")
	else:
		print("[FAIL] Frenzy Charm active at 0.30")
		passed = false
		
	p._set_hp(29.999)
	total_checks += 1
	if is_equal_approx(p.get_attack_speed_bonus(), 0.30):
		passed_checks += 1
		print("[PASS] Frenzy Charm active at 0.29999 ratio")
	else:
		print("[FAIL] Frenzy Charm inactive below 0.30")
		passed = false
		
	# 4. Cooldown extreme overflow and safety floor
	p.spell_cooldown = 1.5 # 150% cooldown reduction (exceeds 100%)
	var cd = p.calculate_cooldown(1.0)
	total_checks += 1
	if cd == 0.05:
		passed_checks += 1
		print("[PASS] Cooldown safety floor holds at extreme spell_cooldown=1.5 (cd=0.05)")
	else:
		print("[FAIL] Cooldown safety floor failed on extreme spell_cooldown: %f" % cd)
		passed = false
		
	p.spell_cooldown = 0.0
	
	# 5. Impact Buckler consecutive threshold dropping
	p.upgrade_character("impactbuckler1")
	p.impact_buckler_cooldown = 0.0
	p.buckler_triggered = false
	p._set_hp(50.0)
	
	# Drop from 50 to 18 (crosses 20%) -> triggers
	p._set_hp(18.0)
	total_checks += 1
	if p.buckler_triggered:
		passed_checks += 1
		print("[PASS] Buckler triggers when crossing from 50% to 18%")
	else:
		print("[FAIL] Buckler did not trigger on crossing 20%")
		passed = false
		
	# Drop from 18 to 10 (does not cross 20% again) -> should not trigger again
	p.buckler_triggered = false
	p._set_hp(10.0)
	total_checks += 1
	if not p.buckler_triggered:
		passed_checks += 1
		print("[PASS] Buckler does not trigger when already below 20% (18% -> 10%)")
	else:
		print("[FAIL] Buckler triggered while already below 20%")
		passed = false
		
	# 6. Warding Brooch exact absorption capacity
	p.upgrade_character("wardingbrooch1")
	p.warding_brooch_charge = true
	var res = p.absorb_warding_damage(5.0)
	total_checks += 1
	if res["absorbed"] == 5.0 and res["spillover"] == 0.0 and not p.warding_brooch_charge:
		passed_checks += 1
		print("[PASS] Warding Brooch absorbs exact 5.0 capacity without spillover")
	else:
		print("[FAIL] Warding Brooch failed on exact capacity absorption")
		passed = false
		
	# 7. EnemyBody boss displacement immunity with different angles and sources
	var normal = enemy_script.new()
	normal.isBoss = 0
	normal._on_hurt_box_hurt(0.0, Vector2(1, 1).normalized(), 500.0, "impact_buckler")
	total_checks += 1
	if normal.knockback.length() > 499.0:
		passed_checks += 1
		print("[PASS] Normal enemy displaced along diagonal angle (kb=%.1f)" % normal.knockback.length())
	else:
		print("[FAIL] Normal enemy not displaced properly")
		passed = false
		
	var boss = enemy_script.new()
	boss.isBoss = 1
	boss._on_hurt_box_hurt(0.0, Vector2(1, 1).normalized(), 500.0, "impact_buckler")
	total_checks += 1
	if boss.knockback == Vector2.ZERO:
		passed_checks += 1
		print("[PASS] Boss enemy is completely immovable (kb=Vector2.ZERO)")
	else:
		print("[FAIL] Boss enemy was displaced: %s" % boss.knockback)
		passed = false
		
	normal.free()
	boss.free()
	mock_gui.cleanup()
	mock_gui.free()
	cs.shape = null
	cs.free()
	p.free()
	
	print("\n--- RESULTS: %d/%d passed ---" % [passed_checks, total_checks])
	quit(0 if passed else 1)
	return true
