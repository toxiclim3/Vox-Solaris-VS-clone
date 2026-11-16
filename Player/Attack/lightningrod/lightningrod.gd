extends Area2D

var level = 1
var damage = 10
var chains = 1
var knockback_amount = 50
var attack_size = 1.0

var current_chain = 0
var current_pos = Vector2.ZERO
var hit_positions = []
var hit_targets: Array = []
var hit_once_array = []
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
	z_index = 20
	# Configure based on level
	if is_instance_valid(player) and "lightningrod_level" in player:
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
	if is_instance_valid(player) and "lightningrod_endless_level" in player:
		damage += player.lightningrod_endless_level * 2.0
	
	if is_instance_valid(player) and "spell_size" in player:
		scale = Vector2(1.0, 1.0) * (1 + player.spell_size)
	
	if is_instance_valid(player):
		current_pos = player.global_position
	else:
		current_pos = global_position
		
	# Find first target
	var first_target = Vector2.INF
	if is_instance_valid(player):
		if player.has_method("get_strongest_target"):
			first_target = player.get_strongest_target()
		elif player.has_method("get_random_target"):
			first_target = player.get_random_target()
	if first_target != null and first_target != Vector2.INF:
		strike(first_target)
	elif is_instance_valid(player):
		queue_free()
		return

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

func _is_target_valid(body) -> bool:
	if is_instance_valid(player) and player.has_method("_is_enemy_valid_target"):
		return player._is_enemy_valid_target(body)
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	if body.get("is_dying") == true or (body.get("hp") != null and body.hp <= 0):
		return false
	if not body.visible:
		return false
	var sprite_node = body.get_node_or_null("EnemyBase/Sprite2D")
	if not sprite_node:
		sprite_node = body.get_node_or_null("Sprite2D")
	if sprite_node and not sprite_node.visible:
		return false
	var hurt_box = body.get_node_or_null("EnemyBase/HurtBox")
	if not hurt_box:
		hurt_box = body.get_node_or_null("HurtBox")
	if hurt_box:
		var cs = hurt_box.get_node_or_null("CollisionShape2D")
		if cs and cs.disabled:
			return false
	return true

func _find_entity_at(pos: Vector2):
	if is_instance_valid(player) and "enemy_close" in player:
		for body in player.enemy_close:
			if is_instance_valid(body) and _is_target_valid(body) and body.global_position.distance_squared_to(pos) <= 64.0:
				return body
	var swarm = get_tree().get_first_node_in_group("swarm_manager")
	if swarm and "swarm_data" in swarm:
		for enemy in swarm.swarm_data:
			if not enemy.is_dead and enemy.hp > 0 and enemy.position.distance_squared_to(pos) <= 64.0:
				return enemy
	return null

func get_next_target(from_pos: Vector2) -> Vector2:
	var closest_pos = Vector2.INF
	var min_dist = INF
	var closest_target = null
	
	if is_instance_valid(player) and "enemy_close" in player:
		for body in player.enemy_close:
			if is_instance_valid(body) and _is_target_valid(body) and not hit_targets.has(body):
				var pos = body.global_position
				var dist = from_pos.distance_squared_to(pos)
				if dist > 16.0 and dist < min_dist and dist < 90000.0: # 300px range limit for chain
					min_dist = dist
					closest_pos = pos
					closest_target = body
					
	var swarm = get_tree().get_first_node_in_group("swarm_manager")
	if swarm and "swarm_data" in swarm:
		for enemy in swarm.swarm_data:
			if not enemy.is_dead and enemy.hp > 0 and not hit_targets.has(enemy):
				var pos = enemy.position
				var dist = from_pos.distance_squared_to(pos)
				if dist > 16.0 and dist < min_dist and dist < 90000.0:
					min_dist = dist
					closest_pos = pos
					closest_target = enemy
					
	if closest_target != null:
		if not hit_targets.has(closest_target):
			hit_targets.append(closest_target)
		if not hit_once_array.has(closest_target):
			hit_once_array.append(closest_target)
					
	return closest_pos

func is_hit(pos: Vector2) -> bool:
	for hit_pos in hit_positions:
		if hit_pos.distance_squared_to(pos) < 16.0:
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
	
	var entity = _find_entity_at(target_pos)
	if entity != null:
		if not hit_targets.has(entity):
			hit_targets.append(entity)
		if not hit_once_array.has(entity):
			hit_once_array.append(entity)
	
	# Add line to draw queue (using global positions, converted in _draw via to_local)
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
		var p0 = to_local(line.start)
		var p1 = to_local(line.end)
		
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
