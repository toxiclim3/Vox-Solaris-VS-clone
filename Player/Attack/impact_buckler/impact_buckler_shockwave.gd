extends Area2D

var damage: float = 0.0
var knockback_amount: float = 400.0
var killer_source: String = "impact_buckler"
var proc_coefficient: float = 0.0
var hit_once_array: Array = []
var angle: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("attack")
	area_entered.connect(_on_area_entered)
	
	if is_inside_tree():
		var tween = create_tween()
		if tween != null:
			scale = Vector2(0.2, 0.2)
			tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.25)
			tween.tween_callback(queue_free)
		else:
			var timer = get_tree().create_timer(0.25)
			if timer != null:
				timer.timeout.connect(queue_free)

func _on_area_entered(area: Area2D) -> void:
	if area.name == "HurtBox":
		var enemy = null
		if area.owner is EnemyBody:
			enemy = area.owner
		elif area.get_parent() is EnemyBody:
			enemy = area.get_parent()
		elif area.get_parent() and area.get_parent().get_parent() is EnemyBody:
			enemy = area.get_parent().get_parent()
		
		if enemy != null:
			var dir = global_position.direction_to(enemy.global_position)
			if dir == Vector2.ZERO:
				dir = Vector2.UP
			if not enemy.isBoss and not enemy.is_in_group("boss"):
				enemy.knockback = dir * knockback_amount

func _draw() -> void:
	draw_arc(Vector2.ZERO, 80.0, 0.0, TAU, 32, Color(0.4, 0.8, 1.0, 0.6), 4.0)
