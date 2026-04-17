extends Area2D

var damage = 30
var level = 1
var target_pos = Vector2.ZERO
var angle = Vector2.ZERO
var start_rotation = 0.0
var sweep_angle = PI
var lifetime = 0.4
var knockback_amount = 50.0
var killer_source = "glasslash"
var proc_coefficient = 1.0
var timer = 0.0
var hit_once_array = []

@onready var player = get_tree().get_first_node_in_group("player")
@onready var line = $Line2D
@onready var handle_sprite = $HandleSprite
@onready var tip_sprite = $TipSprite

func _ready():
	# Reset local transforms to ensure perfect alignment
	line.position = Vector2.ZERO
	if handle_sprite:
		handle_sprite.position = Vector2.ZERO
	if tip_sprite:
		tip_sprite.position = Vector2.ZERO
		
	# Offset the spawn position to roughly the character's chest/hands
	global_position = player.global_position + Vector2(0, -10)
	
	# Calculate start rotation so the sweep is centered on target
	var target_dir = global_position.direction_to(target_pos)
	angle = target_dir
	start_rotation = target_dir.angle() + PI/2.0 - (sweep_angle / 2.0)
	rotation = start_rotation
	
	# Scale based on player spell size
	var spell_scale = (1.0 + player.spell_size)
	scale *= spell_scale
	
	# === AUTO-CALIBRATION LOGIC ===
	if line and line.material is ShaderMaterial:
		var mat = line.material as ShaderMaterial
		
		# 1. Total local length of the line
		var local_len = 0.0
		if line.points.size() > 1:
			local_len = abs(line.points[-1].y - line.points[0].y)
		mat.set_shader_parameter("total_length", local_len)
		
		# 2. Texture size
		if line.texture:
			mat.set_shader_parameter("texture_size", line.texture.get_size())
			
		# 3. Dynamic Margins (Texture Pixels)
		if handle_sprite:
			mat.set_shader_parameter("start_margin", handle_sprite.region_rect.size.x)
			mat.set_shader_parameter("texture_scale", handle_sprite.scale.x)
			
		if tip_sprite:
			mat.set_shader_parameter("end_margin", tip_sprite.region_rect.size.x)
	
	area_entered.connect(_on_area_entered)

func _process(delta):
	timer += delta
	var t = clamp(timer / lifetime, 0.0, 1.0)
	
	# Follow the player actively so the whip doesn't drift
	global_position = player.global_position + Vector2(0, -10)
	
	# Master rotation
	var eased_t = -0.5 * (cos(PI * t) - 1.0)
	rotation = start_rotation + (eased_t * sweep_angle)
	
	if line:
		var point_count = line.points.size()
		var total_length = 100.0
		var new_points = line.points.duplicate()
		
		# Update Line2D point positions for lagging effect
		for i in range(point_count):
			var base_y = -i * (total_length / (point_count - 1))
			var weight = abs(base_y) / total_length 
			var lag_factor = 0.18
			var t_lagged = clamp((timer / lifetime) - (weight * lag_factor), 0.0, 1.0)
			var eased_t_lagged = -0.5 * (cos(PI * t_lagged) - 1.0)
			
			var angle_diff = (eased_t_lagged - eased_t) * sweep_angle
			new_points[i] = Vector2(0, base_y).rotated(angle_diff)
		
		# Apply the new points array to force a re-draw
		line.points = new_points
		
		# Sync Rigid Sprites
		if handle_sprite:
			handle_sprite.position = line.points[0]
			handle_sprite.rotation = (line.points[1] - line.points[0]).angle()
		
		if tip_sprite:
			# Anchor at the very end and use negative offset to extend backwards
			tip_sprite.position = line.points[-1]
			tip_sprite.rotation = (line.points[-1] - line.points[-2]).angle()
			
	# Fade out (moved outside 'if line' to ensure it runs)
	if t > 0.8:
		var alpha = lerp(1.0, 0.0, (t - 0.8) / 0.2)
		modulate.a = alpha # Simpler than updating every child
	
	if timer >= lifetime:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		if not hit_once_array.has(area):
			hit_once_array.append(area)
			if area.has_method("temp_disable"):
				area.temp_disable()
