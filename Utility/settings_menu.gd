extends PanelContainer

signal settings_closed

@onready var profile_button = %ProfileButton
@onready var language_button = %LanguageButton

enum Languages {en,ru,ua}

func _ready() -> void:
	if profile_button:
		profile_button.add_item("Full")
		profile_button.add_item("Grindfest")
		profile_button.select(SettingsManager.get_sound_profile_index())
		profile_button.item_selected.connect(_on_profile_selected)
		
	if language_button:
		language_button.add_item("English")
		language_button.add_item("Русский")
		language_button.add_item("Українська")
		var lang_index = 0
		match SettingsManager.language:
			"en":
				lang_index = Languages.en
			"ru":
				lang_index = Languages.ru
			"ua":
				lang_index = Languages.ua
		language_button.select(lang_index)
		language_button.item_selected.connect(_on_language_selected)

func _on_close_settings_button_pressed() -> void:
	settings_closed.emit()

func _on_profile_selected(index: int) -> void:
	var profiles = ["Full", "Grindfest"]
	SettingsManager.set_sound_profile(profiles[index])

func _on_language_selected(index: int) -> void:
	SettingsManager.set_language(Languages.find_key(index))
