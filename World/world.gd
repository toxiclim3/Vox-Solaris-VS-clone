extends Node2D

var prev_player_pos = Vector2.ZERO
var smoothed_motion = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalEvents.time = 0
	MusicController.resetPlaylists()
	MusicController.setLooping(true)
	MusicController.fadeInFromSilence()
	MusicController.playNext(MusicController.MusicType.NORMAL)
	
	if get_tree().get_first_node_in_group("player"):
		prev_player_pos = get_tree().get_first_node_in_group("player").global_position
	
	SettingsManager.apply_elite_settings()
	update_elite_graphics(0)

func _process(delta: float) -> void:
	update_elite_graphics(delta)

func update_elite_graphics(delta: float):
	var pp = %PostProcess
	if not pp or not pp.material is ShaderMaterial: return
	
	var mat = pp.material as ShaderMaterial
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		var current_pos = player.global_position
		var motion = current_pos - prev_player_pos
		
		# Smooth the motion to simulate persistence
		smoothed_motion = smoothed_motion.lerp(motion, 8.0 * delta if delta > 0 else 1.0)
		prev_player_pos = current_pos
		
		# Convert to UV space (resolution is 640x360) and scale up dramatically
		var uv_motion = Vector2(smoothed_motion.x / 640.0, smoothed_motion.y / 360.0) * 50.0
		mat.set_shader_parameter("motion_offset", uv_motion)
	
	var ghosting = 0.0
	var blur = 0.0
	
	if SettingsManager.fsr_enabled: ghosting = 0.7 # FSR -> Afterimages
	if SettingsManager.taa_enabled: blur = 0.5      # TAA -> Subtle Smoothing
	
	mat.set_shader_parameter("ghosting_strength", ghosting)
	mat.set_shader_parameter("blur_strength", blur)
	
	# Only show layer if something is active
	var is_active = (ghosting > 0.01 or blur > 0.1)
	pp.get_parent().visible = is_active
	pp.visible = is_active
