extends Node2D

var ammo = 0
var level = 0
var endless_level = 0

var javelin = preload("res://Player/Attack/javelin/javelin.tscn")
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
		"javelin_endless":
			endless_level += 1
			
	player.javelin_level = level  # Update the property that Javelin script expects
	player.javelin_endless_level = endless_level
	attack()


func attack():
	if level > 0:
		spawn_javelin()

func spawn_javelin():
	var extra_attacks = int(player.additional_attacks)
	if randf() < (player.additional_attacks - extra_attacks):
		extra_attacks += 1
	var get_javelin_total = get_child_count()
	var calc_spawns = (ammo + extra_attacks) - get_javelin_total
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
