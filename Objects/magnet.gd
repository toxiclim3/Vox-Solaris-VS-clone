extends Area2D

var target = null
var speed = -1

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var sound = $snd_collected

func _ready():
	add_to_group("loot")

func _physics_process(delta):
	if target != null:
		global_position = global_position.move_toward(target.global_position, speed)
		speed += 4*delta

func collect():
	sound.play()
	collision.call_deferred("set","disabled",true)
	sprite.visible = false
	
	var player = get_tree().get_first_node_in_group("player")
	var loot = get_tree().get_nodes_in_group("loot")
	for item in loot:
		if "target" in item and item != self:
			item.target = player
	
	return 0 # No experience from the magnet itself


func _on_snd_collected_finished():
	queue_free()
