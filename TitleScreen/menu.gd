extends Control

var level = "res://World/world.tscn"
@onready var settings_menu = %SettingsMenu
@onready var stats_menu = %StatsMenu
@onready var custom_menu = %CustomDifficultyMenu
@onready var main_menu_content = %MarginContainer
@onready var title_label = get_node("Label")
@onready var btn_difficulty = main_menu_content.get_node("VBoxContainer/btn_difficulty")
@onready var btn_custom_difficulty = main_menu_content.get_node("VBoxContainer/btn_custom_difficulty")

@export var transition_duration: float = 0.4
@export var gap: float = 0.5 * 8 * 8

var main_menu_original_x: float
var is_settings_open: bool = false
var is_stats_open: bool = false
var is_custom_diff_open: bool = false

func _ready():
	get_tree().paused = false
	MusicController.setLooping(false)
	MusicController.playSpecificTrack(MusicController.titleMusic)
	
	# Initial positions
	main_menu_original_x = main_menu_content.position.x
	
	var viewport_size = get_viewport_rect().size
	
	# Hide menus at top
	settings_menu.position.y = -viewport_size.y
	settings_menu.hide()
	stats_menu.position.y = -viewport_size.y
	stats_menu.hide()
	custom_menu.position.y = -viewport_size.y
	custom_menu.hide()
	
	# Intro animation: slide in from top
	var original_title_y = title_label.position.y
	var original_buttons_y = main_menu_content.position.y
	
	# Start above screen
	title_label.position.y = -100
	main_menu_content.position.y = -100
	
	var intro_tween = create_tween().set_parallel(true)
	intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(title_label, "position:y", original_title_y, 0.8)
	intro_tween.tween_property(main_menu_content, "position:y", original_buttons_y, 1.0)
	intro_tween.set_parallel(false)
	intro_tween.tween_callback(func():
		# Refresh original X after intro to be safe
		main_menu_original_x = main_menu_content.position.x
	)

func _on_btn_play_click_end():
	MusicController.fadeOutToSilence()
	var _level = get_tree().change_scene_to_file(level)

func _on_btn_exit_click_end():
	get_tree().quit()

func _on_btn_settings_click_end() -> void:
	toggle_settings()

func _on_btn_stats_click_end() -> void:
	toggle_stats()

func _on_settings_menu_settings_closed() -> void:
	toggle_settings()

func _on_stats_menu_stats_closed() -> void:
	toggle_stats()

func _on_btn_difficulty_click_end() -> void:
	GlobalEvents.next_difficulty()
	btn_difficulty.text = GlobalEvents.get_difficulty_name()
	if GlobalEvents.current_difficulty == GlobalEvents.Difficulty.CUSTOM:
		btn_custom_difficulty.show()
	else:
		btn_custom_difficulty.hide()
		if is_custom_diff_open:
			toggle_custom_diff()

func _on_btn_custom_difficulty_click_end() -> void:
	toggle_custom_diff()

func _on_custom_difficulty_menu_closed() -> void:
	toggle_custom_diff()

func toggle_settings():
	if is_stats_open:
		close_stats()
		is_stats_open = false
	if is_custom_diff_open:
		close_custom_diff()
		is_custom_diff_open = false
	is_settings_open = !is_settings_open
	if is_settings_open:
		open_settings()
	else:
		close_settings()

func toggle_stats():
	if is_settings_open:
		close_settings()
		is_settings_open = false
	if is_custom_diff_open:
		close_custom_diff()
		is_custom_diff_open = false
	is_stats_open = !is_stats_open
	if is_stats_open:
		open_stats()
	else:
		close_stats()

func toggle_custom_diff():
	if is_settings_open:
		close_settings()
		is_settings_open = false
	if is_stats_open:
		close_stats()
		is_stats_open = false
	is_custom_diff_open = !is_custom_diff_open
	if is_custom_diff_open:
		open_custom_diff()
	else:
		close_custom_diff()

func open_settings() -> void:
	settings_menu.show()
	
	var screen_size = get_viewport_rect().size
	var screen_center_x: float = screen_size.x / 2.0
	var screen_center_y: float = screen_size.y / 2.0
	
	# Centering logic (identical to Player/gui.gd)
	var total_width: float = main_menu_content.size.x + gap + settings_menu.size.x
	var group_start_x: float = screen_center_x - (total_width / 2.0)
	
	var main_target_x: float = group_start_x
	var settings_target_x: float = group_start_x + main_menu_content.size.x + gap
	var bottom_y: float = main_menu_content.position.y + main_menu_content.size.y - 32.0
	var settings_target_y: float = bottom_y - settings_menu.size.y
	
	# Initialize settings position for the slide if it's the first time or if it was closed
	# We want it to slide from the TOP every time
	settings_menu.position.x = settings_target_x
	settings_menu.position.y = -settings_menu.size.y - 10
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(main_menu_content, "position:x", main_target_x, transition_duration)
	tween.tween_property(settings_menu, "position:y", settings_target_y, transition_duration)

func close_settings() -> void:
	var viewport_size = get_viewport_rect().size
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(main_menu_content, "position:x", main_menu_original_x, transition_duration)
	# Slide back to top
	tween.tween_property(settings_menu, "position:y", -settings_menu.size.y - 50, transition_duration)
	
	tween.chain().tween_callback(settings_menu.hide)

func open_stats() -> void:
	stats_menu.update_stats()
	stats_menu.show()
	
	var screen_size = get_viewport_rect().size
	var screen_center_x: float = screen_size.x / 2.0
	var screen_center_y: float = screen_size.y / 2.0
	
	var total_width: float = main_menu_content.size.x + gap + stats_menu.size.x
	var group_start_x: float = screen_center_x - (total_width / 2.0)
	
	var main_target_x: float = group_start_x
	var stats_target_x: float = group_start_x + main_menu_content.size.x + gap
	var bottom_y: float = main_menu_content.position.y + main_menu_content.size.y - 32.0
	var stats_target_y: float = bottom_y - stats_menu.size.y
	
	stats_menu.position.x = stats_target_x
	stats_menu.position.y = -stats_menu.size.y - 10
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(main_menu_content, "position:x", main_target_x, transition_duration)
	tween.tween_property(stats_menu, "position:y", stats_target_y, transition_duration)

func close_stats() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(main_menu_content, "position:x", main_menu_original_x, transition_duration)
	tween.tween_property(stats_menu, "position:y", -stats_menu.size.y - 50, transition_duration)
	
	tween.chain().tween_callback(stats_menu.hide)

func _on_btn_how_to_play_click_end() -> void:
	MusicController.playSpecificTrack(MusicController.tutorialMusic,0)

func open_custom_diff() -> void:
	custom_menu.show()
	
	var screen_size = get_viewport_rect().size
	var screen_center_x: float = screen_size.x / 2.0
	
	var total_width: float = main_menu_content.size.x + gap + custom_menu.size.x
	var group_start_x: float = screen_center_x - (total_width / 2.0)
	
	var main_target_x: float = group_start_x
	var custom_target_x: float = group_start_x + main_menu_content.size.x + gap
	var bottom_y: float = main_menu_content.position.y + main_menu_content.size.y - 32.0
	var custom_target_y: float = bottom_y - custom_menu.size.y
	
	custom_menu.position.x = screen_size.x + custom_menu.size.x + 50
	custom_menu.position.y = custom_target_y
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(main_menu_content, "position:x", main_target_x, transition_duration)
	tween.tween_property(custom_menu, "position:x", custom_target_x, transition_duration)

func close_custom_diff() -> void:
	var viewport_size = get_viewport_rect().size
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(main_menu_content, "position:x", main_menu_original_x, transition_duration)
	tween.tween_property(custom_menu, "position:x", viewport_size.x + custom_menu.size.x + 50, transition_duration)
	
	tween.chain().tween_callback(custom_menu.hide)
