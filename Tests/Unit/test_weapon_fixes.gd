# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Unit Testing Suite - Weapon & ICD Fixes Verification
# Validates double-scaling removal, hit_box signal naming, tornado pulsing,
# swarm melting / contact despawn fixes, RelicRocket reparenting, and player IFrames.

extends "res://Tests/test_base.gd"

var global_events: Node = null

func before_all() -> void:
	global_events = Engine.get_main_loop().root.get_node_or_null("GlobalEvents")

func after_each() -> void:
	if global_events != null:
		global_events.set_difficulty(global_events.Difficulty.NORMAL)

func test_hitbox_signal_naming_and_array() -> void:
	var hitbox_script = load("res://Utility/hit_box.gd")
	assert_not_null(hitbox_script, "hit_box.gd must load")
	
	var hitbox = Area2D.new()
	hitbox.set_script(hitbox_script)
	
	assert_true(hitbox.has_signal("remove_from_array"), "hit_box must have remove_from_array signal")
	assert_false(hitbox.has_signal("_remove_from_array"), "hit_box must not have _remove_from_array signal")
	assert_true("hit_once_array" in hitbox, "hit_box must have hit_once_array property")
	assert_eq(typeof(hitbox.get("hit_once_array")), TYPE_ARRAY, "hit_once_array must be an Array")
	assert_true(hitbox.has_method("enemy_hit"), "hit_box must have enemy_hit method")
	
	# Verify hurt_box connects cleanly to remove_from_array
	var hurtbox_scene = load("res://Utility/hurt_box.tscn")
	var hurtbox = hurtbox_scene.instantiate()
	hurtbox.HurtBoxType = 1 # HitOnce
	
	hitbox.add_to_group("attack")
	hitbox.damage = 10
	
	hurtbox._on_area_entered(hitbox)
	assert_true(hurtbox.hit_once_array.has(hitbox), "Hurtbox hit_once_array must track hitbox")
	assert_true(hitbox.is_connected("remove_from_array", Callable(hurtbox, "remove_from_list")),
		"Hurtbox must be connected to hitbox remove_from_array")
	
	# Emitting signal should remove from hurtbox list
	hitbox.remove_from_array.emit(hitbox)
	assert_false(hurtbox.hit_once_array.has(hitbox), "Emitting remove_from_array must clear hitbox from hurtbox list")
	
	hitbox.free()
	hurtbox.free()

func test_tornado_pulse_signal_and_array_clear() -> void:
	var tornado_scene = load("res://Player/Attack/tornado/tornado.tscn")
	assert_not_null(tornado_scene, "tornado.tscn must load")
	
	var tornado = tornado_scene.instantiate()
	assert_true(tornado.has_signal("remove_from_array"), "tornado must have remove_from_array signal")
	assert_true("hit_once_array" in tornado, "tornado must have hit_once_array property")
	
	var result = {"emitted": false, "arg": null}
	tornado.remove_from_array.connect(func(obj):
		result["emitted"] = true
		result["arg"] = obj
	)
	
	# Simulate dummy entries in hit_once_array
	tornado.hit_once_array.append("enemy_1")
	tornado.hit_once_array.append("enemy_2")
	assert_eq(tornado.hit_once_array.size(), 2, "Tornado hit_once_array should have 2 dummy entries")
	
	tornado._on_pulse()
	assert_true(result["emitted"], "Tornado _on_pulse must emit remove_from_array")
	assert_eq(result["arg"], tornado, "Tornado _on_pulse must pass self in remove_from_array signal")
	assert_eq(tornado.hit_once_array.size(), 0, "Tornado _on_pulse must clear hit_once_array")
	
	tornado.free()

func test_swarm_melting_and_contact_despawn_scripts() -> void:
	# Glassshard
	var shard_script = load("res://Player/Attack/glasslash/glassshard.gd")
	assert_not_null(shard_script, "glassshard.gd must load")
	var shard = Area2D.new()
	shard.set_script(shard_script)
	assert_true("hit_once_array" in shard, "glassshard must have hit_once_array property")
	assert_eq(typeof(shard.get("hit_once_array")), TYPE_ARRAY, "glassshard hit_once_array must be an Array")
	assert_true(shard.has_method("enemy_hit"), "glassshard must have enemy_hit method")
	shard.free()
	
	# RelicRocket
	var rocket_script = load("res://Player/Attack/relicdrone/RelicRocket.gd")
	assert_not_null(rocket_script, "RelicRocket.gd must load")
	var rocket = Area2D.new()
	rocket.set_script(rocket_script)
	assert_true("hit_once_array" in rocket, "RelicRocket must have hit_once_array property")
	assert_eq(typeof(rocket.get("hit_once_array")), TYPE_ARRAY, "RelicRocket hit_once_array must be an Array")
	assert_true(rocket.has_method("enemy_hit"), "RelicRocket must have enemy_hit method")
	rocket.free()
	
	# Lightningrod
	var rod_script = load("res://Player/Attack/lightningrod/lightningrod.gd")
	assert_not_null(rod_script, "lightningrod.gd must load")
	var rod = Area2D.new()
	rod.set_script(rod_script)
	assert_true("hit_once_array" in rod, "lightningrod must have hit_once_array property")
	assert_eq(typeof(rod.get("hit_once_array")), TYPE_ARRAY, "lightningrod hit_once_array must be an Array")
	rod.free()

func test_relic_drone_rocket_parentage() -> void:
	var drone_script = load("res://Player/Attack/relicdrone/relicdrone.gd")
	assert_not_null(drone_script, "relicdrone.gd must load")
	
	# Create world parent, player, and drone hierarchy
	var world = Node2D.new()
	var player = Node2D.new()
	player.add_to_group("player")
	world.add_child(player)
	
	var drone = drone_script.new()
	player.add_child(drone)
	drone.player = player
	
	drone.spawn_rocket(10.0, null)
	
	# Rocket should be a child of world (player.get_parent()), not root
	var rocket_found = false
	for child in world.get_children():
		if child != player:
			rocket_found = true
			assert_eq(child.get_parent(), world, "Rocket must be child of player's parent")
			child.free()
	
	assert_true(rocket_found, "Spawned rocket must exist in player's parent node")
	
	drone.free()
	player.free()
	world.free()

func test_player_hurtbox_cooldown_and_iframes() -> void:
	var player_scene = load("res://Player/player.tscn")
	assert_not_null(player_scene, "player.tscn must load")
	
	var player = player_scene.instantiate()
	var hurtbox = player.get_node_or_null("HurtBox")
	assert_not_null(hurtbox, "Player must contain HurtBox node")
	
	# Validate properties
	assert_eq(hurtbox.HurtBoxType, 0, "Player HurtBoxType must be 0 (Cooldown)")
	assert_eq(hurtbox.collision_layer, 2, "Player HurtBox collision_layer must be 2")
	assert_eq(hurtbox.collision_mask, 2, "Player HurtBox collision_mask must be 2")
	
	var disable_timer = hurtbox.get_node_or_null("DisableTimer")
	assert_not_null(disable_timer, "HurtBox must contain DisableTimer")
	assert_almost_eq(disable_timer.wait_time, 0.3, 0.001, "DisableTimer wait_time must be 0.3s (Tier 1 IFrames)")
	
	player.free()

func test_weapon_spawners_do_not_multiply_global_player_damage_modifier() -> void:
	# Set a high damage modifier in GlobalEvents to detect any double-scaling
	if global_events != null:
		global_events.set_difficulty(global_events.Difficulty.CUSTOM)
		global_events.custom_player_damage_modifier = 3.5
		assert_almost_eq(global_events.get_player_damage_modifier(), 3.5, 0.001, "Modifier set to 3.5")
	
	# Create parent context
	var world = Node2D.new()
	Engine.get_main_loop().root.add_child(world)
	var dummy_script = GDScript.new()
	dummy_script.source_code = """
extends Node2D
var spell_cooldown: float = 0.0
var spell_size: float = 0.0
var additional_attacks: float = 0.0
var last_movement: Vector2 = Vector2.UP
func get_closest_target() -> Vector2:
	return Vector2(100, 0)
"""
	dummy_script.reload()
	var player = dummy_script.new()
	player.add_to_group("player")
	world.add_child(player)
	
	# Whip spawner
	var whip_spawner_script = load("res://Player/Attack/whip/whip_spawner.gd")
	var whip_spawner = whip_spawner_script.new()
	whip_spawner.timer = Timer.new()
	whip_spawner.add_child(whip_spawner.timer)
	player.add_child(whip_spawner)
	whip_spawner.player = player
	whip_spawner.upgrade("whip1") # Base damage is 8
	assert_eq(whip_spawner.damage, 8, "Whip level 1 base damage is 8")
	
	# Trigger timeout to spawn whip
	whip_spawner._on_timer_timeout()
	
	var spawned_whip = null
	for child in world.get_children():
		if child != player:
			spawned_whip = child
			break
	assert_not_null(spawned_whip, "Whip must be spawned in world")
	if spawned_whip != null:
		assert_eq(spawned_whip.damage, 8, "Whip damage must NOT be multiplied by player damage modifier (got %s)" % spawned_whip.damage)
		spawned_whip.free()
	
	# Glasslash spawner
	var glasslash_spawner_script = load("res://Player/Attack/glasslash/glasslash_spawner.gd")
	var glasslash_spawner = glasslash_spawner_script.new()
	glasslash_spawner.timer = Timer.new()
	glasslash_spawner.add_child(glasslash_spawner.timer)
	player.add_child(glasslash_spawner)
	glasslash_spawner.player = player
	glasslash_spawner.damage = 15.0
	glasslash_spawner._on_timer_timeout()
	
	var spawned_lash = null
	for child in world.get_children():
		if child != player:
			spawned_lash = child
			break
	assert_not_null(spawned_lash, "Glasslash must be spawned in world")
	if spawned_lash != null:
		assert_eq(spawned_lash.damage, 15.0, "Glasslash damage must NOT be multiplied by player damage modifier (got %s)" % spawned_lash.damage)
		spawned_lash.free()
	glasslash_spawner.free()

	# Vampire knives spawner
	var vk_spawner_script = load("res://Player/Attack/vampireknives/vampireknives_spawner.gd")
	var vk_spawner = vk_spawner_script.new()
	player.add_child(vk_spawner)
	vk_spawner.player = player
	vk_spawner.damage = 12.0
	vk_spawner._throw_fan()
	
	var spawned_knife = null
	for child in world.get_children():
		if child != player:
			spawned_knife = child
			break
	assert_not_null(spawned_knife, "Vampire knife must be spawned in world")
	if spawned_knife != null:
		assert_eq(spawned_knife.damage, 12.0, "Vampire knife damage must NOT be multiplied by player damage modifier (got %s)" % spawned_knife.damage)
		# Clear all spawned knives
		for child in world.get_children():
			if child != player:
				child.free()
	vk_spawner.free()

	# Clean up
	whip_spawner.free()
	player.free()
	world.free()

func test_swarm_enemy_duck_typing() -> void:
	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)
	
	sm.add_enemy(Vector2(50, 60), 100.0, 100.0, 50.0, 1, 1, type_id)
	var enemy = sm.swarm_data[0]
	
	# Test global_position getter
	assert_eq(enemy.global_position, Vector2(50, 60), "enemy.global_position must return enemy.position")
	
	# Test global_position setter
	enemy.global_position = Vector2(75, 85)
	assert_eq(enemy.position, Vector2(75, 85), "Setting enemy.global_position must update enemy.position")
	assert_eq(enemy.global_position, Vector2(75, 85), "enemy.global_position must reflect new position")
	
	# Test is_alive method
	assert_true(enemy.is_alive(), "enemy.is_alive() must return true when alive")
	enemy.is_dead = true
	assert_false(enemy.is_alive(), "enemy.is_alive() must return false when dead")
	
	sm.free()

func test_swarm_pierce_leak_fixed() -> void:
	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)
	
	# Spawn 3 enemies close together
	sm.add_enemy(Vector2(100, 100), 50.0, 50.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(105, 100), 50.0, 50.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(110, 100), 50.0, 50.0, 50.0, 1, 1, type_id)
	
	# Create attack with hp = 1 (single pierce) that calls queue_free when hp <= 0
	var atk_script = GDScript.new()
	atk_script.source_code = """extends Area2D
var hp = 1
var damage = 20.0
var knockback_amount = 0.0
var hit_once_array = []
func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		queue_free()
"""
	atk_script.reload()
	var atk_node = atk_script.new()
	atk_node.add_to_group("attack")
	atk_node.collision_layer = 4
	var cs = CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var circle = CircleShape2D.new()
	circle.radius = 30.0 # Large enough to overlap all 3 enemies
	cs.shape = circle
	atk_node.add_child(cs)
	
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)
	var player = Node2D.new()
	player.add_to_group("player")
	test_root.add_child(player)
	test_root.add_child(sm)
	test_root.add_child(atk_node)
	atk_node.global_position = Vector2(105, 100)
	sm.player = player
	
	# Process one physics frame
	sm._physics_process(0.016)
	
	# Only ONE enemy should have taken damage
	var damaged_count = 0
	for enemy in sm.swarm_data:
		if enemy.hp < 50.0:
			damaged_count += 1
	assert_eq(damaged_count, 1, "Single-pierce attack must hit exactly 1 swarm enemy without pierce leaking (got %d)" % damaged_count)
	assert_true(atk_node.is_queued_for_deletion(), "Attack must be queued for deletion after hitting 1 enemy")
	
	test_root.free()

func test_swarm_circle_collision_cross_term() -> void:
	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 10.0) # Enemy radius 10
	
	# Attack radius 20, Enemy radius 10 -> (20+10)^2 = 900.
	# Old math: 20^2 + 10^2 = 500.
	# At distance 25: 25^2 = 625.
	# 500 < 625 <= 900.
	# Old math would miss! New math must hit!
	sm.add_enemy(Vector2(25, 0), 100.0, 100.0, 50.0, 1, 1, type_id)
	var enemy = sm.swarm_data[0]
	
	var atk_script = GDScript.new()
	atk_script.source_code = """extends Area2D
var damage = 15.0
var knockback_amount = 0.0
var hit_once_array = []
"""
	atk_script.reload()
	var atk_node = atk_script.new()
	atk_node.add_to_group("attack")
	atk_node.collision_layer = 4
	var cs = CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	cs.shape = circle
	atk_node.add_child(cs)
	atk_node.global_position = Vector2(0, 0)
	
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)
	var player = Node2D.new()
	player.add_to_group("player")
	test_root.add_child(player)
	test_root.add_child(sm)
	test_root.add_child(atk_node)
	sm.player = player
	
	sm._physics_process(0.016)
	
	assert_almost_eq(enemy.hp, 85.0, 0.01, "Enemy at distance 25 with radii (20+10) must be hit by corrected circle collision formula (got HP %s)" % enemy.hp)
	
	test_root.free()

func test_swarm_on_hit_enemy_and_killer_source() -> void:
	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)
	
	sm.add_enemy(Vector2(100, 100), 20.0, 20.0, 50.0, 1, 1, type_id)
	var enemy = sm.swarm_data[0]
	
	var atk_script = GDScript.new()
	atk_script.source_code = """extends Area2D
var killer_source = "test_scythe"
var damage = 50.0
var knockback_amount = 0.0
var hit_once_array = []
var on_hit_called_with = null
func on_hit_enemy(e):
	on_hit_called_with = e
"""
	atk_script.reload()
	var atk_node = atk_script.new()
	atk_node.add_to_group("attack")
	atk_node.collision_layer = 4
	var cs = CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	cs.shape = circle
	atk_node.add_child(cs)
	
	var recorded_result = {"killer": ""}
	var on_died = func(_pos, _hp, killer):
		recorded_result["killer"] = killer
	GlobalEvents.enemy_died.connect(on_died)
	
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)
	var player = Node2D.new()
	player.add_to_group("player")
	test_root.add_child(player)
	test_root.add_child(sm)
	test_root.add_child(atk_node)
	atk_node.global_position = Vector2(100, 100)
	sm.player = player
	
	sm._physics_process(0.016)
	
	GlobalEvents.enemy_died.disconnect(on_died)
	
	assert_eq(atk_node.on_hit_called_with, enemy, "on_hit_enemy must be called on attack node with enemy instance")
	assert_eq(recorded_result["killer"], "test_scythe", "GlobalEvents.enemy_died must report actual killer_source from attack ('test_scythe'), got: '%s'" % recorded_result["killer"])
	assert_true(enemy.is_dead, "Enemy taking lethal damage must be marked dead")
	
	test_root.free()

func test_lightning_rod_visual_coordinate_alignment() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)

	var rod_scene = load("res://Player/Attack/lightningrod/lightningrod.tscn")
	assert_not_null(rod_scene, "lightningrod.tscn must load")

	# Test across spell_size = 0.0 and spell_size = 0.5
	for spell_size in [0.0, 0.5]:
		var rod = rod_scene.instantiate()
		rod.global_position = Vector2(250, 350)
		rod.scale = Vector2.ONE * (1.0 + spell_size)
		test_root.add_child(rod)

		# Check z_index and top_level
		assert_eq(rod.z_index, 20, "LightningRod z_index must be 20")
		assert_true(rod.top_level, "LightningRod must be top_level")

		var target_pos = Vector2(800, 600)
		rod.strike(target_pos)

		assert_eq(rod.lines_to_draw.size(), 1, "Must have 1 line to draw after strike")
		var line = rod.lines_to_draw[0]
		assert_eq(line.end, target_pos, "Stored line end must match target_pos")

		# Verify local-to-global transform maps endpoint exactly to target_pos
		var p1_local = rod.to_local(line.end)
		var p1_global = rod.to_global(p1_local)
		assert_almost_eq(p1_global.x, target_pos.x, 0.01, "Transformed visual endpoint X must equal target global X at spell_size %s" % spell_size)
		assert_almost_eq(p1_global.y, target_pos.y, 0.01, "Transformed visual endpoint Y must equal target global Y at spell_size %s" % spell_size)

		# Verify collision shape global position matches target_pos
		assert_almost_eq(rod.collision.global_position.x, target_pos.x, 0.01, "CollisionShape2D global X must equal target global X")
		assert_almost_eq(rod.collision.global_position.y, target_pos.y, 0.01, "CollisionShape2D global Y must equal target global Y")

		rod.free()

	test_root.free()

func test_player_target_validity_filters_invalid_enemies() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)

	var dummy_gui_script = GDScript.new()
	dummy_gui_script.source_code = """extends Node
func adjust_gui_collection(_upgrade): pass
func set_expbar(_c, _m): pass
func show_levelup(_o, _l): pass
func hide_level_panels(): pass
func set_level_text(_l): pass
"""
	dummy_gui_script.reload()
	var dummy_gui = dummy_gui_script.new()
	dummy_gui.add_to_group("gui")
	dummy_gui.add_to_group("gui_layer")
	test_root.add_child(dummy_gui)

	var player_scene = load("res://Player/player.tscn")
	assert_not_null(player_scene, "player.tscn must load")
	var player = player_scene.instantiate()
	test_root.add_child(player)
	player.global_position = Vector2(100, 100)
	player.enemy_close = []

	var dummy_enemy_script = GDScript.new()
	dummy_enemy_script.source_code = """extends CharacterBody2D
var hp: float = 50.0
var is_dying: bool = false
"""
	dummy_enemy_script.reload()

	# Helper to create a dummy CharacterBody2D enemy with EnemyBase structure
	var make_enemy = func(pos: Vector2, hp: float, is_dying: bool, visible: bool, sprite_visible: bool, hurtbox_disabled: bool):
		var body = CharacterBody2D.new()
		body.set_script(dummy_enemy_script)
		body.global_position = pos
		body.hp = hp
		body.is_dying = is_dying
		body.visible = visible
		var base = Node2D.new()
		base.name = "EnemyBase"
		body.add_child(base)
		var sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.visible = sprite_visible
		base.add_child(sprite)
		var hurtbox = Area2D.new()
		hurtbox.name = "HurtBox"
		var cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		cs.disabled = hurtbox_disabled
		hurtbox.add_child(cs)
		base.add_child(hurtbox)
		test_root.add_child(body)
		return body

	# 1. Valid enemy
	var valid_enemy = make_enemy.call(Vector2(150, 100), 50.0, false, true, true, false)
	assert_true(player._is_enemy_valid_target(valid_enemy), "Valid enemy must pass validation")

	# 2. Dead enemy (hp <= 0)
	var dead_enemy = make_enemy.call(Vector2(160, 100), 0.0, false, true, true, false)
	assert_false(player._is_enemy_valid_target(dead_enemy), "Dead enemy (hp <= 0) must fail validation")

	# 3. Dying enemy (is_dying == true)
	var dying_enemy = make_enemy.call(Vector2(170, 100), 50.0, true, true, true, false)
	assert_false(player._is_enemy_valid_target(dying_enemy), "Dying enemy (is_dying == true) must fail validation")

	# 4. Queued for deletion enemy
	var queued_enemy = make_enemy.call(Vector2(180, 100), 50.0, false, true, true, false)
	queued_enemy.queue_free()
	assert_false(player._is_enemy_valid_target(queued_enemy), "Queued for deletion enemy must fail validation")

	# 5. Invisible root enemy (e.g. dissolved)
	var invisible_enemy = make_enemy.call(Vector2(190, 100), 50.0, false, false, true, false)
	assert_false(player._is_enemy_valid_target(invisible_enemy), "Invisible root enemy must fail validation")

	# 6. Invisible sprite enemy (e.g. telegraphing Ancient Amoeba)
	var hidden_sprite_enemy = make_enemy.call(Vector2(200, 100), 50.0, false, true, false, false)
	assert_false(player._is_enemy_valid_target(hidden_sprite_enemy), "Enemy with invisible sprite must fail validation")

	# 7. Disabled hurtbox enemy (e.g. invulnerable state)
	var disabled_hb_enemy = make_enemy.call(Vector2(210, 100), 50.0, false, true, true, true)
	assert_false(player._is_enemy_valid_target(disabled_hb_enemy), "Enemy with disabled hurtbox must fail validation")

	# Test player.get_random_target() and get_closest_target() filtering
	player.enemy_close = [dead_enemy, dying_enemy, queued_enemy, invisible_enemy, hidden_sprite_enemy, disabled_hb_enemy]
	assert_eq(player.get_random_target(), Vector2.INF, "get_random_target must return Vector2.INF when all enemies in enemy_close are invalid")
	assert_eq(player.get_closest_target(), Vector2.INF, "get_closest_target must return Vector2.INF when all enemies in enemy_close are invalid")

	# Adding valid enemy should return its position
	player.enemy_close.append(valid_enemy)
	assert_eq(player.get_random_target(), valid_enemy.global_position, "get_random_target must return valid enemy position")
	assert_eq(player.get_closest_target(), valid_enemy.global_position, "get_closest_target must return valid enemy position")

	test_root.free()

func test_lightning_rod_dense_swarm_chaining() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)

	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	test_root.add_child(sm)
	sm.add_to_group("swarm_manager")

	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)

	# Add 4 dense swarm enemies 10px apart (< 20px, which previously broke under is_hit spatial check)
	sm.add_enemy(Vector2(100, 100), 50.0, 50.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(110, 100), 50.0, 50.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(120, 100), 50.0, 50.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(130, 100), 50.0, 50.0, 50.0, 1, 1, type_id)

	var e0 = sm.swarm_data[0]
	var e1 = sm.swarm_data[1]
	var e2 = sm.swarm_data[2]
	var e3 = sm.swarm_data[3]

	var rod_scene = load("res://Player/Attack/lightningrod/lightningrod.tscn")
	var rod = rod_scene.instantiate()
	test_root.add_child(rod)
	rod.chains = 3

	# Strike first enemy
	rod.strike(e0.position)
	assert_true(rod.hit_targets.has(e0), "First strike must record e0 in hit_targets")
	assert_true(rod.hit_once_array.has(e0), "First strike must record e0 in hit_once_array")

	# Chain 1: Should find e1 (10px away from e0)
	var target1 = rod.get_next_target(e0.position)
	assert_eq(target1, e1.position, "Chain 1 must find e1 at 10px distance without spatial 20px exclusion failure")
	assert_true(rod.hit_targets.has(e1), "Chain 1 must record e1 in hit_targets")

	# Chain 2: Should find e2 (10px away from e1)
	var target2 = rod.get_next_target(target1)
	assert_eq(target2, e2.position, "Chain 2 must find e2 at 10px distance")
	assert_true(rod.hit_targets.has(e2), "Chain 2 must record e2 in hit_targets")

	# Chain 3: Should find e3 (10px away from e2)
	var target3 = rod.get_next_target(target2)
	assert_eq(target3, e3.position, "Chain 3 must find e3 at 10px distance")
	assert_true(rod.hit_targets.has(e3), "Chain 3 must record e3 in hit_targets")

	# Chain 4: All 4 are in hit_targets; should return Vector2.INF
	var target4 = rod.get_next_target(target3)
	assert_eq(target4, Vector2.INF, "Chain 4 must return Vector2.INF when all swarm enemies have been hit")

	assert_eq(rod.hit_targets.size(), 4, "All 4 distinct swarm enemies must be tracked in hit_targets")

	test_root.free()

func test_freed_enemy_handling_in_player_and_lightning_rod() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)

	var dummy_gui_script = GDScript.new()
	dummy_gui_script.source_code = """extends Node
func adjust_gui_collection(_upgrade): pass
func set_expbar(_c, _m): pass
func show_levelup(_o, _l): pass
func hide_level_panels(): pass
func set_level_text(_l): pass
"""
	dummy_gui_script.reload()
	var dummy_gui = dummy_gui_script.new()
	dummy_gui.add_to_group("gui")
	dummy_gui.add_to_group("gui_layer")
	test_root.add_child(dummy_gui)

	var player_scene = load("res://Player/player.tscn")
	assert_not_null(player_scene, "player.tscn must load")
	var player = player_scene.instantiate()
	test_root.add_child(player)
	player.global_position = Vector2(100, 100)
	player.enemy_close = []

	var rod_scene = load("res://Player/Attack/lightningrod/lightningrod.tscn")
	assert_not_null(rod_scene, "lightningrod.tscn must load")
	var rod = rod_scene.instantiate()
	rod.player = player
	test_root.add_child(rod)

	# Create an enemy and free it immediately to produce a <Freed Object>
	var enemy = Node2D.new()
	test_root.add_child(enemy)
	player.enemy_close = [enemy]
	enemy.free()

	# Assert that helper validity checks handle <Freed Object> safely
	assert_false(player._is_enemy_valid_target(enemy), "_is_enemy_valid_target must return false on freed object without engine type crash")
	assert_false(rod._is_target_valid(enemy), "_is_target_valid must return false on freed object without engine type crash")

	# Assert player targeting returns Vector2.INF without script error
	var random_target = player.get_random_target()
	assert_eq(random_target, Vector2.INF, "player.get_random_target must return Vector2.INF when enemy in enemy_close is freed")

	var closest_target = player.get_closest_target()
	assert_eq(closest_target, Vector2.INF, "player.get_closest_target must return Vector2.INF when enemy in enemy_close is freed")

	# Assert rod chaining returns Vector2.INF without script error or crashing at (0, 0)
	var next_target = rod.get_next_target(Vector2.ZERO)
	assert_eq(next_target, Vector2.INF, "rod.get_next_target must return Vector2.INF when enemy in enemy_close is freed")

	# Verify with both a freed object and a valid enemy in enemy_close
	var dummy_enemy_script = GDScript.new()
	dummy_enemy_script.source_code = """extends CharacterBody2D
var hp: float = 50.0
var is_dying: bool = false
"""
	dummy_enemy_script.reload()
	var valid_enemy = CharacterBody2D.new()
	valid_enemy.set_script(dummy_enemy_script)
	valid_enemy.global_position = Vector2(150, 100)
	var base = Node2D.new()
	base.name = "EnemyBase"
	valid_enemy.add_child(base)
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	base.add_child(sprite)
	var hurtbox = Area2D.new()
	hurtbox.name = "HurtBox"
	var cs = CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	hurtbox.add_child(cs)
	base.add_child(hurtbox)
	test_root.add_child(valid_enemy)

	player.enemy_close = [enemy, valid_enemy]
	assert_eq(player.get_random_target(), valid_enemy.global_position, "get_random_target must return valid enemy position even when enemy_close has freed object")
	assert_eq(player.get_closest_target(), valid_enemy.global_position, "get_closest_target must return valid enemy position even when enemy_close has freed object")
	assert_eq(rod.get_next_target(Vector2.ZERO), valid_enemy.global_position, "rod.get_next_target must return valid enemy position even when enemy_close has freed object")

	test_root.free()

func _setup_targeting_context() -> Dictionary:
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Node2D.new()
	tree.root.add_child(test_root)

	var dummy_gui_script = GDScript.new()
	dummy_gui_script.source_code = """extends Node
func adjust_gui_collection(_upgrade): pass
func set_expbar(_c, _m): pass
func show_levelup(_o, _l): pass
func hide_level_panels(): pass
func set_level_text(_l): pass
"""
	dummy_gui_script.reload()
	var dummy_gui = dummy_gui_script.new()
	dummy_gui.add_to_group("gui")
	dummy_gui.add_to_group("gui_layer")
	test_root.add_child(dummy_gui)

	var player_scene = load("res://Player/player.tscn")
	var player = player_scene.instantiate()
	test_root.add_child(player)
	player.global_position = Vector2.ZERO
	player.enemy_close = []

	var dummy_enemy_script = GDScript.new()
	dummy_enemy_script.source_code = """extends CharacterBody2D
var hp: float = 50.0
var is_dying: bool = false
"""
	dummy_enemy_script.reload()

	var make_enemy = func(pos: Vector2, hp: float):
		var body = CharacterBody2D.new()
		body.set_script(dummy_enemy_script)
		body.global_position = pos
		body.hp = hp
		var base = Node2D.new()
		base.name = "EnemyBase"
		body.add_child(base)
		var sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		base.add_child(sprite)
		var hurtbox = Area2D.new()
		hurtbox.name = "HurtBox"
		var cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		hurtbox.add_child(cs)
		base.add_child(hurtbox)
		test_root.add_child(body)
		return body

	return {
		"root": test_root,
		"player": player,
		"make_enemy": make_enemy
	}

func test_player_frontal_targeting() -> void:
	var ctx = _setup_targeting_context()
	var player = ctx["player"]
	var make_enemy: Callable = ctx["make_enemy"]
	player.last_movement = Vector2.RIGHT

	assert_eq(player.get_frontal_target(), Vector2.INF,
		"get_frontal_target must return Vector2.INF when no enemies exist")

	var behind_close = make_enemy.call(Vector2(-30, 0), 50.0)
	var front_far = make_enemy.call(Vector2(200, 0), 50.0)
	var front_near = make_enemy.call(Vector2(120, 10), 50.0)
	player.enemy_close = [behind_close, front_far, front_near]

	assert_eq(player.get_frontal_target(), front_near.global_position,
		"get_frontal_target must prioritize closest enemy inside frontal cone over behind enemy")

	# Fallback when no enemies are inside the frontal 120-degree cone
	var rear_straight = make_enemy.call(Vector2(-100, 0), 50.0)
	var rear_angled = make_enemy.call(Vector2(-100, 100), 50.0)
	player.enemy_close = [rear_straight, rear_angled]
	assert_eq(player.get_frontal_target(), rear_angled.global_position,
		"get_frontal_target must fall back to best-aligned enemy when frontal cone is empty")

	ctx["root"].free()

func test_player_strongest_targeting() -> void:
	var ctx = _setup_targeting_context()
	var player = ctx["player"]
	var make_enemy: Callable = ctx["make_enemy"]

	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	ctx["root"].add_child(sm)
	sm.add_to_group("swarm_manager")

	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)
	sm.add_enemy(Vector2(100, 0), 50.0, 50.0, 50.0, 1, 1, type_id)

	var weak_close = make_enemy.call(Vector2(30, 0), 10.0)
	var elite_far = make_enemy.call(Vector2(250, 0), 200.0)
	player.enemy_close = [weak_close, elite_far]

	assert_eq(player.get_strongest_target(), elite_far.global_position,
		"get_strongest_target must pick highest-HP enemy across enemy_close and SwarmManager")

	# Equal max HP must tie-break by closest distance
	var elite_near = make_enemy.call(Vector2(150, 0), 200.0)
	player.enemy_close.append(elite_near)
	assert_eq(player.get_strongest_target(), elite_near.global_position,
		"get_strongest_target must tie-break equal HP by closest distance")

	ctx["root"].free()

func test_player_crowd_targeting() -> void:
	var ctx = _setup_targeting_context()
	var player = ctx["player"]
	var make_enemy: Callable = ctx["make_enemy"]

	var sm_scene = load("res://Utility/swarm_manager.tscn")
	var sm = sm_scene.instantiate()
	ctx["root"].add_child(sm)
	sm.add_to_group("swarm_manager")

	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var tex = ImageTexture.create_from_image(img)
	var type_id = sm.register_enemy_type(tex, 8.0)

	# Isolated enemy very close to player
	var isolated_close = make_enemy.call(Vector2(20, 0), 10.0)
	player.enemy_close = [isolated_close]

	# Dense swarm cluster further away (within 400px radius)
	var cluster_center = Vector2(215, 212)
	sm.add_enemy(Vector2(210, 210), 20.0, 20.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(215, 212), 20.0, 20.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(220, 208), 20.0, 20.0, 50.0, 1, 1, type_id)
	sm.add_enemy(Vector2(212, 220), 20.0, 20.0, 50.0, 1, 1, type_id)

	var chosen = player.get_crowd_target()
	assert_ne(chosen, isolated_close.global_position,
		"get_crowd_target must ignore closer isolated enemy in favor of dense cluster")
	assert_lt(chosen.distance_to(cluster_center), 32.0,
		"get_crowd_target must return an enemy position inside the dense cluster")

	ctx["root"].free()

func test_item_option_targeting_badge() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var test_root = Control.new()
	tree.root.add_child(test_root)

	var dummy_player_script = GDScript.new()
	dummy_player_script.source_code = """extends Node
var collected_endless: Dictionary = {}
func upgrade_character(_u): pass
"""
	dummy_player_script.reload()
	var dummy_player = dummy_player_script.new()
	dummy_player.add_to_group("player")
	test_root.add_child(dummy_player)

	var option_scene = load("res://Utility/item_option.tscn")
	assert_not_null(option_scene, "item_option.tscn must load")

	var prev_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")

	var whip_opt = option_scene.instantiate()
	whip_opt.item = "whip1"
	test_root.add_child(whip_opt)
	assert_not_null(whip_opt.lblTargeting, "ItemOption must expose lblTargeting")
	assert_true(whip_opt.lblTargeting.visible, "Weapon card whip1 must show targeting badge")
	assert_eq(whip_opt.lblTargeting.text, "[Closest]",
		"whip1 badge text must resolve to [Closest]")

	var spear_opt = option_scene.instantiate()
	spear_opt.item = "icespear1"
	test_root.add_child(spear_opt)
	assert_true(spear_opt.lblTargeting.visible, "Weapon card icespear1 must show targeting badge")
	assert_eq(spear_opt.lblTargeting.text, "[Frontal]",
		"icespear1 badge text must resolve to [Frontal]")

	var rod_endless_opt = option_scene.instantiate()
	rod_endless_opt.item = "lightningrod_endless"
	test_root.add_child(rod_endless_opt)
	assert_true(rod_endless_opt.lblTargeting.visible, "Endless weapon card must show targeting badge")
	assert_eq(rod_endless_opt.lblTargeting.text, "[Strongest]",
		"lightningrod_endless badge text must resolve to [Strongest]")

	var armor_opt = option_scene.instantiate()
	armor_opt.item = "armor1"
	test_root.add_child(armor_opt)
	assert_false(armor_opt.lblTargeting.visible, "Passive upgrade card armor1 must hide targeting badge")
	assert_eq(armor_opt.lblTargeting.text, "", "Passive upgrade badge text must be empty")

	TranslationServer.set_locale(prev_locale)
	test_root.free()

