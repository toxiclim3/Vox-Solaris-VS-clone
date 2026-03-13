extends Node
# Вешается на пустой Node, который затем добавляется в Autoload (Project Settings -> Globals)

signal trackChanged(newStream: AudioStream, isBoss: bool)

enum MusicType { NORMAL, BOSS, EXTRA}

@export_group("Directories")
@export_dir var normalMusicDir: String = "res://Audio/Music/Normal"
@export_dir var bossMusicDir: String = "res://Audio/Music/Boss"
@export_dir var extraMusicDir: String = "res://Audio/Music/Extra"

@export_group("Settings")
@export var fadeDuration: float = 1.5
@export var maxVolumeDb: float = 0.0
@export var minVolumeDb: float = -60.0 # Порог тишины
@export var backgroundVolumeDb: float = -10.0 # Громкость музыки "на фоне" (в меню)

var normalTracks: Array[AudioStream] = []
var bossTracks: Array[AudioStream] = []
var extraTracks: Array[AudioStream] = []

var currentNormalIndex: int = -1
var currentBossIndex: int = -1

var playerA: AudioStreamPlayer
var playerB: AudioStreamPlayer
var activePlayer: AudioStreamPlayer
var fadeTween: Tween

# Состояние паузы музыки (не путать с get_tree().paused)
var isMusicMuted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_initPlayers()
	loadTracksFromDir(normalMusicDir, normalTracks)
	loadTracksFromDir(bossMusicDir, bossTracks)
	loadTracksFromDir(extraMusicDir, extraTracks)


var winMusic = "res://Audio/Music/Extra/i finally found my voice as an artist [FsTc4TCRHy8].mp3"
var titleMusic = "res://Audio/Music/Extra/checkpoint (day) [sOZNRzxwJXA].mp3"
# Словарь для хранения загруженных ресурсов: { "res://path": AudioStream }
var trackCache: Dictionary = {}

# Запуск конкретного файла с кэшированием
func playSpecificTrack(filePath: String) -> void:
	var stream: AudioStream
	
	# 1. Проверяем, есть ли трек в кэше
	if trackCache.has(filePath):
		stream = trackCache[filePath]
	else:
		# 2. Если нет, проверяем файл и загружаем
		if not FileAccess.file_exists(filePath):
			push_error("MusicController: Файл не найден: ", filePath)
			return
			
		stream = load(filePath) as AudioStream
		if stream:
			trackCache[filePath] = stream # Сохраняем в кэш
		else:
			push_error("MusicController: Ошибка загрузки ресурса: ", filePath)
			return

	# 3. Если этот трек уже играет — выходим
	if activePlayer.playing and activePlayer.stream and activePlayer.stream.resource_path == stream.resource_path:
		return
		
	_crossfadeTo(stream)

# Функция для ручной очистки памяти (если кэш раздулся)
func clearMusicCache() -> void:
	trackCache.clear()

func playNext(type: MusicType) -> void:
	var tracks: Array[AudioStream] = normalTracks if type == MusicType.NORMAL else bossTracks
	
	if tracks.is_empty():
		push_warning("MusicController: Папка с музыкой пуста!")
		return
		
	var nextIndex: int = 0
	
	if type == MusicType.NORMAL:
		currentNormalIndex = (currentNormalIndex + 1) % tracks.size()
		nextIndex = currentNormalIndex
	else:
		currentBossIndex = (currentBossIndex + 1) % tracks.size()
		nextIndex = currentBossIndex
		
	_crossfadeTo(tracks[nextIndex])
	trackChanged.emit(tracks[nextIndex], type == MusicType.BOSS)

func _initPlayers() -> void:
	playerA = AudioStreamPlayer.new()
	playerB = AudioStreamPlayer.new()
	
	# Назначаем на аудиошину Music (создай её в настройках Audio)
	playerA.bus = &"Music"
	playerB.bus = &"Music"
	
	add_child(playerA)
	add_child(playerB)
	
	activePlayer = playerA

func loadTracksFromDir(path: String, targetArray: Array[AudioStream]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("MusicController: Не удалось открыть папку: ", path)
		return
		
	var files := dir.get_files()
	for file in files:
		# Защита от особенностей экспорта Godot: в билде файлы получают суффикс .import
		var cleanName := file.trim_suffix(".remap").trim_suffix(".import")
		
		if cleanName.get_extension() in ["ogg", "mp3", "wav"]:
			var fullPath := path.path_join(cleanName)
			var stream := load(fullPath) as AudioStream
			if stream and not targetArray.has(stream):
				targetArray.append(stream)
	targetArray.shuffle()

func _crossfadeTo(newStream: AudioStream) -> void:
	# Определяем, какой плеер сейчас свободен
	var nextPlayer: AudioStreamPlayer = playerB if activePlayer == playerA else playerA
	
	nextPlayer.stream = newStream
	nextPlayer.volume_db = minVolumeDb
	nextPlayer.play()
	
	# Убиваем предыдущий Tween, если мы переключили трек слишком быстро
	if fadeTween and fadeTween.is_valid():
		fadeTween.kill()
		
	fadeTween = create_tween().set_parallel(true)
	
	# Затухание текущего плеера
	if activePlayer.playing:
		fadeTween.tween_property(activePlayer, "volume_db", minVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)
	
	# Нарастание нового плеера
	fadeTween.tween_property(nextPlayer, "volume_db", maxVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)
	
	# После завершения анимации останавливаем старый трек и меняем ссылки
	fadeTween.chain().tween_callback(activePlayer.stop)
	fadeTween.tween_callback(func(): activePlayer = nextPlayer)

# Плавный уход в тишину (Mute)
func fadeOutToSilence() -> void:
	isMusicMuted = true
	
	if fadeTween and fadeTween.is_valid():
		fadeTween.kill()
		
	fadeTween = create_tween()
	# Затухаем до minVolumeDb
	fadeTween.tween_property(activePlayer, "volume_db", minVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)
	# Опционально: ставим на паузу поток, когда громкость упала (чтобы не тратить ресурсы)
	fadeTween.tween_callback(func(): if isMusicMuted: activePlayer.stream_paused = true)

# Плавное возвращение из тишины (Unmute)
func fadeInFromSilence() -> void:
	isMusicMuted = false
	
	if fadeTween and fadeTween.is_valid():
		fadeTween.kill()
		
	activePlayer.stream_paused = false
	
	fadeTween = create_tween()
	# Возвращаемся к рабочей громкости
	fadeTween.tween_property(activePlayer, "volume_db", maxVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)

# Переключатель (Toggle) для удобства
func toggleMusic(shouldPlay: bool) -> void:
	if shouldPlay:
		fadeInFromSilence()
	else:
		fadeOutToSilence()
		

# Функция для приглушения музыки (например, для меню паузы)
func focusMusic(isFocused: bool) -> void:
	if fadeTween and fadeTween.is_valid():
		fadeTween.kill()
	
	fadeTween = create_tween()
	var targetVolume: float = maxVolumeDb if isFocused else backgroundVolumeDb
	
	# Плавно переходим к нужной громкости
	fadeTween.tween_property(activePlayer, "volume_db", targetVolume, fadeDuration).set_trans(Tween.TRANS_SINE)
	
	# На случай, если музыка была на паузе (stream_paused), снимаем её
	if isFocused and activePlayer.stream_paused:
		activePlayer.stream_paused = false

# Функция сброса плейлистов
func resetPlaylists() -> void:
	currentNormalIndex = -1
	currentBossIndex = -1
	# Если нужно, чтобы музыка сразу выключилась при сбросе:
	# activePlayer.stop()
