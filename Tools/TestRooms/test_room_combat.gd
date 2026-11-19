class_name TestRoomCombat
extends TestRoomBase

const GuiClass = preload("res://Tools/TestRooms/test_room_gui.gd")

const WEAPON_FAMILIES: Array[String] = [
	"icespear", "javelin", "tornado", "poisonbottle",
	"lightningrod", "ritualcircle", "whip", "glasslash", "vampireknives"
]

var player: CharacterBody2D = null
var mock_gui: Control = null
var swarm_manager: Node2D = null
var swarm_type_id: int = -1

# Station coordinates (spaced 600-650px apart so zones never cross-target)
const STATION_POSITIONS: Dictionary = {
	1: Vector2(0, -600),   # North: Single DPS Dummy
	2: Vector2(650, 0),    # East: Pierce Line + 3x3 AoE Matrix
	3: Vector2(0, 600),    # South: Retaliation Dummy + HP Snap Pads
	4: Vector2(-650, 0),   # West: Swarm Pen & Prototype Walls
	0: Vector2(0, 0)       # Center: Spawn pad
}
const ZONE_RADIUS: float = 260.0

var active_zone_idx: int = -1

# Dummy references
var station1_dummy: TargetDummy = null
var station3_dummy: TargetDummy = null
var custom_dummies: Array[TargetDummy] = []
var station2_dummies: Array[TargetDummy] = []

# Wall prototype
var wall_mode: int = 1 # 0: Off, 1: Standard L-box, 2: Corridor
var wall_container: Node2D = null

# Retaliation damage cycle
var retal_damages: Array[float] = [5.0, 15.0, 30.0]
var retal_idx: int = 0
var knockback_enabled: bool = false

# UI references in top bar
var wall_btn: Button = null
var zone_lbl: Label = null

func _get_room_title() -> String:
	return "COMBAT PROVING GROUND"

func _get_keybind_entries() -> Array[Dictionary]:
	return [
		{"key": "1 - 4", "desc": "Warp: 1 DPS | 2 Pierce/AoE | 3 Retal/HP | 4 Swarm/Walls"},
		{"key": "0", "desc": "Center / Recharge Brooch & Buckler CDs"},
		{"key": "F1", "desc": "Open Build Workbench (Weapons, Passives, Endless, Presets)"},
		{"key": "T / Alt+T", "desc": "Spawn TargetDummy at Cursor / Clear Custom Dummies"},
		{"key": "Shift+T", "desc": "Toggle Retaliation & Cycle Damage (5 -> 15 -> 30)"},
		{"key": "K", "desc": "Toggle Knockback on Active Dummies"},
		{"key": "M / Shift+M", "desc": "Spawn 50 Swarm Kobolds at Cursor / Clear Swarm"},
		{"key": "O", "desc": "Cycle Prototype Walls (Standard -> Corridor -> Off)"},
		{"key": "C", "desc": "Clear Active Projectiles & Reset DPS Meter"}
	]

func _setup_room() -> void:
	ring_centers = [
		STATION_POSITIONS[1],
		STATION_POSITIONS[2],
		STATION_POSITIONS[3],
		STATION_POSITIONS[4],
		STATION_POSITIONS[0]
	]
	ring_radii = [50.0, 100.0, ZONE_RADIUS]
	queue_grid_redraw()

	var bg_scene := load("res://World/background.tscn") as PackedScene
	if bg_scene:
		var bg := bg_scene.instantiate()
		bg.z_index = -50
		add_child(bg)

	_setup_mock_gui()
	_setup_player()
	_setup_swarm()
	_setup_station_1()
	_setup_station_2()
	_setup_station_3()
	_setup_station_4_walls()
	_setup_extra_topbar_buttons()

	_update_zone_states(true)

func _setup_mock_gui() -> void:
	mock_gui = GuiClass.new()
	ui_layer.add_child(mock_gui)

func _setup_player() -> void:
	var p_scene := preload("res://Player/player.tscn")
	player = p_scene.instantiate()
	player.position = STATION_POSITIONS[0]
	add_child(player)

	# Safety fallback in case GUI groups were initialized after player ready
	if player.get("gui") == null:
		player.set("gui", mock_gui)

	var p_cam := player.get_node_or_null("Camera2D") as Camera2D
	if p_cam:
		if camera:
			camera.enabled = false
		p_cam.enabled = true
		p_cam.make_current()

func _setup_swarm() -> void:
	var sm_scene := preload("res://Utility/swarm_manager.tscn")
	swarm_manager = sm_scene.instantiate()
	add_child(swarm_manager)

	var tex: Texture2D = load("res://Textures/Enemy/kolbold_weak.png")
	if tex:
		swarm_type_id = swarm_manager.register_enemy_type(tex, 16.0, 2, 1)

func _setup_station_1() -> void:
	station1_dummy = TargetDummy.new()
	station1_dummy.name = "Station1_DPSDummy"
	station1_dummy.position = STATION_POSITIONS[1]
	station1_dummy.is_immortal = true
	station1_dummy.is_stationary = true
	station1_dummy.allow_knockback = knockback_enabled
	add_child(station1_dummy)

func _setup_station_2() -> void:
	# Line of 8 dummies (spaced 28px horizontally)
	var line_start := STATION_POSITIONS[2] + Vector2(-98, -50)
	for i in range(8):
		var d := TargetDummy.new()
		d.position = line_start + Vector2(i * 28, 0)
		d.is_immortal = true
		d.is_stationary = true
		d.allow_knockback = knockback_enabled
		add_child(d)
		station2_dummies.append(d)

	# 3x3 Cluster (spaced 24px)
	var cluster_center := STATION_POSITIONS[2] + Vector2(0, 50)
	for r in range(-1, 2):
		for c in range(-1, 2):
			var d := TargetDummy.new()
			d.position = cluster_center + Vector2(c * 24, r * 24)
			d.is_immortal = true
			d.is_stationary = true
			d.allow_knockback = knockback_enabled
			add_child(d)
			station2_dummies.append(d)

func _setup_station_3() -> void:
	station3_dummy = TargetDummy.new()
	station3_dummy.name = "Station3_RetalDummy"
	station3_dummy.position = STATION_POSITIONS[3]
	station3_dummy.is_immortal = true
	station3_dummy.is_stationary = true
	station3_dummy.retaliate_enabled = true
	station3_dummy.retaliate_damage = retal_damages[retal_idx]
	station3_dummy.allow_knockback = knockback_enabled
	add_child(station3_dummy)

func _setup_station_4_walls() -> void:
	wall_container = Node2D.new()
	wall_container.name = "PrototypeWalls"
	add_child(wall_container)
	_build_wall_geometry()

func _build_wall_geometry() -> void:
	for c in wall_container.get_children():
		c.queue_free()

	if wall_mode == 0:
		return

	var center := STATION_POSITIONS[4]

	if wall_mode == 1:
		# Standard L-box corner
		_add_wall_segment(center + Vector2(-60, -60), Vector2(120, 12))
		_add_wall_segment(center + Vector2(-60, -60), Vector2(12, 120))
	elif wall_mode == 2:
		# Narrow Corridor (chokepoint testing)
		_add_wall_segment(center + Vector2(-60, -30), Vector2(120, 12))
		_add_wall_segment(center + Vector2(-60, 30), Vector2(120, 12))

func _add_wall_segment(top_left: Vector2, size: Vector2) -> void:
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 1
	wall_container.add_child(sb)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = top_left + size * 0.5
	sb.add_child(col)

	var cr := ColorRect.new()
	cr.position = top_left
	cr.size = size
	cr.color = Color(0.3, 0.45, 0.7, 0.75)
	sb.add_child(cr)

func _setup_extra_topbar_buttons() -> void:
	var btn_build := Button.new()
	btn_build.text = "F1 Build"
	btn_build.pressed.connect(func():
		if debug_controller:
			debug_controller.toggle_workbench()
	)
	extra_buttons_bar.add_child(btn_build)

	zone_lbl = Label.new()
	zone_lbl.text = "Zone: Center"
	zone_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	extra_buttons_bar.add_child(zone_lbl)

	wall_btn = Button.new()
	wall_btn.text = "Walls: Std"
	wall_btn.pressed.connect(_cycle_wall_mode)
	extra_buttons_bar.add_child(wall_btn)

	var snap_lbl := Label.new()
	snap_lbl.text = "HP:"
	extra_buttons_bar.add_child(snap_lbl)

	for pct in [100, 95, 90, 29, 19]:
		var b := Button.new()
		b.text = "%d%%" % pct
		var val := float(pct) / 100.0
		b.pressed.connect(func(): _snap_player_hp(val))
		extra_buttons_bar.add_child(b)

func _process(_delta: float) -> void:
	_update_zone_states(false)

func _update_zone_states(force: bool) -> void:
	var next_zone := -1
	if player and is_instance_valid(player):
		for z in [1, 2, 3, 4]:
			if player.global_position.distance_to(STATION_POSITIONS[z]) <= ZONE_RADIUS:
				next_zone = z
				break
	if not force and next_zone == active_zone_idx:
		return
	active_zone_idx = next_zone
	if zone_lbl:
		var z_names := {-1: "Center", 1: "1 DPS", 2: "2 Pierce/AoE", 3: "3 Retal", 4: "4 Swarm"}
		zone_lbl.text = "Zone: %s" % z_names.get(active_zone_idx, "Center")

	_set_dummy_zone_active(station1_dummy, active_zone_idx == 1)
	for d in station2_dummies:
		_set_dummy_zone_active(d, active_zone_idx == 2)
	_set_dummy_zone_active(station3_dummy, active_zone_idx == 3)

func _set_dummy_zone_active(dummy: TargetDummy, active: bool) -> void:
	if dummy == null or not is_instance_valid(dummy):
		return
	dummy.modulate.a = 1.0 if active else 0.25
	dummy.collision_layer = 5 if active else 0
	dummy.set_physics_process(active)
	if active:
		if not dummy.is_in_group("enemy"):
			dummy.add_to_group("enemy")
	else:
		if dummy.is_in_group("enemy"):
			dummy.remove_from_group("enemy")
	var hb := dummy.get("hurtBox") as Area2D
	if hb and is_instance_valid(hb):
		hb.set_deferred("monitoring", active)
		hb.set_deferred("monitorable", active)
		var cs := hb.get_node_or_null("CollisionShape2D")
		if cs:
			cs.set_deferred("disabled", not active)

func _snap_player_hp(ratio: float) -> void:
	if not player:
		return
	var target_hp := maxf(1.0, round(float(player.maxhp) * ratio))
	player._set_hp(target_hp)

func _cycle_wall_mode() -> void:
	wall_mode = (wall_mode + 1) % 3
	_build_wall_geometry()
	if wall_btn:
		match wall_mode:
			0: wall_btn.text = "Walls: Off"
			1: wall_btn.text = "Walls: Std"
			2: wall_btn.text = "Walls: Corr"

func _toggle_knockback() -> void:
	knockback_enabled = not knockback_enabled
	for d in [station1_dummy, station3_dummy] + station2_dummies + custom_dummies:
		if is_instance_valid(d):
			d.allow_knockback = knockback_enabled

func _cycle_retaliation_damage() -> void:
	retal_idx = (retal_idx + 1) % retal_damages.size()
	var dmg := retal_damages[retal_idx]
	if station3_dummy and is_instance_valid(station3_dummy):
		station3_dummy.retaliate_damage = dmg
		station3_dummy.enemy_damage = int(dmg)
		station3_dummy._refresh_info_label()

func _spawn_custom_dummy_at_mouse() -> void:
	var m_pos := get_global_mouse_position()
	var d := TargetDummy.new()
	d.position = m_pos
	d.is_immortal = true
	d.is_stationary = true
	d.allow_knockback = knockback_enabled
	add_child(d)
	custom_dummies.append(d)

func _clear_custom_dummies() -> void:
	for d in custom_dummies:
		if is_instance_valid(d):
			d.queue_free()
	custom_dummies.clear()

func _spawn_swarm_batch(count: int = 50) -> void:
	if not swarm_manager:
		return
	var center := get_global_mouse_position()
	for i in range(count):
		var offset := Vector2(randf_range(-40, 40), randf_range(-40, 40))
		swarm_manager.add_enemy(center + offset, 20.0, 20.0, 25.0, 1, 5, swarm_type_id)

func _clear_swarm() -> void:
	if swarm_manager:
		swarm_manager.clear_all()

func _clear_projectiles_and_reset_dps() -> void:
	for d in [station1_dummy, station3_dummy] + station2_dummies + custom_dummies:
		if is_instance_valid(d):
			d.reset_stats()

	# Clear flying projectiles under player weapons or stage
	for child in get_tree().get_nodes_in_group("attack"):
		if is_instance_valid(child) and child != player:
			child.queue_free()

	if debug_controller and debug_controller.telemetry:
		if debug_controller.telemetry.has_method("reset_meter"):
			debug_controller.telemetry.reset_meter()

func _reset_room_state() -> void:
	_clear_custom_dummies()
	_clear_swarm()
	_clear_projectiles_and_reset_dps()
	if player:
		player.position = STATION_POSITIONS[0]
		player._set_hp(player.maxhp)
	if debug_controller:
		debug_controller.reset_item_cooldowns()
	_update_zone_states(true)

func _handle_room_key(event: InputEventKey) -> bool:
	match DebugController.get_effective_keycode(event):
		KEY_1:
			if player: player.position = STATION_POSITIONS[1] + Vector2(0, 80)
			_update_zone_states(true)
			return true
		KEY_2:
			if player: player.position = STATION_POSITIONS[2] + Vector2(-130, 0)
			_update_zone_states(true)
			return true
		KEY_3:
			if player: player.position = STATION_POSITIONS[3] + Vector2(0, -80)
			_update_zone_states(true)
			return true
		KEY_4:
			if player: player.position = STATION_POSITIONS[4] + Vector2(80, 0)
			_update_zone_states(true)
			return true
		KEY_0:
			if player:
				player.position = STATION_POSITIONS[0]
			if debug_controller:
				debug_controller.reset_item_cooldowns()
			_update_zone_states(true)
			return true
		KEY_T:
			if event.alt_pressed:
				_clear_custom_dummies()
			elif event.shift_pressed:
				_cycle_retaliation_damage()
			else:
				_spawn_custom_dummy_at_mouse()
			return true
		KEY_K:
			_toggle_knockback()
			return true
		KEY_M:
			if event.shift_pressed:
				_clear_swarm()
			else:
				_spawn_swarm_batch(50)
			return true
		KEY_O:
			_cycle_wall_mode()
			return true
		KEY_C:
			_clear_projectiles_and_reset_dps()
			return true

	return false
