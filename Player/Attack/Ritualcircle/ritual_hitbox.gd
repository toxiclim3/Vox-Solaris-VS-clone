extends Area2D

var damage = 0
var angle = Vector2.ZERO
var knockback_amount = 0
var proc_coefficient = 1.0
var hit_once_array = []

signal remove_from_array(object)
