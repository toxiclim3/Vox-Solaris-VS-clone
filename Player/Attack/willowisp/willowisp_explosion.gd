extends Area2D

var damage = 5.0
var level = 1
var killer_source = "willowisp"
var animator: PhasedAnimator
var knockback_amount = 0.0
var hit_once_array = []
var proc_coefficient = 0.1

@onready var sprite = $Sprite2D
@onready var animation_timer = $AnimationTimer

func _ready():
	# Configure PhasedAnimator for one-shot
	animator = PhasedAnimator.new()
	animator.target_sprite = sprite
	animator.row_index = 0 # Can be randomized if multiple rows exist
	animator.col_offset = 0
	animator.loop_start = 10 # Force it to exit loop immediately
	animator.loop_end = 10
	animator.total_frames = 11
	add_child(animator)
	
	$snd_explosion.play()
	
	# Initial damage
	_deal_damage()
	
	# Start animation
	animation_timer.start()

func _deal_damage():
	# The system handles damage via signals or direct calls usually.
	# We'll use the overlapping bodies to deal damage once.
	# Wait for a frame to ensure areas are updated
	await get_tree().physics_frame
	for area in get_overlapping_areas():
		if area.name == "HurtBox":
			var enemy = area.get_parent()
			if enemy.has_method("_on_hurt_box_hurt"):
				enemy._on_hurt_box_hurt(damage, Vector2.ZERO, 0, killer_source)

func _on_animation_timer_timeout():
	# Advance animation
	# Since it's one-shot, we check if we reached the last frame
	if sprite.frame % 11 >= 10:
		animation_timer.stop()
		sprite.visible = false
		if $snd_explosion.playing:
			$snd_explosion.finished.connect(queue_free)
		else:
			queue_free()
	else:
		animator.advance(true) # Pass true to force finishing
