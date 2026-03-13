extends Control

@export var pause_menu: Control
@export var debug_menu: Control
@export var anim_player: AnimationPlayer

var titleMenu = "res://TitleScreen/menu.tscn"

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	
	if event.is_action("debugMenu"):
		if debug_menu:
			if event.is_pressed():
				anim_player.play("show")
			
			if event.is_released():
				anim_player.play("hide")
		get_viewport().set_input_as_handled()
		
		
	if event.is_action_pressed("menu"):
		if pause_menu:
			pause_menu.visible = !pause_menu.visible
			get_tree().paused = pause_menu.visible
			MusicController.focusMusic(!pause_menu.visible)
		get_viewport().set_input_as_handled()

#death menu buttons
func _on_btn_menu_click_end() -> void:
	get_tree().paused = false
	var _level = get_tree().change_scene_to_file(titleMenu)

func _on_btn_restart_click_end() -> void:
	GlobalEvents.restart_run()

#pause menu buttons
func _on_btn_exit_game_click_end() -> void:
	get_tree().quit()

func _on_btn_end_run_click_end() -> void:
	var _level = get_tree().change_scene_to_file(titleMenu)
