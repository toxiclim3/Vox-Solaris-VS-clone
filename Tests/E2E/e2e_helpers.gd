# SPDX-License-Identifier: GPL-3.0-or-later
# Shared opaque-box E2E test helpers for Inritus (Godot 4.6+)
# Provides defensive probing, scene spawn/cleanup, physics/frame stepping,
# autoload state backup/restore, input simulation, and Python CLI wrappers.

class_name E2EHelpers
extends RefCounted

const PLAYER_SCENE_PATH := "res://Player/player.tscn"
const WORLD_SCENE_PATH := "res://World/world.tscn"
const ITEM_OPTION_SCENE_PATH := "res://Utility/item_option.tscn"
const SETTINGS_MENU_SCENE_PATH := "res://Utility/settings_menu.tscn"
const DEBUG_CONTROLLER_SCRIPT_PATH := "res://Utility/Debug/debug_controller.gd"

const DEFAULT_ACTIONS: Array[String] = [
	"left", "right", "up", "down",
	"ui_left", "ui_right", "ui_up", "ui_down",
	"ui_accept", "ui_cancel", "click", "menu", "debugMenu", "mobility"
]


class _E2EStubGui extends Control:
	var levelPanel: Control
	var bossLevelPanel: Control
	var deathPanel: Control
	var collectedWeapons: HBoxContainer
	var collectedUpgrades: HBoxContainer
	var collectedBossItems: HBoxContainer
	var last_exp: float = 0.0
	var last_exp_cap: float = 0.0
	var last_level: int = 1
	var last_timer: int = 0
	var levelup_count: int = 0
	var boss_levelup_count: int = 0
	var last_levelup_options: Array = []
	var last_boss_options: Array = []
	var adjusted_upgrades: Array = []

	func _init() -> void:
		name = "E2EStubGUI"
		process_mode = Node.PROCESS_MODE_ALWAYS
		add_to_group("gui")

		levelPanel = Control.new()
		levelPanel.name = "LevelUp"
		levelPanel.visible = false
		add_child(levelPanel)

		bossLevelPanel = Control.new()
		bossLevelPanel.name = "BossLevelUp"
		bossLevelPanel.visible = false
		add_child(bossLevelPanel)

		deathPanel = Control.new()
		deathPanel.name = "DeathPanel"
		deathPanel.visible = false
		add_child(deathPanel)

		collectedWeapons = HBoxContainer.new()
		collectedWeapons.name = "CollectedWeapons"
		add_child(collectedWeapons)

		collectedUpgrades = HBoxContainer.new()
		collectedUpgrades.name = "CollectedUpgrades"
		add_child(collectedUpgrades)

		collectedBossItems = HBoxContainer.new()
		collectedBossItems.name = "CollectedBossItems"
		add_child(collectedBossItems)

	func set_expbar(current: float, maximum: float) -> void:
		last_exp = current
		last_exp_cap = maximum

	func set_level_text(level: int) -> void:
		last_level = level

	func update_timer(time_seconds: int) -> void:
		last_timer = time_seconds

	func adjust_gui_collection(upgrade: String) -> void:
		adjusted_upgrades.append(upgrade)

	func refresh_gui_collection() -> void:
		pass

	func hide_level_panels() -> void:
		levelPanel.visible = false
		bossLevelPanel.visible = false

	func show_levelup(options: Array, level: int) -> void:
		last_level = level
		last_levelup_options = options.duplicate()
		levelup_count += 1
		levelPanel.visible = true

	func show_boss_levelup(options: Array) -> void:
		last_boss_options = options.duplicate()
		boss_levelup_count += 1
		bossLevelPanel.visible = true

	func show_death_panel(_has_won: bool) -> void:
		deathPanel.visible = true


# -----------------------------------------------------------------------------
# 0. Autoload Lookup (safe at compile-time even from SceneTree entry scripts)
# -----------------------------------------------------------------------------

static func get_autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/" + autoload_name)


# -----------------------------------------------------------------------------
# 1. Defensive Probing
# -----------------------------------------------------------------------------

static func has_prop(obj: Variant, prop: String) -> bool:
	if obj == null:
		return false
	if obj is Dictionary:
		return (obj as Dictionary).has(prop)
	if obj is Object:
		if not is_instance_valid(obj):
			return false
		return prop in obj
	return false


static func get_prop(obj: Variant, prop: String, default: Variant = null) -> Variant:
	if not has_prop(obj, prop):
		return default
	if obj is Dictionary:
		return (obj as Dictionary).get(prop, default)
	return (obj as Object).get(prop)


static func set_prop(obj: Variant, prop: String, val: Variant) -> bool:
	if not has_prop(obj, prop):
		return false
	if obj is Dictionary:
		(obj as Dictionary)[prop] = val
		return true
	(obj as Object).set(prop, val)
	return true


static func has_method_safe(obj: Variant, method: String) -> bool:
	if obj == null or not (obj is Object) or not is_instance_valid(obj):
		return false
	return (obj as Object).has_method(method)


static func has_signal_safe(obj: Variant, sig_name: String) -> bool:
	if obj == null or not (obj is Object) or not is_instance_valid(obj):
		return false
	return (obj as Object).has_signal(sig_name)


static func safe_call(obj: Variant, method: String, args: Array = [], default: Variant = null) -> Variant:
	if not has_method_safe(obj, method):
		return default
	return (obj as Object).callv(method, args)


static func find_node_recursive(root: Node, node_name: String) -> Node:
	if root == null or not is_instance_valid(root):
		return null
	if String(root.name) == node_name:
		return root
	if node_name.begins_with("%") or node_name.contains("/"):
		var direct := root.get_node_or_null(node_name)
		if direct != null:
			return direct
	for child in root.get_children():
		var found := find_node_recursive(child, node_name)
		if found != null:
			return found
	return null


static func find_child_by_name_or_group(root: Node, node_name: String, group_name: String = "") -> Node:
	if root == null or not is_instance_valid(root):
		return null
	if node_name != "":
		var by_name := find_node_recursive(root, node_name)
		if by_name != null:
			return by_name
	if group_name != "":
		if root.is_in_group(group_name):
			return root
		var in_group := find_nodes_in_group_under(root, group_name)
		if not in_group.is_empty():
			return in_group[0]
	return null


static func find_nodes_in_group_under(root: Node, group_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if root == null or not is_instance_valid(root) or group_name == "":
		return result
	for child in root.get_children():
		if child.is_in_group(group_name):
			result.append(child)
		result.append_array(find_nodes_in_group_under(child, group_name))
	return result


# -----------------------------------------------------------------------------
# 2. Scene / Node Spawning & Deterministic Cleanup
# -----------------------------------------------------------------------------

static func spawn_player(tree: SceneTree, char_id: String = "mage") -> Node:
	if tree == null:
		return null
	var packed := load(PLAYER_SCENE_PATH) as PackedScene
	if packed == null:
		return null

	var global_events := get_autoload("GlobalEvents")
	if char_id != "" and global_events != null:
		global_events.set("selected_character", char_id)

	var host := Node2D.new()
	host.name = "E2EPlayerHost"
	tree.root.add_child(host)

	# Give each E2E-spawned player its own stub GUI / GUI layer when no real
	# (non-stub) World GUI exists, so freeing an earlier player never leaves
	# another concurrent player's `gui` as a dangling reference.
	var has_real_gui_layer := false
	var existing_stub_layers: Array[Node] = []
	for gl in tree.get_nodes_in_group("gui_layer"):
		if gl.has_meta("_e2e_stub_gui_layer"):
			existing_stub_layers.append(gl)
		else:
			has_real_gui_layer = true

	var has_real_gui := false
	var existing_stub_guis: Array[Node] = []
	for g in tree.get_nodes_in_group("gui"):
		if g is _E2EStubGui:
			existing_stub_guis.append(g)
		else:
			has_real_gui = true

	if not has_real_gui_layer:
		for gl in existing_stub_layers:
			gl.remove_from_group("gui_layer")
		var gui_layer := CanvasLayer.new()
		gui_layer.name = "E2EStubGUILayer"
		gui_layer.set_meta("_e2e_stub_gui_layer", true)
		gui_layer.add_to_group("gui_layer")
		host.add_child(gui_layer)

	if not has_real_gui:
		for g in existing_stub_guis:
			g.remove_from_group("gui")
		var stub_gui := _E2EStubGui.new()
		host.add_child(stub_gui)

	var player := packed.instantiate()
	if player == null:
		for gl in existing_stub_layers:
			if is_instance_valid(gl):
				gl.add_to_group("gui_layer")
		for g in existing_stub_guis:
			if is_instance_valid(g):
				g.add_to_group("gui")
		host.get_parent().remove_child(host)
		host.free()
		return null

	player.set_meta("_e2e_host", host)
	host.add_child(player)

	for gl in existing_stub_layers:
		if is_instance_valid(gl):
			gl.add_to_group("gui_layer")
	for g in existing_stub_guis:
		if is_instance_valid(g):
			g.add_to_group("gui")

	return player


## Spawns a player and awaits 1 SceneTree physics frame so CharacterBody2D
## move_and_slide() and get_real_velocity() are initialized (avoiding frame-0 NaN).
static func spawn_player_ready(tree: SceneTree, char_id: String = "mage") -> Node:
	var player := spawn_player(tree, char_id)
	if player != null and tree != null:
		await step_tree_frames(tree, 1)
	return player


static func spawn_world(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var packed := load(WORLD_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var world := packed.instantiate()
	if world == null:
		return null
	tree.root.add_child(world)
	return world


static func spawn_item_option(tree: SceneTree, item_id: String = "food") -> Control:
	if tree == null:
		return null
	var packed := load(ITEM_OPTION_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var card := packed.instantiate() as Control
	if card == null:
		return null
	card.set("item", item_id)
	tree.root.add_child(card)
	return card


static func spawn_settings_menu(tree: SceneTree) -> CanvasLayer:
	if tree == null:
		return null
	var packed := load(SETTINGS_MENU_SCENE_PATH) as PackedScene
	if packed == null:
		return null
	var menu := packed.instantiate() as CanvasLayer
	if menu == null:
		return null
	tree.root.add_child(menu)
	return menu


static func attach_debug_workbench(gui_or_tree: Object, world_root: Node = null) -> Dictionary:
	var ctrl_script := load(DEBUG_CONTROLLER_SCRIPT_PATH)
	if ctrl_script == null:
		return {}

	var tree: SceneTree = null
	var gui_root: Node = null
	var aux_host: Node = null

	if gui_or_tree is SceneTree:
		tree = gui_or_tree as SceneTree
		gui_root = tree.get_first_node_in_group("gui")
		if gui_root == null:
			aux_host = Node2D.new()
			aux_host.name = "E2EDebugHost"
			tree.root.add_child(aux_host)
			var stub_gui := _E2EStubGui.new()
			aux_host.add_child(stub_gui)
			gui_root = stub_gui
	elif gui_or_tree is Node:
		gui_root = gui_or_tree as Node
		tree = gui_root.get_tree()
	else:
		return {}

	var ctrl: Node = ctrl_script.new()
	var ctrl_parent: Node = aux_host if aux_host != null else (world_root if world_root != null else (tree.root if tree != null else gui_root))
	ctrl_parent.add_child(ctrl)
	ctrl.call("attach", gui_root, world_root)

	return {
		"controller": ctrl,
		"workbench": get_prop(ctrl, "workbench", null),
		"gui_root": gui_root,
		"aux_host": aux_host
	}


static func cleanup_node(target: Variant) -> void:
	if target == null:
		return
	if target is Dictionary:
		var dict := target as Dictionary
		var ctrl: Variant = dict.get("controller", null)
		var aux_host: Variant = dict.get("aux_host", null)
		var wb: Variant = dict.get("workbench", null)
		if wb != null and wb is Node and is_instance_valid(wb):
			if (wb as Node).get_parent() != null:
				(wb as Node).get_parent().remove_child(wb as Node)
			(wb as Node).free()
		if ctrl != null and ctrl is Node and is_instance_valid(ctrl):
			var tele: Variant = get_prop(ctrl, "telemetry", null)
			var vis: Variant = get_prop(ctrl, "visualizer", null)
			var sw: Variant = get_prop(ctrl, "switcher", null)
			for sub in [tele, vis, sw]:
				if sub != null and sub is Node and is_instance_valid(sub):
					if (sub as Node).get_parent() != null:
						(sub as Node).get_parent().remove_child(sub as Node)
					(sub as Node).free()
			if (ctrl as Node).get_parent() != null:
				(ctrl as Node).get_parent().remove_child(ctrl as Node)
			(ctrl as Node).free()
		if aux_host != null and aux_host is Node and is_instance_valid(aux_host):
			if (aux_host as Node).get_parent() != null:
				(aux_host as Node).get_parent().remove_child(aux_host as Node)
			(aux_host as Node).free()
		return

	if not (target is Node):
		return
	var node := target as Node
	if not is_instance_valid(node):
		return

	var host: Node = null
	if node.has_meta("_e2e_host"):
		var raw_host: Variant = node.get_meta("_e2e_host")
		if raw_host is Node and is_instance_valid(raw_host):
			host = raw_host as Node

	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()

	if host != null and is_instance_valid(host):
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()


static func cleanup_nodes(nodes: Array) -> void:
	for n in nodes:
		cleanup_node(n)
	nodes.clear()


static func free_nodes(nodes: Array) -> void:
	cleanup_nodes(nodes)


# -----------------------------------------------------------------------------
# 3. Physics & Process Stepping
# -----------------------------------------------------------------------------
# IMPORTANT: CharacterBody2D.move_and_slide() always uses the SceneTree physics
# tick (1.0 / Engine.physics_ticks_per_second, default 1/60s), NOT the `delta`
# parameter passed to `_physics_process(delta)`.
# - Immediately after synchronous `spawn_player()`, before any SceneTree physics
#   frame has elapsed, `move_and_slide()` can yield `get_real_velocity() == (nan, nan)`
#   and zero displacement. Call `await spawn_player_ready(tree, char_id)` or
#   `await step_tree_frames(tree, 1)` before measuring movement or stride.
# - For `stride_distance_total` / `move_and_slide()` parity, prefer
#   `await step_tree_frames(tree, frames)`, or call `step_physics(player, frames, 1.0 / 60.0)`
#   after at least 1 SceneTree physics frame.

static func step_physics(node: Node, frames: int, delta: float = 1.0 / 60.0, include_children: bool = true) -> void:
	if node == null or not is_instance_valid(node) or frames <= 0:
		return
	if node is CharacterBody2D:
		var tree_dt := 1.0 / float(maxi(1, Engine.physics_ticks_per_second))
		if absf(delta - tree_dt) > 0.001:
			push_warning("E2EHelpers.step_physics: CharacterBody2D.move_and_slide() uses SceneTree physics tick (%.5fs), not delta=%.5fs. Use step_tree_frames() or delta=1.0/60.0 for displacement/stride parity." % [tree_dt, delta])
	for _i in range(frames):
		if not is_instance_valid(node):
			break
		_step_node_recursive(node, delta, include_children)


static func _step_node_recursive(node: Node, delta: float, include_children: bool) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var should_process := (not node.is_inside_tree()) or node.can_process()
	if should_process and node.is_physics_processing() and node.has_method("_physics_process"):
		node._physics_process(delta)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if should_process and node.is_processing() and node.has_method("_process"):
		node._process(delta)
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if include_children:
		for child in node.get_children():
			if is_instance_valid(child):
				_step_node_recursive(child, delta, true)


static func step_tree_frames(tree: SceneTree, frames: int) -> void:
	if tree == null or frames <= 0:
		return
	for _i in range(frames):
		await tree.physics_frame


# -----------------------------------------------------------------------------
# 4. Autoload State Backup & Restore
# -----------------------------------------------------------------------------

static func backup_settings() -> Dictionary:
	var settings_mgr := get_autoload("SettingsManager")
	var save_path := "user://settings.cfg"
	if settings_mgr != null and has_prop(settings_mgr, "SAVE_PATH"):
		save_path = str(get_prop(settings_mgr, "SAVE_PATH", save_path))

	var cfg_exists := FileAccess.file_exists(save_path)
	var cfg_bytes := PackedByteArray()
	if cfg_exists:
		cfg_bytes = FileAccess.get_file_as_bytes(save_path)

	return {
		"save_path": save_path,
		"cfg_exists": cfg_exists,
		"cfg_bytes": cfg_bytes,
		"locale": TranslationServer.get_locale(),
		"max_fps_engine": Engine.max_fps,
		"sound_profile": get_prop(settings_mgr, "sound_profile", "Full"),
		"language": get_prop(settings_mgr, "language", "en"),
		"screen_shake": get_prop(settings_mgr, "screen_shake", true),
		"mouse_control": get_prop(settings_mgr, "mouse_control", false),
		"window_mode": get_prop(settings_mgr, "window_mode", 1),
		"vsync": get_prop(settings_mgr, "vsync", true),
		"max_fps": get_prop(settings_mgr, "max_fps", 0),
		"taa_enabled": get_prop(settings_mgr, "taa_enabled", false),
		"fsr_enabled": get_prop(settings_mgr, "fsr_enabled", false),
		"dlss_enabled": get_prop(settings_mgr, "dlss_enabled", false),
		"raytracing_enabled": get_prop(settings_mgr, "raytracing_enabled", false),
		"shadows_enabled": get_prop(settings_mgr, "shadows_enabled", false),
		"gui_scale": get_prop(settings_mgr, "gui_scale", 1.0),
		"camera_zoom": get_prop(settings_mgr, "camera_zoom", 1.0),
		"unlimit_rtx": get_prop(settings_mgr, "unlimit_rtx", false),
		"joystick_size": get_prop(settings_mgr, "joystick_size", 2),
		"debug_unlocked": get_prop(settings_mgr, "debug_unlocked", OS.is_debug_build()),
		"has_simplified_descriptions": has_prop(settings_mgr, "simplified_descriptions"),
		"simplified_descriptions": get_prop(settings_mgr, "simplified_descriptions", true),
	}


static func restore_settings(snap: Dictionary) -> void:
	if snap.is_empty():
		return

	var settings_mgr := get_autoload("SettingsManager")
	var save_path: String = snap.get("save_path", "user://settings.cfg")

	if snap.get("cfg_exists", false):
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(snap.get("cfg_bytes", PackedByteArray()))
			f.close()
	else:
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if settings_mgr != null:
		var cfg := ConfigFile.new()
		if snap.get("cfg_exists", false):
			cfg.load(save_path)
		set_prop(settings_mgr, "config", cfg)
		set_prop(settings_mgr, "sound_profile", snap.get("sound_profile", "Full"))
		set_prop(settings_mgr, "language", snap.get("language", "en"))
		set_prop(settings_mgr, "screen_shake", snap.get("screen_shake", true))
		set_prop(settings_mgr, "mouse_control", snap.get("mouse_control", false))
		set_prop(settings_mgr, "window_mode", snap.get("window_mode", 1))
		set_prop(settings_mgr, "vsync", snap.get("vsync", true))
		set_prop(settings_mgr, "max_fps", snap.get("max_fps", 0))
		set_prop(settings_mgr, "taa_enabled", snap.get("taa_enabled", false))
		set_prop(settings_mgr, "fsr_enabled", snap.get("fsr_enabled", false))
		set_prop(settings_mgr, "dlss_enabled", snap.get("dlss_enabled", false))
		set_prop(settings_mgr, "raytracing_enabled", snap.get("raytracing_enabled", false))
		set_prop(settings_mgr, "shadows_enabled", snap.get("shadows_enabled", false))
		set_prop(settings_mgr, "gui_scale", snap.get("gui_scale", 1.0))
		set_prop(settings_mgr, "camera_zoom", snap.get("camera_zoom", 1.0))
		set_prop(settings_mgr, "unlimit_rtx", snap.get("unlimit_rtx", false))
		set_prop(settings_mgr, "joystick_size", snap.get("joystick_size", 2))
		set_prop(settings_mgr, "debug_unlocked", snap.get("debug_unlocked", OS.is_debug_build()))

		if snap.get("has_simplified_descriptions", false) and has_prop(settings_mgr, "simplified_descriptions"):
			set_prop(settings_mgr, "simplified_descriptions", snap.get("simplified_descriptions", true))

		TranslationServer.set_locale(snap.get("locale", "en"))

		if snap.get("cfg_exists", false) and cfg.has_section("audio"):
			for bus_name in cfg.get_section_keys("audio"):
				if bus_name != "sound_profile":
					safe_call(settings_mgr, "applyBusVolume", [bus_name, cfg.get_value("audio", bus_name, 1.0)])
		safe_call(settings_mgr, "applySoundProfile", [snap.get("sound_profile", "Full")])
		safe_call(settings_mgr, "apply_window_mode", [int(snap.get("window_mode", 1))])
		safe_call(settings_mgr, "apply_vsync", [bool(snap.get("vsync", true))])
		safe_call(settings_mgr, "apply_max_fps", [int(snap.get("max_fps", 0))])
		safe_call(settings_mgr, "apply_elite_settings")

		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var gui_node := tree.get_first_node_in_group("gui")
			if gui_node != null and has_method_safe(gui_node, "apply_gui_scale"):
				gui_node.call("apply_gui_scale", float(snap.get("gui_scale", 1.0)))

		if has_signal_safe(settings_mgr, "camera_zoom_changed"):
			settings_mgr.emit_signal("camera_zoom_changed", float(snap.get("camera_zoom", 1.0)))
		if has_signal_safe(settings_mgr, "shadow_settings_changed"):
			settings_mgr.emit_signal("shadow_settings_changed", bool(snap.get("shadows_enabled", false)))
		if has_signal_safe(settings_mgr, "raytracing_settings_changed"):
			settings_mgr.emit_signal("raytracing_settings_changed", bool(snap.get("raytracing_enabled", false)))
		if has_signal_safe(settings_mgr, "joystick_settings_changed"):
			settings_mgr.emit_signal("joystick_settings_changed", int(snap.get("joystick_size", 2)))
		if has_signal_safe(settings_mgr, "debug_mode_changed"):
			settings_mgr.emit_signal("debug_mode_changed", bool(snap.get("debug_unlocked", OS.is_debug_build())))
		if snap.get("has_simplified_descriptions", false) and has_signal_safe(settings_mgr, "simplified_descriptions_changed"):
			settings_mgr.emit_signal("simplified_descriptions_changed", bool(snap.get("simplified_descriptions", true)))
	else:
		TranslationServer.set_locale(snap.get("locale", "en"))

	Engine.max_fps = snap.get("max_fps_engine", 0)


static func backup_global_events() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var global_events := get_autoload("GlobalEvents")
	var stats_mgr := get_autoload("StatsManager")

	var movement_cfg_copy: Variant = null
	if has_prop(global_events, "MOVEMENT_CONFIG"):
		var raw_cfg: Variant = get_prop(global_events, "MOVEMENT_CONFIG", null)
		if raw_cfg is Dictionary:
			movement_cfg_copy = (raw_cfg as Dictionary).duplicate(true)
	elif has_prop(global_events, "movement_config"):
		var raw_cfg2: Variant = get_prop(global_events, "movement_config", null)
		if raw_cfg2 is Dictionary:
			movement_cfg_copy = (raw_cfg2 as Dictionary).duplicate(true)

	var stats_save_path := "user://statistics.cfg"
	if stats_mgr != null and has_prop(stats_mgr, "SAVE_PATH"):
		stats_save_path = str(get_prop(stats_mgr, "SAVE_PATH", stats_save_path))
	var stats_cfg_exists := FileAccess.file_exists(stats_save_path)
	var stats_cfg_bytes := PackedByteArray()
	if stats_cfg_exists:
		stats_cfg_bytes = FileAccess.get_file_as_bytes(stats_save_path)

	return {
		"selected_character": get_prop(global_events, "selected_character", "mage"),
		"current_difficulty": get_prop(global_events, "current_difficulty", 1),
		"time": get_prop(global_events, "time", 0),
		"custom_enemy_spawn_modifier": get_prop(global_events, "custom_enemy_spawn_modifier", 1.0),
		"custom_enemy_hp_modifier": get_prop(global_events, "custom_enemy_hp_modifier", 1.0),
		"custom_boss_hp_modifier": get_prop(global_events, "custom_boss_hp_modifier", 1.0),
		"custom_player_regen_modifier": get_prop(global_events, "custom_player_regen_modifier", 1.0),
		"custom_player_damage_modifier": get_prop(global_events, "custom_player_damage_modifier", 1.0),
		"custom_xp_gain_modifier": get_prop(global_events, "custom_xp_gain_modifier", 1.0),
		"movement_coupled_enabled": get_prop(global_events, "movement_coupled_enabled", null),
		"movement_config": movement_cfg_copy,
		"engine_time_scale": Engine.time_scale,
		"tree_paused": tree.paused if tree != null else false,
		"stats_save_path": stats_save_path,
		"stats_cfg_exists": stats_cfg_exists,
		"stats_cfg_bytes": stats_cfg_bytes,
		"stats_is_run_tainted": get_prop(stats_mgr, "is_run_tainted", false),
		"allow_tainted_stats": get_prop(stats_mgr, "allow_tainted_stats", false),
		"stats_enemy_kills": get_prop(stats_mgr, "enemy_kills", 0),
		"stats_boss_kills": get_prop(stats_mgr, "boss_kills", 0),
		"stats_total_deaths": get_prop(stats_mgr, "total_deaths", 0),
		"stats_total_wins": get_prop(stats_mgr, "total_wins", 0),
		"stats_best_run_level": get_prop(stats_mgr, "best_run_level", 0),
		"stats_best_run_time": get_prop(stats_mgr, "best_run_time", 0),
	}


static func restore_global_events(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var global_events := get_autoload("GlobalEvents")
	var stats_mgr := get_autoload("StatsManager")

	if global_events != null:
		set_prop(global_events, "selected_character", snap.get("selected_character", "mage"))
		set_prop(global_events, "current_difficulty", snap.get("current_difficulty", 1))
		set_prop(global_events, "time", snap.get("time", 0))
		set_prop(global_events, "custom_enemy_spawn_modifier", snap.get("custom_enemy_spawn_modifier", 1.0))
		set_prop(global_events, "custom_enemy_hp_modifier", snap.get("custom_enemy_hp_modifier", 1.0))
		set_prop(global_events, "custom_boss_hp_modifier", snap.get("custom_boss_hp_modifier", 1.0))
		set_prop(global_events, "custom_player_regen_modifier", snap.get("custom_player_regen_modifier", 1.0))
		set_prop(global_events, "custom_player_damage_modifier", snap.get("custom_player_damage_modifier", 1.0))
		set_prop(global_events, "custom_xp_gain_modifier", snap.get("custom_xp_gain_modifier", 1.0))

		if snap.get("movement_coupled_enabled", null) != null and has_prop(global_events, "movement_coupled_enabled"):
			set_prop(global_events, "movement_coupled_enabled", snap["movement_coupled_enabled"])

		var saved_cfg: Variant = snap.get("movement_config", null)
		if saved_cfg is Dictionary:
			var cfg_copy: Dictionary = (saved_cfg as Dictionary).duplicate(true)
			if has_prop(global_events, "movement_config") and get_prop(global_events, "movement_config", null) is Dictionary:
				var target_cfg: Dictionary = get_prop(global_events, "movement_config")
				target_cfg.clear()
				for k in cfg_copy.keys():
					target_cfg[k] = cfg_copy[k]
			elif has_prop(global_events, "MOVEMENT_CONFIG") and get_prop(global_events, "MOVEMENT_CONFIG", null) is Dictionary:
				var target_const_cfg: Dictionary = get_prop(global_events, "MOVEMENT_CONFIG")
				target_const_cfg.clear()
				for k in cfg_copy.keys():
					target_const_cfg[k] = cfg_copy[k]
				if has_signal_safe(global_events, "movement_config_changed"):
					global_events.emit_signal("movement_config_changed")

	Engine.time_scale = snap.get("engine_time_scale", 1.0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = snap.get("tree_paused", false)

	if stats_mgr != null:
		var stats_save_path: String = snap.get("stats_save_path", "user://statistics.cfg")
		if snap.get("stats_cfg_exists", false):
			var sf := FileAccess.open(stats_save_path, FileAccess.WRITE)
			if sf != null:
				sf.store_buffer(snap.get("stats_cfg_bytes", PackedByteArray()))
				sf.close()
		else:
			if FileAccess.file_exists(stats_save_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(stats_save_path))
		var stats_cfg := ConfigFile.new()
		if snap.get("stats_cfg_exists", false):
			stats_cfg.load(stats_save_path)
		set_prop(stats_mgr, "config", stats_cfg)

		if bool(snap.get("stats_is_run_tainted", false)):
			safe_call(stats_mgr, "mark_run_tainted")
		else:
			safe_call(stats_mgr, "clear_run_taint")
		set_prop(stats_mgr, "allow_tainted_stats", snap.get("allow_tainted_stats", false))
		set_prop(stats_mgr, "enemy_kills", snap.get("stats_enemy_kills", 0))
		set_prop(stats_mgr, "boss_kills", snap.get("stats_boss_kills", 0))
		set_prop(stats_mgr, "total_deaths", snap.get("stats_total_deaths", 0))
		set_prop(stats_mgr, "total_wins", snap.get("stats_total_wins", 0))
		set_prop(stats_mgr, "best_run_level", snap.get("stats_best_run_level", 0))
		set_prop(stats_mgr, "best_run_time", snap.get("stats_best_run_time", 0))


# -----------------------------------------------------------------------------
# 5. Input Simulation Helpers
# -----------------------------------------------------------------------------

static func press_action(action_name: String, pressed: bool = true, strength: float = 1.0, emit_event: bool = true) -> bool:
	if not InputMap.has_action(action_name):
		return false
	if pressed:
		Input.action_press(action_name, strength)
	else:
		Input.action_release(action_name)

	if emit_event:
		var ev := InputEventAction.new()
		ev.action = action_name
		ev.pressed = pressed
		ev.strength = strength if pressed else 0.0
		Input.parse_input_event(ev)
	return true


static func release_all_inputs(actions: Array = DEFAULT_ACTIONS) -> void:
	for act_var in actions:
		var act := String(act_var)
		if InputMap.has_action(act):
			if Input.is_action_pressed(act):
				var ev := InputEventAction.new()
				ev.action = act
				ev.pressed = false
				ev.strength = 0.0
				Input.parse_input_event(ev)
			Input.action_release(act)
	Input.flush_buffered_events()


# -----------------------------------------------------------------------------
# 6. External Python CLI Helpers
# -----------------------------------------------------------------------------

static func run_python_script(script_rel_path: String, args: Array = []) -> Dictionary:
	var project_root := ProjectSettings.globalize_path("res://")
	var abs_script := script_rel_path
	if not script_rel_path.is_absolute_path():
		abs_script = project_root.path_join(script_rel_path)

	var exec_args := PackedStringArray([abs_script])
	for a in args:
		exec_args.append(str(a))

	var output: Array = []
	var exit_code := OS.execute("python", exec_args, output, true)
	var joined := "\n".join(PackedStringArray(output))
	return {
		"exit_code": exit_code,
		"output": joined,
		"script_path": abs_script
	}


static func run_localization_validator(extra_args: Array = []) -> Dictionary:
	var project_root := ProjectSettings.globalize_path("res://")
	var args: Array = [
		"--csv", project_root.path_join("translations/translations.csv"),
		"--code-dir", project_root
	]
	args.append_array(extra_args)
	return run_python_script(".agents/skills/localization-validator/validate_translations.py", args)


static func run_balance_eval(extra_args: Array = []) -> Dictionary:
	return run_python_script(".agents/skills/game-balance-eval/balance_eval.py", extra_args)
