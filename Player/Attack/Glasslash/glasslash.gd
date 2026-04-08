extends Area2D

var damage = 30
var level = 1
var target_pos = Vector2.ZERO
var angle = Vector2.ZERO # Direction vector for HurtBox
var start_rotation = 0.0
var sweep_angle = PI # Total arc size (180 degrees)
var lifetime = 0.4 # Slightly longer for better visual
var timer = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	# Calculate start rotation so the sweep is centered on target
	var target_dir = global_position.direction_to(target_pos)
	angle = target_dir
	start_rotation = target_dir.angle() - (sweep_angle / 2.0)
	rotation = start_rotation
	
	# Scale based on player spell size
	scale *= (1.0 + player.spell_size)
	
	# Connect signal for damage
	area_entered.connect(_on_area_entered)

func _process(delta):
	timer += delta
	var t = clamp(timer / lifetime, 0.0, 1.0)
	
	# Ease-in-out sinusoidal interpolation
	var eased_t = -0.5 * (cos(PI * t) - 1.0)
	rotation = start_rotation + (eased_t * sweep_angle)
	
	if timer >= lifetime:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		if area.has_method("temp_disable"):
			area.temp_disable()
		
		# Apply damage with kill attribution
		if area.owner.has_method("_on_hurt_box_hurt"):
			var knockback = global_position.direction_to(area.global_position)
			area.owner._on_hurt_box_hurt(damage, knockback, 50, "glasslash")
