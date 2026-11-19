# SPDX-License-Identifier: GPL-3.0-or-later
# Standalone E2E Headless Test Runner for Inritus (Godot 4.6+)
# Executes E2E suites across Tiers 1-4 via Godot CLI:
#   Godot_v4.7.2-stable_win64_console.exe --headless -s res://Tests/E2E/e2e_runner.gd
# Optional user args (passed after `--`):
#   --tier=<1|2|3|4>
#   --suite=<substring>
#   --ignore-missing
#   --smoke

extends SceneTree

const TestBaseScript = preload("res://Tests/test_base.gd")
const E2EHelpersScript = preload("res://Tests/E2E/e2e_helpers.gd")

var _has_run: bool = false

const SUITES: Array[Dictionary] = [
	{
		"tier": 1,
		"id": "tier1_substrate",
		"name": "Tier 1: Movement Substrate & Config",
		"path": "res://Tests/E2E/test_e2e_tier1_substrate.gd"
	},
	{
		"tier": 1,
		"id": "tier1_mobility",
		"name": "Tier 1: Character Mobility",
		"path": "res://Tests/E2E/test_e2e_tier1_mobility.gd"
	},
	{
		"tier": 1,
		"id": "tier1_items_weapons",
		"name": "Tier 1: Items, Passives & Weapons",
		"path": "res://Tests/E2E/test_e2e_tier1_items_weapons.gd"
	},
	{
		"tier": 1,
		"id": "tier1_visuals_ui",
		"name": "Tier 1: Visual Cues, Cards & Localization",
		"path": "res://Tests/E2E/test_e2e_tier1_visuals_ui.gd"
	},
	{
		"tier": 2,
		"id": "tier2_movement_limits",
		"name": "Tier 2: Movement & Mobility Boundaries",
		"path": "res://Tests/E2E/test_e2e_tier2_movement_limits.gd"
	},
	{
		"tier": 2,
		"id": "tier2_combat_edges",
		"name": "Tier 2: Weapons, Passives & UpgradeDb Edges",
		"path": "res://Tests/E2E/test_e2e_tier2_combat_edges.gd"
	},
	{
		"tier": 2,
		"id": "tier2_ui_loc_edges",
		"name": "Tier 2: UI, Settings & Localization Edges",
		"path": "res://Tests/E2E/test_e2e_tier2_ui_loc_edges.gd"
	},
	{
		"tier": 3,
		"id": "tier3_combinations",
		"name": "Tier 3: Pairwise Feature Combinations",
		"path": "res://Tests/E2E/test_e2e_tier3_combinations.gd"
	},
	{
		"tier": 4,
		"id": "tier4_scenarios",
		"name": "Tier 4: Real-World Gameplay Scenarios",
		"path": "res://Tests/E2E/test_e2e_tier4_scenarios.gd"
	}
]


class _SmokeProcessProbeNode extends Node:
	var physics_ticks: int = 0
	var process_ticks: int = 0

	func _physics_process(_delta: float) -> void:
		physics_ticks += 1

	func _process(_delta: float) -> void:
		process_ticks += 1


class _E2ESmokeSuite extends "res://Tests/test_base.gd":
	var _settings_snap: Dictionary = {}
	var _ge_snap: Dictionary = {}
	var _cleanup_list: Array = []

	func _tree() -> SceneTree:
		return Engine.get_main_loop() as SceneTree

	func before_each() -> void:
		_settings_snap = E2EHelpersScript.backup_settings()
		_ge_snap = E2EHelpersScript.backup_global_events()

	func after_each() -> void:
		E2EHelpersScript.release_all_inputs()
		E2EHelpersScript.cleanup_nodes(_cleanup_list)
		E2EHelpersScript.restore_global_events(_ge_snap)
		E2EHelpersScript.restore_settings(_settings_snap)

	func test_smoke_defensive_probing() -> void:
		var node := Node2D.new()
		node.name = "SmokeProbeRoot"
		var child := Node.new()
		child.name = "TargetChild"
		child.add_to_group("smoke_grp")
		node.add_child(child)

		assert_true(E2EHelpersScript.has_prop(node, "position"), "Existing Node2D property must probe true")
		assert_false(E2EHelpersScript.has_prop(node, "nonexistent_future_prop"), "Missing property must probe false without crash")
		assert_eq(E2EHelpersScript.get_prop(node, "nonexistent_future_prop", 42), 42, "Missing property returns default")
		assert_false(E2EHelpersScript.set_prop(node, "nonexistent_future_prop", 99), "set_prop returns false for missing property")
		assert_eq(E2EHelpersScript.safe_call(node, "nonexistent_method", [], "fallback"), "fallback", "safe_call returns default for missing method")
		assert_eq(E2EHelpersScript.find_node_recursive(node, "TargetChild"), child, "find_node_recursive finds child")
		assert_eq(E2EHelpersScript.find_child_by_name_or_group(node, "", "smoke_grp"), child, "find_child_by_name_or_group finds group member")
		node.free()

	func test_smoke_spawn_player_and_step_physics() -> void:
		var settings_mgr := E2EHelpersScript.get_autoload("SettingsManager")
		E2EHelpersScript.set_prop(settings_mgr, "mouse_control", false)

		var player := E2EHelpersScript.spawn_player(_tree(), "mage")
		assert_not_null(player, "spawn_player returns valid Player instance")
		assert_true(is_instance_valid(player), "Player instance is valid")
		_cleanup_list.append(player)

		var start_pos: Vector2 = player.global_position
		assert_true(E2EHelpersScript.press_action("right", true), "Action 'right' pressed")
		var strength := Input.get_action_strength("right")
		await E2EHelpersScript.step_tree_frames(_tree(), 10)
		var vel: Vector2 = player.velocity
		var real_vel: Vector2 = player.get_real_velocity()
		var end_pos: Vector2 = player.global_position
		assert_gt(end_pos.x, start_pos.x, "Player moved right during physics stepping (strength=%s, vel=%s, real_vel=%s)" % [str(strength), str(vel), str(real_vel)])

		var mid_pos: Vector2 = player.global_position
		E2EHelpersScript.step_physics(player, 3, 1.0 / 60.0, false)
		assert_gt(player.global_position.x, mid_pos.x, "step_physics advances unpaused player")

		_tree().paused = true
		var paused_pos: Vector2 = player.global_position
		E2EHelpersScript.step_physics(player, 3, 1.0 / 60.0, false)
		assert_eq(player.global_position, paused_pos, "step_physics respects SceneTree.paused for pausable nodes")
		_tree().paused = false

		E2EHelpersScript.release_all_inputs()

	func test_smoke_spawn_world_ui_and_debug_workbench() -> void:
		var world := E2EHelpersScript.spawn_world(_tree())
		assert_not_null(world, "spawn_world loads world.tscn")
		_cleanup_list.append(world)

		var gui_root := E2EHelpersScript.find_child_by_name_or_group(world, "", "gui")
		var dbg := E2EHelpersScript.attach_debug_workbench(gui_root, world)
		assert_true(dbg.has("workbench") and is_instance_valid(dbg["workbench"]), "DebugWorkbench attached via DebugController")
		_cleanup_list.append(dbg)

		var card := E2EHelpersScript.spawn_item_option(_tree(), "icespear1")
		assert_not_null(card, "spawn_item_option loads item_option.tscn")
		_cleanup_list.append(card)

		var menu := E2EHelpersScript.spawn_settings_menu(_tree())
		assert_not_null(menu, "spawn_settings_menu loads settings_menu.tscn")
		_cleanup_list.append(menu)

	func test_smoke_state_backup_restore() -> void:
		var settings_mgr := E2EHelpersScript.get_autoload("SettingsManager")
		var global_events := E2EHelpersScript.get_autoload("GlobalEvents")
		assert_not_null(settings_mgr, "SettingsManager autoload available")
		assert_not_null(global_events, "GlobalEvents autoload available")

		var orig_locale := TranslationServer.get_locale()
		var orig_diff: int = int(E2EHelpersScript.get_prop(global_events, "current_difficulty", 1))
		var stats_mgr := E2EHelpersScript.get_autoload("StatsManager")
		var orig_kills: int = int(E2EHelpersScript.get_prop(stats_mgr, "enemy_kills", 0))
		E2EHelpersScript.set_prop(stats_mgr, "enemy_kills", orig_kills + 77)
		settings_mgr.call("set_language", "ru")
		global_events.call("set_difficulty", 2)
		assert_eq(TranslationServer.get_locale(), "ru", "Locale mutated to ru")
		assert_eq(int(E2EHelpersScript.get_prop(global_events, "current_difficulty", -1)), 2, "Difficulty mutated to HARD (2)")
		E2EHelpersScript.restore_settings(_settings_snap)
		E2EHelpersScript.restore_global_events(_ge_snap)
		assert_eq(TranslationServer.get_locale(), orig_locale, "Locale restored")
		assert_eq(int(E2EHelpersScript.get_prop(global_events, "current_difficulty", -1)), orig_diff, "Difficulty restored")
		assert_eq(int(E2EHelpersScript.get_prop(stats_mgr, "enemy_kills", -1)), orig_kills, "StatsManager enemy_kills restored")

	func test_smoke_python_cli_helpers() -> void:
		var loc_res := E2EHelpersScript.run_localization_validator()
		assert_eq(loc_res.get("exit_code", -1), 0, "validate_translations.py exited 0")
		var bal_res := E2EHelpersScript.run_balance_eval(["--minutes", "5", "--json"])
		assert_eq(bal_res.get("exit_code", -1), 0, "balance_eval.py exited 0")

	func test_smoke_step_physics_respects_disabled_processing() -> void:
		var parent_probe := _SmokeProcessProbeNode.new()
		var child_probe := _SmokeProcessProbeNode.new()
		_tree().root.add_child(parent_probe)
		parent_probe.add_child(child_probe)
		_cleanup_list.append(parent_probe)

		E2EHelpersScript.step_physics(parent_probe, 2, 1.0 / 60.0, true)
		assert_eq(parent_probe.physics_ticks, 2, "Enabled parent ticked physics twice")
		assert_eq(parent_probe.process_ticks, 2, "Enabled parent ticked process twice")
		assert_eq(child_probe.physics_ticks, 2, "Enabled child ticked physics twice")
		assert_eq(child_probe.process_ticks, 2, "Enabled child ticked process twice")

		child_probe.set_physics_process(false)
		child_probe.set_process(false)
		E2EHelpersScript.step_physics(parent_probe, 3, 1.0 / 60.0, true)
		assert_eq(parent_probe.physics_ticks, 5, "Enabled parent continues ticking physics")
		assert_eq(parent_probe.process_ticks, 5, "Enabled parent continues ticking process")
		assert_eq(child_probe.physics_ticks, 2, "Disabled child does not tick _physics_process")
		assert_eq(child_probe.process_ticks, 2, "Disabled child does not tick _process")

		parent_probe.set_physics_process(false)
		parent_probe.set_process(false)
		E2EHelpersScript.step_physics(parent_probe, 4, 1.0 / 60.0, false)
		assert_eq(parent_probe.physics_ticks, 5, "Disabled parent does not tick _physics_process")
		assert_eq(parent_probe.process_ticks, 5, "Disabled parent does not tick _process")

		var off_tree_probe := _SmokeProcessProbeNode.new()
		off_tree_probe.set_physics_process(false)
		off_tree_probe.set_process(false)
		E2EHelpersScript.step_physics(off_tree_probe, 3, 1.0 / 60.0, false)
		assert_eq(off_tree_probe.physics_ticks, 0, "Disabled off-tree node does not tick _physics_process")
		assert_eq(off_tree_probe.process_ticks, 0, "Disabled off-tree node does not tick _process")
		off_tree_probe.free()

	func test_smoke_restore_settings_updates_live_camera_zoom() -> void:
		var player := E2EHelpersScript.spawn_player(_tree(), "mage")
		assert_not_null(player, "spawn_player returns valid Player instance")
		_cleanup_list.append(player)

		var cam := player.get_node_or_null("Camera2D") as Camera2D
		assert_not_null(cam, "Player has Camera2D")

		var settings_mgr := E2EHelpersScript.get_autoload("SettingsManager")
		var local_snap := E2EHelpersScript.backup_settings()
		var orig_zoom: Vector2 = cam.zoom

		var zoom_emitted_count := [0]
		var last_emitted_zoom := [0.0]
		var on_zoom := func(z: float) -> void:
			zoom_emitted_count[0] += 1
			last_emitted_zoom[0] = z
		settings_mgr.connect("camera_zoom_changed", on_zoom)

		settings_mgr.call("set_camera_zoom", 2.25)
		assert_almost_eq(cam.zoom.x, 2.25, 0.001, "Live Camera2D.zoom updated on set_camera_zoom")
		assert_almost_eq(cam.zoom.y, 2.25, 0.001, "Live Camera2D.zoom.y updated on set_camera_zoom")

		zoom_emitted_count[0] = 0
		E2EHelpersScript.restore_settings(local_snap)
		settings_mgr.disconnect("camera_zoom_changed", on_zoom)

		assert_gt(zoom_emitted_count[0], 0, "restore_settings re-emits camera_zoom_changed")
		assert_almost_eq(last_emitted_zoom[0], orig_zoom.x, 0.001, "Emitted camera_zoom matches snapshot")
		assert_almost_eq(cam.zoom.x, orig_zoom.x, 0.001, "Live Camera2D.zoom.x restored")
		assert_almost_eq(cam.zoom.y, orig_zoom.y, 0.001, "Live Camera2D.zoom.y restored")

	func test_smoke_concurrent_players_cleanup_isolation() -> void:
		var p1 := E2EHelpersScript.spawn_player(_tree(), "mage")
		var p2 := E2EHelpersScript.spawn_player(_tree(), "occultist")
		assert_not_null(p1, "First player spawned")
		assert_not_null(p2, "Second player spawned")
		_cleanup_list.append(p1)
		_cleanup_list.append(p2)

		var gui1: Variant = p1.get("gui")
		var gui2: Variant = p2.get("gui")
		assert_true(gui1 != null and is_instance_valid(gui1), "p1.gui is valid")
		assert_true(gui2 != null and is_instance_valid(gui2), "p2.gui is valid")
		assert_ne(gui1, gui2, "Concurrent players own isolated stub GUIs")

		E2EHelpersScript.cleanup_node(p1)
		assert_false(is_instance_valid(p1), "p1 freed by cleanup_node")
		assert_true(is_instance_valid(p2), "p2 remains valid after p1 cleanup")
		assert_true(is_instance_valid(p2.get("gui")), "p2.gui remains valid (non-dangling) after p1 cleanup")
		p2.call("calculate_experience", 1)
		assert_true(is_instance_valid(p2.get("gui")), "p2.gui remains functional on calculate_experience")

	func test_smoke_post_spawn_stride_parity() -> void:
		var settings_mgr := E2EHelpersScript.get_autoload("SettingsManager")
		E2EHelpersScript.set_prop(settings_mgr, "mouse_control", false)

		var player := await E2EHelpersScript.spawn_player_ready(_tree(), "mage")
		assert_not_null(player, "spawn_player_ready returns initialized Player")
		_cleanup_list.append(player)
		assert_true(E2EHelpersScript.has_prop(player, "stride_distance_total"), "Player exposes stride_distance_total")

		var start_pos: Vector2 = player.global_position
		var start_stride := float(E2EHelpersScript.get_prop(player, "stride_distance_total", 0.0))

		assert_true(E2EHelpersScript.press_action("right", true), "Action 'right' pressed")
		await E2EHelpersScript.step_tree_frames(_tree(), 10)

		var disp1: float = player.global_position.distance_to(start_pos)
		var stride1: float = float(E2EHelpersScript.get_prop(player, "stride_distance_total", 0.0)) - start_stride
		assert_gt(disp1, 0.0, "Player displaced over 10 SceneTree physics frames")
		assert_almost_eq(stride1, disp1, 0.05, "stride_distance_total matches SceneTree displacement")

		var mid_pos: Vector2 = player.global_position
		var mid_stride := float(E2EHelpersScript.get_prop(player, "stride_distance_total", 0.0))
		E2EHelpersScript.step_physics(player, 6, 1.0 / 60.0, false)
		var disp2: float = player.global_position.distance_to(mid_pos)
		var stride2: float = float(E2EHelpersScript.get_prop(player, "stride_distance_total", 0.0)) - mid_stride
		assert_gt(disp2, 0.0, "Player displaced during post-sync step_physics at 1/60s")
		assert_almost_eq(stride2, disp2, 0.05, "stride_distance_total matches step_physics(1/60s) displacement")

		E2EHelpersScript.release_all_inputs()


func _physics_process(_delta: float) -> bool:
	if _has_run:
		return false
	_has_run = true

	_run_and_quit()
	return false


func _run_and_quit() -> void:
	var exit_code: int = await run_all_e2e_tests()
	quit(exit_code)


func _parse_cli_args() -> Dictionary:
	var result := {
		"valid": true,
		"error": "",
		"tier": 0,
		"suite": "",
		"ignore_missing": false,
		"smoke": false
	}

	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg).strip_edges()
		if arg == "":
			continue
		if arg.begins_with("--tier="):
			var val := arg.substr(7).strip_edges()
			if not val.is_valid_int():
				result["valid"] = false
				result["error"] = "Invalid --tier value '%s' (expected 1, 2, 3, or 4)" % val
				return result
			var tier_num := int(val)
			if tier_num < 1 or tier_num > 4:
				result["valid"] = false
				result["error"] = "Out-of-range --tier value '%d' (expected 1..4)" % tier_num
				return result
			result["tier"] = tier_num
		elif arg.begins_with("--suite="):
			var suite_val := arg.substr(8).strip_edges().to_lower()
			if suite_val == "":
				result["valid"] = false
				result["error"] = "Empty --suite value (expected non-empty substring)"
				return result
			result["suite"] = suite_val
		elif arg == "--ignore-missing":
			result["ignore_missing"] = true
		elif arg == "--smoke":
			result["smoke"] = true
		else:
			result["valid"] = false
			result["error"] = "Unknown CLI argument: '%s' (supported: --tier=<1..4>, --suite=<substr>, --ignore-missing, --smoke)" % arg
			return result

	return result


func _execute_suite_instance(suite: Object, suite_name: String, suite_path: String) -> Dictionary:
	var stats := {
		"passed_tests": 0,
		"failed_tests": 0,
		"total_tests": 0,
		"assertions": 0,
		"failures": 0,
		"hook_failures": 0,
		"suite_passed": false
	}

	var suite_assertions_start: int = int(suite.assertion_count)
	var suite_failures_start: int = int(suite.failure_count)
	var before_all_msg_start: int = (suite.failures as Array).size()

	if suite.has_method("before_all"):
		await suite.call("before_all")

	var before_all_new_fails: int = int(suite.failure_count) - suite_failures_start
	if before_all_new_fails > 0:
		stats["hook_failures"] += before_all_new_fails
		print("  [FAIL] before_all()")
		var all_fails: Array = suite.failures
		for idx in range(before_all_msg_start, all_fails.size()):
			print("         %s" % str(all_fails[idx]))

	var test_methods: Array[String] = []
	for method in suite.get_method_list():
		var m_name: String = method["name"]
		if m_name.begins_with("test_"):
			test_methods.append(m_name)
	test_methods.sort()

	if test_methods.is_empty():
		printerr("ERROR: Suite %s (%s) defines 0 test_* methods" % [suite_name, suite_path])
		stats["total_tests"] += 1
		stats["failed_tests"] += 1

		var empty_after_fail_start: int = int(suite.failure_count)
		var empty_after_msg_start: int = (suite.failures as Array).size()
		if suite.has_method("after_all"):
			await suite.call("after_all")
		var empty_after_new_fails: int = int(suite.failure_count) - empty_after_fail_start
		if empty_after_new_fails > 0:
			stats["hook_failures"] += empty_after_new_fails
			print("  [FAIL] after_all()")
			var all_fails_empty: Array = suite.failures
			for idx in range(empty_after_msg_start, all_fails_empty.size()):
				print("         %s" % str(all_fails_empty[idx]))

		stats["assertions"] = int(suite.assertion_count) - suite_assertions_start
		stats["failures"] = maxi(1, int(suite.failure_count) - suite_failures_start)
		stats["suite_passed"] = false
		return stats

	for test_name in test_methods:
		stats["total_tests"] += 1
		suite._start_test(test_name)

		if suite.has_method("before_each"):
			await suite.call("before_each")

		var t_start := Time.get_ticks_usec()
		await suite.call(test_name)
		var elapsed_ms := (Time.get_ticks_usec() - t_start) / 1000.0

		if suite.has_method("after_each"):
			await suite.call("after_each")

		var test_failures: Array[String] = suite._get_current_test_failures()
		if test_failures.is_empty():
			stats["passed_tests"] += 1
			print("  [PASS] %s (%.2f ms)" % [test_name, elapsed_ms])
		else:
			stats["failed_tests"] += 1
			print("  [FAIL] %s (%.2f ms)" % [test_name, elapsed_ms])
			for f in test_failures:
				print("         %s" % f)

	var after_all_fail_start: int = int(suite.failure_count)
	var after_all_msg_start: int = (suite.failures as Array).size()
	if suite.has_method("after_all"):
		await suite.call("after_all")
	var after_all_new_fails: int = int(suite.failure_count) - after_all_fail_start
	if after_all_new_fails > 0:
		stats["hook_failures"] += after_all_new_fails
		print("  [FAIL] after_all()")
		var all_fails_after: Array = suite.failures
		for idx in range(after_all_msg_start, all_fails_after.size()):
			print("         %s" % str(all_fails_after[idx]))

	stats["assertions"] = int(suite.assertion_count) - suite_assertions_start
	stats["failures"] = int(suite.failure_count) - suite_failures_start
	stats["suite_passed"] = (stats["failures"] == 0 and stats["failed_tests"] == 0 and stats["hook_failures"] == 0)
	return stats


func run_all_e2e_tests() -> int:
	print("\n======================================================================")
	print(" Inritus E2E Test Suite (Godot 4.6+ Headless CLI Runner)")
	print("======================================================================\n")

	var cli := _parse_cli_args()
	if not cli["valid"]:
		printerr("ERROR: %s" % cli["error"])
		print("STATUS: E2E TESTS FAILED")
		print("======================================================================\n")
		return 1

	var filter_tier: int = cli["tier"]
	var filter_suite: String = cli["suite"]
	var ignore_missing: bool = cli["ignore_missing"]
	var run_smoke: bool = cli["smoke"]

	var total_suites: int = 0
	var passed_suites: int = 0
	var skipped_suites: int = 0
	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	var total_assertions: int = 0
	var total_assertion_failures: int = 0

	var tier_stats: Dictionary = {}
	for t in [1, 2, 3, 4]:
		tier_stats[t] = {
			"suites": 0,
			"passed_suites": 0,
			"skipped_suites": 0,
			"tests": 0,
			"passed": 0,
			"failed": 0,
			"assertions": 0
		}

	var runner_start_time := Time.get_ticks_usec()

	if run_smoke:
		var smoke_haystack := "smoke e2e_smoke built-in runner helpers"
		var smoke_matches_suite := (filter_suite == "" or smoke_haystack.contains(filter_suite))
		if smoke_matches_suite:
			total_suites += 1
			print("----------------------------------------------------------------------")
			print("RUNNING SUITE: E2E Runner & Helpers Smoke Check (built-in)")
			print("----------------------------------------------------------------------")
			var smoke_suite := _E2ESmokeSuite.new()
			var s_res: Dictionary = await _execute_suite_instance(smoke_suite, "E2E Smoke Check", "built-in")
			total_tests += s_res["total_tests"]
			passed_tests += s_res["passed_tests"]
			failed_tests += s_res["failed_tests"]
			total_assertions += s_res["assertions"]
			total_assertion_failures += s_res["failures"]
			if s_res["suite_passed"]:
				passed_suites += 1
			print("")

	for suite_info in SUITES:
		var tier: int = suite_info["tier"]
		var suite_id: String = suite_info["id"]
		var suite_name: String = suite_info["name"]
		var suite_path: String = suite_info["path"]

		if filter_tier > 0 and tier != filter_tier:
			continue
		if filter_suite != "":
			var haystack := (suite_id + " " + suite_name + " " + suite_path).to_lower()
			if not haystack.contains(filter_suite):
				continue

		total_suites += 1
		tier_stats[tier]["suites"] += 1

		print("----------------------------------------------------------------------")
		print("RUNNING SUITE [Tier %d]: %s (%s)" % [tier, suite_name, suite_path])
		print("----------------------------------------------------------------------")

		if not ResourceLoader.exists(suite_path):
			if ignore_missing:
				skipped_suites += 1
				tier_stats[tier]["skipped_suites"] += 1
				print("  [SKIP - not yet created] %s\n" % suite_path)
				continue
			else:
				printerr("ERROR: E2E suite file does not exist: %s" % suite_path)
				failed_tests += 1
				tier_stats[tier]["failed"] += 1
				print("")
				continue

		var suite_script := load(suite_path)
		if suite_script == null or not (suite_script is GDScript) or not (suite_script as GDScript).can_instantiate():
			printerr("ERROR: Could not load/compile E2E suite script: %s" % suite_path)
			failed_tests += 1
			tier_stats[tier]["failed"] += 1
			print("")
			continue

		var suite: Object = (suite_script as GDScript).new()
		if suite == null or not (suite is TestBaseScript):
			printerr("ERROR: E2E suite must instantiate and extend TestBase: %s" % suite_path)
			failed_tests += 1
			tier_stats[tier]["failed"] += 1
			print("")
			continue

		var res: Dictionary = await _execute_suite_instance(suite, suite_name, suite_path)
		total_tests += res["total_tests"]
		passed_tests += res["passed_tests"]
		failed_tests += res["failed_tests"]
		total_assertions += res["assertions"]
		total_assertion_failures += res["failures"]

		tier_stats[tier]["tests"] += res["total_tests"]
		tier_stats[tier]["passed"] += res["passed_tests"]
		tier_stats[tier]["failed"] += res["failed_tests"]
		tier_stats[tier]["assertions"] += res["assertions"]

		if res["suite_passed"]:
			passed_suites += 1
			tier_stats[tier]["passed_suites"] += 1

		print("")

	var total_elapsed_ms := (Time.get_ticks_usec() - runner_start_time) / 1000.0

	print("======================================================================")
	print("                       E2E TEST RUN SUMMARY")
	print("======================================================================")
	for t in [1, 2, 3, 4]:
		var ts: Dictionary = tier_stats[t]
		if ts["suites"] > 0:
			print("Tier %d:      Suites %d/%d passed (skipped %d) | Tests %d/%d passed, %d failed | Assertions %d" % [
				t, ts["passed_suites"], ts["suites"], ts["skipped_suites"],
				ts["passed"], ts["tests"], ts["failed"], ts["assertions"]
			])
	print("Suites:      %d passed, %d skipped, %d total" % [passed_suites, skipped_suites, total_suites])
	print("Tests:       %d passed, %d failed, %d total" % [passed_tests, failed_tests, total_tests])
	print("Assertions:  %d passed (%d failures)" % [maxi(0, total_assertions - total_assertion_failures), total_assertion_failures])
	print("Duration:    %.2f ms" % total_elapsed_ms)

	var no_suites_matched := (total_suites == 0)
	var no_tests_executed := (total_tests == 0 and not ignore_missing)
	if failed_tests == 0 and total_assertion_failures == 0 and passed_suites == (total_suites - skipped_suites) and not no_suites_matched and not no_tests_executed:
		print("STATUS:      ALL E2E TESTS PASSED [OK]")
		print("======================================================================\n")
		return 0
	else:
		if no_suites_matched:
			printerr("ERROR: No E2E suites matched the provided filters.")
		print("STATUS:      E2E TESTS FAILED")
		print("======================================================================\n")
		return 1
