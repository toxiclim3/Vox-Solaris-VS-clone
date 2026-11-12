# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Unit Testing Suite - UpgradeDb Integrity
# Validates UpgradeDb.UPGRADES schema, types, prerequisite DAG, and progression.

extends "res://Tests/test_base.gd"

var upgrades: Dictionary = {}

func before_all() -> void:
	var udb_script = preload("res://Utility/upgrade_db.gd")
	upgrades = udb_script.UPGRADES

func test_upgrade_db_not_empty() -> void:
	assert_true(not upgrades.is_empty(), "UpgradeDb.UPGRADES must not be empty")
	assert_gt(upgrades.size(), 80, "Expected at least 80 registered upgrades in database")

func test_required_schema_keys() -> void:
	var required_keys = ["icon", "displayname", "details", "level", "prerequisite", "type"]
	for item_key in upgrades:
		var entry = upgrades[item_key]
		assert_true(entry is Dictionary, "Entry %s must be a Dictionary" % item_key)
		for req in required_keys:
			assert_has(entry, req, "Entry '%s' missing required schema key '%s'" % [item_key, req])
		
		assert_true(entry.get("icon") is String and not entry.get("icon").is_empty(),
			"Entry '%s' icon must be a non-empty String" % item_key)
		assert_true(entry.get("displayname") is String and not entry.get("displayname").is_empty(),
			"Entry '%s' displayname must be a non-empty String" % item_key)
		assert_true(entry.get("details") is String and not entry.get("details").is_empty(),
			"Entry '%s' details must be a non-empty String" % item_key)
		assert_true(entry.get("level") is String and not entry.get("level").is_empty(),
			"Entry '%s' level must be a non-empty String" % item_key)
		assert_true(entry.get("prerequisite") is Array,
			"Entry '%s' prerequisite must be an Array" % item_key)
		assert_true(entry.get("type") is String and not entry.get("type").is_empty(),
			"Entry '%s' type must be a non-empty String" % item_key)

func test_valid_types() -> void:
	var allowed_types = ["weapon", "upgrade", "bossitem", "item", "endless"]
	for item_key in upgrades:
		var type_str = upgrades[item_key].get("type", "")
		assert_has(allowed_types, type_str,
			"Entry '%s' has unrecognized type '%s'" % [item_key, type_str])

func test_valid_levels() -> void:
	var allowed_levels = [
		"item_level1", "item_level2", "item_level3", "item_level4",
		"item_levelNA", "item_level_endless"
	]
	for item_key in upgrades:
		var lvl_str = upgrades[item_key].get("level", "")
		assert_has(allowed_levels, lvl_str,
			"Entry '%s' has unrecognized level string '%s'" % [item_key, lvl_str])

func test_all_prerequisites_exist() -> void:
	for item_key in upgrades:
		var prereqs = upgrades[item_key].get("prerequisite", [])
		for prereq in prereqs:
			assert_has(upgrades, prereq,
				"Entry '%s' specifies non-existent prerequisite '%s'" % [item_key, str(prereq)])

func test_prerequisites_dag_has_no_cycles() -> void:
	# Topological / DFS cycle check on prerequisite graph
	# State: 0 = unvisited, 1 = visiting (in recursion stack), 2 = visited
	var visited_state := {}
	for item_key in upgrades:
		visited_state[item_key] = 0

	for item_key in upgrades:
		if visited_state[item_key] == 0:
			var has_cycle = _check_cycle_dfs(item_key, visited_state)
			assert_false(has_cycle, "Cycle detected in prerequisites originating from '%s'" % item_key)

func _check_cycle_dfs(node: String, state: Dictionary) -> bool:
	state[node] = 1 # Visiting
	var prereqs = upgrades.get(node, {}).get("prerequisite", [])
	for next_node in prereqs:
		if not upgrades.has(next_node):
			continue
		var s = state.get(next_node, 0)
		if s == 1:
			return true # Cycle detected
		elif s == 0:
			if _check_cycle_dfs(next_node, state):
				return true
	state[node] = 2 # Visited
	return false

func test_tier_1_and_consumables_prerequisites_empty() -> void:
	for item_key in upgrades:
		var lvl = upgrades[item_key].get("level", "")
		var prereqs = upgrades[item_key].get("prerequisite", [])
		if lvl == "item_level1" or lvl == "item_levelNA":
			assert_eq(prereqs.size(), 0,
				"Entry '%s' with level '%s' must have empty prerequisites, got: %s" % [item_key, lvl, str(prereqs)])

func test_sequential_level_progression() -> void:
	for item_key in upgrades:
		var lvl = upgrades[item_key].get("level", "")
		var prereqs = upgrades[item_key].get("prerequisite", [])
		if lvl in ["item_level2", "item_level3", "item_level4"]:
			assert_gte(prereqs.size(), 1,
				"Multi-tier entry '%s' (%s) must specify at least 1 prerequisite" % [item_key, lvl])
			for prereq in prereqs:
				assert_has(upgrades, prereq, "Prerequisite '%s' must exist" % prereq)
				var prereq_lvl = upgrades[prereq].get("level", "")
				var expected_prereq_lvl = ""
				match lvl:
					"item_level2": expected_prereq_lvl = "item_level1"
					"item_level3": expected_prereq_lvl = "item_level2"
					"item_level4": expected_prereq_lvl = "item_level3"
				assert_eq(prereq_lvl, expected_prereq_lvl,
					"Entry '%s' (%s) has prerequisite '%s' with wrong level '%s' (expected %s)" % [
						item_key, lvl, prereq, prereq_lvl, expected_prereq_lvl
					])

func test_endless_prerequisites() -> void:
	for item_key in upgrades:
		var entry = upgrades[item_key]
		if entry.get("type") == "endless":
			var prereqs = entry.get("prerequisite", [])
			assert_gt(prereqs.size(), 0, "Endless entry '%s' must have prerequisite" % item_key)
			for p in prereqs:
				assert_has(upgrades, p, "Endless prerequisite '%s' must exist" % p)
				assert_ne(upgrades[p].get("type"), "endless",
					"Endless entry '%s' cannot have endless prerequisite '%s'" % [item_key, p])

func test_stat_modifiers_schema() -> void:
	for item_key in upgrades:
		var entry = upgrades[item_key]
		if entry.has("stat_modifiers"):
			var sm = entry["stat_modifiers"]
			assert_true(sm is Dictionary,
				"Entry '%s' stat_modifiers must be Dictionary" % item_key)
			for stat_name in sm:
				assert_true(stat_name is String and not stat_name.is_empty(),
					"Stat name in '%s' must be non-empty String" % item_key)
				var val = sm[stat_name]
				var is_numeric = (typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT)
				assert_true(is_numeric,
					"Stat value for '%s.%s' must be numeric, got %s" % [item_key, stat_name, typeof(val)])

func test_core_weapon_families_exist() -> void:
	var weapon_prefixes = ["icespear", "javelin", "tornado", "poisonbottle", "ritualcircle", "lightningrod", "whip"]
	for prefix in weapon_prefixes:
		for tier in range(1, 5):
			var key = "%s%d" % [prefix, tier]
			assert_has(upgrades, key, "Expected weapon tier '%s' in UpgradeDb" % key)
			assert_eq(upgrades[key].get("type"), "weapon",
				"Key '%s' must be of type 'weapon'" % key)
			assert_eq(upgrades[key].get("level"), "item_level%d" % tier,
				"Key '%s' must have level 'item_level%d'" % [key, tier])

func test_passive_upgrade_families_exist() -> void:
	var passive_prefixes = ["armor", "speed", "tome", "scroll"]
	for prefix in passive_prefixes:
		for tier in range(1, 5):
			var key = "%s%d" % [prefix, tier]
			assert_has(upgrades, key, "Expected passive tier '%s' in UpgradeDb" % key)
			assert_eq(upgrades[key].get("type"), "upgrade",
				"Key '%s' must be of type 'upgrade'" % key)
