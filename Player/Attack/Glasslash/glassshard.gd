extends Area2D

var damage = 5.0
var speed = 250.0
var direction = Vector2.RIGHT
var lifetime = 1.0
var timer = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	rotation = direction.angle()
	# Scale based on player spell size
	scale *= (1.0 + player.spell_size)
	area_entered.connect(_on_area_entered)

func _process(delta):
	position += direction * speed * delta
	timer += delta
	if timer >= lifetime:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		if area.owner.has_method("_on_hurt_box_hurt"):
			var knockback = direction * 50
			area.owner._on_hurt_box_hurt(damage, knockback, 20, "glass_shard")
			queue_free() # Shards break on hit
