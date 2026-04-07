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

@onready var player = get_tree().get_first_node_in_group("player")
@onready var damage_area = $Area2D
@onready var damage_collision = $Area2D/CollisionShape2D
@onready var burst_sprite = $BurstSprite
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
	burst_sprite.visible = false
	
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
	elif state == State.BURSTING:
		# Draw the circle itself
		draw_arc(Vector2.ZERO, 40, 0, PI * 2, 64, Color(0.6, 0.2, 0.8), 2.0)

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

func _on_draw_timer_timeout():
	state = State.BURSTING
	queue_redraw()
	damage_area.set_deferred("monitoring", true)
	# We keep the collision disabled initially and only enable it during the pulse.
	damage_collision.set_deferred("disabled", true)
	burst_sprite.visible = true
	burst_timer.start(duration)
	pulse_timer.start(0.5)
	
	# Trigger the first pulse immediately
	_on_pulse_timer_timeout()
	
	# Burst animation
	var tween = create_tween()
	tween.tween_property(burst_sprite, "scale", Vector2.ONE, 0.2).from(Vector2.ZERO).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.play()

func _on_pulse_timer_timeout():
	if state != State.BURSTING:
		pulse_timer.stop()
		return
	
	# Clear the hit list for the next pulse
	if damage_area.has_signal("remove_from_array"):
		damage_area.emit_signal("remove_from_array", damage_area)
	
	# Momentarily enable the collision to deal damage at the exact pulse time
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
