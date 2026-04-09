extends Node2D

# --- Layer references ---
@onready var sky_layer: TextureRect = $Sky
@onready var city_layer: TextureRect = $City
@onready var terrain_layer: TextureRect = $Terrain
@onready var foreground_layer: TextureRect = $Foreground
@onready var lightning_overlay: ColorRect = $LightningOverlay
@onready var fire_particles: GPUParticles2D = $FireParticles

# --- Parallax factors (pixels of shift per pixel of mouse offset from center) ---
const SKY_FACTOR        := Vector2(0.008, 0.004)
const CITY_FACTOR       := Vector2(0.018, 0.010)
const TERRAIN_FACTOR    := Vector2(0.035, 0.018)
const FOREGROUND_FACTOR := Vector2(0.055, 0.028)

const LERP_SPEED := 3.0

# Base positions of each layer (centered on screen)
var sky_base: Vector2
var city_base: Vector2
var terrain_base: Vector2
var foreground_base: Vector2

var smooth_offset: Vector2 = Vector2.ZERO

# --- Fire flicker ---
var flicker_timer: float = 0.0
var flicker_interval: float = 0.08
var flicker_intensity: float = 0.0
var target_flicker: float = 0.0

# --- Lightning ---
var lightning_timer: float = 0.0
var next_lightning_time: float = 0.0
var lightning_state: int = 0  # 0=waiting, 1=flash, 2=fading
var lightning_alpha: float = 0.0

func _ready() -> void:
	# Defer so TextureRect layout has resolved its size
	call_deferred("_setup_layers")
	_schedule_next_lightning()

func _setup_layers() -> void:
	var viewport := get_viewport_rect().size  # 640x360
	# Extra margin so parallax movement never reveals the edge (15% on each side)
	const PARALLAX_MARGIN := 1.15

	for layer in [sky_layer, city_layer, terrain_layer, foreground_layer]:
		var tex: Texture2D = layer.texture
		if tex:
			var tex_size := Vector2(tex.get_width(), tex.get_height())
			# Scale to cover the viewport (use whichever axis needs more scaling)
			var cover_scale := maxf(viewport.x / tex_size.x, viewport.y / tex_size.y)
			var display_size := tex_size * cover_scale * PARALLAX_MARGIN
			layer.size = display_size
			layer.custom_minimum_size = display_size
		# Center on screen — the overflow bleeds off all edges equally
		layer.position = viewport / 2.0 - layer.size / 2.0

	sky_base        = sky_layer.position
	city_base       = city_layer.position
	terrain_base    = terrain_layer.position
	foreground_base = foreground_layer.position

	# Stretch lightning overlay to fill screen
	lightning_overlay.position = Vector2.ZERO
	lightning_overlay.size = viewport

func _process(delta: float) -> void:
	_update_parallax(delta)
	_update_fire_flicker(delta)
	_update_lightning(delta)

func _update_parallax(delta: float) -> void:
	var viewport := get_viewport_rect().size
	var mouse_pos := get_viewport().get_mouse_position()
	var mouse_offset := mouse_pos - viewport / 2.0

	smooth_offset = smooth_offset.lerp(mouse_offset, LERP_SPEED * delta)

	sky_layer.position        = sky_base        + smooth_offset * SKY_FACTOR
	city_layer.position       = city_base       + smooth_offset * CITY_FACTOR
	terrain_layer.position    = terrain_base    + smooth_offset * TERRAIN_FACTOR
	foreground_layer.position = foreground_base + smooth_offset * FOREGROUND_FACTOR

func _update_fire_flicker(delta: float) -> void:
	flicker_timer += delta
	if flicker_timer >= flicker_interval:
		flicker_timer = 0.0
		flicker_interval = randf_range(0.05, 0.18)
		target_flicker = randf_range(-0.06, 0.06)

	flicker_intensity = lerp(flicker_intensity, target_flicker, 8.0 * delta)

	# Subtly modulate brightness and warmth of the city layer
	city_layer.modulate = Color(
		1.0 + flicker_intensity * 0.4,
		1.0 + flicker_intensity * 0.15,
		1.0 - absf(flicker_intensity) * 0.1,
		1.0
	)

func _update_lightning(delta: float) -> void:
	match lightning_state:
		0:  # Waiting for next strike
			lightning_timer += delta
			if lightning_timer >= next_lightning_time:
				lightning_timer = 0.0
				lightning_state = 1
				lightning_alpha = randf_range(0.22, 0.40)
				_apply_lightning(lightning_alpha)

		1:  # Hold for one frame, then begin fade
			lightning_state = 2

		2:  # Fade out
			lightning_alpha = move_toward(lightning_alpha, 0.0, delta * 2.2)
			_apply_lightning(lightning_alpha)
			if lightning_alpha <= 0.0:
				_apply_lightning(0.0)
				lightning_state = 0
				_schedule_next_lightning()

func _apply_lightning(alpha: float) -> void:
	lightning_overlay.color = Color(0.85, 0.88, 1.0, alpha)
	var b := 1.0 + alpha * 0.35
	terrain_layer.modulate = Color(b, b, b, 1.0)
	foreground_layer.modulate = Color(b, b, b, 1.0)
	sky_layer.modulate = Color(1.0 + alpha * 0.15, 1.0 + alpha * 0.15, 1.0 + alpha * 0.2, 1.0)

func _schedule_next_lightning() -> void:
	next_lightning_time = randf_range(8.0, 22.0)
