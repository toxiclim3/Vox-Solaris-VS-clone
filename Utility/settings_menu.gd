extends PanelContainer

signal settings_closed

@onready var profile_button = %ProfileButton
@onready var language_button = %LanguageButton

func _ready() -> void:
	if profile_button:
		profile_button.add_item("Full")
		profile_button.add_item("Grindfest")
		profile_button.select(SettingsManager.get_sound_profile_index())
		profile_button.item_selected.connect(_on_profile_selected)
		
	if language_button:
		language_button.add_item("English")
		language_button.add_item("Русский")
		var lang_index = 0
		if SettingsManager.language == "ru":
			lang_index = 1
		language_button.select(lang_index)
		language_button.item_selected.connect(_on_language_selected)

func _on_close_settings_button_pressed() -> void:
	settings_closed.emit()

func _on_profile_selected(index: int) -> void:
	var profiles = ["Full", "Grindfest"]
	SettingsManager.set_sound_profile(profiles[index])

func _on_language_selected(index: int) -> void:
	var langs = ["en", "ru"]
	SettingsManager.set_language(langs[index])
