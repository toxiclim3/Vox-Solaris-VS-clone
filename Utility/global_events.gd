extends Node

signal advanceBackground
signal enableSpawns
signal disableSpawns

@export var musicInterval = 5
@export var bossMusicInterval = 5 * 60 #Minutes		

@export var time = 0

func restart_run() -> void:
	MusicController.fadeOutToSilence()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()
	
