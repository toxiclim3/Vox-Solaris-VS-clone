extends Area2D

var damage = 10.0
var target_node = null
var speed = 0.0
var max_speed = 400.0
var acceleration = 800.0
var steer_force = 25.0
var velocity = Vector2.ZERO
var lifetime = 3.0

var proc_coefficient = 0.0 # Proc items shouldn't proc themselves

@onready var player = get_tree().get_first_node_in_group("player")
@onready var sprite = $ColorRect
@onready var particles = $CPUParticles2D
@onready var snd_launch = $AudioStreamPlayer2D

func _ready():
	# Play launch sound
	snd_launch.play()
	
	# Initial burst direction (upwards or random)
	var angle = randf_range(-PI, PI)
	velocity = Vector2.RIGHT.rotated(angle) * 150.0
	
	# If no target provided, try to find one
	if not is_instance_valid(target_node):
		find_new_target()

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		explode()
		return

	if is_instance_valid(target_node):
		var target_dir = global_position.direction_to(target_node.global_position)
		var desired_velocity = target_dir * max_speed
		var steer = (desired_velocity - velocity).normalized() * steer_force
		velocity += steer
	else:
		# If target died, find a new one
		find_new_target()
	
	speed = min(speed + acceleration * delta, max_speed)
	velocity = velocity.normalized() * speed
	
	rotation = velocity.angle()
	global_position += velocity * delta

func find_new_target():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_dist = INF
	var closest_enemy = null
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy
	
	target_node = closest_enemy

func explode():
	# Visual effect could be added here
	queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		# The HurtBox script will handle damage via the 'hurt' signal
		# But since this is a projectile, we might want to explode it
		explode()

func enemy_hit(charge = 1):
	explode()
