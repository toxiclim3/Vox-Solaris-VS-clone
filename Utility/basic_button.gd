extends Button

signal click_end()

@export var padding: int = 8
var original_font_size: int = -1

func _ready() -> void:
	if has_theme_font_size_override("font_size"):
		original_font_size = get_theme_font_size("font_size")
	else:
		var current_theme = theme
		if current_theme:
			original_font_size = current_theme.get_font_size("font_size", "Button")
		if original_font_size <= 0:
			original_font_size = 16
			
	scale_text_to_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		scale_text_to_fit()

func scale_text_to_fit():
	if original_font_size <= 0:
		return
		
	var font = get_theme_font("font")
	if not font: return
	
	var text_to_check = tr(text)
	var available_width = size.x - padding
	
	var current_size = original_font_size
	var text_size = font.get_string_size(text_to_check, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)
	
	while text_size.x > available_width and current_size > 8:
		current_size -= 1
		text_size = font.get_string_size(text_to_check, HORIZONTAL_ALIGNMENT_LEFT, -1, current_size)
		
	add_theme_font_size_override("font_size", current_size)

func _on_mouse_entered():
	$snd_hover.play()
	
func _on_pressed():
	$snd_click.play()

func _on_snd_click_finished():
	emit_signal("click_end")
