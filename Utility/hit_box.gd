extends Area2D

@export var damage = 1
@onready var collision = $CollisionShape2D
@onready var disableTimer = get_node_or_null("DisableHitBoxTimer")

signal remove_from_array(object)

func enemy_hit(charge = 1):
	pass

func tempdisable():
	collision.call_deferred("set","disabled",true)
	disableTimer.start()


func _on_disable_hit_box_timer_timeout():
	collision.call_deferred("set","disabled",false)
