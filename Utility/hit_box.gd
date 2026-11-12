extends Area2D

@export var damage = 1
var proc_coefficient = 1.0
@onready var collision = $CollisionShape2D
@onready var disableTimer = get_node_or_null("DisableHitBoxTimer")

@warning_ignore("unused_signal")
signal remove_from_array(object)
var hit_once_array = []

func enemy_hit(_charge = 1):
	pass

func tempdisable():
	collision.call_deferred("set","disabled",true)
	if disableTimer != null:
		disableTimer.start()


func _on_disable_hit_box_timer_timeout():
	collision.call_deferred("set","disabled",false)
