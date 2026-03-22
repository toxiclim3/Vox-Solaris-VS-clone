extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalEvents.time = 0
	MusicController.resetPlaylists()
	MusicController.setLooping(true)
	MusicController.fadeInFromSilence()
	MusicController.playNext(MusicController.MusicType.NORMAL)
