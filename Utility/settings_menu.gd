extends PanelContainer

signal settings_closed

@onready var profile_button = %ProfileButton

func _ready() -> void:
	if profile_button:
		profile_button.add_item("Full")
		profile_button.add_item("Grindfest")
		profile_button.select(SettingsManager.get_sound_profile_index())
		profile_button.item_selected.connect(_on_profile_selected)

func _on_close_settings_button_pressed() -> void:
	settings_closed.emit()

func _on_profile_selected(index: int) -> void:
	var profiles = ["Full", "Grindfest"]
	SettingsManager.set_sound_profile(profiles[index])
