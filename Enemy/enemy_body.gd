extends CharacterBody2D

class_name EnemyBody

@export var movement_speed = 20.0
@export var hp = 10
@export var knockback_recovery = 3.5
@export var experience = 1
@export var enemy_damage = 1
@export var isBoss = 0
var max_hp = 0
var knockback = Vector2.ZERO

@onready var sprite = $EnemyBase/Sprite2D
@onready var anim = $AnimationPlayer
@onready var snd_hit = $EnemyBase/snd_hit
@onready var hitBox = $EnemyBase/HitBox
@onready var hurtBox = $EnemyBase/HurtBox
@onready var collision = $CollisionShape2D

@onready var player = get_tree().get_first_node_in_group("player")
@onready var loot_base = get_tree().get_first_node_in_group("loot")

var death_anim = preload("res://Enemy/explosion.tscn")
var exp_gem = preload("res://Objects/experience_gem.tscn")

signal remove_from_array(object)

var screen_size
var update_timer = 0.0

func _ready():
	max_hp = hp
	add_to_group("enemy")
	if isBoss:
		add_to_group("boss")
	anim.play("walk")
	hitBox.damage = enemy_damage
	screen_size = get_viewport_rect().size
	hurtBox.connect("hurt",Callable(self,"_on_hurt_box_hurt"))
	
func _physics_process(delta):
	knockback = knockback.move_toward(Vector2.ZERO, knockback_recovery)
	var direction = Vector2.ZERO
	
	var dist_sq = global_position.distance_squared_to(player.global_position)
	if dist_sq > 400000:
		update_timer -= delta
		if update_timer <= 0:
			direction = global_position.direction_to(player.global_position)
			velocity = direction * movement_speed
			update_timer = 0.2
		else:
			direction = velocity.normalized()
	else:
		direction = global_position.direction_to(player.global_position)
		velocity = direction * movement_speed
		
		if hurtBox.has_overlapping_areas():
			var push_vector = Vector2.ZERO
			for area in hurtBox.get_overlapping_areas():
				if area.owner != self and area.owner != null:
					var dist = global_position.distance_to(area.global_position)
					if dist < 22.0:
						var push_strength = 1.0 - (dist / 22.0)
						push_vector += area.global_position.direction_to(global_position) * push_strength
			velocity += push_vector.normalized() * (movement_speed * 0.4)
			
		if velocity.length() > movement_speed:
			velocity = velocity.normalized() * movement_speed
			
	velocity += knockback
	move_and_slide()
	
	if direction.x > 0.1:
		sprite.flip_h = true
	elif direction.x < -0.1:
		sprite.flip_h = false

func death():
	emit_signal("remove_from_array",self)
	
	var enemy_death = death_anim.instantiate()
	enemy_death.scale = sprite.scale
	enemy_death.global_position = global_position
	get_parent().call_deferred("add_child",enemy_death)
	
	var new_gem = exp_gem.instantiate()
	new_gem.global_position = global_position
	new_gem.experience = experience
	loot_base.call_deferred("add_child",new_gem)
	
	if isBoss:
		GlobalEvents.boss_defeated.emit()
	
	queue_free()

func _on_hurt_box_hurt(damage, angle, knockback_amount):
	hp -= damage
	knockback = angle * knockback_amount
	if hp <= 0:
		death()
	else:
		snd_hit.play()
