extends Node2D

var ammo = 0
var baseammo = 1
var attackspeed = 3	
var level = 0
var endless_level = 0

var poisonBottle = preload("res://Player/Attack/Poisonbottle/poisonbottle.tscn")
@onready var player = get_tree().get_first_node_in_group("player")

@onready var timer = Timer.new()
@onready var attackTimer = Timer.new()

func _ready():
	add_child(timer)
	add_child(attackTimer)
	timer.timeout.connect(_on_timer_timeout)
	attackTimer.timeout.connect(_on_attack_timer_timeout)
	attackTimer.wait_time = 0.15

func upgrade(upgrade_id: String):
	match upgrade_id:
		"poisonbottle1":
			level = 1
		"poisonbottle2":
			level = 2
		"poisonbottle3":
			level = 3
		"poisonbottle4":
			level = 4
		"poisonbottle_endless":
			endless_level += 1

	
	attack()

func attack():
	if level > 0:
		timer.wait_time = attackspeed * (1 - player.spell_cooldown)
		if timer.is_stopped():
			timer.start()

func _on_timer_timeout():
	var extra_attacks = int(player.additional_attacks)
	if randf() < (player.additional_attacks - extra_attacks):
		extra_attacks += 1
	var attack_burst = baseammo + extra_attacks
	if ammo < attack_burst:
		ammo = attack_burst
	attackTimer.start()



func _on_attack_timer_timeout():
	if ammo > 0:
		var target = player.get_random_target()
		if target != Vector2.INF:
			var bottle_attack = poisonBottle.instantiate()
			bottle_attack.position = player.position
			bottle_attack.target = target
			bottle_attack.level = level
			bottle_attack.endless_level = endless_level
			# Add to main scene tree or to a projectiles node so they don't move with player
			player.get_parent().add_child(bottle_attack)
			ammo -= 1
		
		if ammo > 0:
			attackTimer.start()
		else:
			attackTimer.stop()
