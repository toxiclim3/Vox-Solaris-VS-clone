## slide_protips_splash.gd
## Diorama: "Pro Tips" text in CursiveHeader theme, shimmer particles behind it.
extends Node2D

const BG_COLOR := Color(0.08, 0.06, 0.12)

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size  = Vector2(640, 360)
	add_child(bg)

	# Shimmer particles behind the text
	var particles := GPUParticles2D.new()
	particles.position = Vector2(320, 180)
	particles.amount   = 28
	particles.lifetime = 2.5
	particles.speed_scale = 0.6
	particles.randomness = 1.0
	particles.z_index    = -1

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(200, 60, 0)
	mat.particle_flag_disable_z = true
	mat.direction              = Vector3(0, -1, 0)
	mat.spread                 = 18.0
	mat.initial_velocity_min   = 5.0
	mat.initial_velocity_max   = 22.0
	mat.gravity                = Vector3(0, -10, 0)
	mat.scale_min              = 2.5
	mat.scale_max              = 5.5

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.8, 0.5, 1.0, 0.9), Color(0.5, 0.2, 0.8, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	particles.process_material = mat
	add_child(particles)

	# "Pro Tips" label  (uses CursiveHeader if theme loads, else graceful fallback)
	var lbl := Label.new()
	lbl.text = "Pro Tips"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(640, 360)
	lbl.position = Vector2.ZERO
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.0, 0.5, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

	var cursive_theme := load("res://Themes/CursiveHeader.tres")
	if cursive_theme:
		lbl.theme = cursive_theme
	add_child(lbl)

	# Subtitle
	var sub := Label.new()
	sub.text = "Advanced tactics for the brave"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size     = Vector2(640, 20)
	sub.position = Vector2(0, 220)
	sub.add_theme_font_size_override("font_size", 9)
	sub.modulate = Color(0.75, 0.60, 0.90)
	add_child(sub)

	# Gentle float animation on the main label
	_float_label(lbl)

func _float_label(lbl: Label) -> void:
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(lbl, "position:y", -6.0, 1.4)
	tw.tween_property(lbl, "position:y",  0.0, 1.4)

func start_loop() -> void:
	pass  # particles auto-play, float runs in _ready

func stop_loop() -> void:
	pass
