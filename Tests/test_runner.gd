# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Headless Unit Test Runner
# Executes test suites via Godot CLI: godot --headless -s res://Tests/test_runner.gd

extends SceneTree

var _has_run: bool = false

# Registered test suite scripts
const SUITES: Array[Dictionary] = [
	{
		"name": "UpgradeDb Integrity",
		"id": "upgrade_db",
		"path": "res://Tests/Unit/test_upgrade_db.gd"
	},
	{
		"name": "Player Stats & Leveling",
		"id": "player_stats",
		"path": "res://Tests/Unit/test_player_stats.gd"
	},
	{
		"name": "Difficulty Scaling & Progression",
		"id": "difficulty_scaling",
		"path": "res://Tests/Unit/test_difficulty_scaling.gd"
	},
	{
		"name": "Health Items & Mechanics",
		"id": "health_items",
		"path": "res://test/unit/test_health_items.gd"
	},
	{
		"name": "Health Items Adversarial Stress",
		"id": "health_items_stress",
		"path": "res://test/unit/test_health_items_stress.gd"
	},
	{
		"name": "Weapon & ICD Fixes",
		"id": "weapon_fixes",
		"path": "res://Tests/Unit/test_weapon_fixes.gd"
	},
	{
		"name": "Diorama Studio & Player System",
		"id": "diorama_system",
		"path": "res://Tests/Unit/test_diorama_system.gd"
	}
]

func _process(_delta: float) -> bool:
	if _has_run:
		return false
	_has_run = true
	
	var exit_code = run_all_tests()
	quit(exit_code)
	return true



func run_all_tests() -> int:
	var total_suites: int = 0
	var passed_suites: int = 0
	var total_tests: int = 0
	var passed_tests: int = 0
	var failed_tests: int = 0
	var total_assertions: int = 0
	
	var filter_suite: String = _get_cli_suite_filter()
	
	print("\n======================================================================")
	print(" SurvivorsClone Unit Test Suite (Godot 4.6 Headless CLI Runner)")
	print("======================================================================\n")
	
	var runner_start_time = Time.get_ticks_usec()
	
	for suite_info in SUITES:
		if filter_suite != "" and not suite_info["id"].contains(filter_suite):
			continue
		
		total_suites += 1
		var suite_name: String = suite_info["name"]
		var suite_path: String = suite_info["path"]
		
		print("----------------------------------------------------------------------")
		print("RUNNING SUITE: %s (%s)" % [suite_name, suite_path])
		print("----------------------------------------------------------------------")
		
		var suite_script = load(suite_path)
		if suite_script == null:
			printerr("ERROR: Could not load test suite script: %s" % suite_path)
			failed_tests += 1
			continue
		
		var suite = suite_script.new()
		if suite == null:
			printerr("ERROR: Could not instantiate test suite: %s" % suite_path)
			failed_tests += 1
			continue
		
		# Lifecycle: before_all
		if suite.has_method("before_all"):
			suite.before_all()
		
		# Discover test methods
		var test_methods: Array[String] = []
		for method in suite.get_method_list():
			var m_name: String = method["name"]
			if m_name.begins_with("test_"):
				test_methods.append(m_name)
		test_methods.sort()
		
		var suite_failures_start = suite.failure_count
		
		for test_name in test_methods:
			total_tests += 1
			suite._start_test(test_name)
			
			if suite.has_method("before_each"):
				suite.before_each()
			
			var t_start = Time.get_ticks_usec()
			suite.call(test_name)
			var elapsed_ms = (Time.get_ticks_usec() - t_start) / 1000.0
			
			if suite.has_method("after_each"):
				suite.after_each()
			
			var failures: Array[String] = suite._get_current_test_failures()
			if failures.is_empty():
				passed_tests += 1
				print("  [PASS] %s (%.2f ms)" % [test_name, elapsed_ms])
			else:
				failed_tests += 1
				print("  [FAIL] %s (%.2f ms)" % [test_name, elapsed_ms])
				for f in failures:
					print("         %s" % f)
		
		# Lifecycle: after_all
		if suite.has_method("after_all"):
			suite.after_all()
		
		total_assertions += suite.assertion_count
		if suite.failure_count == suite_failures_start:
			passed_suites += 1
		
		print("")
	
	var total_elapsed_ms = (Time.get_ticks_usec() - runner_start_time) / 1000.0
	
	print("======================================================================")
	print("                         TEST RUN SUMMARY")
	print("======================================================================")
	print("Suites:      %d passed, %d total" % [passed_suites, total_suites])
	print("Tests:       %d passed, %d failed, %d total" % [passed_tests, failed_tests, total_tests])
	print("Assertions:  %d passed (%d failures)" % [total_assertions - failed_tests, failed_tests])
	print("Duration:    %.2f ms" % total_elapsed_ms)
	
	if failed_tests == 0 and total_tests > 0:
		print("STATUS:      ALL TESTS PASSED [OK]")
		print("======================================================================\n")
		return 0
	else:
		print("STATUS:      TEST FAILURES ENCOUNTERED [FAIL]")
		print("======================================================================\n")
		return 1

func _get_cli_suite_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			return arg.substr(8).strip_edges().to_lower()
	return ""
