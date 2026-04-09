extends Area2D

var damage = 5.0
var angle = Vector2.RIGHT # Renamed from direction for system compatibility
var knockback_amount = 20.0
var killer_source = "glassshard"
var speed = 250.0
var lifetime = 0.4
var timer = 0.0
var base_scale = Vector2.ONE

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	rotation = angle.angle()
	# Scale based on player spell size
	base_scale = Vector2.ONE * (1.0 + player.spell_size)
	scale = base_scale
	area_entered.connect(_on_area_entered)

func _process(delta):
	position += angle * speed * delta
	timer += delta
	
	# Handle scaling: shrink in the last 20% of life
	var life_percent = timer / lifetime
	if life_percent > 0.8:
		# Map 0.8->1.0 to 1.0->0.0
		var shrink_percent = (1.0 - life_percent) / 0.2
		scale = base_scale * shrink_percent
	
	if timer >= lifetime:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		queue_free() # Shards break on hit. Damage handled by system.
