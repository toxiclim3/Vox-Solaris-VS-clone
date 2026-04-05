extends Node

@warning_ignore_start("unused_signal")
signal advanceBackground
signal enableSpawns
signal disableSpawns
signal boss_defeated
signal boss_spawned(boss: EnemyBody)
signal show_boss_warning(warning_text_key: String)
signal queue_boss
signal camera_shake(intensity: float)
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

enum Difficulty { EASY, NORMAL, HARD, CUSTOM }
var current_difficulty: Difficulty = Difficulty.NORMAL

# Custom Difficulty Modifiers
var custom_enemy_spawn_modifier: float = 1.0
var custom_enemy_hp_modifier: float = 1.0
var custom_boss_hp_modifier: float = 1.0
var custom_player_regen_modifier: float = 1.0
var custom_player_damage_modifier: float = 1.0
var custom_xp_gain_modifier: float = 1.0

func set_difficulty(diff: Difficulty) -> void:
	current_difficulty = diff

func next_difficulty() -> void:
	match current_difficulty:
		Difficulty.EASY:
			current_difficulty = Difficulty.NORMAL
		Difficulty.NORMAL:
			current_difficulty = Difficulty.HARD
		Difficulty.HARD:
			current_difficulty = Difficulty.CUSTOM
		Difficulty.CUSTOM:
			current_difficulty = Difficulty.EASY

func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.EASY: return "ui_difficulty_easy"
		Difficulty.NORMAL: return "ui_difficulty_normal"
		Difficulty.HARD: return "ui_difficulty_hard"
		Difficulty.CUSTOM: return "ui_difficulty_custom"
	return "ui_difficulty_normal"

func get_enemy_spawn_modifier() -> float:
	match current_difficulty:
		Difficulty.EASY: return 0.8
		Difficulty.HARD: return 1.2
		Difficulty.CUSTOM: return custom_enemy_spawn_modifier
	return 1.0

func get_enemy_hp_modifier() -> float:
	match current_difficulty:
		Difficulty.EASY: return 0.8
		Difficulty.HARD: return 1.2
		Difficulty.CUSTOM: return custom_enemy_hp_modifier
	return 1.0
	
func get_boss_hp_modifier() -> float:
	match current_difficulty:
		Difficulty.EASY: return 0.8
		Difficulty.HARD: return 1.2
		Difficulty.CUSTOM: return custom_boss_hp_modifier
	return 1.0
	
func get_player_regen_modifier() -> float:
	match current_difficulty:
		Difficulty.EASY: return 1.5
		Difficulty.HARD: return 1.0
		Difficulty.CUSTOM: return custom_player_regen_modifier
	return 1.0

func get_player_damage_modifier() -> float:
	match current_difficulty:
		Difficulty.CUSTOM: return custom_player_damage_modifier
	return 1.0
	
func get_xp_gain_modifier() -> float:
	match current_difficulty:
		Difficulty.EASY: return 1.2
		Difficulty.HARD: return 0.8
		Difficulty.CUSTOM: return custom_xp_gain_modifier
	return 1.0

func restart_run() -> void:
	MusicController.fadeOutToSilence()
	MusicController.unlockMusic()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()
	
