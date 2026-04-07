extends EnemyBody

enum BossState { CHASE, DISSOLVING, TELEGRAPHING, REAPPEARING }
var state = BossState.CHASE

@export var dissolve_duration: float = 1.0
@export var reappear_duration: float = 1.0
@export var ability_cooldown: float = 5.0
@export var attack_radius: float = 120.0

var ability_timer: float = ability_cooldown
var state_timer: float = 0.0

var telegraph_scene = preload("res://Enemy/telegraph_area.tscn")
var teleport_target: Vector2
var particles: CPUParticles2D

func _ready():
    super._ready()
    
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
        particles.color = Color(0.0, 0.8, 0.5, 1.0)
        add_child(particles)

func _physics_process(delta):
    match state:
        BossState.CHASE:
            super._physics_process(delta)
            
            ability_timer -= delta
            if ability_timer <= 0:
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
            if state_timer <= 0:
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
    t.duration = 2.0
    t.radius = attack_radius
    get_tree().current_scene.add_child(t)
    
    state_timer = 2.0 

func start_reappear():
    state = BossState.REAPPEARING
    state_timer = reappear_duration
    sprite.visible = true
    sprite.scale = Vector2(0.1, 0.1)
    particles.emitting = true
    
func end_ability():
    state = BossState.CHASE
    ability_timer = ability_cooldown
    
    collision.set_deferred("disabled", false)
    if hurtBox.get("collision"):
        hurtBox.collision.set_deferred("disabled", false)
    elif hurtBox.has_node("CollisionShape2D"):
        hurtBox.get_node("CollisionShape2D").set_deferred("disabled", false)
