extends Node
# Синглтон для работы с настройками (Autoload: Settings)

const SAVE_PATH = "user://settings.cfg"
var config = ConfigFile.new()

var sound_profile: String = "Full"
var language: String = "en"
var screen_shake: bool = true
var mouse_control: bool = false
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen, 2: Borderless Maximized
var vsync: bool = true
var max_fps: int = 0 # 0 means unlimited

# Elite Settings (The "Funny Moment" Update)
var taa_enabled: bool = false
var fsr_enabled: bool = false
var dlss_enabled: bool = false
var raytracing_enabled: bool = false
var shadows_enabled: bool = false # Enabled by default for "Next-Gen" feel

signal shadow_settings_changed(enabled: bool)
signal raytracing_settings_changed(enabled: bool)

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
	
	if config.has_section("display"):
		window_mode = config.get_value("display", "window_mode", 0)
		vsync = config.get_value("display", "vsync", true)
		max_fps = config.get_value("display", "max_fps", 0)
	
	apply_window_mode(window_mode)
	apply_vsync(vsync)
	apply_max_fps(max_fps)
	
	if config.has_section("elite"):
		taa_enabled = config.get_value("elite", "taa_enabled", false)
		fsr_enabled = config.get_value("elite", "fsr_enabled", false)
		dlss_enabled = config.get_value("elite", "dlss_enabled", false)
		raytracing_enabled = config.get_value("elite", "raytracing_enabled", false)
		shadows_enabled = config.get_value("elite", "shadows_enabled", true)
	
	apply_elite_settings()

func apply_elite_settings() -> void:
	var viewport = get_viewport()
	if not viewport: return
	
	# 3D Scaling commands removed for mobile compatibility
	# Ray Tracing (Joke) - Hidden 10 FPS limit
	# DLSS (Joke) - Adds to the placebo vibe
	apply_max_fps(max_fps) # Refresh normal FPS first
	if raytracing_enabled:
		Engine.max_fps = 120 # Cinematic 10fps
	
	shadow_settings_changed.emit(shadows_enabled)
	raytracing_settings_changed.emit(raytracing_enabled)

func set_taa(value: bool) -> void:
	taa_enabled = value
	config.set_value("elite", "taa_enabled", value)
	config.save(SAVE_PATH)
	apply_elite_settings()

func set_fsr(value: bool) -> void:
	fsr_enabled = value
	config.set_value("elite", "fsr_enabled", value)
	config.save(SAVE_PATH)
	apply_elite_settings()

func set_dlss(value: bool) -> void:
	dlss_enabled = value
	config.set_value("elite", "dlss_enabled", value)
	config.save(SAVE_PATH)
	apply_elite_settings()

func set_raytracing(value: bool) -> void:
	raytracing_enabled = value
	config.set_value("elite", "raytracing_enabled", value)
	config.save(SAVE_PATH)
	apply_elite_settings()

func set_shadows(value: bool) -> void:
	shadows_enabled = value
	config.set_value("elite", "shadows_enabled", value)
	config.save(SAVE_PATH)
	apply_elite_settings()

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

func set_window_mode(mode: int) -> void:
	window_mode = mode
	config.set_value("display", "window_mode", mode)
	config.save(SAVE_PATH)
	apply_window_mode(mode)

func set_vsync(value: bool) -> void:
	vsync = value
	config.set_value("display", "vsync", value)
	config.save(SAVE_PATH)
	apply_vsync(value)

func set_max_fps(value: int) -> void:
	max_fps = value
	config.set_value("display", "max_fps", value)
	config.save(SAVE_PATH)
	apply_max_fps(value)

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

func apply_window_mode(mode: int) -> void:
	match mode:
		0: # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: # Borderless Maximized
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func apply_vsync(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func apply_max_fps(fps: int) -> void:
	Engine.max_fps = fps
