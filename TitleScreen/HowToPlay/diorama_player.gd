# SPDX-License-Identifier: GPL-3.0-or-later
## diorama_player.gd
## Lightweight, reusable sprite state playback component for How To Play dioramas.
## Replays recorded sprite tracks from JSON files without running gameplay/physics logic.
## Immune to future combat/stat/balance changes.
class_name DioramaPlayer
extends Node2D

signal playback_started
signal playback_finished
signal loop_restarted
signal frame_changed(current_frame: int, total_frames: int)

@export_file("*.json") var recording_file: String = ""
@export var autoplay: bool = false
@export var loop: bool = true
@export var loop_delay: float = 1.0 # Pause in seconds before restarting loop
@export var show_background: bool = true:
	set(val):
		show_background = val
		if _bg_node:
			_bg_node.visible = show_background
		elif show_background and is_inside_tree():
			_build_background()

# Playback state
var _frames: Array = []
var _fps: float = 20.0
var _frame_interval: float = 0.05
var _total_duration: float = 0.0
var _current_frame_idx: int = 0
var _playback_time: float = 0.0
var _is_playing: bool = false
var _is_loop_paused: bool = false
var _loop_pause_timer: float = 0.0

# Node references & pools
var _pool_container: Node2D
var _sprite_pool: Array[Sprite2D] = []
var _texture_cache: Dictionary = {} # path -> Texture2D
var _bg_node: Node = null

func _ready() -> void:
	_setup_nodes()
	if show_background and _bg_node == null:
		_build_background()
	if recording_file != "":
		load_recording(recording_file)
	if autoplay:
		start_loop()

func _setup_nodes() -> void:
	if not _pool_container:
		_pool_container = get_node_or_null("SpritePool") as Node2D
		if not _pool_container:
			_pool_container = Node2D.new()
			_pool_container.name = "SpritePool"
			add_child(_pool_container)

func _build_background() -> void:
	var bg_scene = preload("res://World/background.tscn")
	if bg_scene:
		_bg_node = bg_scene.instantiate()
		if "pixel_scale" in _bg_node:
			_bg_node.pixel_scale = 1.0
		_bg_node.z_index = -100
		add_child(_bg_node)
		move_child(_bg_node, 0)

## Loads a recording from a JSON file path.
func load_recording(file_path: String) -> bool:
	if file_path.is_empty():
		return false
	if not file_path.begins_with("res://") and not file_path.begins_with("user://") and not file_path.is_absolute_path():
		file_path = "res://" + file_path
	if not FileAccess.file_exists(file_path):
		push_warning("DioramaPlayer: recording file not found: %s" % file_path)
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("DioramaPlayer: could not open file: %s" % file_path)
		return false

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		push_warning("DioramaPlayer: JSON parse error in %s at line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return false

	var data = json.data
	if not (data is Dictionary):
		push_warning("DioramaPlayer: root JSON element must be an object in %s" % file_path)
		return false

	recording_file = file_path
	return load_recording_data(data)

## Loads recording directly from an in-memory Dictionary.
func load_recording_data(data: Dictionary) -> bool:
	_frames = data.get("frames", [])
	_fps = float(data.get("fps", 20.0))
	if _fps <= 0.0:
		_fps = 20.0
	_frame_interval = 1.0 / _fps
	_total_duration = float(data.get("duration", float(_frames.size()) * _frame_interval))
	_current_frame_idx = 0
	_playback_time = 0.0
	_is_loop_paused = false
	_loop_pause_timer = 0.0

	# Preload and cache all referenced textures
	_preload_textures()

	# Display first frame if available
	if not _frames.is_empty():
		_apply_frame(0)
	else:
		_hide_all_sprites()

	return true

func _preload_textures() -> void:
	for frame in _frames:
		if not (frame is Array):
			continue
		for sprite_data in frame:
			if not (sprite_data is Dictionary):
				continue
			var tex_path: String = sprite_data.get("texture", "")
			if tex_path != "" and not _texture_cache.has(tex_path):
				if ResourceLoader.exists(tex_path):
					var tex = load(tex_path)
					if tex is Texture2D:
						_texture_cache[tex_path] = tex

func _get_texture(tex_path: String) -> Texture2D:
	if _texture_cache.has(tex_path):
		return _texture_cache[tex_path]
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		if tex is Texture2D:
			_texture_cache[tex_path] = tex
			return tex
	return null

## Starts or restarts looped playback from frame 0.
func start_loop() -> void:
	if _frames.is_empty() and recording_file != "":
		load_recording(recording_file)
	if _frames.is_empty():
		return

	_is_playing = true
	_is_loop_paused = false
	_loop_pause_timer = 0.0
	_current_frame_idx = 0
	_playback_time = 0.0
	_apply_frame(0)
	playback_started.emit()

## Stops playback and hides all active sprites.
func stop_loop() -> void:
	_is_playing = false
	_is_loop_paused = false
	_hide_all_sprites()

## Resumes playback from current frame.
func play() -> void:
	if _frames.is_empty():
		return
	_is_playing = true

## Pauses playback at current frame.
func pause() -> void:
	_is_playing = false

## Sets playback to a specific frame index.
func seek_frame(idx: int) -> void:
	if _frames.is_empty():
		return
	_is_loop_paused = false
	_loop_pause_timer = 0.0
	_current_frame_idx = clamp(idx, 0, _frames.size() - 1)
	_playback_time = float(_current_frame_idx) * _frame_interval
	_apply_frame(_current_frame_idx)
	frame_changed.emit(_current_frame_idx, _frames.size())

func get_frame_count() -> int:
	return _frames.size()

func get_current_frame() -> int:
	return _current_frame_idx

func is_playing() -> bool:
	return _is_playing

func _process(delta: float) -> void:
	if not _is_playing or _frames.is_empty():
		return

	if _is_loop_paused:
		_loop_pause_timer -= delta
		if _loop_pause_timer <= 0.0:
			_is_loop_paused = false
			_current_frame_idx = 0
			_playback_time = 0.0
			_apply_frame(0)
			loop_restarted.emit()
			frame_changed.emit(_current_frame_idx, _frames.size())
		return

	_playback_time += delta
	var target_frame: int = int(_playback_time / _frame_interval)

	if target_frame >= _frames.size():
		if loop:
			if loop_delay > 0.0:
				_is_loop_paused = true
				_loop_pause_timer = loop_delay
			else:
				_current_frame_idx = 0
				_playback_time = 0.0
				_apply_frame(0)
				loop_restarted.emit()
				frame_changed.emit(_current_frame_idx, _frames.size())
		else:
			_is_playing = false
			_apply_frame(_frames.size() - 1)
			playback_finished.emit()
	elif target_frame != _current_frame_idx:
		_current_frame_idx = target_frame
		_apply_frame(_current_frame_idx)
		frame_changed.emit(_current_frame_idx, _frames.size())

func _apply_frame(frame_idx: int) -> void:
	if frame_idx < 0 or frame_idx >= _frames.size():
		_hide_all_sprites()
		return

	var sprite_list = _frames[frame_idx]
	if not (sprite_list is Array):
		_hide_all_sprites()
		return

	_setup_nodes()

	# Expand sprite pool if needed
	while _sprite_pool.size() < sprite_list.size():
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_pool_container.add_child(spr)
		_sprite_pool.append(spr)

	# Update active sprites
	for i in sprite_list.size():
		var data = sprite_list[i]
		if not (data is Dictionary):
			continue

		var spr = _sprite_pool[i]
		spr.visible = true

		var tex_path: String = data.get("texture", "")
		spr.texture = _get_texture(tex_path) if tex_path != "" else null

		var pos_arr = data.get("pos", [0.0, 0.0])
		spr.position = Vector2(pos_arr[0], pos_arr[1])

		spr.rotation = float(data.get("rotation", 0.0))

		var sc_arr = data.get("scale", [1.0, 1.0])
		spr.scale = Vector2(sc_arr[0], sc_arr[1])

		spr.hframes = int(data.get("hframes", 1))
		spr.vframes = int(data.get("vframes", 1))
		spr.frame = int(data.get("frame", 0))

		spr.flip_h = bool(data.get("flip_h", false))
		spr.flip_v = bool(data.get("flip_v", false))

		var mod_arr = data.get("modulate", [1.0, 1.0, 1.0, 1.0])
		spr.modulate = Color(mod_arr[0], mod_arr[1], mod_arr[2], mod_arr[3])

		spr.z_index = int(data.get("z_index", 0))

	# Hide remaining pooled sprites
	for i in range(sprite_list.size(), _sprite_pool.size()):
		_sprite_pool[i].visible = false

func _hide_all_sprites() -> void:
	for spr in _sprite_pool:
		spr.visible = false
