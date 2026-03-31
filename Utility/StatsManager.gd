extends Node

const SAVE_PATH = "user://statistics.cfg"
var config = ConfigFile.new()

var enemy_kills: int = 0
var boss_kills: int = 0
var total_deaths: int = 0
var total_wins: int = 0
var best_run_level: int = 0
var best_run_time: int = 0

func _ready() -> void:
	load_stats()

func load_stats() -> void:
	var error = config.load(SAVE_PATH)
	if error != OK:
		return
	
	enemy_kills = config.get_value("stats", "enemy_kills", 0)
	boss_kills = config.get_value("stats", "boss_kills", 0)
	total_deaths = config.get_value("stats", "total_deaths", 0)
	total_wins = config.get_value("stats", "total_wins", 0)
	best_run_level = config.get_value("stats", "best_run_level", 0)
	best_run_time = config.get_value("stats", "best_run_time", 0)

func save_stats() -> void:
	config.set_value("stats", "enemy_kills", enemy_kills)
	config.set_value("stats", "boss_kills", boss_kills)
	config.set_value("stats", "total_deaths", total_deaths)
	config.set_value("stats", "total_wins", total_wins)
	config.set_value("stats", "best_run_level", best_run_level)
	config.set_value("stats", "best_run_time", best_run_time)
	config.save(SAVE_PATH)

func register_kill(is_boss: bool) -> void:
	if is_boss:
		boss_kills += 1
	else:
		enemy_kills += 1
	save_stats()

func register_end_run(won: bool) -> void:
	if won:
		total_wins += 1
	else:
		total_deaths += 1
	save_stats()

func update_best_run(level: int, time: int) -> void:
	var updated = false
	if level > best_run_level:
		best_run_level = level
		updated = true
	if time > best_run_time:
		best_run_time = time
		updated = true
	
	if updated:
		save_stats()

func get_total_kills() -> int:
	return enemy_kills + boss_kills

func get_win_ratio() -> float:
	var total_games = total_wins + total_deaths
	if total_games == 0:
		return 0.0
	return (float(total_wins) / float(total_games)) * 100.0

func reset_stats() -> void:
	enemy_kills = 0
	boss_kills = 0
	total_deaths = 0
	total_wins = 0
	best_run_level = 0
	best_run_time = 0
	save_stats()
