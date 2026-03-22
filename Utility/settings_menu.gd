extends PanelContainer

signal settings_closed
# Called when the node enters the scene tree for the first time.

func _on_close_settings_button_pressed() -> void:
	settings_closed.emit()
