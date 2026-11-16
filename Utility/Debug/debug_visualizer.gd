class_name DebugVisualizer
extends Node2D

var last_violations: Array[String] = []
var _label_font: Font = ThemeDB.fallback_font

func _init() -> void:
	name = "DebugVisualizer"
	z_index = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func set_visualizer_enabled(enabled: bool) -> void:
	visible = enabled
	_sync_boss_debug_labels(enabled)
	if enabled:
		queue_redraw()

func _sync_boss_debug_labels(enabled: bool) -> void:
	if not get_tree():
		return
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == null or not is_instance_valid(node):
			continue
		var lbl = node.get("debug_label")
		if lbl != null and is_instance_valid(lbl) and lbl is CanvasItem:
			lbl.visible = enabled

func _process(_delta: float) -> void:
	if not visible:
		return
	queue_redraw()

func _is_enemy_hazard(atk: Area2D) -> bool:
	if atk.name == "HitBox":
		return true
	if (atk.collision_layer & 2) != 0 and (atk.collision_layer & 4) == 0:
		return true
	var parent := atk.get_parent()
	if parent and is_instance_valid(parent) and (parent is EnemyBody or parent.is_in_group("enemy")):
		return true
	if atk.owner and is_instance_valid(atk.owner) and (atk.owner is EnemyBody or atk.owner.is_in_group("enemy")):
		return true
	return false

func audit_attack_compliance() -> Array[String]:
	var violations: Array[String] = []
	if not get_tree():
		last_violations = violations
		return violations
	for atk in get_tree().get_nodes_in_group("attack"):
		if atk == null or not is_instance_valid(atk) or atk.is_queued_for_deletion():
			continue
		if not (atk is Area2D):
			continue
		if _is_enemy_hazard(atk):
			continue
		if (atk.collision_layer & 4) == 0:
			violations.append("%s: missing Layer 3 (bit 4)" % atk.name)
		if atk.get_node_or_null("CollisionShape2D") == null:
			violations.append("%s: missing child 'CollisionShape2D'" % atk.name)
	last_violations = violations
	return violations

func _get_view_rect(player_node: Node2D) -> Rect2:
	var center := Vector2.ZERO
	if get_viewport() and get_viewport().get_camera_2d():
		center = get_viewport().get_camera_2d().get_screen_center_position()
	elif player_node and is_instance_valid(player_node):
		center = player_node.global_position
	return Rect2(center - Vector2(460.0, 300.0), Vector2(920.0, 600.0))

func _draw() -> void:
	if not visible or not get_tree():
		return

	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	var view_rect := _get_view_rect(player_node)

	# 1. SwarmManager spatial grid & individual swarm enemies
	var sm := get_tree().get_first_node_in_group("swarm_manager")
	if sm and is_instance_valid(sm):
		var grid = sm.get("spatial_grid")
		if grid is Dictionary:
			for cell_key in grid.keys():
				if cell_key is Vector2:
					var cell_pos := Vector2(cell_key.x * 40.0, cell_key.y * 40.0)
					var cell_rect := Rect2(cell_pos, Vector2(40.0, 40.0))
					if view_rect.intersects(cell_rect):
						draw_rect(cell_rect, Color(0.25, 0.75, 0.95, 0.25), false, 1.0)
		var swarm_list = sm.get("swarm_data")
		var type_cache = sm.get("enemy_type_cache")
		if swarm_list is Array:
			for se in swarm_list:
				if se == null or se.is_dead:
					continue
				if not view_rect.has_point(se.position):
					continue
				var rad := 10.0
				if type_cache is Dictionary and type_cache.has(se.type_id):
					rad = sqrt(float(type_cache[se.type_id].get("radius_sq", 100.0)))
				var hp_ratio := clampf(se.hp / maxf(1.0, se.max_hp), 0.0, 1.0)
				var col := Color(1.0 - hp_ratio, hp_ratio, 0.2, 0.75)
				draw_arc(se.position, rad, 0.0, TAU, 16, col, 1.0)
				if se.has_debuff("curse"):
					draw_arc(se.position, rad + 2.5, 0.0, TAU, 16, Color(0.75, 0.3, 1.0, 0.85), 1.0)

	# 2. Player pickup, collection, and hurtbox radii
	if player_node and is_instance_valid(player_node):
		var grab_area := player_node.get_node_or_null("GrabArea") as Area2D
		if grab_area:
			_draw_area_shape(grab_area, Color(0.25, 0.95, 0.45, 0.45), 1.0)
		var collect_area := player_node.get_node_or_null("CollectArea") as Area2D
		if collect_area:
			_draw_area_shape(collect_area, Color(0.2, 0.85, 1.0, 0.55), 1.0)
		var hurt_box := player_node.get_node_or_null("HurtBox") as Area2D
		if hurt_box:
			var dt := hurt_box.get_node_or_null("DisableTimer") as Timer
			var is_invuln := dt != null and not dt.is_stopped()
			var hb_col := Color(0.3, 0.95, 1.0, 0.95) if is_invuln else Color(1.0, 0.9, 0.25, 0.85)
			_draw_area_shape(hurt_box, hb_col, 1.5)

	# 3. Attacks & Enemy HitBoxes + Rule 16/17 Audit
	var violations: Array[String] = []
	for atk in get_tree().get_nodes_in_group("attack"):
		if atk == null or not is_instance_valid(atk) or atk.is_queued_for_deletion():
			continue
		if not (atk is Area2D):
			continue
		if not view_rect.has_point(atk.global_position):
			if _is_enemy_hazard(atk):
				continue
		if _is_enemy_hazard(atk):
			if view_rect.has_point(atk.global_position):
				_draw_area_shape(atk, Color(1.0, 0.25, 0.75, 0.65), 1.0)
			continue

		var atk_area := atk as Area2D
		var layer_ok: bool = (atk_area.collision_layer & 4) != 0
		var has_cs: bool = atk_area.get_node_or_null("CollisionShape2D") != null
		if not layer_ok:
			violations.append("%s: missing Layer 3 (bit 4)" % atk_area.name)
		if not has_cs:
			violations.append("%s: missing child 'CollisionShape2D'" % atk_area.name)

		var is_valid: bool = layer_ok and has_cs
		var atk_col := Color(1.0, 0.55, 0.1, 0.8) if is_valid else Color(1.0, 0.1, 0.1, 0.95)
		_draw_area_shape(atk_area, atk_col, 1.5 if is_valid else 2.0)
		if not is_valid and _label_font:
			draw_string(_label_font, atk_area.global_position + Vector2(-18, -12), "RULE16/17!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.2, 0.2))

	last_violations = violations

func _draw_area_shape(area: Area2D, col: Color, width: float) -> void:
	for child in area.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs := child as CollisionShape2D
		if cs.disabled or cs.shape == null:
			continue
		var xf: Transform2D = area.global_transform * cs.transform
		draw_set_transform_matrix(xf)
		if cs.shape is CircleShape2D:
			var r: float = (cs.shape as CircleShape2D).radius
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, col, width)
		elif cs.shape is RectangleShape2D:
			var sz: Vector2 = (cs.shape as RectangleShape2D).size
			draw_rect(Rect2(-sz * 0.5, sz), col, false, width)
		elif cs.shape is CapsuleShape2D:
			var cap := cs.shape as CapsuleShape2D
			var rect_sz := Vector2(cap.radius * 2.0, cap.height)
			draw_rect(Rect2(-rect_sz * 0.5, rect_sz), col, false, width)
		draw_set_transform_matrix(Transform2D.IDENTITY)
