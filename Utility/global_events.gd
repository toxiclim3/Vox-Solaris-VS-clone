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
signal weapon_damage_dealt(source: String, amount: float, target_node: Object)
signal movement_config_changed()
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
		"mobility_type": "sidestep",
		"details": "char_mage_desc",
		"base_stats": {},
		"scaling_stats": {"spell_cooldown": 0.15}, # Goal: +15% CDR
		"scaling_max_level": 20
	},
	"plague_doctor": {
		"displayname": "char_plague_doctor",
		"icon": "res://Textures/Player/player_sprite.png",
		"icon_color": Color(0.3, 0.9, 0.3),
		"starting_weapon": "poisonbottle1",
		"mobility_type": "forward_dash",
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
		"mobility_type": "rock_stance",
		"details": "char_occultist_desc",
		"base_stats": {},
		"scaling_stats": {"lifesteal": 0.02}, # Goal: 2% Damage Lifesteal
		"scaling_max_level": 20
	},
	"punished": {
		"displayname": "char_punished",
		"icon": "res://Textures/Player/player_sprite.png",
		"icon_color": Color(0.2, 0.2, 0.2), # Dark grey
		"starting_weapon": "whip1",
		"mobility_type": "rock_stance",
		"details": "char_punished_desc",
		"base_stats": {"armor": 3, "maxhp": 100},
		"scaling_stats": {"reflected_damage": 40},
		"scaling_max_level": 20,
		"shader_config": {"mix_hue": true, "mix_saturation": true}
	}
}

const DEFAULT_MOVEMENT_CONFIG: Dictionary = {
	"movement_coupled_enabled": true,
	"base_movement_speed": 85.0,
	"bastion_in_time": 0.45,
	"bastion_out_time": 0.20,
	"cooldown_floor": 0.05,
	"sidestep_distance": 84.0,
	"sidestep_duration": 0.12,
	"sidestep_cooldown": 2.5,
	"forward_dash_distance": 140.0,
	"forward_dash_duration": 0.14,
	"forward_dash_cooldown": 3.5,
	"impulse_prime_duration": 1.5,
	"rock_stance_armor_bonus": 4,
	"rock_stance_burst_duration": 1.35,
	"rock_stance_burst_cd_mult": 0.70,
	"rock_stance_icd": 4.0,
	"vector_advance_dot": 0.3,
	"vector_retreat_dot": -0.3,
	"stride_efficiency_per_speed_tier": 0.05,
	"stride_threshold_reduction_per_scroll_tier": 0.05,
}

var MOVEMENT_CONFIG: Dictionary = DEFAULT_MOVEMENT_CONFIG.duplicate(true)

func is_movement_coupled() -> bool:
	return bool(MOVEMENT_CONFIG.get("movement_coupled_enabled", true))

func set_movement_coupled(enabled: bool) -> void:
	if is_movement_coupled() == enabled:
		return
	MOVEMENT_CONFIG["movement_coupled_enabled"] = enabled
	movement_config_changed.emit()

func set_movement_config_value(key: String, value: Variant) -> void:
	MOVEMENT_CONFIG[key] = value
	movement_config_changed.emit()

func reset_movement_config() -> void:
	MOVEMENT_CONFIG = DEFAULT_MOVEMENT_CONFIG.duplicate(true)
	movement_config_changed.emit()

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
	Engine.time_scale = 1.0
	StatsManager.clear_run_taint()
	MusicController.fadeOutToSilence()
	MusicController.unlockMusic()
	MusicController.resetPlaylists()
	get_tree().change_scene_to_file("res://World/world.tscn")
	MusicController.fadeInFromSilence()

func infer_attack_source(atk_node: Node) -> String:
	if atk_node == null or not is_instance_valid(atk_node):
		return "unknown"
	var ks = atk_node.get("killer_source")
	if ks != null and str(ks) != "":
		return normalize_damage_source(str(ks))
	if atk_node.owner != null and is_instance_valid(atk_node.owner):
		var owner_ks = atk_node.owner.get("killer_source")
		if owner_ks != null and str(owner_ks) != "":
			return normalize_damage_source(str(owner_ks))
	var parent := atk_node.get_parent()
	if parent != null and is_instance_valid(parent):
		var parent_ks = parent.get("killer_source")
		if parent_ks != null and str(parent_ks) != "":
			return normalize_damage_source(str(parent_ks))
	for candidate in [atk_node, parent, atk_node.owner]:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var paths: Array[String] = []
		if candidate.scene_file_path != "":
			paths.append(candidate.scene_file_path)
		var scr: Variant = candidate.get_script()
		if scr != null and scr is Script and scr.resource_path != "":
			paths.append(scr.resource_path)
		for p in paths:
			var idx := p.find("/Attack/")
			if idx != -1:
				var sub := p.substr(idx + 8)
				var slash := sub.find("/")
				if slash != -1:
					return normalize_damage_source(sub.substr(0, slash))
	if parent != null and atk_node.name in ["Area2D", "DamageBox", "HitBox"]:
		return normalize_damage_source(str(parent.name))
	return normalize_damage_source(str(atk_node.name))

func normalize_damage_source(raw_source: String) -> String:
	var s := raw_source.strip_edges().to_lower()
	if s == "":
		return "unknown"
	match s:
		"vampireknife": return "vampireknives"
		"glassshard": return "glasslash"
		"thorn ring", "thorn_ring": return "thornring"
		"relicrocket", "relic_rocket": return "relicdrone"
		"poison_gas", "poisongas": return "poisonbottle"
		"willowisp_explosion": return "willowisp"
		"impact_buckler_shockwave": return "impact_buckler"
	return s

func record_weapon_damage(source: String, amount: float, target_node: Object = null) -> void:
	if amount <= 0.0:
		return
	weapon_damage_dealt.emit(normalize_damage_source(source), amount, target_node)
	


# XP magnet orb: drop chance scales with loot on the ground, up to MAGNET_MAX_CHANCE
const MAGNET_MAX_CHANCE := 0.01
const MAGNET_FULL_CHANCE_GEMS := 200

## Roll once per dropped gem. Returns true if a magnet orb should drop too.
func roll_magnet_drop() -> bool:
	var gems_on_ground := get_tree().get_node_count_in_group("loot")
	var chance := MAGNET_MAX_CHANCE * clampf(float(gems_on_ground) / MAGNET_FULL_CHANCE_GEMS, 0.0, 1.0)
	return randf() < chance
