extends Node2D

@export var spawns_easy: Array[Spawn_info] = []
@export var spawns_normal: Array[Spawn_info] = []
@export var spawns_hard: Array[Spawn_info] = []
@export var spawns_super: Array[Spawn_info] = []

@export var base_soft_limit: int = 150
@export var min_soft_limit: int = 80
@export var max_soft_limit: int = 400

@export var boss_spawn_interval: int = GlobalEvents.bossInterval
@export var time_normal_unlock_minutes: float = 1.0
@export var time_hard_unlock_minutes: float = 3.0

@export_group("Boss Scaling")
@export var boss_hp_scaling_base: float = 1.05
@export var enable_boss_debug_logging: bool = true

@export var base_enemy_intensity: float = 3.0
@export var enemy_intensity_time_multiplier: float = 1.5

@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = get_node("Timer")

var isSpawningActive = true
@onready var soft_limit = base_soft_limit
var current_fodder_delay = 0
var current_elite_delay = 0

var upcoming_boss: Spawn_info = null

signal changetime(time)

func _ready():
	startTimer()
	connect("changetime",Callable(player,"change_time"))
	GlobalEvents.enableSpawns.connect(enableSpawns)
	GlobalEvents.disableSpawns.connect(disableSpawns)
	GlobalEvents.queue_boss.connect(force_queue_boss)

func enableSpawns():
	isSpawningActive = true

func disableSpawns():
	isSpawningActive = false

func force_queue_boss() -> void:
	# If a boss is already queued, don't overwrite it
	if upcoming_boss != null:
		return
	if spawns_super.size() == 0:
		return
	upcoming_boss = spawns_super.pick_random()
	# Spawn immediately: instantiate and emit the spawned signal now
	var boss_spawn = upcoming_boss.enemy.instantiate()
	
	# Apply HP scaling
	var multiplier = get_boss_hp_multiplier()
	var original_hp = boss_spawn.hp
	boss_spawn.hp = int(original_hp * multiplier)
	if enable_boss_debug_logging:
		print("[Boss Spawner] Forced Spawn: %s | Time: %d sec | Multiplier: %.2f | HP: %d (was %d)" % [boss_spawn.name, GlobalEvents.time, multiplier, boss_spawn.hp, original_hp])
		
	boss_spawn.global_position = get_random_position()
	add_child(boss_spawn)
	GlobalEvents.boss_spawned.emit(boss_spawn)
	upcoming_boss = null

func stopTimer():
	timer.paused = true
	
func startTimer():
	timer.paused = false

func _on_timer_timeout():
	GlobalEvents.time += 1
	
	if GlobalEvents.time % GlobalEvents.bossInterval == 0: 
		MusicController.playNext(MusicController.MusicType.BOSS)
		
	if isSpawningActive:
		# FPS soft limit adjustment
		var fps = Engine.get_frames_per_second()
		if fps >= 55:
			soft_limit = min(soft_limit + 5, max_soft_limit)
		elif fps <= 30:
			soft_limit = max(soft_limit - 5, min_soft_limit)

		var current_enemies = get_tree().get_nodes_in_group("enemy").size()
		
		# Boss Spawns 1 minute Warning
		if boss_spawn_interval > 60 and (GlobalEvents.time + 60) % boss_spawn_interval == 0 and GlobalEvents.time > 0:
			if spawns_super.size() > 0:
				upcoming_boss = spawns_super.pick_random()
				var boss_path = upcoming_boss.enemy.resource_path
				var warning_key = GlobalEvents.boss_warnings.get(boss_path, "warning_boss_generic")
				GlobalEvents.emit_signal("show_boss_warning", warning_key)
		
		# Boss Spawns
		if boss_spawn_interval > 0 and GlobalEvents.time % boss_spawn_interval == 0 and GlobalEvents.time > 0:
			var boss_info = upcoming_boss
			if not boss_info and spawns_super.size() > 0:
				boss_info = spawns_super.pick_random()
			
			if boss_info:
				var boss_spawn = boss_info.enemy.instantiate()
				
				# Apply HP scaling
				var multiplier = get_boss_hp_multiplier()
				var original_hp = boss_spawn.hp
				boss_spawn.hp = int(original_hp * multiplier)
				if enable_boss_debug_logging:
					print("[Boss Spawner] Scheduled Spawn: %s | Time: %d sec | Multiplier: %.2f | HP: %d (was %d)" % [boss_spawn.name, GlobalEvents.time, multiplier, boss_spawn.hp, original_hp])

				boss_spawn.global_position = get_random_position()
				add_child(boss_spawn)
				GlobalEvents.boss_spawned.emit(boss_spawn)
				upcoming_boss = null

		# Handle Fodder Spawns (Easy + Normal)
		if current_fodder_delay > 0:
			current_fodder_delay -= 1
		else:
			var minutes = GlobalEvents.time / 60.0
			
			var weight_easy = 100
			var weight_normal = 0
			
			if minutes >= time_normal_unlock_minutes:
				# Normal enemies gradually become common, but never completely replace Easy ones
				weight_normal = min(int((minutes - time_normal_unlock_minutes) * 20), 100)
			
			var roll = randi_range(0, weight_easy + weight_normal)
			var selected_pool = spawns_easy
			var selected_type = "easy"
			
			if roll > weight_easy and spawns_normal.size() > 0:
				selected_pool = spawns_normal
				selected_type = "normal"
				
			if selected_pool.size() > 0:
				var enemy_info = selected_pool.pick_random()
				current_fodder_delay = max(1, enemy_info.enemy_spawn_delay)
				current_fodder_delay = max(1, current_fodder_delay + randi_range(-1, 1))
				
				spawn_enemy_group(enemy_info, selected_type)

		# Handle Elite Spawns (Hard)
		if GlobalEvents.time / 60.0 >= time_hard_unlock_minutes:
			if current_elite_delay > 0:
				current_elite_delay -= 1
			else:
				if spawns_hard.size() > 0:
					var elite_info = spawns_hard.pick_random()
					# Elites spawn less frequently than fodder
					current_elite_delay = max(5, elite_info.enemy_spawn_delay * 4)
					current_elite_delay = max(3, current_elite_delay + randi_range(-2, 2))
					
					spawn_enemy_group(elite_info, "hard")
	
	emit_signal("changetime",GlobalEvents.time)

func spawn_enemy_group(enemy_info: Spawn_info, pool_type: String) -> void:
	var current_enemies = get_tree().get_nodes_in_group("enemy").size()
	if current_enemies >= soft_limit:
		return
		
	var minutes = GlobalEvents.time / 60.0
	var time_multiplier = base_enemy_intensity
	
	if minutes > 1.0 and minutes <= 3.0:
		var t = minutes
		var A = enemy_intensity_time_multiplier / 2.0
		time_multiplier = base_enemy_intensity + (A * t * t)
	elif minutes > 3.0:
		var val_at_3 = base_enemy_intensity + enemy_intensity_time_multiplier
		time_multiplier = val_at_3 + minutes * enemy_intensity_time_multiplier
		
	var spawn_count = int(enemy_info.enemy_num * time_multiplier * randf_range(0.8, 1.2) * GlobalEvents.get_enemy_spawn_modifier())
	
	# Small enemies should spawn in larger quantities
	if pool_type == "easy":
		spawn_count = int(spawn_count * 1.5)
		
	if enemy_info.enemy_num > 0 and spawn_count < 1:
		spawn_count = 1
		
	var max_allowed = (soft_limit - current_enemies) + 5
	if spawn_count > max_allowed and max_allowed > 0:
		spawn_count = max_allowed
		
	var counter = 0
	while counter < spawn_count:
		if enemy_info.enemy == null:
			printerr("EnemySpawner: Wave entry missing enemy resource! Skipping.")
			continue
		var enemy_spawn = enemy_info.enemy.instantiate()
		
		# Apply generic Enemy HP modifier
		var hp_mod = GlobalEvents.get_enemy_hp_modifier()
		if hp_mod != 1.0:
			enemy_spawn.hp = int(enemy_spawn.hp * hp_mod)
		
		enemy_spawn.global_position = get_random_position()
		add_child(enemy_spawn)
		counter += 1
	
	emit_signal("changetime",GlobalEvents.time)

func get_boss_hp_multiplier() -> float:
	var minutes = GlobalEvents.time / 60.0
	return pow(boss_hp_scaling_base, minutes) * GlobalEvents.get_boss_hp_modifier()

func get_random_position():
	var vpr = get_viewport_rect().size * randf_range(1.1,1.4)
	var top_left = Vector2(player.global_position.x - vpr.x/2, player.global_position.y - vpr.y/2)
	var top_right = Vector2(player.global_position.x + vpr.x/2, player.global_position.y - vpr.y/2)
	var bottom_left = Vector2(player.global_position.x - vpr.x/2, player.global_position.y + vpr.y/2)
	var bottom_right = Vector2(player.global_position.x + vpr.x/2, player.global_position.y + vpr.y/2)
	var pos_side = ["up","down","right","left"].pick_random()
	var spawn_pos1 = Vector2.ZERO
	var spawn_pos2 = Vector2.ZERO
	
	match pos_side:
		"up":
			spawn_pos1 = top_left
			spawn_pos2 = top_right
		"down":
			spawn_pos1 = bottom_left
			spawn_pos2 = bottom_right
		"right":
			spawn_pos1 = top_right
			spawn_pos2 = bottom_right
		"left":
			spawn_pos1 = top_left
			spawn_pos2 = bottom_left
	
	var x_spawn = randf_range(spawn_pos1.x, spawn_pos2.x)
	var y_spawn = randf_range(spawn_pos1.y,spawn_pos2.y)
	return Vector2(x_spawn,y_spawn)
