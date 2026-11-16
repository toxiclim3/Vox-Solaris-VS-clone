class_name TargetDummy
extends EnemyBody

@export var is_immortal: bool = true
@export var is_stationary: bool = true
@export var allow_knockback: bool = false
@export var retaliate_enabled: bool = false
@export var retaliate_interval: float = 1.5
@export var retaliate_damage: float = 10.0
@export var retaliate_range: float = 180.0

var retaliate_timer: float = 0.0
var hit_history: Array[Dictionary] = []
var total_damage_taken: float = 0.0
var last_hit_damage: float = 0.0
var last_hit_source: String = ""

var info_label: Label = null
var _label_refresh_timer: float = 0.0

func _init() -> void:
	collision_layer = 5
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = 1000000.0
	max_hp = 1000000.0
	movement_speed = 0.0
	knockback_recovery = 8.0
	experience = 0
	enemy_damage = int(retaliate_damage)
	isBoss = 0

	if get_node_or_null("EnemyBase") == null:
		var base_scene: PackedScene = load("res://Enemy/Base/EnemyBase.tscn")
		var enemy_base: Node2D = base_scene.instantiate()
		enemy_base.name = "EnemyBase"
		add_child(enemy_base)
		var base_sprite := enemy_base.get_node_or_null("Sprite2D") as Sprite2D
		if base_sprite:
			base_sprite.texture = load("res://Textures/Enemy/cyclops.png")
			base_sprite.hframes = 2
			base_sprite.frame = 0

	if get_node_or_null("CollisionShape2D") == null:
		var body_col := CollisionShape2D.new()
		body_col.name = "CollisionShape2D"
		var capsule := CapsuleShape2D.new()
		capsule.radius = 4.0
		capsule.height = 14.0
		body_col.shape = capsule
		add_child(body_col)

	if get_node_or_null("AnimationPlayer") == null:
		var anim_player := AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		var lib := AnimationLibrary.new()
		var walk_anim := Animation.new()
		walk_anim.length = 0.6
		walk_anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(&"walk", walk_anim)
		anim_player.add_animation_library(&"", lib)
		add_child(anim_player)

	info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.position = Vector2(-48, -36)
	info_label.custom_minimum_size = Vector2(96, 20)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.theme = load("res://Themes/DebugButtons.tres")
	info_label.z_index = 20
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_label)

func _ready() -> void:
	if is_immortal:
		hp = 1000000.0
	super._ready()
	add_to_group("target_dummy")
	max_hp = float(hp)
	_sync_hitbox_state()
	_refresh_info_label()

func set_retaliate(enabled: bool) -> void:
	retaliate_enabled = enabled
	retaliate_timer = 0.0
	_sync_hitbox_state()
	_refresh_info_label()

func _sync_hitbox_state() -> void:
	if hitBox == null:
		return
	hitBox.damage = retaliate_damage
	hitBox.set_deferred("monitoring", retaliate_enabled)
	hitBox.set_deferred("monitorable", retaliate_enabled)
	if hitBox.has_node("CollisionShape2D"):
		hitBox.get_node("CollisionShape2D").set_deferred("disabled", not retaliate_enabled)

func _physics_process(delta: float) -> void:
	var keys_to_remove: Array = []
	for debuff_name in active_debuffs.keys():
		var data = active_debuffs[debuff_name]
		data["duration"] -= delta
		if data["duration"] <= 0.0:
			keys_to_remove.append(debuff_name)
	for k in keys_to_remove:
		active_debuffs.erase(k)

	if sprite:
		if has_debuff("curse"):
			sprite.self_modulate = Color(0.8, 0.4, 1.0)
		elif retaliate_enabled:
			sprite.self_modulate = Color(1.0, 0.45, 0.35)
		else:
			sprite.self_modulate = Color(1.0, 0.88, 0.35)

	knockback = knockback.move_toward(Vector2.ZERO, knockback_recovery)
	if not allow_knockback:
		knockback = Vector2.ZERO

	if not is_stationary and player != null and is_instance_valid(player) and movement_speed > 0.0:
		var direction := global_position.direction_to(player.global_position)
		velocity = direction * movement_speed + knockback
		if sprite:
			if direction.x > 0.1:
				sprite.flip_h = true
			elif direction.x < -0.1:
				sprite.flip_h = false
		move_and_slide()
	elif allow_knockback and knockback != Vector2.ZERO:
		velocity = knockback
		move_and_slide()

	if retaliate_enabled and player != null and is_instance_valid(player):
		retaliate_timer += delta
		if retaliate_timer >= retaliate_interval:
			retaliate_timer -= retaliate_interval
			perform_retaliation()

	_prune_hit_history(5.0)
	_label_refresh_timer += delta
	if _label_refresh_timer >= 0.15:
		_label_refresh_timer = 0.0
		_refresh_info_label()

func perform_retaliation() -> void:
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > retaliate_range:
		return
	if player.has_method("_on_hurt_box_hurt"):
		var push_dir := global_position.direction_to(player.global_position)
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.RIGHT
		player._on_hurt_box_hurt(retaliate_damage, push_dir, 60.0, "TargetDummy", self, 1.0)

func _on_hurt_box_hurt(damage, angle, knockback_amount, killer_source: String = "", attacker_node = null, proc_coefficient = 1.0):
	if max_hp <= 0.0:
		max_hp = float(hp)
	var prev_hp := float(hp)
	super._on_hurt_box_hurt(damage, angle, knockback_amount, killer_source, attacker_node, proc_coefficient)
	var dealt := maxf(0.0, prev_hp - float(hp))
	var resolved_source := killer_source
	if resolved_source == "" and attacker_node != null:
		resolved_source = GlobalEvents.infer_attack_source(attacker_node)
	last_hit_damage = dealt
	last_hit_source = GlobalEvents.normalize_damage_source(resolved_source) if resolved_source != "" else "Direct"
	total_damage_taken += dealt
	hit_history.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"amount": dealt,
		"source": last_hit_source,
	})
	if is_immortal:
		hp = max_hp
	if not allow_knockback:
		knockback = Vector2.ZERO
	_refresh_info_label()

func death(killer_source: String = ""):
	if is_immortal:
		is_dying = false
		hp = max_hp
		return
	super.death(killer_source)

func _prune_hit_history(window_sec: float = 5.0) -> void:
	var cutoff := (Time.get_ticks_msec() / 1000.0) - window_sec
	while hit_history.size() > 0 and float(hit_history[0].get("time", 0.0)) < cutoff:
		hit_history.remove_at(0)

func get_rolling_dps(window_sec: float = 5.0) -> float:
	_prune_hit_history(window_sec)
	if window_sec <= 0.0:
		return 0.0
	var total := 0.0
	for entry in hit_history:
		total += float(entry.get("amount", 0.0))
	return total / window_sec

func reset_stats() -> void:
	hit_history.clear()
	total_damage_taken = 0.0
	last_hit_damage = 0.0
	last_hit_source = ""
	_refresh_info_label()

func _refresh_info_label() -> void:
	if info_label == null:
		return
	var dps := get_rolling_dps(5.0)
	var tag := "RETAL " if retaliate_enabled else "DUMMY "
	var curse_val := get_debuff_value("curse")
	var curse_txt := " CURSE+%d%%" % int(round(curse_val * 100.0)) if curse_val > 0.0 else ""
	info_label.text = "%s%.1f DPS\nLast: %.1f%s" % [tag, dps, last_hit_damage, curse_txt]
