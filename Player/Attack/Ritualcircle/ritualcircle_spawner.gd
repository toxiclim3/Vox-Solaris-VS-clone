extends Node2D

var ammo = 0
var baseammo = 0
var attackspeed = 5.0
var level = 0

var ritualCircle = preload("res://Player/Attack/Ritualcircle/ritualcircle.tscn")
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
		"ritualcircle1":
			level = 1
			baseammo = 1
		"ritualcircle2":
			level = 2
		"ritualcircle3":
			level = 3
		"ritualcircle4":
			level = 4
			baseammo += 1
	
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
			var ritual_attack = ritualCircle.instantiate()
			ritual_attack.global_position = target
			ritual_attack.level = level
			# Add to main scene tree
			player.get_parent().add_child(ritual_attack)
			ammo -= 1
		
		if ammo > 0:
			attackTimer.start()
		else:
			attackTimer.stop()
