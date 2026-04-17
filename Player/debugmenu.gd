# Повесить на MarginContainer (SlidingMenu)
extends MarginContainer

class_name SlidingMenu

var smallGridSize = 8;
var largeGridSize = 8;

@export var slide_duration: float = 0.5
@export var menu_width: float = 3.5 # Ширина твоего меню

var is_open: bool = false

func _ready() -> void:
	menu_width = self.get_rect().size.x
	
	# Initial state: hidden 8px off-screen
	_set_menu_margin(menu_width + smallGridSize)
	self.visible = false
	
	get_viewport().size_changed.connect(_on_window_resized)

# Функция для переключения состояния меню
func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Animate from hidden (+8px) to flush (0px)
	tween.tween_method(_set_menu_margin, menu_width + smallGridSize, 0.0, slide_duration)
	is_open = true	
	self.visible = is_open

func close_menu() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Animate from flush (0px) to hidden (+8px)
	tween.tween_method(_set_menu_margin, 0.0, menu_width + smallGridSize, slide_duration)
	is_open = false
	await tween.finished
	self.visible = is_open

# Вспомогательный метод для Tween, так как мы меняем theme_override
func _set_menu_margin(value: float) -> void:
	add_theme_constant_override("margin_left", int(value))
	add_theme_constant_override("margin_right", int(-value))
	# Force zero on top/bottom to prevent theme interference
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 0)


func _on_window_resized() -> void:
	# Wait a frame for Godot to update its rects based on new window size
	await get_tree().process_frame
	menu_width = self.get_rect().size.x
	
	if is_open:
		_set_menu_margin(0)
	else:
		_set_menu_margin(menu_width + smallGridSize)


func _on_gui_open_menu() -> void:
	open_menu()

func _on_gui_close_menu() -> void:
	close_menu()
