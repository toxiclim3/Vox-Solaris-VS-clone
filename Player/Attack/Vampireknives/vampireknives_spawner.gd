extends Node2D

var level = 0
var endless_level = 0
var knife_count = 5    # Number of knives per volley
var damage = 5
var attack_speed = 2.0  # Seconds between volleys
var lifesteal_per_hit = 0.5  # HP healed per knife hit

var knife_scene = preload("res://Player/Attack/Vampireknives/vampireknife.tscn")

@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

func upgrade(upgrade_id: String):
	match upgrade_id:
		"vampireknives1":
			level = 1
			knife_count = 5
			damage = 10
			attack_speed = 2.0
			lifesteal_per_hit = 1
		"vampireknives2":
			level = 2
			knife_count = 7
			damage = 12
			attack_speed = 1.8
			lifesteal_per_hit = 1.3
		"vampireknives3":
			level = 3
			knife_count = 9
			damage = 14
			attack_speed = 1.5
			lifesteal_per_hit = 1.5
		"vampireknives4":
			level = 4
			knife_count = 12
			damage = 15
			attack_speed = 1.2
			lifesteal_per_hit = 2
		"vampireknives_endless":
			endless_level += 1
			damage += 1
			lifesteal_per_hit += 0.1


	attack()

func attack():
	if level > 0:
		timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)
		if timer.is_stopped():
			timer.start()

func _on_timer_timeout():
	_throw_fan()
	# Refresh cooldown accounting for CDR changes mid-run
	timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)

func _throw_fan():
	# Spread knives in a fan toward the nearest enemy (or last movement direction)
	var extra_attacks = int(player.additional_attacks)
	if randf() < (player.additional_attacks - extra_attacks):
		extra_attacks += 1
		
	var target_pos = player.get_closest_target()
	var base_dir: Vector2
	if target_pos == Vector2.INF:
		base_dir = player.last_movement.normalized()
	else:
		base_dir = player.global_position.direction_to(target_pos)

	var total_knives = knife_count + extra_attacks


	# Fan spread angle in radians
	var spread = deg_to_rad(60.0) # 60 degree total arc

	for i in range(total_knives):
		var knife = knife_scene.instantiate()
		knife.global_position = player.global_position
		knife.damage = damage * GlobalEvents.get_player_damage_modifier()
		knife.lifesteal_per_hit = lifesteal_per_hit
		knife.hp = 1 # Force no pierce
		knife.scale = Vector2(0.4, 0.4) * (1.0 + player.spell_size)

		# Distribute knives evenly across the arc
		var t = 0.5 if total_knives == 1 else float(i) / float(total_knives - 1)
		var angle_offset = lerp(-spread / 2.0, spread / 2.0, t)
		knife.direction = base_dir.rotated(angle_offset)

		player.get_parent().add_child(knife)
