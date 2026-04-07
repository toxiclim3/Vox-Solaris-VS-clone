extends EnemyBody

enum BossState { CHASE, DISSOLVING, TELEGRAPHING, REAPPEARING }
var state = BossState.CHASE

@export var dissolve_duration: float = 1.0
@export var reappear_duration: float = 1.0
@export var ability_cooldown: float = 15.0
@export var attack_radius: float = 120.0
@export var telegraph_duration: float = 2.0

var ability_timer: float = ability_cooldown
var state_timer: float = 0.0

var telegraph_scene = preload("res://Enemy/Base/telegraph_area.tscn")
var teleport_target: Vector2
var particles: CPUParticles2D
var warning_particles: CPUParticles2D
var debug_label: Label
			
func _ready():
	super()
	ability_timer = ability_cooldown
	
	particles = get_node_or_null("BossParticles")
	if not particles:
		particles = CPUParticles2D.new()
		particles.name = "BossParticles"
		particles.emitting = false
		particles.one_shot = false
		particles.amount = 50
		particles.lifetime = 0.8
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 30.0
		particles.direction = Vector2(0, -1)
		particles.spread = 180.0
		particles.gravity = Vector2(0, 0)
		particles.initial_velocity_min = 20.0
		particles.initial_velocity_max = 60.0
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 4.0
		particles.z_index = 3
		particles.color = Color(0.0, 0.8, 0.5, 1.0)
		add_child(particles)

	warning_particles = get_node_or_null("WarningParticles")
	if not warning_particles:
		warning_particles = CPUParticles2D.new()
		warning_particles.name = "WarningParticles"
		warning_particles.emitting = false
		warning_particles.amount = 40
		if "amount_ratio" in warning_particles:
			warning_particles.amount_ratio = 0.0
		warning_particles.lifetime = 1.0
		warning_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		warning_particles.emission_sphere_radius = 35.0
		warning_particles.direction = Vector2(0, -1)
		warning_particles.gravity = Vector2(0, -50)
		warning_particles.initial_velocity_min = 15.0
		warning_particles.initial_velocity_max = 40.0
		warning_particles.scale_amount_min = 4.0
		warning_particles.scale_amount_max = 8.0
		warning_particles.z_index = 3
		warning_particles.color = Color(1.0, 0.1, 0.1, 0.4)
		add_child(warning_particles)

	debug_label = Label.new()
	debug_label.position = Vector2(-20, -40)
	add_child(debug_label)
	debug_label.hide()

func _physics_process(delta):
	if debug_label:
		debug_label.text = "State: %d\nAbil_T: %.2f\nState_T: %.2f" % [state, ability_timer, state_timer]
		#debug_label.global_rotation = 0.0 # keep it upright

	match state:
		BossState.CHASE:
			super(delta)
			
			ability_timer -= delta
			
			var time_remaining_fraction = ability_timer / ability_cooldown
			if time_remaining_fraction <= 0.3:
				if not warning_particles.emitting:
					warning_particles.emitting = true
				var progress = 1.0 - (time_remaining_fraction / 0.3)
				if "amount_ratio" in warning_particles:
					warning_particles.amount_ratio = progress
				# Blend the alpha starting from low-contrast, progressively getting clearer
				warning_particles.modulate.a = 0.3 + (progress * 0.7)
			else:
				warning_particles.emitting = false
				
			if ability_timer <= 0:
				warning_particles.emitting = false
				start_dissolve()

		BossState.DISSOLVING:
			state_timer -= delta
			var scale_val = max(0.1, state_timer / dissolve_duration)
			sprite.scale = Vector2(scale_val, scale_val)
			
			if state_timer <= 0:
				sprite.visible = false
				particles.emitting = false
				start_telegraph()
				
		BossState.TELEGRAPHING:
			state_timer -= delta
			# Switch to reappearing when remaining time exactly matches reappear duration
			if state_timer <= reappear_duration:
				start_reappear()
				
		BossState.REAPPEARING:
			state_timer -= delta
			var scale_percent = 1.0 - (state_timer / reappear_duration)
			var scale_val = clamp(scale_percent, 0.1, 1.0)
			sprite.scale = Vector2(scale_val, scale_val)
			
			if state_timer <= 0:
				sprite.scale = Vector2(1, 1)
				particles.emitting = false
				end_ability()

func start_dissolve():
	state = BossState.DISSOLVING
	state_timer = dissolve_duration
	if particles:
		particles.emitting = true
	
	collision.set_deferred("disabled", true)
	if hitBox.has_method("tempdisable"):
		hitBox.tempdisable()
	if hurtBox.get("collision"):
		hurtBox.collision.set_deferred("disabled", true)
	elif hurtBox.has_node("CollisionShape2D"):
		hurtBox.get_node("CollisionShape2D").set_deferred("disabled", true)

func start_telegraph():
	state = BossState.TELEGRAPHING
	
	if is_instance_valid(player):
		var random_dir = Vector2.RIGHT.rotated(randf() * TAU)
		teleport_target = player.global_position + random_dir * randf_range(50, 150)
	else:
		teleport_target = global_position
		
	global_position = teleport_target
	
	var t = telegraph_scene.instantiate()
	t.global_position = teleport_target
	t.duration = telegraph_duration
	t.radius = attack_radius
	get_parent().call_deferred("add_child", t)
	
	state_timer = telegraph_duration 

func start_reappear():
	state = BossState.REAPPEARING
	# Do not reset state_timer, so it stays perfectly synced with the telegraph
	if sprite:
		sprite.visible = true
		sprite.scale = Vector2(0.1, 0.1)
	if particles:
		particles.emitting = true
	
func end_ability():
	state = BossState.CHASE
	ability_timer = ability_cooldown
	
	collision.set_deferred("disabled", false)
	if hurtBox.get("collision"):
		hurtBox.collision.set_deferred("disabled", false)
	elif hurtBox.has_node("CollisionShape2D"):
		hurtBox.get_node("CollisionShape2D").set_deferred("disabled", false)
