extends Node2D

var level = 0
var endless_level = 0
var attack_speed = 2.5
var damage = 30
var shards_on_death = false

var glasslash_scene = preload("res://Player/Attack/glasslash/glasslash.tscn")
var glassshard_scene = preload("res://Player/Attack/glasslash/glassshard.tscn")

@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)
	GlobalEvents.enemy_died.connect(_on_enemy_died)

func upgrade(upgrade_id: String):
	match upgrade_id:
		"glasslash1":
			level = 1
			damage = 30
			attack_speed = 3.0
		"glasslash2":
			level = 2
			damage = 45
			attack_speed = 2.0
			shards_on_death = true
		"glasslash3":
			level = 3
			damage = 65
			attack_speed = 1.2
			shards_on_death = true
		"glasslash4":
			level = 4
			damage = 90
			attack_speed = 1.0
			shards_on_death = true
		"glasslash_endless":
			endless_level += 1
			damage += 5

	
	attack()

func attack():
	if level > 0:
		timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)
		if timer.is_stopped():
			timer.start()

func _on_timer_timeout():
	var extra_attacks = int(player.additional_attacks)
	if randf() < (player.additional_attacks - extra_attacks):
		extra_attacks += 1
		
	var target_pos = player.get_closest_target()
	if target_pos == Vector2.INF:
		# If no enemy, just swing in last movement direction
		target_pos = player.global_position + player.last_movement * 50
	
	var attack_burst = 1 + extra_attacks
	for i in range(attack_burst):
		var lash = glasslash_scene.instantiate()
		lash.global_position = player.global_position
		lash.target_pos = target_pos
		lash.damage = damage * GlobalEvents.get_player_damage_modifier()
		lash.level = level

		# Slightly randomize angle for additional attacks
		if i > 0:
			var angle_offset = randf_range(-0.3, 0.3)
			lash.target_pos = player.global_position + (target_pos - player.global_position).rotated(angle_offset)
		
		player.get_parent().add_child(lash)
		
	# Update timer in case cooldown changed
	timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)

func _on_enemy_died(death_pos: Vector2, enemy_max_hp: float, killer_source: String):
	if shards_on_death and killer_source == "glasslash":
		# Spawn shards
		var shard_count = 6
		for i in range(shard_count):
			var shard = glassshard_scene.instantiate()
			shard.global_position = death_pos
			shard.damage = enemy_max_hp * 0.20 # 20% max HP damage
			shard.angle = Vector2.RIGHT.rotated(randf_range(0, 2 * PI))
			player.get_parent().call_deferred("add_child", shard)
