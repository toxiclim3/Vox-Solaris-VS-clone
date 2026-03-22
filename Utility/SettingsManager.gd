extends Node
# Синглтон для работы с настройками (Autoload: Settings)

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

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
		return

	# Применяем громкость для всех сохраненных шин
	if config.has_section("audio"):
		for busName in config.get_section_keys("audio"):
			var volumeValue = config.get_value("audio", busName, 1.0)
			applyBusVolume(busName, volumeValue)

# Вспомогательная функция для применения громкости к AudioServer
func applyBusVolume(busName: String, linearValue: float) -> void:
	var busIndex = AudioServer.get_bus_index(busName)
	if busIndex != -1:
		AudioServer.set_bus_volume_db(busIndex, linear_to_db(linearValue))
		AudioServer.set_bus_mute(busIndex, linearValue < 0.01)
