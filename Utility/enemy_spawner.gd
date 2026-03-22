extends Node2D

@export var spawns_easy: Array[Spawn_info] = []
@export var spawns_normal: Array[Spawn_info] = []
@export var spawns_hard: Array[Spawn_info] = []
@export var spawns_super: Array[Spawn_info] = []

@export var base_soft_limit: int = 100
@export var min_soft_limit: int = 50
@export var max_soft_limit: int = 200

@export var boss_spawn_interval: int = 600
@export var time_normal_unlock_minutes: float = 1.0
@export var time_hard_unlock_minutes: float = 3.0

@export var base_enemy_intensity: float = 3.0
@export var enemy_intensity_time_multiplier: float = 1.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var timer = get_node("Timer")

var isSpawningActive = true
@onready var soft_limit = base_soft_limit
var current_wave_delay = 0

signal changetime(time)

func _ready():
	startTimer()
	connect("changetime",Callable(player,"change_time"))
	GlobalEvents.enableSpawns.connect(enableSpawns)
	GlobalEvents.disableSpawns.connect(disableSpawns)

func enableSpawns():
	isSpawningActive = true

func disableSpawns():
	isSpawningActive = false

func stopTimer():
	timer.paused = true
	
func startTimer():
	timer.paused = false

func _on_timer_timeout():
	GlobalEvents.time += 1
	
	if GlobalEvents.time % GlobalEvents.bossMusicInterval == 0: 
		MusicController.playNext(MusicController.MusicType.BOSS)
		
	if isSpawningActive:
		# FPS soft limit adjustment
		var fps = Engine.get_frames_per_second()
		if fps >= 55:
			soft_limit = min(soft_limit + 5, max_soft_limit)
		elif fps <= 30:
			soft_limit = max(soft_limit - 5, min_soft_limit)

		var current_enemies = get_tree().get_nodes_in_group("enemy").size()
		
		# Boss Spawns
		if boss_spawn_interval > 0 and GlobalEvents.time % boss_spawn_interval == 0 and GlobalEvents.time > 0:
			if spawns_super.size() > 0:
				var boss_info = spawns_super.pick_random()
				var boss_spawn = boss_info.enemy.instantiate()
				boss_spawn.global_position = get_random_position()
				add_child(boss_spawn)

		if current_wave_delay > 0:
			current_wave_delay -= 1
		else:
			var minutes = GlobalEvents.time / 60.0
			
			var weight_easy = 100
			var weight_normal = 0
			var weight_hard = 0
			
			if minutes >= time_normal_unlock_minutes:
				weight_normal = min(int((minutes - time_normal_unlock_minutes) * 10) + 10, 50)
				weight_easy -= weight_normal
				
			if minutes >= time_hard_unlock_minutes:
				weight_hard = min(int((minutes - time_hard_unlock_minutes) * 10), 40)
				weight_easy -= weight_hard
			
			weight_easy = max(10, weight_easy)
			
			var total_weight = weight_easy + weight_normal + weight_hard
			var roll = randi_range(0, total_weight)
			
			var selected_pool_type = "easy"
			var selected_pool = spawns_easy
			if roll > weight_easy and spawns_normal.size() > 0:
				selected_pool_type = "normal"
				selected_pool = spawns_normal
			if roll > (weight_easy + weight_normal) and spawns_hard.size() > 0:
				selected_pool_type = "hard"
				selected_pool = spawns_hard
				
			if selected_pool.size() == 0:
				selected_pool = spawns_easy
				
			if selected_pool.size() > 0:
				var enemy_info = selected_pool.pick_random()
				current_wave_delay = max(1, enemy_info.enemy_spawn_delay) 
				current_wave_delay = max(1, current_wave_delay + randi_range(-1, 1))
				
				if current_enemies < soft_limit:
					var time_multiplier = base_enemy_intensity + (minutes * enemy_intensity_time_multiplier)
					var spawn_count = int(enemy_info.enemy_num * time_multiplier * randf_range(0.8, 1.2))
					
					if selected_pool_type == "easy" and minutes >= time_hard_unlock_minutes:
						spawn_count = int(spawn_count * 1.5)
						
					if enemy_info.enemy_num > 0 and spawn_count < 1:
						spawn_count = 1
						
					var max_allowed = (soft_limit - current_enemies) + 5
					if spawn_count > max_allowed and max_allowed > 0:
						spawn_count = max_allowed
						
					var counter = 0
					while counter < spawn_count:
						var enemy_spawn = enemy_info.enemy.instantiate()
						enemy_spawn.global_position = get_random_position()
						add_child(enemy_spawn)
						counter += 1
	
	emit_signal("changetime",GlobalEvents.time)

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
