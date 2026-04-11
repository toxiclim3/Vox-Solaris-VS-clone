extends Area2D

var damage = 30
var level = 1
var target_pos = Vector2.ZERO
var angle = Vector2.ZERO # Direction vector for HurtBox
var start_rotation = 0.0
var sweep_angle = PI # Total arc size (180 degrees)
var lifetime = 0.4 # Slightly longer for better visual
var knockback_amount = 50.0
var killer_source = "glasslash"
var timer = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	# Calculate start rotation so the sweep is centered on target
	var target_dir = global_position.direction_to(target_pos)
	angle = target_dir
	start_rotation = target_dir.angle() - (sweep_angle / 2.0)
	rotation = start_rotation
	
	# Scale based on player spell size
	var spell_scale = (1.0 + player.spell_size)
	scale *= spell_scale
	
	# Update shader with current physical length
	var line = get_node_or_null("Line2D")
	if line and line.material is ShaderMaterial:
		var current_len = 100.0 * spell_scale
		line.material.set_shader_parameter("total_length", current_len)
		# Update margins to match the 0.5 scaled sprites (22px -> 11px, 30px -> 15px)
		line.material.set_shader_parameter("start_margin", 11.0)
		line.material.set_shader_parameter("end_margin", 15.0)
	
	# Connect signal for damage
	area_entered.connect(_on_area_entered)

@onready var handle_sprite = get_node_or_null("HandleSprite")
@onready var tip_sprite = get_node_or_null("TipSprite")

func _process(delta):
	timer += delta
	var t = clamp(timer / lifetime, 0.0, 1.0)
	
	# Master rotation of the Area2D (the handle)
	var eased_t = -0.5 * (cos(PI * t) - 1.0)
	rotation = start_rotation + (eased_t * sweep_angle)
	
	var line = get_node_or_null("Line2D")
	if line:
		var point_count = line.points.size()
		var total_length = 100.0
		
		for i in range(point_count):
			var base_y = -i * (total_length / (point_count - 1))
			var weight = abs(base_y) / total_length 
			
			var lag_factor = 0.18
			var t_lagged = clamp((timer / lifetime) - (weight * lag_factor), 0.0, 1.0)
			var eased_t_lagged = -0.5 * (cos(PI * t_lagged) - 1.0)
			
			var angle_diff = (eased_t_lagged - eased_t) * sweep_angle
			line.points[i] = Vector2(0, base_y).rotated(angle_diff)
		
		# Position and rotate the rigid sprites to match the line endpoints
		if handle_sprite:
			handle_sprite.position = line.points[0]
			handle_sprite.rotation = (line.points[1] - line.points[0]).angle()
		
		if tip_sprite:
			# With 15px tip margin and 100px total length, the anchor is at 85px.
			# Using index 8 (80px) and a small offset or index 9 (90px)
			var tip_anchor_idx = 8
			if point_count > tip_anchor_idx:
				tip_sprite.position = line.points[tip_anchor_idx]
				tip_sprite.rotation = (line.points[-1] - line.points[tip_anchor_idx]).angle()
		
		# Fade out the whip and sprites towards the end
		if t > 0.8:
			var alpha = lerp(1.0, 0.0, (t - 0.8) / 0.2)
			line.modulate.a = alpha
			if handle_sprite: handle_sprite.modulate.a = alpha
			if tip_sprite: tip_sprite.modulate.a = alpha
	
	if timer >= lifetime:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		if area.has_method("temp_disable"):
			area.temp_disable()
		
		# Damage is now handled automatically by the HurtBox system using our properties.
		# This avoids the previous double-damage bug.
