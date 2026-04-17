extends Area2D

var level = 1
var endless_level = 0
var hp = 1
var speed = 225
var damage = 0 # Damage is dealt by the explosion, not the bottle itself
var attack_size = 1.0
var knockback_amount = 0

var target = Vector2.ZERO
var angle = Vector2.ZERO

@onready var player = get_tree().get_first_node_in_group("player")
signal remove_from_array(object)

var poison_gas_scene = preload("res://Player/Attack/poisonbottle/poison_gas.tscn")

func _ready():
	angle = global_position.direction_to(target)
	rotation = angle.angle() + deg_to_rad(135)
	match level:
		1:
			speed = 225
			attack_size = 1.0 * (1 + player.spell_size)
		2:
			speed = 225
			attack_size = 1.25 * (1 + player.spell_size)
		3:
			speed = 225
			attack_size = 1.25 * (1 + player.spell_size)
		4:
			speed = 225
			attack_size = 1.25 * (1 + player.spell_size)

	var tween = create_tween()
	tween.tween_property(self,"scale",Vector2(1,1)*attack_size,1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.play()

func _physics_process(delta):
	position += angle * speed * delta

func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		spawn_gas()
		emit_signal("remove_from_array",self)
		queue_free()

func _on_timer_timeout(): # If it reaches max distance or time without hitting
	spawn_gas()
	emit_signal("remove_from_array",self)
	queue_free()

func spawn_gas():
	var gas = poison_gas_scene.instantiate()
	gas.global_position = global_position
	gas.level = level
	gas.endless_level = endless_level
	# Pass attack size to scale the gas too
	gas.attack_size = attack_size
	get_parent().call_deferred("add_child", gas)
