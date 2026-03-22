extends HSlider
# Вешается на HSlider в меню настроек

@export var busName: String = "Music"

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.05
	
	# Берем значение из конфига, если его нет — 1.0 (макс)
	value = SettingsManager.config.get_value("audio", busName, 1.0)
	
	value_changed.connect(_on_value_changed)

func _on_value_changed(newValue: float) -> void:
	# Применяем громкость через менеджер
	SettingsManager.applyBusVolume(busName, newValue)
	# Сохраняем в файл
	SettingsManager.saveAudioSetting(busName, newValue)
