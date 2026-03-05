extends Node

@export var pause_menu: Control

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"): 
		toggle_menu()

func toggle_menu() -> void:
	if not pause_menu:
		return
		
	pause_menu.visible = !pause_menu.visible
	
	get_tree().paused = pause_menu.visible
