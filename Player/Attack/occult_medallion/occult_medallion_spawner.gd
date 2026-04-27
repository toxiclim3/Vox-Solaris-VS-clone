extends Node2D

var level = 1
var max_targets = 1
var damage_bonus = 0.05
var application_interval = 2.0
var application_timer = 0.0
var debuff_duration = 10.0 # How long the curse lasts

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	update_stats()

func upgrade(upgrade_name: String):
	var lvl = int(upgrade_name.trim_prefix("occult_medallion"))
	if lvl > level:
		level = lvl
		update_stats()

func update_stats():
	match level:
		1:
			damage_bonus = 0.05
			application_interval = 2.0
			max_targets = 1
		2:
			damage_bonus = 0.10
			application_interval = 1.0
			max_targets = 1
		3:
			damage_bonus = 0.10
			application_interval = 1.0
			max_targets = 2
		4:
			damage_bonus = 0.15
			application_interval = 0.5
			max_targets = 2

func _physics_process(delta):
	application_timer -= delta
	if application_timer <= 0:
		application_timer = application_interval
		apply_curse()

func apply_curse():
	if not player:
		return
	
	var candidates = []
	# Standard enemies
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.get("is_dying") != true and not enemy.has_debuff("curse"):
			candidates.append(enemy)
	
	# Swarm enemies
	var swarm_mgr = get_tree().get_first_node_in_group("swarm_manager")
	if swarm_mgr:
		for enemy in swarm_mgr.swarm_data:
			if not enemy.is_dead and not enemy.has_debuff("curse"):
				candidates.append(enemy)
	
	if candidates.size() == 0:
		return
		
	# Sort descending by max_hp
	candidates.sort_custom(func(a, b): return a.max_hp > b.max_hp)
	
	var targets_applied = 0
	for enemy in candidates:
		if targets_applied >= max_targets:
			break
		enemy.apply_debuff("curse", damage_bonus, debuff_duration)
		targets_applied += 1
