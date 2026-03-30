extends Node

signal advanceBackground
signal enableSpawns
signal disableSpawns
signal boss_defeated
signal show_boss_warning(warning_text_key: String)

var boss_warnings: Dictionary = {
	"res://Enemy/enemy_super.tscn": "warning_boss_super"
}

@export var backgroundInterval = 5
@export var musicInterval = 10
@export var bossInterval = 5 * 60 #minutes

@export var time = 0

@export var playerItem = 0

func restart_run() -> void:
	MusicController.fadeOutToSilence()
	MusicController.unlockMusic()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()
	
