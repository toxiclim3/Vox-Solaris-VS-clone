## slide_movement.gd
## Diorama: Left panel shows WASD + arrow keys + joystick lighting up in sync
## with the player sprite walking a rectangular path on the right.
## Viewport: 640x360, sprite scale 1x
extends Node2D

const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const SHADOW_TEX  := "res://Textures/GUI/blob_shadow.png"
const PROMPTS_DIR := "res://Textures/GUI/Prompts/"

const WALK_SPEED  := 70.0   # px/s

# Walk path corners in 640x360 space (right 60% of screen)
const WAYPOINTS: Array[Vector2] = [
	Vector2(330, 80),
	Vector2(590, 80),
	Vector2(590, 280),
	Vector2(330, 280),
]

var _bg: Node
var _player: Sprite2D
var _player_shadow: Sprite2D

var _key_nodes: Array[TextureRect] = []
var _stick_node: TextureRect

var _wp_idx: int = 0
var _looping: bool = false
var _walk_time: float = 0.0
var _is_walking: bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	_bg = preload("res://World/background.tscn").instantiate()
	_bg.pixel_scale = 1.0
	add_child(_bg)

	_build_key_panel()

	_player_shadow = Sprite2D.new()
	_player_shadow.texture = load(SHADOW_TEX)
	add_child(_player_shadow)

	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	add_child(_player)

	_update_player_position(WAYPOINTS[0])

func _update_player_position(pos: Vector2) -> void:
	_player.position = pos
	_player_shadow.position = pos + Vector2(0, 8)

func _build_key_panel() -> void:
	# Centre of key cluster in left area
	var cx := 130.0
	var gy := 70.0

	# WASD cluster
	var wasd_positions: Array[Vector2] = [
		Vector2(cx,        gy),
		Vector2(cx - 20,   gy + 20),
		Vector2(cx,        gy + 20),
		Vector2(cx + 20,   gy + 20),
	]
	var wasd_prefixes: Array[String] = ["w", "a", "s", "d"]

	# Arrow cluster below
	var arrow_base_y := gy + 70.0
	var arrow_positions: Array[Vector2] = [
		Vector2(cx,        arrow_base_y),
		Vector2(cx - 20,   arrow_base_y + 20),
		Vector2(cx,        arrow_base_y + 20),
		Vector2(cx + 20,   arrow_base_y + 20),
	]
	var arrow_prefixes: Array[String] = ["ua", "la", "da", "ra"]

	var all_pos = wasd_positions + arrow_positions
	var all_pref = wasd_prefixes + arrow_prefixes

	for i in all_pos.size():
		var key := TextureRect.new()
		key.texture = load(PROMPTS_DIR + all_pref[i] + "_up.png")
		key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		key.position = all_pos[i] - Vector2(8, 8)
		key.set_meta("prefix", all_pref[i])
		add_child(key)
		_key_nodes.append(key)

	# Joystick icon
	_stick_node = TextureRect.new()
	_stick_node.texture = load(PROMPTS_DIR + "lstick.png")
	_stick_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stick_node.position = Vector2(cx - 11, arrow_base_y + 50) - Vector2(8, 8)
	add_child(_stick_node)

	# Divider
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.10)
	divider.size = Vector2(1, 300)
	divider.position = Vector2(260, 30)
	add_child(divider)

func _process(delta: float) -> void:
	if _looping and _is_walking:
		_walk_time += delta
		if _walk_time > 0.3:
			_walk_time -= 0.3
			_player.frame = 1 if _player.frame == 0 else 0
	else:
		_player.frame = 0

func start_loop() -> void:
	_looping = true
	_walk_loop()

func stop_loop() -> void:
	_looping = false

func _walk_loop() -> void:
	_wp_idx = 0
	while _looping:
		var target: Vector2 = WAYPOINTS[_wp_idx]
		var dir_idx := _direction_for_waypoint(_wp_idx)
		_light_direction(dir_idx)

		if dir_idx == 1:       # left
			_player.flip_h = false
		elif dir_idx == 3:     # right
			_player.flip_h = true

		var dist := _player.position.distance_to(target)
		var time := dist / WALK_SPEED

		_is_walking = true
		var tw := create_tween()
		tw.tween_method(_update_player_position, _player.position, target, time).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		_is_walking = false

		if not _looping: break
		_wp_idx = (_wp_idx + 1) % WAYPOINTS.size()
		await get_tree().create_timer(0.12).timeout

func _direction_for_waypoint(idx: int) -> int:
	var from_idx := (idx - 1 + WAYPOINTS.size()) % WAYPOINTS.size()
	var delta := WAYPOINTS[idx] - WAYPOINTS[from_idx]
	if abs(delta.x) > abs(delta.y):
		return 3 if delta.x > 0 else 1
	else:
		return 2 if delta.y > 0 else 0

func _light_direction(dir: int) -> void:
	for i in _key_nodes.size():
		var prefix = _key_nodes[i].get_meta("prefix")
		_key_nodes[i].texture = load(PROMPTS_DIR + prefix + "_up.png")

	var wasd_map  := [0, 1, 2, 3]
	var arrow_map := [4, 5, 6, 7]
	var w_node = _key_nodes[wasd_map[dir]]
	var a_node = _key_nodes[arrow_map[dir]]
	w_node.texture = load(PROMPTS_DIR + w_node.get_meta("prefix") + "_down.png")
	a_node.texture = load(PROMPTS_DIR + a_node.get_meta("prefix") + "_down.png")

	var stick_textures = ["lstick_up.png", "lstick_left.png", "lstick_down.png", "lstick_right.png"]
	_stick_node.texture = load(PROMPTS_DIR + stick_textures[dir])
