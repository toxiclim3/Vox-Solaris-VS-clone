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
@export var polyphony: int = 1

var normalTracks: Array[String] = []
var bossTracks: Array[String] = []
var extraTracks: Array[String] = []

var currentNormalIndex: int = -1
var currentBossIndex: int = -1

var playerA: AudioStreamPlayer
var playerB: AudioStreamPlayer
var activePlayer: AudioStreamPlayer
var fadeTween: Tween

var restartable = true
# Состояние паузы музыки (не путать с get_tree().paused)
var isMusicMuted: bool = false
var is_music_locked: bool = false
var is_audio_functional: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if AudioServer.get_bus_count() > 0:
		is_audio_functional = true
	else:
		push_warning("MusicController: AudioServer failed to initialize buses. Music is disabled.")
		return # Bailing out early
	
	if OS.has_feature("lite_audio"):
		normalMusicDir = normalMusicDir.replace("Music", "Music_Lite")
		bossMusicDir = bossMusicDir.replace("Music", "Music_Lite")
		extraMusicDir = extraMusicDir.replace("Music", "Music_Lite")
		winMusic = winMusic.replace("Music", "Music_Lite")
		titleMusic = titleMusic.replace("Music", "Music_Lite")
		tutorialMusic = tutorialMusic.replace("Music", "Music_Lite")
		
	_initPlayers()
	loadTracksFromDir(normalMusicDir, normalTracks)
	loadTracksFromDir(bossMusicDir, bossTracks)
	loadTracksFromDir(extraMusicDir, extraTracks)
	
	playerA.finished.connect(_on_track_finished)
	playerB.finished.connect(_on_track_finished)
	GlobalEvents.boss_defeated.connect(_on_boss_death)

func unlockMusic() -> void:
	is_music_locked = false

func lockMusic() -> void:
	is_music_locked = true

var winMusic = "res://Audio/Music/Extra/i finally found my voice as an artist [FsTc4TCRHy8].mp3"
var titleMusic = "res://Audio/Music/Extra/checkpoint (day) [sOZNRzxwJXA].mp3"
var tutorialMusic = "res://Audio/Music/Extra/musicHitItSonA.ogg"
# Словарь для хранения загруженных ресурсов: { "res://path": AudioStream }
var trackCache: Dictionary = {}

const MUSIC_KEY_A: PackedByteArray = [
	0x7A, 0x31, 0xC4, 0x8E, 0x19, 0xB2, 0x55, 0xE0,
	0x4C, 0x93, 0x27, 0xF1, 0x68, 0xD4, 0x0B, 0xA6,
	0x3E, 0x85, 0xDF, 0x12, 0x79, 0xC0, 0x44, 0x9B,
	0xE7, 0x2A, 0x61, 0xB8, 0x03, 0x5C, 0xA9, 0xF4
]
const MUSIC_KEY_B: PackedByteArray = [
	0x33, 0x5F, 0xB6, 0xE7, 0x6D, 0xC7, 0x26, 0xBF,
	0x1A, 0xFC, 0x5F, 0xA2, 0x07, 0xB8, 0x6A, 0xD4,
	0x57, 0xF6, 0x80, 0x53, 0x0C, 0xA4, 0x2D, 0xF4,
	0xB8, 0x6D, 0x14, 0xD9, 0x71, 0x38, 0x9F, 0xC2
]

func _load_encrypted_stream(mencPath: String, logicalPath: String) -> AudioStream:
	var data := FileAccess.get_file_as_bytes(mencPath)
	if data.size() < 44:
		push_error("MusicController: Некорректный размер зашифрованного файла: ", mencPath)
		return null
	if data[0] != 0x49 or data[1] != 0x4E or data[2] != 0x52 or data[3] != 0x4D:
		push_error("MusicController: Неверный заголовок файла .menc: ", mencPath)
		return null

	var fmt := data[4]
	var orig_size := data.decode_u32(8)
	var iv := data.slice(12, 28)
	var cipher := data.slice(28)
	if orig_size == 0 or cipher.is_empty() or (cipher.size() % 16) != 0 or orig_size > cipher.size():
		push_error("MusicController: Поврежденные метаданные в .menc: ", mencPath)
		return null

	var key := PackedByteArray()
	key.resize(32)
	for i in range(32):
		key[i] = MUSIC_KEY_A[i] ^ MUSIC_KEY_B[i]

	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, key, iv) != OK:
		push_error("MusicController: Не удалось запустить AES расшифровку: ", mencPath)
		return null
	var dec := aes.update(cipher)
	aes.finish()
	if dec.size() < orig_size:
		push_error("MusicController: Ошибка расшифровки данных: ", mencPath)
		return null
	dec.resize(orig_size)

	var stream: AudioStream = null
	if fmt == 1:
		stream = AudioStreamMP3.load_from_buffer(dec)
	elif fmt == 2:
		stream = AudioStreamOggVorbis.load_from_buffer(dec)
	else:
		push_error("MusicController: Неизвестный формат аудио в .menc: ", fmt)
		return null

	if stream:
		stream.resource_path = logicalPath
		return stream

	push_error("MusicController: Ошибка декодирования аудио из буфера: ", mencPath)
	return null

func _get_stream_from_cache(filePath: String) -> AudioStream:
	if trackCache.has(filePath):
		return trackCache[filePath]

	var mencPath := filePath if filePath.ends_with(".menc") else filePath + ".menc"
	if FileAccess.file_exists(mencPath):
		var enc_stream := _load_encrypted_stream(mencPath, filePath)
		if enc_stream:
			trackCache[filePath] = enc_stream
			return enc_stream
		return null
		
	if not FileAccess.file_exists(filePath) and not FileAccess.file_exists(filePath + ".import") and not FileAccess.file_exists(filePath + ".remap") and not ResourceLoader.exists(filePath):
		push_error("MusicController: Файл не найден: ", filePath)
		return null
		
	var stream = load(filePath) as AudioStream
	if stream:
		trackCache[filePath] = stream
		return stream
	
	push_error("MusicController: Ошибка загрузки ресурса: ", filePath)
	return null

# Запуск конкретного файла с кэшированием
func playSpecificTrack(filePath: String,crossfade: bool = 1) -> void:
	if not is_audio_functional:
		return
		
	if is_music_locked and filePath != winMusic and filePath != titleMusic:
		return
		
	var stream = _get_stream_from_cache(filePath)
	if not stream:
		return

	# 3. Если этот трек уже играет — выходим
	if activePlayer.playing and activePlayer.stream and activePlayer.stream.resource_path == stream.resource_path:
		return
	
	if crossfade:
		_crossfadeTo(stream,true)
	else:
		_crossfadeTo(stream,false)

# Функция для ручной очистки памяти (если кэш раздулся)
func clearMusicCache() -> void:
	trackCache.clear()

func playNext(type: MusicType) -> void:
	if not is_audio_functional:
		return
		
	if is_music_locked and type != MusicType.BOSS:
		return
		
	if type == MusicType.BOSS:
		lockMusic()
		
	var tracks: Array[String] = normalTracks if type == MusicType.NORMAL else bossTracks
	
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
		
	var filePath = tracks[nextIndex]
	var stream = _get_stream_from_cache(filePath)
	
	if stream:
		_crossfadeTo(stream)
		trackChanged.emit(stream, type == MusicType.BOSS)

func _initPlayers() -> void:
	playerA = AudioStreamPlayer.new()
	playerB = AudioStreamPlayer.new()
	
	# Назначаем на аудиошину Music (создай её в настройках Audio)
	playerA.bus = &"Music"
	playerB.bus = &"Music"
	
	playerA.max_polyphony = polyphony
	playerB.max_polyphony = polyphony
	
	add_child(playerA)
	add_child(playerB)
	
	activePlayer = playerA

func loadTracksFromDir(path: String, targetArray: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("MusicController: Не удалось открыть папку: ", path)
		return
		
	var files := dir.get_files()
	for file in files:
		# Защита от особенностей экспорта Godot: в билде файлы получают суффикс .import
		var cleanName := file.trim_suffix(".remap").trim_suffix(".import").trim_suffix(".menc")
		
		if cleanName.get_extension() in ["ogg", "mp3", "wav"]:
			var fullPath := path.path_join(cleanName)
			if not targetArray.has(fullPath):
				targetArray.append(fullPath)
	targetArray.shuffle()

func _switchTo(newStream: AudioStream) -> void:
	var nextPlayer: AudioStreamPlayer = playerA if activePlayer == playerA else playerB
	
	nextPlayer.stream = newStream
	nextPlayer.volume_db = minVolumeDb
	nextPlayer.play()

func _crossfadeTo(newStream: AudioStream, immediate: bool = 1) -> void:
	# Убиваем предыдущий Tween, если мы переключили трек слишком быстро
	if fadeTween and fadeTween.is_valid():
		await fadeTween.finished
		
	# Определяем, какой плеер сейчас свободен
	var nextPlayer: AudioStreamPlayer = playerB if activePlayer == playerA else playerA
	
	nextPlayer.stream = newStream
	nextPlayer.volume_db = minVolumeDb
	if immediate:
		nextPlayer.play()
		
	fadeTween = create_tween().set_parallel(true)
	
	# Затухание текущего плеера
	if activePlayer.playing:
		fadeTween.tween_property(activePlayer, "volume_db", minVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)
	
	# Нарастание нового плеера
	fadeTween.tween_property(nextPlayer, "volume_db", maxVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)
	
	# После завершения анимации останавливаем старый трек и меняем ссылки
	fadeTween.chain().tween_callback(activePlayer.stop)
	if !immediate:
		fadeTween.chain().tween_callback(nextPlayer.play)
	fadeTween.tween_callback(func(): activePlayer = nextPlayer)

# Плавный уход в тишину (Mute)
func fadeOutToSilence() -> void:
	isMusicMuted = true
	
	if fadeTween and fadeTween.is_valid():
		await fadeTween.finished
		
	fadeTween = create_tween()
	# Затухаем до minVolumeDb
	fadeTween.tween_property(activePlayer, "volume_db", minVolumeDb, fadeDuration).set_trans(Tween.TRANS_SINE)
	# Опционально: ставим на паузу поток, когда громкость упала (чтобы не тратить ресурсы)
	fadeTween.tween_callback(func(): if isMusicMuted: activePlayer.stream_paused = true)

# Плавное возвращение из тишины (Unmute)
func fadeInFromSilence() -> void:
	isMusicMuted = false
	
	if fadeTween and fadeTween.is_valid():
		await fadeTween.finished
		
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
	if activePlayer == null:
		return
	if fadeTween and fadeTween.is_valid():
		await fadeTween.finished
	
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

func setLooping(willLoop: bool):
	restartable = willLoop

func _on_boss_death():
	unlockMusic()
	playNext(MusicType.NORMAL)

func _on_track_finished():
	if restartable:
		activePlayer.play()
