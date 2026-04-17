extends Control

# Dedicated signal for player movement
signal joystick_vector(vector: Vector2)

@export var joystick_active := false
@export var min_drag := 10.0 # Minimum pixels to start movement
@export var max_drag := 60.0 # Maximum pixels for full strength

## Visual scale multiplier for the joystick sprites.
## Proportionally adjusts max_drag so input feel matches the new size.
## 1.0 = default size, 1.5 = 50% larger, etc.
@export var joystick_scale: float = 1.0:
	set(value):
		joystick_scale = clampf(value, 0.25, 4.0)
		_apply_joystick_scale()

@onready var base = $Base
@onready var stick = $Base/Stick

var _base_max_drag := 60.0  # Reference value before scaling
var _pause_btn: Control = null  # Cached for dynamic exclusion zone
var touch_id := -1
var start_pos := Vector2.ZERO
var current_vector := Vector2.ZERO

func _ready():
	visible = false # Only show when touched
	base.position = Vector2.ZERO
	stick.position = Vector2.ZERO
	_apply_joystick_scale()
	# Cache the mobile pause button for the dynamic exclusion zone
	_pause_btn = get_parent().find_child("btn_pause_mobile", true, false)

func _apply_joystick_scale() -> void:
	# Guards: only run after children are available
	if not is_node_ready():
		return
	var b = get_node_or_null("Base")
	if b:
		b.scale = Vector2(joystick_scale, joystick_scale)
	max_drag = _base_max_drag * joystick_scale
	min_drag = 10.0 * joystick_scale

func _input(event):
	if event is InputEventScreenTouch:
		# Dynamic exclusion zone: ignore touches that fall on the pause button.
		# 8px grow() adds padding around the button rect for comfortable tap rejection.
		if event.pressed:
			var excluded := false
			if _pause_btn and _pause_btn.visible:
				excluded = _pause_btn.get_global_rect().grow(8.0).has_point(event.position)
			else:
				# Fallback: static top-right 80×80 if button node isn't found
				var vp := get_viewport_rect().size
				excluded = event.position.y < 80.0 and event.position.x > vp.x - 80.0
			if excluded:
				return

		if event.pressed and touch_id == -1:
			# Start joystick
			touch_id = event.index
			start_pos = event.position
			global_position = start_pos
			visible = true
			joystick_active = true
			base.position = Vector2.ZERO
			stick.position = Vector2.ZERO
		elif not event.pressed and event.index == touch_id:
			# Stop joystick
			touch_id = -1
			joystick_active = false
			visible = false
			current_vector = Vector2.ZERO
			joystick_vector.emit(Vector2.ZERO)

	if event is InputEventScreenDrag:
		if event.index == touch_id:
			var drag_vector = event.position - start_pos
			if drag_vector.length() > max_drag:
				drag_vector = drag_vector.normalized() * max_drag
			
			stick.position = drag_vector
			
			# Normalize vector for movement
			if drag_vector.length() > min_drag:
				current_vector = drag_vector / max_drag
			else:
				current_vector = Vector2.ZERO
			
			joystick_vector.emit(current_vector)

func get_vector() -> Vector2:
	return current_vector
