extends Camera2D

var shake_amount: float = 0.0
var shake_decay: float = 0.0
var default_offset: Vector2 = Vector2.ZERO

func _ready():
	default_offset = offset
	GlobalEvents.camera_shake.connect(start_shake)

func start_shake(intensity: float, duration: float):
	if SettingsManager.screen_shake:
		shake_amount = max(shake_amount, intensity)
		shake_decay = shake_amount / max(duration, 0.001)

func _process(delta):
	if shake_amount > 0:
		shake_amount = move_toward(shake_amount, 0.0, shake_decay * delta)
		if shake_amount < 0.05: # Threshold
			shake_amount = 0.0
		
		# Generate random offset
		var random_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		offset = random_offset
	else:
		# Lerp back to center
		offset = offset.lerp(default_offset, 10.0 * delta)
		if offset.length() < 0.1:
			offset = default_offset
