extends Area2D

var level = 1
var attack_size = 1.0
var damage = 2.5
var slow_amount = 0
var duration = 2.0

var min_frame = 33
var max_frame = 43

@export var debug_red = false

@onready var sprite = $Sprite2D
@onready var damage_box = $DamageBox
@onready var duration_timer = $DurationTimer

func _ready():
	match level:
		1:
			damage = damage
			slow_amount = 0.0
			duration = 2.0
		2:
			damage = damage
			slow_amount = 0.0
			duration = 2.0
		3:
			damage = damage + 2.5
			slow_amount = 0.20
			duration = 2.0
		4:
			damage = damage + 5
			slow_amount = 0.45
			duration = 3.0
			min_frame = 11
			max_frame = 21

	var tween = create_tween()
	tween.tween_property(self,"scale",Vector2(1,1)*attack_size,0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()
	
	sprite.frame = min_frame
	
	duration_timer.wait_time = duration
	duration_timer.start()
	
	damage_box.damage = damage
	damage_box.get_node("CollisionShape2D").disabled = true
	
	if debug_red:
		sprite.modulate = Color(1.0, 0.0, 0.0, 0.7)

func _on_animation_timer_timeout():
	if sprite.frame < max_frame:
		sprite.frame += 1
	else:
		sprite.frame = min_frame + 2

func _on_pulse_timer_timeout():
	if damage_box.has_signal("remove_from_array"):
		damage_box.emit_signal("remove_from_array", damage_box)
	
	damage_box.get_node("CollisionShape2D").set_deferred("disabled", false)
	await get_tree().create_timer(0.05).timeout
	damage_box.get_node("CollisionShape2D").set_deferred("disabled", true)

func _on_duration_timer_timeout():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
	tween.play()

func _on_area_entered(area):
	if area.name == "HurtBox":
		var enemy = area.get_parent().get_parent()
		if enemy and enemy.is_in_group("enemy") and slow_amount > 0:
			enemy.movement_speed *= (1.0 - slow_amount)

func _on_area_exited(area):
	if area.name == "HurtBox":
		var enemy = area.get_parent().get_parent()
		if enemy and enemy.is_in_group("enemy") and slow_amount > 0:
			enemy.movement_speed /= (1.0 - slow_amount)
