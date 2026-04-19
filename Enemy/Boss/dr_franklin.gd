extends EnemyBody

## Dr. Franklin — boss with a directional rectangle beam attack.
## State machine: CHASE -> TELEGRAPHING -> RECOVERING -> CHASE.
## No teleportation: the boss stops in place, charges the beam, then resumes.

enum BossState { CHASE, TELEGRAPHING, RECOVERING }
var state: BossState = BossState.CHASE

@export var ability_cooldown: float = 10.0
@export var telegraph_duration: float = 1.5
@export var rect_length: float = 240.0
@export var rect_width: float = 80.0
## Max random rotation (degrees) applied to the aimed direction.
@export var angle_offset_max: float = 10.0

var ability_timer: float = 0.0
var state_timer: float = 0.0
var hitBox_shape: CollisionShape2D  # cached in _ready(); disabled during non-CHASE states

var franklin_telegraph_scene = preload("res://Enemy/Base/franklin_telegraph_rect.tscn")

var warning_particles: CPUParticles2D
var debug_label: Label

func _ready() -> void:
	super()
	ability_timer = ability_cooldown

	# Override sprite texture with the placeholder (avoids UID in .tscn).
	sprite.texture = load("res://Textures/PLACEHOLDER.png")

	# Store a direct reference to the HitBox collision shape so we can
	# disable contact damage while the boss is standing still during an attack.
	hitBox_shape = hitBox.get_node("CollisionShape2D")
	
	# Force HitBox to ONLY interact with Player (Layer 2)
	# Layer 2 is Bit 2 in the editor, but 1-indexed helper uses '2'.
	hitBox.set_collision_layer_value(1, false) # World
	hitBox.set_collision_layer_value(2, true)  # Player
	hitBox.set_collision_layer_value(3, false) # Enemy
	hitBox.collision_mask = 0

	# Warning particles — identical look to the existing boss.
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

func _physics_process(delta: float) -> void:
	if debug_label:
		debug_label.text = "State: %d\nAbil_T: %.2f\nState_T: %.2f" % [state, ability_timer, state_timer]

	match state:
		BossState.CHASE:
			super(delta)  # Normal movement toward player.

			ability_timer -= delta

			# Warning particles build up during the last 30% of the cooldown.
			var time_fraction := ability_timer / ability_cooldown
			if time_fraction <= 0.3:
				if not warning_particles.emitting:
					warning_particles.emitting = true
				var progress := 1.0 - (time_fraction / 0.3)
				if "amount_ratio" in warning_particles:
					warning_particles.amount_ratio = progress
				warning_particles.modulate.a = 0.3 + (progress * 0.7)
			else:
				warning_particles.emitting = false

			if ability_timer <= 0.0:
				warning_particles.emitting = false
				_start_attack()

		BossState.TELEGRAPHING:
			# Boss stands still while the telegraph fills.
			velocity = Vector2.ZERO
			move_and_slide()

			state_timer -= delta
			if state_timer <= 0.0:
				_end_telegraph()

		BossState.RECOVERING:
			# Brief pause before resuming the chase.
			velocity = Vector2.ZERO
			move_and_slide()

			state_timer -= delta
			if state_timer <= 0.0:
				_end_ability()

func _start_attack() -> void:
	state = BossState.TELEGRAPHING
	state_timer = telegraph_duration

	# Freeze contact damage while the boss stands still in the crowd.
	if hitBox_shape:
		hitBox_shape.set_deferred("disabled", true)

	# Aim toward the player with a small random offset.
	var attack_dir := Vector2.RIGHT
	if is_instance_valid(player):
		attack_dir = global_position.direction_to(player.global_position)
	var offset_rad := deg_to_rad(randf_range(-angle_offset_max, angle_offset_max))
	attack_dir = attack_dir.rotated(offset_rad)

	# Spawn the rectangle telegraph at the boss's current position.
	var t = franklin_telegraph_scene.instantiate()
	t.global_position = global_position
	t.duration = telegraph_duration
	t.rect_length = rect_length
	t.rect_width = rect_width
	t.direction = attack_dir
	t.player_damage = enemy_damage  # 30 (Boss contact damage level)
	t.enemy_damage = enemy_damage * 2.5  # 75 (High damage to other enemies)
	get_parent().call_deferred("add_child", t)

func _end_telegraph() -> void:
	state = BossState.RECOVERING
	state_timer = 0.5  # Half-second pause before moving again.

func _end_ability() -> void:
	state = BossState.CHASE
	ability_timer = ability_cooldown
	# Re-enable contact damage now that the boss is chasing again.
	if hitBox_shape:
		hitBox_shape.set_deferred("disabled", false)
