extends Area2D

var level = 1
var endless_level = 0
var attack_size = 1.0
var damage = 2.5
var slow_amount = 0
var duration = 2.0

var animator: PhasedAnimator

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
	
	animator = PhasedAnimator.new()
	add_child(animator)
	
	match level:
		1, 2, 3:
			animator.setup_variant(3, 0) # Row 3 (Greens)
		4:
			animator.setup_variant(1, 1) # Row 1, Column 1 (Index 13 - Purples)

	var tween = create_tween()
	tween.tween_property(self,"scale",Vector2(1,1)*attack_size,0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()
	
	# Initial frame setup handled by animator
	
	# Apply Endless scaling
	damage += endless_level * 1.0
	duration += endless_level * 0.2
	
	duration_timer.wait_time = duration
	duration_timer.start()
	
	damage_box.damage = damage
	damage_box.proc_coefficient = 0.2
	damage_box.get_node("CollisionShape2D").disabled = true

	
	if debug_red:
		sprite.modulate = Color(1.0, 0.0, 0.0, 0.7)

func _on_animation_timer_timeout():
	var is_expiring = duration_timer.time_left < duration_timer.wait_time * 0.2
	animator.advance(is_expiring)

func _on_pulse_timer_timeout():
	if damage_box.has_signal("remove_from_array"):
		damage_box.emit_signal("remove_from_array", damage_box)
	
	if "hit_once_array" in damage_box:
		damage_box.hit_once_array.clear()
	
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
