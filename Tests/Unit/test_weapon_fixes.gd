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

