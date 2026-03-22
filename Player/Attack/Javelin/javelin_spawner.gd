extends Node2D

var ammo = 0
var level = 0

var javelin = preload("res://Player/Attack/Javelin/javelin.tscn")
@onready var player = get_tree().get_first_node_in_group("player")

func upgrade(upgrade_id: String):
	match upgrade_id:
		"javelin1":
			level = 1
			ammo = 1
		"javelin2":
			level = 2
		"javelin3":
			level = 3
		"javelin4":
			level = 4
			
	player.javelin_level = level  # Update the property that Javelin script expects
	attack()

func attack():
	if level > 0:
		spawn_javelin()

func spawn_javelin():
	var get_javelin_total = get_child_count()
	var calc_spawns = (ammo + player.additional_attacks) - get_javelin_total
	while calc_spawns > 0:
		var javelin_spawn = javelin.instantiate()
		javelin_spawn.global_position = player.global_position
		add_child(javelin_spawn)
		calc_spawns -= 1
		
	# Upgrade existing Javelins
	var get_javelins = get_children()
	for i in get_javelins:
		if i.has_method("update_javelin"):
			i.update_javelin()
