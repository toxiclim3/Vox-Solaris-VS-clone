extends Area2D

var damage = 8
var knockback_amount = 50.0
var speed = 350.0
var direction = Vector2.ZERO
var killer_source = "vampireknife"
var lifetime = 1.5
var timer = 0.0

# Piercing limit (hp)
var hp = 1

# Per-hit lifesteal: heal this many HP when a knife hits
var lifesteal_per_hit = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	area_entered.connect(_on_area_entered)
	# Orient the sprite toward travel direction
	rotation = direction.angle() + deg_to_rad(90)

func _process(delta):
	position += direction * speed * delta
	timer += delta
	if timer >= lifetime:
		queue_free()

func _on_area_entered(area):
	if area.is_in_group("hurtbox"):
		if area.has_method("temp_disable"):
			area.temp_disable()
		
		# Lifesteal: heal player on hit
		if lifesteal_per_hit > 0.0 and is_instance_valid(player) and player.hp > 0:
			player.hp = clamp(player.hp + lifesteal_per_hit, 0, player.maxhp)
			player.healthBar.value = player.hp
		
		enemy_hit()

func enemy_hit(charge = 1):
	hp -= charge
	if hp <= 0:
		queue_free()
