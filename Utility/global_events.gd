extends Node

@warning_ignore_start("unused_signal")
signal advanceBackground
signal enableSpawns
signal disableSpawns
signal boss_defeated
signal boss_spawned(boss: EnemyBody)
signal show_boss_warning(warning_text_key: String)
signal queue_boss
@warning_ignore_restore("unused_signal")

var boss_warnings: Dictionary = {
	"generic": "warning_boss_generic",
	"res://Enemy/enemy_super.tscn": "warning_boss_super"
}

var boss_names: Dictionary = {
	"res://Enemy/enemy_super.tscn": "boss_name_super"
}

@export var backgroundInterval = 5
@export var musicInterval = 10
@export var bossInterval = 5 * 60 #minutes

@export var time = 0

@export var playerItem = 1

func restart_run() -> void:
	MusicController.fadeOutToSilence()
	MusicController.unlockMusic()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()
	
