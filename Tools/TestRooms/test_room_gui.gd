class_name TestRoomGui
extends Control

var levelPanel: Control
var bossLevelPanel: Control
var deathPanel: Control
var collectedWeapons: Node
var collectedUpgrades: Node
var collectedBossItems: Node

func _init() -> void:
	name = "MockGui"
	add_to_group("gui")
	add_to_group("gui_layer")

	levelPanel = Control.new()
	bossLevelPanel = Control.new()
	deathPanel = Control.new()
	levelPanel.visible = false
	bossLevelPanel.visible = false
	deathPanel.visible = false

	collectedWeapons = HBoxContainer.new()
	collectedUpgrades = HBoxContainer.new()
	collectedBossItems = HBoxContainer.new()

	add_child(levelPanel)
	add_child(bossLevelPanel)
	add_child(deathPanel)
	add_child(collectedWeapons)
	add_child(collectedUpgrades)
	add_child(collectedBossItems)

func set_expbar(_cur_exp: float, _exp_cap: float) -> void:
	pass

func set_level_text(_lvl: int) -> void:
	pass

func update_timer(_t: int) -> void:
	pass

func hide_level_panels() -> void:
	pass

func show_levelup(_options_list: Array, _current_visual_level: int = 1) -> void:
	pass

func show_boss_levelup(_options_list: Array) -> void:
	pass

func adjust_gui_collection(_uid: String) -> void:
	pass

func refresh_gui_collection() -> void:
	pass

func show_death_panel(_has_won: bool) -> void:
	pass
