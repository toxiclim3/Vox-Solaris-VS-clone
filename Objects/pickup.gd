extends Area2D

# 0 = Experience Gem, 1 = Magnet
@export_enum("Experience", "Magnet") var pickup_type = 0
@export var experience = 1

var spr_green = preload("res://Textures/Items/Gems/Gem_green.png")
var spr_blue= preload("res://Textures/Items/Gems/Gem_blue.png")
var spr_red = preload("res://Textures/Items/Gems/Gem_red.png")

var target = null
var speed = -1

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var sound = $snd_collected

func _ready():
	if pickup_type == 1:
		add_to_group("loot")
		return

	if experience < 5:
		pass # Keep default texture
	elif experience < 25:
		sprite.texture = spr_blue
	else:
		sprite.texture = spr_red

func _physics_process(delta):
	if target != null:
		global_position = global_position.move_toward(target.global_position, speed)
		speed += 4*delta

func collect():
	sound.play()
	collision.call_deferred("set","disabled",true)
	sprite.visible = false
	
	if pickup_type == 1: # Magnet
		var player = get_tree().get_first_node_in_group("player")
		var loot = get_tree().get_nodes_in_group("loot")
		for item in loot:
			if "target" in item and item != self:
				item.target = player
		return 0 # No experience
		
	return experience # Experience Gem

func _on_snd_collected_finished():
	queue_free()
