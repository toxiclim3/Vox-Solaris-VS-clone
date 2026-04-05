extends Node
# Синглтон для работы с настройками (Autoload: Settings)

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

var sound_profile: String = "Full"
var language: String = "en"
var mouse_control: bool = false
var screen_shake: bool = true

const PROFILES = {
	"Full": {
		"EnemyHurt": 1.0,
		"EnemyDeath": 1.0,
		"PlayerHurt": 1.0,
		"LevelUp": 1.0,
		"MiscImportant": 1.0,
		"MiscUnimportant": 1.0
	},
	"Grindfest": {
		"EnemyHurt": 0.15,
		"EnemyDeath": 0.15,
		"PlayerHurt": 0.8,
		"LevelUp": 0.5,
		"MiscImportant": 0.8,
		"MiscUnimportant": 0.2
	}
}

func _ready() -> void:
	loadSettings()

# Сохранение значения громкости
func saveAudioSetting(busName: String, value: float) -> void:
	config.set_value("audio", busName, value)
	config.save(SAVE_PATH)

# Загрузка и применение всех настроек
func loadSettings() -> void:
	var error = config.load(SAVE_PATH)
	
	# Если файла нет (первый запуск), ничего не делаем
	if error != OK:
		TranslationServer.set_locale(language)
		return

	# Применяем громкость для всех сохраненных шин
	if config.has_section("audio"):
		sound_profile = config.get_value("audio", "sound_profile", "Full")
		for busName in config.get_section_keys("audio"):
			if busName != "sound_profile":
				var volumeValue = config.get_value("audio", busName, 1.0)
				applyBusVolume(busName, volumeValue)
	
	applySoundProfile(sound_profile)
	
	if config.has_section("localization"):
		language = config.get_value("localization", "language", "en")
	TranslationServer.set_locale(language)
	
	if config.has_section("controls"):
		mouse_control = config.get_value("controls", "mouse_control", false)
		screen_shake = config.get_value("controls", "screen_shake", true)

func set_language(lang: String) -> void:
	language = lang
	config.set_value("localization", "language", lang)
	config.save(SAVE_PATH)
	TranslationServer.set_locale(lang)

func set_sound_profile(profile: String) -> void:
	sound_profile = profile
	config.set_value("audio", "sound_profile", profile)
	config.save(SAVE_PATH)
	applySoundProfile(profile)

func set_mouse_control(value: bool) -> void:
	mouse_control = value
	config.set_value("controls", "mouse_control", value)
	config.save(SAVE_PATH)

func set_screen_shake(value: bool) -> void:
	screen_shake = value
	config.set_value("controls", "screen_shake", value)
	config.save(SAVE_PATH)

func get_sound_profile_index() -> int:
	if sound_profile == "Grindfest":
		return 1
	return 0

func applySoundProfile(profile: String) -> void:
	if not PROFILES.has(profile):
		return
	var settings = PROFILES[profile]
	for busName in settings:
		applyBusVolume(busName, settings[busName])

# Вспомогательная функция для применения громкости к AudioServer
func applyBusVolume(busName: String, linearValue: float) -> void:
	var busIndex = AudioServer.get_bus_index(busName)
	if busIndex != -1:
		AudioServer.set_bus_volume_db(busIndex, linear_to_db(linearValue))
		AudioServer.set_bus_mute(busIndex, linearValue < 0.01)
