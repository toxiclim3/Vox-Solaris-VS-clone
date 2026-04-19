extends Area2D

## Rectangle telegraph for Dr. Franklin's directional beam attack.
## Spawned by dr_franklin.gd at the boss's position, rotated to face the target direction.
## Fills a rectangle from the boss outward over [duration] seconds, then deals damage.

@export var duration: float = 1.5
@export var rect_length: float = 120.0
@export var rect_width: float = 80.0
@export var player_damage: int = 30
@export var enemy_damage: int = 75
## Set before adding to scene tree; determines which way the beam fires.
@export var direction: Vector2 = Vector2.RIGHT
@export var damage: int = 0
@export var knockback_amount: float = 0.0

var current_time: float = 0.0
var active: bool = false
var executed: bool = false

func _ready() -> void:
	# Rotate the whole Area2D so local +X points toward the target.
	rotation = direction.angle()

	# Collision rectangle — center is offset forward so the rect starts at boss origin.
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect_length, rect_width)
	var coll := CollisionShape2D.new()
	coll.name = "CollisionShape2D"
	coll.shape = shape
	coll.position = Vector2(rect_length / 2.0, 0.0)
	add_child(coll)

	# Both hurt_box.gd and swarm_manager gate on is_in_group("attack").
	# Remove from the group now so neither system fires during the telegraph.
	# execute_attack() re-adds the group for ~0.1 s to allow a single damage tick.
	remove_from_group("attack")
	collision_mask = 2 | 4
	collision_layer = 4

	current_time = duration
	active = true
	damage = enemy_damage

func _process(delta: float) -> void:
	if not active:
		return

	current_time -= delta
	queue_redraw()

	if current_time <= 0.0 and not executed:
		execute_attack()

# ---------------------------------------------------------------------------
# Electric visual colour palette (Doctor-style Shock Therapy)
# ---------------------------------------------------------------------------
const COLOR_BG_FILL  := Color(0.12, 0.02, 0.45, 0.22)  # Dim purple area fill
const COLOR_OUTLINE  := Color(0.55, 0.25, 1.00, 0.90)  # Electric-purple border
const COLOR_GLOW     := Color(0.50, 0.30, 1.00, 0.20)  # Wide soft-glow pass
const COLOR_MID      := Color(0.75, 0.55, 1.00, 0.75)  # Mid-layer arc
const COLOR_CORE     := Color(1.00, 0.95, 1.00, 1.00)  # Bright white-blue core
const COLOR_EDGE     := Color(1.00, 0.90, 1.00, 0.90)  # Leading-edge flash

## Recursive midpoint-displacement lightning arc.
## Re-randomised every call so it crackles every frame.
## [roughness] is clamped to the rect half-width so arcs stay inside the beam.
func _draw_arc(p0: Vector2, p1: Vector2, roughness: float, depth: int,
		color: Color, width: float) -> void:
	if depth == 0:
		draw_line(p0, p1, color, width)
		return
	var mid: Vector2 = (p0 + p1) * 0.5
	var perp: Vector2 = (p1 - p0).rotated(PI * 0.5).normalized()
	mid += perp * randf_range(-roughness, roughness)
	var half: float = roughness * 0.6
	_draw_arc(p0, mid, half, depth - 1, color, width)
	_draw_arc(mid, p1, half, depth - 1, color, width)

func _draw() -> void:
	if not active or executed:
		return

	var fill_ratio: float = 1.0 - clamp(current_time / duration, 0.0, 1.0)
	var fill_len: float   = rect_length * fill_ratio
	var half_w: float     = rect_width / 2.0

	# --- 1. Dim purple background in the filled zone ---
	if fill_len > 0.0:
		draw_rect(Rect2(0.0, -half_w, fill_len, rect_width), COLOR_BG_FILL, true)

	# --- 2. Outline of the full danger rectangle ---
	draw_rect(Rect2(0.0, -half_w, rect_length, rect_width), COLOR_OUTLINE, false, 2.0)

	if fill_len < 2.0:
		return

	# --- 3. Main horizontal lightning arcs (3 strands, each drawn 3 passes) ---
	var roughness: float = half_w * 0.5   # Arcs can deviate up to half the half-width
	for _i in 3:
		var y0: float = randf_range(-half_w * 0.7, half_w * 0.7)
		var y1: float = randf_range(-half_w * 0.7, half_w * 0.7)
		var a := Vector2(0.0, y0)
		var b := Vector2(fill_len, y1)
		_draw_arc(a, b, roughness,        4, COLOR_GLOW, 6.0)  # soft glow halo
		_draw_arc(a, b, roughness * 0.85, 4, COLOR_MID,  2.0)  # coloured mid layer
		_draw_arc(a, b, roughness * 0.70, 4, COLOR_CORE, 1.0)  # bright white core

	# --- 4. Random branch forks off the main body ---
	for _j in 2:
		var bx: float  = fill_len * randf_range(0.25, 0.75)
		var by: float  = randf_range(-half_w * 0.5, half_w * 0.5)
		var ex: float  = fill_len * randf_range(0.60, 1.00)
		var ey: float  = randf_range(-half_w * 0.85, half_w * 0.85)
		var bs := Vector2(bx, by)
		var be := Vector2(ex, ey)
		_draw_arc(bs, be, roughness * 0.5, 3, COLOR_MID,  1.5)
		_draw_arc(bs, be, roughness * 0.4, 3, COLOR_CORE, 0.8)

	# --- 5. Sweeping bright leading edge ---
	draw_line(Vector2(fill_len, -half_w), Vector2(fill_len, half_w), COLOR_EDGE, 3.0)


## Walks up the node tree from [area] to find the owning CharacterBody2D.
## Needed because HurtBox is nested inside an instanced EnemyBase subscene,
## so area.owner / get_parent() only reaches EnemyBase, not the boss root.
func _find_entity_root(area: Area2D) -> Node:
	var node: Node = area
	while node:
		if node is CharacterBody2D:
			return node
		node = node.get_parent()
	# Fallback (should not normally be reached).
	return area.owner if area.owner else area.get_parent()

func execute_attack() -> void:
	executed = true

	# Re-join the "attack" group so hurtboxes and swarm_manager fire once.
	# Removed again after ~0.1 s (several physics frames) to prevent repeat hits.
	add_to_group("attack")
	get_tree().create_timer(0.1).timeout.connect(func(): remove_from_group("attack"))
	
	# Force physics state to sync so get_overlapping_areas() is accurate.
	force_update_transform()
	
	queue_redraw()

	var areas := get_overlapping_areas()
	for area in areas:
		if area.name == "HurtBox" or area.has_signal("hurt"):
			var target := _find_entity_root(area)

			# Bosses are immune to each other's telegraphs and their own.
			if target and target.is_in_group("boss"):
				continue

			var damage_to_deal: int = enemy_damage
			if target and target.is_in_group("player"):
				damage_to_deal = player_damage

			area.emit_signal("hurt", damage_to_deal, Vector2.ZERO, 0)

	# Spawn the outward burst, then free the node once particles finish.
	_spawn_blast_particles()


## Spawns two one-shot CPUParticles2D bursts perpendicular to the beam (±Y local).
## Particles start fast, decelerate sharply, and shrink to nothing — like an
## electric discharge venting sideways out of the beam.
func _spawn_blast_particles() -> void:
	const PARTICLE_LIFETIME := 1.25
	var half_len := rect_length / 2.0
	var half_w   := rect_width  / 2.0

	# Build a reusable shrink curve (1.0 → 0.0 over lifetime).
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))

	# Fade from bright white to transparent electric-purple.
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(1.0, 0.95, 1.0, 1.0))
	color_ramp.set_color(1, Color(0.65, 0.40, 1.0, 0.0))

	for side in [-1.0, 1.0]:
		var p := CPUParticles2D.new()

		# Emit all particles at once in a burst.
		p.emitting       = true
		p.one_shot       = true
		p.amount         = 50
		p.lifetime       = PARTICLE_LIFETIME
		p.explosiveness  = 0.90   # fire them all at once
		p.randomness     = 0.25

		# Thin strip spanning the full beam length.
		p.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(half_len, 1.0)
		p.position              = Vector2(half_len, 0.0) # centred on beam

		# Fire perpendicular to beam (±Y in local space) with a narrow cone.
		p.direction               = Vector2(0.0, side)
		p.spread                  = 18.0
		p.gravity                 = Vector2.ZERO
		p.initial_velocity_min    = 130.0
		p.initial_velocity_max    = 190.0

		# Heavy damping → particles decelerate almost to a stop very quickly.
		p.damping_min = 320.0
		p.damping_max = 330.0

		# Start particles at max scale, shrink to zero at end of life.
		p.scale_amount_min   = 3.0
		p.scale_amount_max   = 5.5
		p.scale_amount_curve = scale_curve

		p.color      = Color(1.0, 0.95, 1.0, 1.0)
		p.color_ramp = color_ramp
		p.z_index    = 4

		add_child(p)

	# Keep the node alive just long enough for the burst to finish, then free.
	get_tree().create_timer(PARTICLE_LIFETIME + 0.15).timeout.connect(queue_free)
