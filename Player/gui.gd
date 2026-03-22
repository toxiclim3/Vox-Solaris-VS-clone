extends Control

var titleMenu = "res://TitleScreen/menu.tscn"

@onready var settings_menu = get_node("SettingsMenu")
@onready var pause_menu = get_node("PauseMenu")
@onready var debug_menu = get_node("DebugMenu")

@export var transition_duration: float = 0.4
@export var gap: float = 0.5 * 8 * 8 # Расстояние между окнами

var pause_idle_x: float # Позиция паузы, когда она одна в центре
var settings_idle_x: float # Позиция настроек, когда они открыты

signal openMenu()
signal closeMenu()

# Запоминаем изначальный центр для возврата
var pause_original_x: float

func _ready() -> void:
	# Запоминаем, где меню паузы стоит по умолчанию
	pause_original_x = pause_menu.position.x
	
	# Прячем настройки за правый край экрана
	var screen_width: float = get_viewport_rect().size.x
	settings_menu.position.x = screen_width + gap
	settings_menu.hide()

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	
	if event.is_action("debugMenu"):
		if debug_menu:
			if event.is_pressed():
				openMenu.emit()
			
			if event.is_released():
				closeMenu.emit()
		get_viewport().set_input_as_handled()
		
		
	if event.is_action_pressed("menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()


func toggle_menu():
	if pause_menu:
		pause_menu.visible = !pause_menu.visible
		get_tree().paused = pause_menu.visible
		MusicController.focusMusic(!pause_menu.visible)


func open_settings() -> void:
	settings_menu.show()
	
	var screen_width: float = get_viewport_rect().size.x
	var screen_center_x: float = screen_width / 2.0
	
	# 1. Считаем габариты всего визуального блока
	var total_width: float = pause_menu.size.x + gap + settings_menu.size.x
	
	# 2. Находим координату X, откуда этот блок должен начинаться, чтобы быть в центре
	var group_start_x: float = screen_center_x - (total_width / 2.0)
	
	# 3. Распределяем позиции
	var pause_target_x: float = group_start_x
	var settings_target_x: float = group_start_x + pause_menu.size.x + gap
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(pause_menu, "position:x", pause_target_x, transition_duration)
	tween.tween_property(settings_menu, "position:x", settings_target_x, transition_duration)

func close_settings() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Возвращаем меню паузы на его законное место слева
	tween.tween_property(pause_menu, "position:x", pause_original_x, transition_duration)
	
	# Настройки снова улетают вправо за экран
	var screen_width: float = get_viewport_rect().size.x
	tween.tween_property(settings_menu, "position:x", screen_width + gap, transition_duration)
	
	tween.chain().tween_callback(settings_menu.hide)
	
#death menu buttons
func _on_btn_menu_click_end() -> void:
	get_tree().paused = false
	var _level = get_tree().change_scene_to_file(titleMenu)

func _on_btn_restart_click_end() -> void:
	GlobalEvents.restart_run()

#pause menu buttons
func _on_btn_exit_game_click_end() -> void:
	get_tree().quit()

func _on_btn_end_run_click_end() -> void:
	var _level = get_tree().change_scene_to_file(titleMenu)

func _on_btn_resume_run_click_end() -> void:
	toggle_menu()

func _on_btn_settings_click_end() -> void:
	if settings_menu.visible:
		close_settings()
	else:
		open_settings()

func _on_settings_menu_settings_closed() -> void:
	close_settings()
