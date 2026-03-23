extends Node

signal advanceBackground
signal enableSpawns
signal disableSpawns
signal boss_defeated

@export var backgroundInterval = 5
@export var musicInterval = 10
@export var bossMusicInterval = 5 * 60 #Minutes		

@export var time = 0

func restart_run() -> void:
	MusicController.fadeOutToSilence()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()
	
