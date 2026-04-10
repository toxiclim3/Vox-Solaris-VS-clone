extends Node2D

enum State { DRAWING, BURSTING, DISSOLVING }
var state = State.DRAWING

var level = 1
var damage = 30.0
var duration = 3.0
var max_speed = 60.0
var steering_force = 150.0
var velocity = Vector2.ZERO

var attack_size = 1.0

var min_frame = 11
var max_frame = 20

@onready var player = get_tree().get_first_node_in_group("player")
@onready var damage_area = $Area2D
@onready var damage_collision = $Area2D/CollisionShape2D
@onready var sprite = $Sprite2D
@onready var draw_timer = $DrawTimer
@onready var burst_timer = $BurstTimer
@onready var pulse_timer = $PulseTimer

func _ready():
	# Setup based on level
	match level:
		1:
			damage = 15
			duration = 1.5
			max_speed = 60.0
			steering_force = 150.0
		2:
			damage = 15
			duration = 1.5
			max_speed = 100.0
			steering_force = 300.0
		3:
			damage = 20
			duration = 2.5
			max_speed = 100.0
			steering_force = 300.0
		4:
			damage = 20
			duration = 2.5
			max_speed = 100.0
			steering_force = 300.0

	attack_size = 1.0 * (1 + player.spell_size)
	scale = Vector2.ONE * attack_size
	z_index = 20
	top_level = true
	
	# Set variables on damage_area for HurtBox to see
	damage_area.damage = damage
	damage_area.angle = Vector2.ZERO
	damage_area.knockback_amount = 0
	
	# Init UI
	damage_area.monitoring = false
	damage_collision.disabled = true
	sprite.frame = min_frame
	sprite.visible = false # Only show during Burst
	
	draw_timer.start(1.0)

func _physics_process(delta):
	if state == State.DISSOLVING:
		return
		
	var current_max_speed = max_speed
	if state == State.BURSTING:
		current_max_speed *= 0.5
		
	# Steering tracking
	var target = get_closest_enemy()
	if target:
		var target_vel = (target.global_position - global_position).normalized() * current_max_speed
		var steer = (target_vel - velocity) * steering_force * delta
		velocity += steer
		velocity = velocity.limit_length(current_max_speed)
	
	global_position += velocity * delta
	
	if state == State.DRAWING:
		queue_redraw()

func _draw():
	if state == State.DRAWING:
		var progress = (1.0 - draw_timer.time_left / draw_timer.wait_time)
		var angle = progress * PI * 2
		draw_arc(Vector2.ZERO, 35, 0, angle, 32, Color(0.8, 0.4, 1.0), 3.0)

func get_closest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var min_dist = INF
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy
	return closest
	
func _on_animation_timer_timeout():
	if sprite.frame < max_frame:
		sprite.frame += 1
	else:
		sprite.frame = min_frame

func _on_draw_timer_timeout():
	state = State.BURSTING
	damage_area.set_deferred("monitoring", true)
	damage_collision.set_deferred("disabled", true)
	
	# Transition to Spritesheet Burst
	sprite.visible = true
	sprite.modulate.a = 1.0
	
	burst_timer.start(duration)
	pulse_timer.start(0.5)
	
	_on_pulse_timer_timeout()

func _on_pulse_timer_timeout():
	if state != State.BURSTING:
		pulse_timer.stop()
		return
	
	if damage_area.has_signal("remove_from_array"):
		damage_area.emit_signal("remove_from_array", damage_area)
	
	damage_collision.set_deferred("disabled", false)
	await get_tree().create_timer(0.05).timeout
	damage_collision.set_deferred("disabled", true)

func _on_burst_timer_timeout():
	state = State.DISSOLVING
	damage_area.set_deferred("monitoring", false)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
	tween.play()
