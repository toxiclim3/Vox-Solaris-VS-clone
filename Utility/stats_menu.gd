extends PanelContainer

signal stats_closed

@onready var lbl_enemy_kills = %lbl_enemy_kills
@onready var lbl_boss_kills = %lbl_boss_kills
@onready var lbl_total_kills = %lbl_total_kills
@onready var lbl_total_deaths = %lbl_total_deaths
@onready var lbl_total_wins = %lbl_total_wins
@onready var lbl_win_ratio = %lbl_win_ratio
@onready var lbl_best_level = %lbl_best_level
@onready var lbl_best_time = %lbl_best_time

func _ready() -> void:
	update_stats()

func update_stats() -> void:
	lbl_enemy_kills.text = str(StatsManager.enemy_kills)
	lbl_boss_kills.text = str(StatsManager.boss_kills)
	lbl_total_kills.text = str(StatsManager.get_total_kills())
	lbl_total_deaths.text = str(StatsManager.total_deaths)
	lbl_total_wins.text = str(StatsManager.total_wins)
	lbl_win_ratio.text = "%.1f%%" % StatsManager.get_win_ratio()
	lbl_best_level.text = str(StatsManager.best_run_level)
	
	var time = StatsManager.best_run_time
	var m = int(time / 60.0)
	var s = time % 60
	lbl_best_time.text = "%02d:%02d" % [m, s]

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
	   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
	   event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		if get_viewport().gui_get_focus_owner() == null:
			grab_initial_focus()
			get_viewport().set_input_as_handled()

func _on_close_stats_button_pressed() -> void:
	stats_closed.emit()

func grab_initial_focus() -> void:
	%CloseStatsButton.grab_focus()
