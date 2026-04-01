extends Node2D

var ammo = 0
var baseammo = 0
var attackspeed = 1.5
var level = 0

var iceSpear = preload("res://Player/Attack/Icespear/icespear.tscn")
@onready var player = get_tree().get_first_node_in_group("player")

@onready var timer = Timer.new()
@onready var attackTimer = Timer.new()

func _ready():
	add_child(timer)
	add_child(attackTimer)
	timer.timeout.connect(_on_timer_timeout)
	attackTimer.timeout.connect(_on_attack_timer_timeout)
	attackTimer.wait_time = 0.075

func upgrade(upgrade_id: String):
	match upgrade_id:
		"icespear1":
			level = 1
			baseammo += 1
		"icespear2":
			level = 2
			baseammo += 1
		"icespear3":
			level = 3
		"icespear4":
			level = 4
			baseammo += 2
	
	attack()

func attack():
	if level > 0:
		timer.wait_time = attackspeed * (1 - player.spell_cooldown)
		if timer.is_stopped():
			timer.start()

func _on_timer_timeout():
	var attack_burst = baseammo + player.additional_attacks
	if ammo < attack_burst:
		ammo = attack_burst
	attackTimer.start()

func _on_attack_timer_timeout():
	if ammo > 0:
		var target = player.get_random_target()
		if target != Vector2.INF:
			var icespear_attack = iceSpear.instantiate()
			icespear_attack.position = player.position
			icespear_attack.target = target
			icespear_attack.level = level
			# Add to main scene tree or to a projectiles node so they don't move with player
			player.get_parent().add_child(icespear_attack)
			ammo -= 1
		
		if ammo > 0:
			attackTimer.start()
		else:
			attackTimer.stop()
