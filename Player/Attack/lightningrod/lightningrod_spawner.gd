extends Node2D

var level = 0
var endless_level = 0
var base_cooldown = 3.0

var lightningrod = preload("res://Player/Attack/lightningrod/lightningrod.tscn")
@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.timeout.connect(_on_timer_timeout)

func upgrade(upgrade_id: String):
	match upgrade_id:
		"lightningrod1":
			level = 1
			base_cooldown = 3.0
		"lightningrod2":
			level = 2
			base_cooldown = 2.5
		"lightningrod3":
			level = 3
			base_cooldown = 2.0
		"lightningrod4":
			level = 4
			base_cooldown = 2.0
		"lightningrod_endless":
			endless_level += 1
			
	player.lightningrod_level = level
	player.lightningrod_endless_level = endless_level
	
	var actual_cooldown = max(0.1, base_cooldown * (1.0 - player.spell_cooldown))
	timer.wait_time = actual_cooldown
	if timer.is_stopped() and level > 0:
		timer.start()
		# Optionally fire immediately on upgrade/equip
		_on_timer_timeout()

func attack():
	# For dynamic spawner pattern compatibility
	var actual_cooldown = max(0.1, base_cooldown * (1.0 - player.spell_cooldown))
	timer.wait_time = actual_cooldown

func _on_timer_timeout():
	if level > 0:
		spawn_lightning()

func spawn_lightning():
	var extra_attacks = int(player.additional_attacks)
	if randf() < (player.additional_attacks - extra_attacks):
		extra_attacks += 1
		
	var targets_to_spawn = 1 + extra_attacks
	for i in range(targets_to_spawn):
		var rod_spawn = lightningrod.instantiate()
		rod_spawn.global_position = player.global_position
		add_child(rod_spawn)
