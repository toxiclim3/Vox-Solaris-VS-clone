extends Area2D

var level = 1
var damage = 10
var chains = 1
var knockback_amount = 50
var attack_size = 1.0

var current_chain = 0
var current_pos = Vector2.ZERO
var hit_positions = []
var active = true

@onready var player = get_tree().get_first_node_in_group("player")
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var audio_stream = $AudioStreamPlayer2D

# Visuals
const COLOR_MID = Color(0.75, 0.55, 1.00, 0.75)
const COLOR_CORE = Color(1.00, 0.95, 1.00, 1.00)
var lines_to_draw = [] # Array of dicts: {"start": Vector2, "end": Vector2, "alpha": 1.0}

func _ready():
	# Configure based on level
	level = player.lightningrod_level
	match level:
		1:
			damage = 10
			chains = 1
		2:
			damage = 15
			chains = 1
		3:
			damage = 15
			chains = 3
		4:
			damage = 20
			chains = 4
			
	# Endless scaling
	damage += player.lightningrod_endless_level * 2.0
	
	scale = Vector2(1.0, 1.0) * (1 + player.spell_size)
	
	global_position = Vector2.ZERO
	current_pos = player.global_position
	# Find first target
	var first_target = player.get_random_target()
	if first_target == Vector2.INF:
		queue_free()
		return
		
	strike(first_target)

func _physics_process(delta):
	# Fade out drawn lines
	var any_visible = false
	for line in lines_to_draw:
		line.alpha -= delta * 3.0 # Fade out over ~0.33s
		if line.alpha > 0:
			any_visible = true
			
	queue_redraw()
	
	if not active and not any_visible:
		queue_free()

func get_next_target(from_pos: Vector2) -> Vector2:
	var closest_pos = Vector2.INF
	var min_dist = INF
	
	for body in player.enemy_close:
		if is_instance_valid(body):
			var pos = body.global_position
			var dist = from_pos.distance_squared_to(pos)
			if dist < min_dist and not is_hit(pos) and dist < 90000: # 300px range limit for chain
				min_dist = dist
				closest_pos = pos
				
	var swarm = get_tree().get_first_node_in_group("swarm_manager")
	if swarm:
		for enemy in swarm.swarm_data:
			if not enemy.is_dead:
				var pos = enemy.position
				var dist = from_pos.distance_squared_to(pos)
				if dist < min_dist and not is_hit(pos) and dist < 90000:
					min_dist = dist
					closest_pos = pos
					
	return closest_pos

func is_hit(pos: Vector2) -> bool:
	for hit_pos in hit_positions:
		if hit_pos.distance_squared_to(pos) < 400: # 20px overlap check
			return true
	return false

func strike(target_pos: Vector2):
	# Play sound
	audio_stream.global_position = target_pos
	audio_stream.play()
	
	# Enable damage collision at target
	collision.global_position = target_pos
	collision.set_deferred("disabled", false)
	
	hit_positions.append(target_pos)
	
	# Add line to draw queue (using global positions since root is at Vector2.ZERO)
	lines_to_draw.append({"start": current_pos, "end": target_pos, "alpha": 1.0})
	
	current_pos = target_pos
	
	# Disable collision next frame so it only hits once per strike
	get_tree().create_timer(0.05).timeout.connect(func(): collision.set_deferred("disabled", true))
	
	current_chain += 1
	if current_chain <= chains:
		timer.start()
	else:
		active = false

func _on_timer_timeout():
	var next = get_next_target(current_pos)
	if next != Vector2.INF:
		strike(next)
	else:
		active = false

# --- Visuals ---
func _draw_arc(p0: Vector2, p1: Vector2, roughness: float, depth: int, color: Color, width: float) -> void:
	if depth == 0:
		draw_line(p0, p1, color, width)
		return
	var mid: Vector2 = (p0 + p1) * 0.5
	var perp: Vector2 = (p1 - p0).rotated(PI * 0.5).normalized()
	mid += perp * randf_range(-roughness, roughness)
	var half: float = roughness * 0.6
	_draw_arc(p0, mid, half, depth - 1, color, width)
	_draw_arc(mid, p1, half, depth - 1, color, width)

func _draw():
	for line in lines_to_draw:
		if line.alpha <= 0: continue
		var p0 = line.start
		var p1 = line.end
		
		# Set alpha for colors
		var c_mid = COLOR_MID
		c_mid.a *= line.alpha
		var c_core = COLOR_CORE
		c_core.a *= line.alpha
		
		var roughness = 15.0
		# Main strike
		_draw_arc(p0, p1, roughness, 3, c_mid, 2.0)
		_draw_arc(p0, p1, roughness * 0.7, 3, c_core, 1.0)
		
		# Small fork
		if randf() > 0.5:
			var bx = p0.lerp(p1, randf_range(0.2, 0.8))
			var be = bx + (p1 - p0).rotated(randf_range(-0.5, 0.5)).normalized() * randf_range(20, 50)
			_draw_arc(bx, be, roughness * 0.5, 2, c_mid, 1.0)
