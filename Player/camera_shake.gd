extends Camera2D

var shake_amount: float = 0.0
var default_offset: Vector2 = Vector2.ZERO

func _ready():
	default_offset = offset
	GlobalEvents.camera_shake.connect(start_shake)

func start_shake(intensity: float):
	if SettingsManager.screen_shake:
		shake_amount = max(shake_amount, intensity)

func _process(delta):
	if shake_amount > 0:
		shake_amount = lerp(shake_amount, 0.0, 5.0 * delta)
		if shake_amount < 0.1:
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
