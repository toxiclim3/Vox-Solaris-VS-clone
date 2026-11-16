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

# Station coordinates
const STATION_POSITIONS: Dictionary = {
	1: Vector2(0, -220),   # North: Single DPS Dummy
	2: Vector2(260, 0),    # East: Pierce Line + 3x3 AoE Matrix
	3: Vector2(0, 220),    # South: Retaliation Dummy + HP Snap Pads
	4: Vector2(-260, 0),   # West: Swarm Pen & Prototype Walls
	0: Vector2(0, 0)       # Center: Spawn pad
}

var current_weapon_idx: int = 0
var current_weapon_tier: int = 1

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
var weapon_lbl: Label = null
var hp_snap_btn: OptionButton = null
var wall_btn: Button = null

func _get_room_title() -> String:
	return "COMBAT PROVING GROUND"

func _get_keybind_entries() -> Array[Dictionary]:
	return [
		{"key": "1 - 4", "desc": "Warp: 1 DPS | 2 Pierce/AoE | 3 Retal/HP | 4 Swarm/Walls"},
		{"key": "0", "desc": "Center / Recharge Brooch & Buckler CDs"},
		{"key": "Q / E", "desc": "Previous / Next Weapon Family (Auto-Equips Lv1)"},
		{"key": "Up / Down", "desc": "Step Weapon Tier (Lv 1..4, Endless +1)"},
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
	ring_radii = [50.0, 100.0, 180.0, 250.0]
	queue_grid_redraw()

	_setup_mock_gui()
	_setup_player()
	_setup_swarm()
	_setup_station_1()
	_setup_station_2()
	_setup_station_3()
	_setup_station_4_walls()
	_setup_extra_topbar_buttons()

	_equip_weapon(current_weapon_idx, current_weapon_tier)

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
	weapon_lbl = Label.new()
	weapon_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	extra_buttons_bar.add_child(weapon_lbl)

	var btn_prev_w := Button.new()
	btn_prev_w.text = "<"
	btn_prev_w.pressed.connect(func(): _cycle_weapon(-1))
	extra_buttons_bar.add_child(btn_prev_w)

	var btn_next_w := Button.new()
	btn_next_w.text = ">"
	btn_next_w.pressed.connect(func(): _cycle_weapon(1))
	extra_buttons_bar.add_child(btn_next_w)

	var btn_up_tier := Button.new()
	btn_up_tier.text = "+Tier"
	btn_up_tier.pressed.connect(func(): _step_tier(1))
	extra_buttons_bar.add_child(btn_up_tier)

	var btn_down_tier := Button.new()
	btn_down_tier.text = "-Tier"
	btn_down_tier.pressed.connect(func(): _step_tier(-1))
	extra_buttons_bar.add_child(btn_down_tier)

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

func _equip_weapon(family_idx: int, tier: int) -> void:
	if not player:
		return
	family_idx = posmod(family_idx, WEAPON_FAMILIES.size())
	current_weapon_idx = family_idx
	current_weapon_tier = clamp(tier, 1, 5)

	var fam := WEAPON_FAMILIES[current_weapon_idx]
	player.reset_all_upgrades()

	var upgrade_id := ""
	if current_weapon_tier <= 4:
		upgrade_id = "%s%d" % [fam, current_weapon_tier]
	else:
		upgrade_id = "%s_endless" % fam

	if UpgradeDb.UPGRADES.has(upgrade_id):
		player.grant_upgrade_with_prereqs(upgrade_id)

	var tier_str := str(current_weapon_tier) if current_weapon_tier <= 4 else "Endless"
	if weapon_lbl:
		weapon_lbl.text = "%s Lv%s" % [fam.capitalize(), tier_str]

func _cycle_weapon(delta: int) -> void:
	_equip_weapon(current_weapon_idx + delta, current_weapon_tier)

func _step_tier(delta: int) -> void:
	var next_tier: int = clampi(current_weapon_tier + delta, 1, 5)
	_equip_weapon(current_weapon_idx, next_tier)

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
		# Re-arm brooch & buckler
		if "brooch_current_capacity" in player and "brooch_max_capacity" in player:
			player.brooch_current_capacity = player.brooch_max_capacity
		if "buckler_cooldown_timer" in player:
			player.buckler_cooldown_timer = 0.0

func _handle_room_key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_1:
			if player: player.position = STATION_POSITIONS[1] + Vector2(0, 80)
			return true
		KEY_2:
			if player: player.position = STATION_POSITIONS[2] + Vector2(-130, 0)
			return true
		KEY_3:
			if player: player.position = STATION_POSITIONS[3] + Vector2(0, -80)
			return true
		KEY_4:
			if player: player.position = STATION_POSITIONS[4] + Vector2(80, 0)
			return true
		KEY_0:
			if player:
				player.position = STATION_POSITIONS[0]
				if "brooch_current_capacity" in player and "brooch_max_capacity" in player:
					player.brooch_current_capacity = player.brooch_max_capacity
				if "buckler_cooldown_timer" in player:
					player.buckler_cooldown_timer = 0.0
			return true
		KEY_Q:
			_cycle_weapon(-1)
			return true
		KEY_E:
			_cycle_weapon(1)
			return true
		KEY_UP:
			_step_tier(1)
			return true
		KEY_DOWN:
			_step_tier(-1)
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
