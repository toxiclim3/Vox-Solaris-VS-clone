extends PanelContainer

signal settings_closed

@onready var profile_button = %ProfileButton
@onready var language_button = %LanguageButton
@onready var mouse_control_button = %MouseControlButton
@onready var screen_shake_button = %ScreenShakeButton
@onready var confirmation_dialog = $ConfirmationDialog

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
	
	if mouse_control_button:
		mouse_control_button.button_pressed = SettingsManager.mouse_control
		mouse_control_button.toggled.connect(_on_mouse_control_toggled)
	
	if screen_shake_button:
		screen_shake_button.button_pressed = SettingsManager.screen_shake
		screen_shake_button.toggled.connect(_on_screen_shake_toggled)

func _on_close_settings_button_pressed() -> void:
	settings_closed.emit()

func _on_profile_selected(index: int) -> void:
	var profiles = ["Full", "Grindfest"]
	SettingsManager.set_sound_profile(profiles[index])

func _on_language_selected(index: int) -> void:
	SettingsManager.set_language(Languages.find_key(index))

func _on_mouse_control_toggled(toggled_on: bool) -> void:
	SettingsManager.set_mouse_control(toggled_on)

func _on_screen_shake_toggled(toggled_on: bool) -> void:
	SettingsManager.set_screen_shake(toggled_on)

func _on_btn_reset_stats_click_end() -> void:
	if confirmation_dialog:
		confirmation_dialog.popup_centered()

func _on_confirmation_dialog_confirmed() -> void:
	StatsManager.reset_stats()
