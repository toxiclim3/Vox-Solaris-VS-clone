extends Node2D

var ammo = 0
var baseammo = 0
var attackspeed = 3.0
var level = 0
var endless_level = 0

var tornado = preload("res://Player/Attack/tornado/tornado.tscn")
@onready var player = get_tree().get_first_node_in_group("player")

@onready var timer = Timer.new()
@onready var attackTimer = Timer.new()

func _ready():
	add_child(timer)
	add_child(attackTimer)
	timer.timeout.connect(_on_timer_timeout)
	attackTimer.timeout.connect(_on_attack_timer_timeout)
	attackTimer.wait_time = 0.2

func upgrade(upgrade_id: String):
	match upgrade_id:
		"tornado1":
			level = 1
			baseammo += 1
		"tornado2":
			level = 2
			baseammo += 1
		"tornado3":
			level = 3
			attackspeed -= 0.5
		"tornado4":
			level = 4
			baseammo += 1
		"tornado_endless":
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
	ammo += baseammo + extra_attacks
	attackTimer.start()


func _on_attack_timer_timeout():
	if ammo > 0:
		var tornado_attack = tornado.instantiate()
		tornado_attack.position = player.position
		tornado_attack.last_movement = player.last_movement
		tornado_attack.level = level
		tornado_attack.endless_level = endless_level
		player.get_parent().add_child(tornado_attack)

		ammo -= 1
		if ammo > 0:
			attackTimer.start()
		else:
			attackTimer.stop()
