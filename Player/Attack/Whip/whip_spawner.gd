extends Node2D

var level = 0
var attack_speed = 1.3
var damage = 8

var whip_scene = preload("res://Player/Attack/Whip/whip.tscn")

@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

func upgrade(upgrade_id: String):
	match upgrade_id:
		"whip1":
			level = 1
			damage = 8
			attack_speed = 1.3
		"whip2":
			level = 2
			damage = 12
			attack_speed = 1.1
		"whip3":
			level = 3
			damage = 16
			attack_speed = 1.0
		"whip4":
			level = 4
			damage = 20
			attack_speed = 0.8
	
	attack()

func attack():
	if level > 0:
		timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)
		if timer.is_stopped():
			timer.start()

func _on_timer_timeout():
	var target_pos = player.get_closest_target()
	if target_pos == Vector2.INF:
		# If no enemy, just swing in last movement direction
		target_pos = player.global_position + player.last_movement * 50
	
	var attack_burst = 1 + player.additional_attacks
	for i in range(attack_burst):
		var whip = whip_scene.instantiate()
		whip.global_position = player.global_position
		whip.target_pos = target_pos
		whip.damage = damage * GlobalEvents.get_player_damage_modifier()
		whip.level = level
		
		# Slightly randomize angle for additional attacks
		if i > 0:
			var angle_offset = randf_range(-0.3, 0.3)
			whip.target_pos = player.global_position + (target_pos - player.global_position).rotated(angle_offset)
		
		player.get_parent().add_child(whip)
		
	# Update timer in case cooldown changed
	timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)
