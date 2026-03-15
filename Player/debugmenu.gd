# Повесить на MarginContainer (SlidingMenu)
extends MarginContainer

class_name SlidingMenu

var smallGridSize = 8;
var largeGridSize = 8;

@export var slide_duration: float = 0.5
@export var menu_width: float = 3.5 # Ширина твоего меню

var is_open: bool = false

func _ready() -> void:
	# 1. Задаем фиксированную ширину меню
	menu_width *= largeGridSize * smallGridSize
	custom_minimum_size.x = menu_width
	
	# 2. Прячем меню при старте (сдвигаем влево за край экрана)
	# Мы используем отрицательный margin_left, равный ширине меню
	add_theme_constant_override("margin_left", menu_width+smallGridSize)
	add_theme_constant_override("margin_right", -menu_width-smallGridSize)

# Функция для переключения состояния меню
func toggle_menu() -> void:
	if is_open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Анимируем отступ к 0 (край экрана)
	tween.tween_method(_set_menu_margin, menu_width+smallGridSize, 0.0, slide_duration)
	is_open = true	
	self.visible = is_open

func close_menu() -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Анимируем отступ обратно за экран
	tween.tween_method(_set_menu_margin, 0.0, menu_width+smallGridSize, slide_duration)
	is_open = false
	await tween.finished
	self.visible = is_open

# Вспомогательный метод для Tween, так как мы меняем theme_override
func _set_menu_margin(value: float) -> void:
	add_theme_constant_override("margin_left", value)
	add_theme_constant_override("margin_right", -value)


func _on_gui_open_menu() -> void:
	open_menu()

func _on_gui_close_menu() -> void:
	close_menu()
