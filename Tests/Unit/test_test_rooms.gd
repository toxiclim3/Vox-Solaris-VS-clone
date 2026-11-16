# SPDX-License-Identifier: GPL-3.0-or-later
# Unit Tests for Dedicated Testing Levels & Diagnostic Utilities Suite

extends "res://Tests/test_base.gd"

const SwitcherScript = preload("res://Tools/TestRooms/test_room_switcher.gd")
const CombatRoomScript = preload("res://Tools/TestRooms/test_room_combat.gd")
const AssetsRoomScript = preload("res://Tools/TestRooms/test_room_assets.gd")
const BossSwarmRoomScript = preload("res://Tools/TestRooms/test_room_boss_swarm.gd")
const UiAudioRoomScript = preload("res://Tools/TestRooms/test_room_ui_audio.gd")
const DebugControllerScript = preload("res://Utility/Debug/debug_controller.gd")

var _spawned_nodes: Array[Node] = []

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func before_each() -> void:
	if _tree():
		_tree().paused = false
	Engine.time_scale = 1.0
	SettingsManager.debug_unlocked = true

func after_each() -> void:
	for n in _spawned_nodes:
		if is_instance_valid(n):
			if n.is_inside_tree():
				n.queue_free()
			else:
				n.free()
	_spawned_nodes.clear()

	if _tree():
		_tree().paused = false
	Engine.time_scale = 1.0

# -----------------------------------------------------------------------------
# 1. Scene Loading & Resource Integrity Tests
# -----------------------------------------------------------------------------

func test_all_test_room_scenes_exist_and_load() -> void:
	var scenes := [
		"res://Tools/TestRooms/test_room_combat.tscn",
		"res://Tools/TestRooms/test_room_assets.tscn",
		"res://Tools/TestRooms/test_room_boss_swarm.tscn",
		"res://Tools/TestRooms/test_room_ui_audio.tscn"
	]
	for scn_path in scenes:
		assert_true(ResourceLoader.exists(scn_path), "Test room scene must exist: " + scn_path)
		var scn: PackedScene = load(scn_path)
		assert_not_null(scn, "PackedScene must load cleanly: " + scn_path)
		var inst = scn.instantiate()
		assert_not_null(inst, "Instance must be non-null: " + scn_path)
		_spawned_nodes.append(inst)

# -----------------------------------------------------------------------------
# 2. TestRoomSwitcher Tests
# -----------------------------------------------------------------------------

func test_switcher_catalog_and_modal_lifecycle() -> void:
	var switcher := SwitcherScript.new()
	_tree().root.add_child(switcher)
	_spawned_nodes.append(switcher)

	assert_eq(switcher.ROOMS.size(), 7, "Switcher must list all 7 rooms")

	# Check that all room paths exist on disk
	for r in switcher.ROOMS:
		var p: String = r["path"]
		assert_true(ResourceLoader.exists(p), "Destination scene must exist: " + p)

	# Modal open & close
	switcher.open_modal()
	assert_true(switcher.visible, "Switcher must be visible after open_modal")
	assert_true(_tree().paused, "Switcher must pause tree on open")
	# Rule 14 verification: ensure no button is auto-focused upon modal open
	var focus_owner := _tree().root.get_viewport().gui_get_focus_owner() if _tree().root.get_viewport() else null
	assert_true(focus_owner == null or not switcher.room_buttons.has(focus_owner), "Rule 14: Buttons must not be auto-focused on modal open")

	# Test Escape key closes modal via _unhandled_input
	var esc_ev := InputEventKey.new()
	esc_ev.pressed = true
	esc_ev.keycode = KEY_ESCAPE
	switcher._unhandled_input(esc_ev)
	assert_false(switcher.visible, "Switcher must close on KEY_ESCAPE")
	assert_false(_tree().paused, "Switcher must restore unpaused state on Escape")

	# Test Backspace key closes modal via _unhandled_input
	switcher.open_modal()
	assert_true(switcher.visible, "Switcher reopened")
	var bsp_ev := InputEventKey.new()
	bsp_ev.pressed = true
	bsp_ev.keycode = KEY_BACKSPACE
	switcher._unhandled_input(bsp_ev)
	assert_false(switcher.visible, "Switcher must close on KEY_BACKSPACE")

# -----------------------------------------------------------------------------
# 3. Combat Proving Ground Tests
# -----------------------------------------------------------------------------

func test_combat_proving_ground_setup_and_weapons() -> void:
	var combat_room = CombatRoomScript.new()
	_tree().root.add_child(combat_room)
	_spawned_nodes.append(combat_room)

	assert_not_null(combat_room.player, "Player must be spawned in combat room")
	assert_not_null(combat_room.station1_dummy, "Station 1 DPS dummy must exist")
	assert_not_null(combat_room.station3_dummy, "Station 3 Retaliation dummy must exist")
	assert_eq(combat_room.station2_dummies.size(), 17, "Station 2 must have 8 line + 9 cluster dummies = 17")

	# Weapon cycling: cycle through all weapon families cleanly
	var initial_fam = combat_room.WEAPON_FAMILIES[combat_room.current_weapon_idx]
	combat_room._cycle_weapon(1)
	var next_fam = combat_room.WEAPON_FAMILIES[combat_room.current_weapon_idx]
	assert_true(initial_fam != next_fam, "Cycling weapon must advance to different family")

	# Tier stepping: step up to 4 and endless (5)
	combat_room._step_tier(1)
	assert_eq(combat_room.current_weapon_tier, 2, "Weapon tier stepped up to 2")
	combat_room._step_tier(3)
	assert_eq(combat_room.current_weapon_tier, 5, "Weapon tier clamped to endless (5)")

	# Wall mode cycling
	var orig_wall = combat_room.wall_mode
	combat_room._cycle_wall_mode()
	assert_eq(combat_room.wall_mode, (orig_wall + 1) % 3, "Wall mode must advance (0..2)")

	# Retaliation damage cycling
	var initial_retal = combat_room.station3_dummy.retaliate_damage
	combat_room._cycle_retaliation_damage()
	var new_retal = combat_room.station3_dummy.retaliate_damage
	assert_true(initial_retal != new_retal, "Retaliation damage must cycle through values")

	# HP snap triggers
	combat_room._snap_player_hp(0.95)
	var expected_95 = int(round(float(combat_room.player.maxhp) * 0.95))
	assert_almost_eq(float(combat_room.player.hp), float(expected_95), 1.0, "Player HP snapped to 95%")

	combat_room._snap_player_hp(0.29)
	var expected_29 = int(round(float(combat_room.player.maxhp) * 0.29))
	assert_almost_eq(float(combat_room.player.hp), float(expected_29), 1.0, "Player HP snapped to 29%")

	# Swarm clearing & room reset verification
	combat_room._spawn_swarm_batch(10)
	assert_true(combat_room.swarm_manager.swarm_data.size() > 0, "Swarm spawned 10 units")
	combat_room._clear_swarm()
	assert_eq(combat_room.swarm_manager.swarm_data.size(), 0, "SwarmManager.clear_all cleared swarm_data")

	# Mock GUI levelup stubs
	assert_not_null(combat_room.mock_gui, "Mock GUI exists")
	combat_room.mock_gui.show_levelup(["icespear1"], 2)
	combat_room.mock_gui.show_boss_levelup(["wardingbrooch1"])

	# Room reset trigger
	combat_room.reset_room()
	assert_eq(combat_room.player.position, combat_room.STATION_POSITIONS[0], "Player reset to center pad")

# -----------------------------------------------------------------------------
# 4. Texture, Animation & Shader Gallery Tests
# -----------------------------------------------------------------------------

func test_assets_room_tabs_and_icon_audit() -> void:
	var assets_room = AssetsRoomScript.new()
	_tree().root.add_child(assets_room)
	_spawned_nodes.append(assets_room)

	# Tab switching
	assets_room._switch_tab(assets_room.TabMode.WHIP)
	assert_true(assets_room.tab_containers[assets_room.TabMode.WHIP].visible, "Whip tab visible")
	assert_false(assets_room.tab_containers[assets_room.TabMode.SPRITES].visible, "Sprites tab hidden")

	assets_room._switch_tab(assets_room.TabMode.ICONS)
	assert_true(assets_room.tab_containers[assets_room.TabMode.ICONS].visible, "Icons tab visible")

	# Backdrop cycling
	var orig_b = assets_room.active_backdrop_idx
	assets_room._cycle_backdrop()
	assert_eq(assets_room.active_backdrop_idx, (orig_b + 1) % assets_room.BACKDROP_COLORS.size(), "Backdrop index cycled")

	# Loupe Zoom cycling
	var orig_z = assets_room.zoom_idx
	assets_room._cycle_zoom()
	assert_eq(assets_room.zoom_idx, (orig_z + 1) % assets_room.zoom_levels.size(), "Zoom index cycled")

	# Rule 12 Icon Audit
	assets_room._run_icon_audit()
	assert_true(assets_room.audit_grid.get_child_count() > 0, "Icon audit must have inspected icons")

	# Verify all assets in sprite_catalog exist and load cleanly
	assert_eq(assets_room.sprite_catalog.size(), 8, "Catalog contains 8 assets")
	for i in range(assets_room.sprite_catalog.size()):
		var item: Dictionary = assets_room.sprite_catalog[i]
		var path: String = item["path"]
		assert_true(ResourceLoader.exists(path), "Asset file must exist: " + path)
		assets_room._load_sprite_catalog_item(i)
		assert_not_null(assets_room.active_sprite_node, "Active sprite node instantiated for: " + item["name"])

	# Mouse wheel zoom testing
	var orig_zoom = assets_room.zoom_idx
	var wheel_up := InputEventMouseButton.new()
	wheel_up.pressed = true
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	assets_room._unhandled_input(wheel_up)
	assert_true(assets_room.zoom_idx > orig_zoom, "Wheel Up zoomed in")

	# Whip curve update and handle verification
	assert_not_null(assets_room.whip_handles, "Whip point handles node created")
	assets_room.whip_points[1] = Vector2(-20, -80)
	assets_room._update_whip_length()
	var new_len: float = assets_room.whip_material.get_shader_parameter("total_length")
	assert_true(new_len > 240.0, "total_length parameter updated dynamically on whip point edit")

	# Tab 2 Whip Rig Asset Cycling & Shader Toggles
	assets_room._switch_tab(assets_room.TabMode.WHIP)
	assert_eq(assets_room.whip_cat_idx, 0, "Initial whip is Leather Whip")
	var bracket_r := InputEventKey.new()
	bracket_r.pressed = true
	bracket_r.keycode = KEY_BRACKETRIGHT
	assets_room._unhandled_input(bracket_r)
	assert_eq(assets_room.whip_cat_idx, 1, "BracketRight switched to Glass Lash")
	assert_not_null(assets_room.whip_line.texture, "Glass lash texture loaded")

	var bracket_l := InputEventKey.new()
	bracket_l.pressed = true
	bracket_l.keycode = KEY_BRACKETLEFT
	assets_room._unhandled_input(bracket_l)
	assert_eq(assets_room.whip_cat_idx, 0, "BracketLeft switched back to Leather Whip")

	var initial_tile: bool = assets_room.whip_tile_middle
	var t_key := InputEventKey.new()
	t_key.pressed = true
	t_key.keycode = KEY_T
	assets_room._unhandled_input(t_key)
	assert_eq(assets_room.whip_tile_middle, not initial_tile, "T key toggled whip_tile_middle")

	var initial_caps: bool = assets_room.whip_hide_caps
	var c_key := InputEventKey.new()
	c_key.pressed = true
	c_key.keycode = KEY_C
	assets_room._unhandled_input(c_key)
	assert_eq(assets_room.whip_hide_caps, not initial_caps, "C key toggled whip_hide_caps")

	# Tab 3 Shader Lab & Live Swarm MultiMesh Preview
	assets_room._switch_tab(assets_room.TabMode.SHADER)
	assert_not_null(assets_room.elite_preview_sprite, "Elite material preview node exists")
	assert_eq(assets_room.elite_preview_sprite.material, assets_room.elite_material, "Elite material assigned to preview sprite")
	assert_not_null(assets_room.shader_preview_sprite, "Recolor preview node exists")
	assert_eq(assets_room.shader_preview_sprite.material, assets_room.recolor_material, "Recolor material assigned to preview sprite")
	assert_not_null(assets_room.tab3_swarm_mgr, "Live SwarmManager instantiated in Tab 3")
	assert_eq(assets_room.tab3_swarm_mgr.swarm_data.size(), 9, "Tab 3 SwarmManager has 3x3 (9) kobolds preview")

	# Gizmos Toggle (KEY_G)
	assert_true(assets_room.show_gizmos, "Gizmos visible by default")
	assert_not_null(assets_room.gizmo_overlay, "Gizmo overlay exists")
	var g_key := InputEventKey.new()
	g_key.pressed = true
	g_key.keycode = KEY_G
	assets_room._unhandled_input(g_key)
	assert_false(assets_room.show_gizmos, "KEY_G toggled show_gizmos to false")
	assets_room._unhandled_input(g_key)
	assert_true(assets_room.show_gizmos, "KEY_G toggled show_gizmos back to true")

# -----------------------------------------------------------------------------
# 5. Boss Choreography & Swarm Stress Tests
# -----------------------------------------------------------------------------

func test_boss_swarm_room_boss_spawning_and_states() -> void:
	var boss_room = BossSwarmRoomScript.new()
	_tree().root.add_child(boss_room)
	_spawned_nodes.append(boss_room)

	assert_not_null(boss_room.active_boss, "Boss must be spawned by default")

	# Spawn Dr. Franklin
	boss_room.spawn_boss("franklin")
	assert_not_null(boss_room.active_boss, "Dr. Franklin boss must be spawned")

	# Force state
	boss_room._force_boss_state(1)
	assert_eq(int(boss_room.active_boss.get("state")), 1, "Boss state forced to 1")

	# Hold after telegraph toggle
	var orig_hold = boss_room.hold_after_telegraph
	boss_room._toggle_hold_after_telegraph()
	assert_true(boss_room.hold_after_telegraph != orig_hold, "Hold after telegraph toggled")

	# Godmode toggle
	var orig_god = boss_room.is_godmode
	boss_room._toggle_godmode()
	assert_true(boss_room.is_godmode != orig_god, "Godmode toggled")

	# Test Amoeba dissolve and telegraph transitions
	boss_room.spawn_boss("amoeba")
	assert_not_null(boss_room.active_boss, "Amoeba boss spawned")
	boss_room._force_boss_state(1)
	assert_eq(int(boss_room.active_boss.get("state")), 1, "Amoeba dissolve initiated via start_dissolve")

	# Test room reset and swarm clearing
	boss_room.reset_room()
	assert_not_null(boss_room.active_boss, "Amoeba respawned on reset")
	assert_eq(boss_room.swarm_manager.swarm_data.size(), 0, "Swarm data cleared on reset")

# -----------------------------------------------------------------------------
# 6. UI, Localization & Audio Soundboard Tests
# -----------------------------------------------------------------------------

func test_ui_audio_room_locales_and_focus_graph() -> void:
	var ui_audio_room = UiAudioRoomScript.new()
	_tree().root.add_child(ui_audio_room)
	_spawned_nodes.append(ui_audio_room)

	# 3 cards generated
	assert_eq(ui_audio_room.cards_hbox.get_child_count(), 3, "Must render 3 cards for EN, RU, UA")

	# Item cycling
	var orig_idx = ui_audio_room.current_up_idx
	ui_audio_room._cycle_item(1)
	assert_true(ui_audio_room.current_up_idx != orig_idx, "Upgrade item cycled")

	# Locale cycling
	var orig_loc = TranslationServer.get_locale()
	ui_audio_room._cycle_locale()
	var new_loc = TranslationServer.get_locale()
	assert_true(orig_loc != new_loc, "Engine locale cycled")
	# Restore locale
	TranslationServer.set_locale("en")

	# Focus visualizer toggle
	var orig_focus = ui_audio_room.show_focus_graph
	ui_audio_room._toggle_focus_graph()
	assert_true(ui_audio_room.show_focus_graph != orig_focus, "Focus graph toggled")
	assert_eq(ui_audio_room.focus_overlay.get_parent(), ui_audio_room.ui_layer, "Focus overlay must be on ui_layer in screen space")

	# Rule 14 focus neighbor links between cards
	var card_0 = ui_audio_room.cards_hbox.get_child(0) as Control
	var card_1 = ui_audio_room.cards_hbox.get_child(1) as Control
	assert_true(not card_0.focus_neighbor_right.is_empty(), "Card 0 has focus_neighbor_right")
	assert_true(not card_1.focus_neighbor_left.is_empty(), "Card 1 has focus_neighbor_left")

	# Test Shift+L toggles between 3-locale split view and single-locale view
	assert_true(ui_audio_room.is_split_locale_view, "Initial view is 3-locale split")
	assert_eq(ui_audio_room.cards_hbox.get_child_count(), 3, "3 cards rendered in split view")

	var shift_l := InputEventKey.new()
	shift_l.pressed = true
	shift_l.keycode = KEY_L
	shift_l.shift_pressed = true
	ui_audio_room._unhandled_input(shift_l)
	assert_false(ui_audio_room.is_split_locale_view, "Shift+L toggled to single-locale view")
	assert_eq(ui_audio_room.cards_hbox.get_child_count(), 1, "1 card rendered in single-locale view")

	ui_audio_room._unhandled_input(shift_l)
	assert_true(ui_audio_room.is_split_locale_view, "Shift+L toggled back to 3-locale split view")
	assert_eq(ui_audio_room.cards_hbox.get_child_count(), 3, "3 cards rendered after re-enabling split view")

	# Test Escape closes legend panel
	ui_audio_room.legend_panel.visible = true
	var esc_ev := InputEventKey.new()
	esc_ev.pressed = true
	esc_ev.keycode = KEY_ESCAPE
	ui_audio_room._unhandled_input(esc_ev)
	assert_false(ui_audio_room.legend_panel.visible, "KEY_ESCAPE must close legend panel")

# -----------------------------------------------------------------------------
# 7. DebugController Keybind & Mouse5 Integration Tests
# -----------------------------------------------------------------------------

func test_debug_controller_f4_f5_and_mouse5_handling() -> void:
	var ctrl := DebugControllerScript.new()
	_tree().root.add_child(ctrl)
	_spawned_nodes.append(ctrl)

	SettingsManager.debug_unlocked = true

	# Test F5 toggles switcher
	var f5_ev := InputEventKey.new()
	f5_ev.pressed = true
	f5_ev.keycode = KEY_F5
	var handled_f5 := ctrl.handle_key_event(f5_ev)
	assert_true(handled_f5, "F5 must be handled by DebugController")
	assert_not_null(ctrl.switcher, "Switcher modal instantiated on F5")
	assert_true(ctrl.switcher.visible, "Switcher modal visible on F5")

	ctrl.switcher.close_modal()
	assert_false(_tree().paused, "Tree unpaused after closing switcher")

	# Test F4 toggles freeze
	var f4_ev := InputEventKey.new()
	f4_ev.pressed = true
	f4_ev.keycode = KEY_F4
	var handled_f4 := ctrl.handle_key_event(f4_ev)
	assert_true(handled_f4, "F4 must be handled by DebugController")
	assert_true(ctrl.is_frozen_by_debug, "Simulation frozen by F4")

	# Test Mouse5 (MOUSE_BUTTON_XBUTTON2) unfreezes
	var m5_ev := InputEventMouseButton.new()
	m5_ev.pressed = true
	m5_ev.button_index = MOUSE_BUTTON_XBUTTON2
	var handled_m5 := ctrl.handle_key_event(m5_ev)
	assert_true(handled_m5, "Mouse5 must be handled by DebugController")
	assert_false(ctrl.is_frozen_by_debug, "Simulation unfrozen by Mouse5")

# -----------------------------------------------------------------------------
# 8. KEY_PERIOD Unpaused Fallthrough & Frame Stepping Tests
# -----------------------------------------------------------------------------

func test_debug_controller_period_stepping_and_unpaused_behavior() -> void:
	var ctrl := DebugControllerScript.new()
	_tree().root.add_child(ctrl)
	_spawned_nodes.append(ctrl)

	SettingsManager.debug_unlocked = true

	# When unpaused and not frozen, KEY_PERIOD must return false (fallthrough)
	_tree().paused = false
	ctrl.is_frozen_by_debug = false
	var period_ev := InputEventKey.new()
	period_ev.pressed = true
	period_ev.keycode = KEY_PERIOD
	var handled_unpaused := ctrl.handle_key_event(period_ev)
	assert_false(handled_unpaused, "KEY_PERIOD must return false when tree is unpaused so room hotkeys receive it")

	# When frozen by debug or tree is paused, KEY_PERIOD must return true (steps 1 frame)
	ctrl.toggle_freeze()
	assert_true(ctrl.is_frozen_by_debug, "Simulation frozen")
	var handled_frozen := ctrl.handle_key_event(period_ev)
	assert_true(handled_frozen, "KEY_PERIOD must return true when simulation is frozen")
	ctrl.toggle_freeze()
	_tree().paused = false

	# Test in TestRoomAssets: when unpaused, KEY_PERIOD steps the sprite frame
	var assets_room = AssetsRoomScript.new()
	_tree().root.add_child(assets_room)
	_spawned_nodes.append(assets_room)

	# Load Player Sprite (hframes = 2, vframes = 1)
	assets_room._load_sprite_catalog_item(4)
	assert_not_null(assets_room.active_sprite_node, "Player sprite loaded")
	var sp := assets_room.active_sprite_node as Sprite2D
	assert_not_null(sp, "Active node is Sprite2D")
	sp.frame = 0

	# Send KEY_PERIOD
	assets_room._unhandled_input(period_ev)
	assert_eq(sp.frame, 1, "KEY_PERIOD stepped frame from 0 to 1")
	assert_false(assets_room.is_anim_playing, "Stepping paused auto-playback")

	# Send KEY_COMMA to step backwards
	var comma_ev := InputEventKey.new()
	comma_ev.pressed = true
	comma_ev.keycode = KEY_COMMA
	assets_room._unhandled_input(comma_ev)
	assert_eq(sp.frame, 0, "KEY_COMMA stepped frame back from 1 to 0")

# -----------------------------------------------------------------------------
# 9. TestRoomBase Esc vs Backspace Modal Lifecycle Tests
# -----------------------------------------------------------------------------

func test_test_room_base_esc_and_backspace_modal_behavior() -> void:
	var room = AssetsRoomScript.new()
	_tree().root.add_child(room)
	_spawned_nodes.append(room)

	# Top-bar button text verification
	var found_bksp_btn := false
	for child in room.top_bar.find_children("*", "Button", true, false):
		if child is Button and child.text == "Bksp Title":
			found_bksp_btn = true
			break
	assert_true(found_bksp_btn, "Top bar must have 'Bksp Title' button")

	# When modal is open (e.g. legend), Backspace closes the modal
	room.legend_panel.visible = true
	var bksp_ev := InputEventKey.new()
	bksp_ev.pressed = true
	bksp_ev.keycode = KEY_BACKSPACE
	room._unhandled_input(bksp_ev)
	assert_false(room.legend_panel.visible, "Backspace closed open legend panel")

	# When modal is open, Escape closes the modal
	room.legend_panel.visible = true
	var esc_ev := InputEventKey.new()
	esc_ev.pressed = true
	esc_ev.keycode = KEY_ESCAPE
	room._unhandled_input(esc_ev)
	assert_false(room.legend_panel.visible, "Escape closed open legend panel")

	# When NO modal is open, Escape opens the TestRoomSwitcher modal (pausing tree)
	assert_false(room.switcher.visible, "Switcher initially closed")
	room._unhandled_input(esc_ev)
	assert_true(room.switcher.visible, "Escape opened TestRoomSwitcher when no modal was open")
	assert_true(_tree().paused, "TestRoomSwitcher paused the tree")

	# Close switcher modal with Escape
	room.switcher._unhandled_input(esc_ev)
	assert_false(room.switcher.visible, "Escape closed TestRoomSwitcher")
	assert_false(_tree().paused, "Tree unpaused after closing switcher")

	# Test F5 toggles TestRoomSwitcher in room and shares instance with DebugController
	assert_not_null(room.debug_controller, "Room has DebugController")
	assert_eq(room.debug_controller.switcher, room.switcher, "DebugController and TestRoomBase share same Switcher instance")
	var f5_ev := InputEventKey.new()
	f5_ev.pressed = true
	f5_ev.keycode = KEY_F5
	room._unhandled_input(f5_ev)
	assert_true(room.switcher.visible, "F5 opened TestRoomSwitcher in room")
	room._unhandled_input(f5_ev)
	assert_false(room.switcher.visible, "F5 closed TestRoomSwitcher in room")
