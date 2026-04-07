extends Area2D

@export var duration: float = 2.0
@export var radius: float = 100.0
@export var player_damage: int = 30
@export var enemy_damage: int = 75

var current_time: float = 0.0
var active: bool = false
var executed: bool = false

func _ready():
    # Setup CollisionShape2D
    var shape = CircleShape2D.new()
    shape.radius = radius
    var collision = CollisionShape2D.new()
    collision.shape = shape
    add_child(collision)
    
    # We want to detect layers 2 (Player) and 4 (Enemies)
    collision_mask = 2 | 4 
    collision_layer = 0 # Don't act as a physics object to others
    
    current_time = duration
    active = true

func _process(delta):
    if not active:
        return
        
    current_time -= delta
    queue_redraw()
    
    if current_time <= 0 and not executed:
        execute_attack()

func _draw():
    if not active or executed:
        return
        
    # Draw the outer ring
    draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0, 0, 0.5), 2.0)
    
    # Draw the filling circle
    var fill_ratio = 1.0 - (current_time / duration)
    fill_ratio = clamp(fill_ratio, 0.0, 1.0)
    var current_radius = radius * fill_ratio
    
    if current_radius > 0:
        draw_circle(Vector2.ZERO, current_radius, Color(1, 0, 0, 0.3))

func execute_attack():
    executed = true
    
    # Briefly show full circle before freeing
    queue_redraw()
    
    var areas = get_overlapping_areas()
    for area in areas:
        if area.name == "HurtBox" or area.has_signal("hurt"):
            var target = area.owner if area.owner else area.get_parent()
            
            # Skip the boss itself
            if target and target.is_in_group("boss"):
                continue
                
            var damage_to_deal = enemy_damage
            if target and target.is_in_group("player"):
                damage_to_deal = player_damage
                
            area.emit_signal("hurt", damage_to_deal, Vector2.ZERO, 0)
            
    # Remove after a tiny delay so the flash is visible
    get_tree().create_timer(0.2).timeout.connect(queue_free)
