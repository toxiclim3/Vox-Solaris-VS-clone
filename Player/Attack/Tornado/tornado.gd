extends Area2D

var level = 1
var endless_level = 0
var hp = 9999
var speed = 150.0
var damage = 5
var attack_size = 1.0
var knockback_amount = 100
var proc_coefficient = 0.5

var last_movement = Vector2.ZERO
var angle = Vector2.ZERO
var angle_less = Vector2.ZERO
var angle_more = Vector2.ZERO

signal remove_from_array(object)

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	match level:
		1:
			hp = 9999
			speed = 150.0
			damage = 5
			knockback_amount = 100
			attack_size = 1.0 * (1 + player.spell_size)
		2:
			hp = 9999
			speed = 150.0
			damage = 5
			knockback_amount = 100
			attack_size = 1.0 * (1 + player.spell_size)
		3:
			hp = 9999
			speed = 150.0
			damage = 5
			knockback_amount = 100
			attack_size = 1.0 * (1 + player.spell_size)
		4:
			hp = 9999
			speed = 150.0
			damage = 5
			knockback_amount = 125
			attack_size = 1.0 * (1 + player.spell_size)
			
	# Apply Endless Scaling (approx 5% per level)
	attack_size += endless_level * 0.05


			
	# Generate swerve targets by rotating the base movement direction.
	# This works for any angle (Keyboard/Controller/Mouse).
	var move_to_less = global_position + last_movement.rotated(deg_to_rad(randf_range(-45, -25))) * 500
	var move_to_more = global_position + last_movement.rotated(deg_to_rad(randf_range(25, 45))) * 500
	
	angle_less = global_position.direction_to(move_to_less)
	angle_more = global_position.direction_to(move_to_more)
	
	var initital_tween = create_tween().set_parallel(true)
	initital_tween.tween_property(self,"scale",Vector2(1,1)*attack_size,3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var final_speed = speed
	speed = speed/5.0
	initital_tween.tween_property(self,"speed",final_speed,6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	initital_tween.play()
	
	var tween = create_tween()
	var set_angle = randi_range(0,1)
	if set_angle == 1:
		angle = angle_less
		tween.tween_property(self,"angle", angle_more,2)
		tween.tween_property(self,"angle", angle_less,2)
		tween.tween_property(self,"angle", angle_more,2)
		tween.tween_property(self,"angle", angle_less,2)
		tween.tween_property(self,"angle", angle_more,2)
		tween.tween_property(self,"angle", angle_less,2)
	else:
		angle = angle_more
		tween.tween_property(self,"angle", angle_less,2)
		tween.tween_property(self,"angle", angle_more,2)
		tween.tween_property(self,"angle", angle_less,2)
		tween.tween_property(self,"angle", angle_more,2)
		tween.tween_property(self,"angle", angle_less,2)
		tween.tween_property(self,"angle", angle_more,2)
	tween.play()

func _physics_process(delta):
	position += angle*speed*delta

func _on_timer_timeout():
	emit_signal("remove_from_array",self)
	queue_free()
