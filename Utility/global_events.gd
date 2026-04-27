extends Node

@warning_ignore_start("unused_signal")
signal advanceBackground
signal enableSpawns
signal disableSpawns
signal boss_defeated
signal boss_spawned(boss: EnemyBody)
signal show_boss_warning(warning_text_key: String)
signal queue_boss(boss_path: String)
signal camera_shake(intensity: float, duration: float)
signal enemy_died(death_position: Vector2, enemy_max_hp: float, killer_source: String)
signal player_took_damage(amount: float, attacker_node: Node)
signal player_dealt_damage(amount: float, target_node: Object, proc_coefficient: float)
@warning_ignore_restore("unused_signal")

var boss_warnings: Dictionary = {
	"generic": "warning_boss_generic",
	"res://Enemy/Boss/enemy_super.tscn": "warning_boss_super",
	"res://Enemy/Boss/dr_franklin.tscn": "warning_boss_franklin"
}

var boss_names: Dictionary = {
	"res://Enemy/Boss/enemy_super.tscn": "boss_name_super",
	"res://Enemy/Boss/dr_franklin.tscn": "boss_name_franklin"
}

@export var backgroundInterval = 5
@export var musicInterval = 10
@export var bossInterval = 5 * 60 #minutes

@export var time = 0

const CHARACTERS: Dictionary = {
	"mage": {
		"displayname": "char_mage",
		"icon": "res://Textures/Player/player_sprite.png",
		"icon_color": Color(1.0, 1.0, 1.0),
		"starting_weapon": "icespear1",
		"details": "char_mage_desc",
		"base_stats": {},
		"scaling_stats": {"spell_cooldown": -0.15}, # Goal: -15% CDR
		"scaling_max_level": 20
	},
	"plague_doctor": {
		"displayname": "char_plague_doctor",
		"icon": "res://Textures/Player/player_sprite.png",
		"icon_color": Color(0.3, 0.9, 0.3),
		"starting_weapon": "poisonbottle1",
		"details": "char_plague_doctor_desc",
		"base_stats": {},
		"scaling_stats": {"spell_size": 0.50}, # Goal: +50% Size
		"scaling_max_level": 20
	},
	"occultist": {
		"displayname": "char_occultist",
		"icon": "res://Textures/Player/player_sprite.png",
		"icon_color": Color(0.7, 0.3, 0.9),
		"starting_weapon": "ritualcircle1",
		"details": "char_occultist_desc",
		"base_stats": {},
		"scaling_stats": {"lifesteal": 0.02}, # Goal: 2% Damage Lifesteal
		"scaling_max_level": 20
	},
	"punished": {
		"displayname": "char_punished",
		"icon": "res://Textures/Player/player_sprite.png",
		"icon_color": Color(0.2, 0.2, 0.2), # Dark grey
		"starting_weapon": "",
		"details": "char_punished_desc",
		"base_stats": {},
		"scaling_stats": {},
		"scaling_max_level": 20,
		"shader_config": {"mix_hue": true, "mix_saturation": true}
	}
}

var selected_character: String = "mage"

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

func get_max_weapon_slots() -> int:
	match current_difficulty:
		Difficulty.HARD: return 5
	return 6

func get_max_upgrade_slots() -> int:
	match current_difficulty:
		Difficulty.HARD: return 6
	return 8


func restart_run() -> void:
	MusicController.fadeOutToSilence()
	MusicController.unlockMusic()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()
	
