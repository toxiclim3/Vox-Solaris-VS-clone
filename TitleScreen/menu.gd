extends Control

var level = "res://World/world.tscn"
@onready var settings = %SettingsMenu


func _ready():
	get_tree().paused = false
	MusicController.setLooping(false)
	MusicController.playSpecificTrack(MusicController.titleMusic)

func _on_btn_play_click_end():
	MusicController.fadeOutToSilence()
	var _level = get_tree().change_scene_to_file(level)

func _on_btn_exit_click_end():
	get_tree().quit()

func _on_btn_settings_click_end() -> void:
	settings.visible = !settings.visible

func _on_settings_menu_settings_closed() -> void:
	settings.visible = !settings.visible


func _on_btn_how_to_play_click_end() -> void:
	MusicController.playSpecificTrack(MusicController.tutorialMusic,0)
