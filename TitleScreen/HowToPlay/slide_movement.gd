## slide_movement.gd
## Diorama: Left panel shows WASD + arrow keys + joystick lighting up in sync
## with the player sprite walking a rectangular path on the right.
extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────
const PLAYER_TEX  := "res://Textures/Player/player_sprite.png"
const BG_COLOR    := Color(0.08, 0.06, 0.12)
const WALK_SPEED  := 55.0   # px/s in diorama coords
const SCALE       := Vector2(2, 2)

# Walk path corners (in 320×180 diorama space, right portion only)
const WAYPOINTS: Array[Vector2] = [
	Vector2(200, 50),
	Vector2(295, 50),
	Vector2(295, 130),
	Vector2(200, 130),
]

# Input key positions & sizes in the left panel (x: 0‥80, centred around x=40)
const KBD_SIZE  := Vector2(14, 14)
const KBD_COLOR := Color(0.25, 0.25, 0.30)
const KBD_LIT   := Color(0.85, 0.85, 1.0)

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _bg:        ColorRect
var _player:    Sprite2D
# key rects: W A S D up down left right
var _key_nodes: Array[ColorRect] = []
var _key_labels: Array[Label] = []
var _stick_tint: ColorRect   # overlay on the stick icon to fake highlighting

var _wp_idx: int = 0
var _looping: bool = false

func _ready() -> void:
	_build_scene()

func _build_scene() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = BG_COLOR
	_bg.size = Vector2(320, 180)
	add_child(_bg)

	# ── Left panel ────────────────────────────────────────────────────────────
	_build_key_panel()

	# ── Player sprite ─────────────────────────────────────────────────────────
	_player = Sprite2D.new()
	_player.texture = load(PLAYER_TEX)
	_player.hframes = 2
	_player.frame   = 0
	_player.scale   = SCALE
	_player.position = WAYPOINTS[0]
	add_child(_player)

func _build_key_panel() -> void:
	# Layout: two rows of keys
	# Row 1 WASD centred at x=40   (labels: W A S D)
	# Row 2 Arrows centred at x=40
	# Joystick icon below arrows
	var cx := 40.0
	var gy := 20.0   # top of the group

	# ─ WASD cluster ─
	var wasd_positions: Array[Vector2] = [
		Vector2(cx,        gy),          # W  — top centre
		Vector2(cx - 16,   gy + 16),     # A  — left
		Vector2(cx,        gy + 16),     # S  — centre
		Vector2(cx + 16,   gy + 16),     # D  — right
	]
	var wasd_labels: Array[String] = ["W","A","S","D"]

	# ─ Arrow cluster ─ (same layout, shifted down)
	var arrow_base_y := gy + 46.0
	var arrow_positions: Array[Vector2] = [
		Vector2(cx,        arrow_base_y),          # ↑
		Vector2(cx - 16,   arrow_base_y + 16),     # ←
		Vector2(cx,        arrow_base_y + 16),     # ↓
		Vector2(cx + 16,   arrow_base_y + 16),     # →
	]
	var arrow_labels: Array[String] = ["↑","←","↓","→"]

	var all_pos: Array[Vector2]   = wasd_positions + arrow_positions
	var all_lbl: Array[String]    = wasd_labels    + arrow_labels

	for i in all_pos.size():
		var key := ColorRect.new()
		key.size = KBD_SIZE
		key.color = KBD_COLOR
		key.position = all_pos[i] - KBD_SIZE / 2
		add_child(key)
		_key_nodes.append(key)

		var lbl := Label.new()
		lbl.text = all_lbl[i]
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size = KBD_SIZE
		lbl.position = key.position
		add_child(lbl)
		_key_labels.append(lbl)

	# Joystick icon area (coloured chip)
	var stick_bg := ColorRect.new()
	stick_bg.size = Vector2(22, 22)
	stick_bg.color = Color(0.18, 0.18, 0.22)
	stick_bg.position = Vector2(cx - 11, arrow_base_y + 36)
	add_child(stick_bg)

	var stick_lbl := Label.new()
	stick_lbl.text = "○"
	stick_lbl.add_theme_font_size_override("font_size", 14)
	stick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stick_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	stick_lbl.size = Vector2(22, 22)
	stick_lbl.position = stick_bg.position
	add_child(stick_lbl)

	_stick_tint = ColorRect.new()
	_stick_tint.size = Vector2(22, 22)
	_stick_tint.position = stick_bg.position
	_stick_tint.color = Color(1, 1, 1, 0)   # transparent by default
	add_child(_stick_tint)

	# Divider between panels
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.08)
	divider.size = Vector2(1, 160)
	divider.position = Vector2(80, 10)
	add_child(divider)

func start_loop() -> void:
	_looping = true
	_walk_loop()

func stop_loop() -> void:
	_looping = false

func _walk_loop() -> void:
	_wp_idx = 0
	while _looping:
		var target: Vector2 = WAYPOINTS[_wp_idx]
		# Determine direction index: 0=up 1=left 2=down 3=right
		# (matches our key order: W A S D and ↑ ← ↓ →)
		var dir_idx := _direction_for_waypoint(_wp_idx)
		_light_direction(dir_idx)

		# Update sprite flip
		if dir_idx == 1:   # left
			_player.flip_h = true
		elif dir_idx == 3: # right
			_player.flip_h = false

		var dist := _player.position.distance_to(target)
		var time := dist / WALK_SPEED

		var tw := create_tween()
		tw.tween_property(_player, "position", target, time).set_ease(Tween.EASE_IN_OUT)
		await tw.finished

		if not _looping:
			break

		_wp_idx = (_wp_idx + 1) % WAYPOINTS.size()
		# brief pause at corners
		await get_tree().create_timer(0.15).timeout

func _direction_for_waypoint(idx: int) -> int:
	# Movement from WAYPOINTS[idx-1] to WAYPOINTS[idx]
	# 0=up 1=left 2=down 3=right  (matching WASD/arrow order)
	var from_idx := (idx - 1 + WAYPOINTS.size()) % WAYPOINTS.size()
	var delta := WAYPOINTS[idx] - WAYPOINTS[from_idx]
	if abs(delta.x) > abs(delta.y):
		return 3 if delta.x > 0 else 1
	else:
		return 2 if delta.y > 0 else 0

func _light_direction(dir: int) -> void:
	# Dim all keys first
	for i in _key_nodes.size():
		_key_nodes[i].color = KBD_COLOR
	_stick_tint.color = Color(1, 1, 1, 0)

	# Light the matching WASD key (0‥3) AND arrow key (4‥7) AND stick
	var wasd_map   := [0, 1, 2, 3]   # W=up A=left S=down D=right
	var arrow_map  := [4, 5, 6, 7]   # ↑ ← ↓ →
	_key_nodes[wasd_map[dir]].color  = KBD_LIT
	_key_nodes[arrow_map[dir]].color = KBD_LIT
	_stick_tint.color = Color(1, 1, 1, 0.3)
