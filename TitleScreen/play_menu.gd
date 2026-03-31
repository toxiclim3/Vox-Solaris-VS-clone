extends PanelContainer

signal play_menu_closed
signal start_run_requested
signal edit_custom_requested

@onready var btn_difficulty = %btn_difficulty
@onready var btn_custom_difficulty = %btn_custom_difficulty

func _ready():
	_update_difficulty_buttons()

func _update_difficulty_buttons() -> void:
	if btn_difficulty:
		btn_difficulty.text = GlobalEvents.get_difficulty_name()
	if btn_custom_difficulty:
		if GlobalEvents.current_difficulty == GlobalEvents.Difficulty.CUSTOM:
			btn_custom_difficulty.show()
		else:
			btn_custom_difficulty.hide()

func update_menu_state() -> void:
	_update_difficulty_buttons()

func _on_close_play_menu_button_pressed() -> void:
	emit_signal("play_menu_closed")

func _on_btn_difficulty_click_end() -> void:
	GlobalEvents.next_difficulty()
	_update_difficulty_buttons()

func _on_btn_custom_difficulty_click_end() -> void:
	emit_signal("edit_custom_requested")

func _on_btn_start_run_click_end() -> void:
	emit_signal("start_run_requested")
