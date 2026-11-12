# SPDX-License-Identifier: GPL-3.0-or-later
# SurvivorsClone Unit Testing Framework - Base Test Class
# Pragmatic, zero-dependency unit testing assertion library for Godot 4.6.

class_name TestBase
extends RefCounted

var assertion_count: int = 0
var failure_count: int = 0
var current_test_name: String = ""
var failures: Array[String] = []
var _test_failures: Array[String] = []

# Optional lifecycle hooks to be overridden by subclasses
func before_all() -> void:
	pass

func before_each() -> void:
	pass

func after_each() -> void:
	pass

func after_all() -> void:
	pass

# Called by the runner before starting each test method
func _start_test(test_name: String) -> void:
	current_test_name = test_name
	_test_failures.clear()

# Returns failures accumulated in the currently executing test
func _get_current_test_failures() -> Array[String]:
	return _test_failures

# Fail registration helper
func fail(msg: String) -> void:
	assertion_count += 1
	failure_count += 1
	var formatted = "[%s] FAIL: %s" % [current_test_name, msg]
	failures.append(formatted)
	_test_failures.append(formatted)

# Assertion: Boolean True
func assert_true(cond: bool, msg: String = "") -> bool:
	assertion_count += 1
	if not cond:
		failure_count += 1
		var reason = msg if msg != "" else "Expected condition to be true, got false"
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Boolean False
func assert_false(cond: bool, msg: String = "") -> bool:
	assertion_count += 1
	if cond:
		failure_count += 1
		var reason = msg if msg != "" else "Expected condition to be false, got true"
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Value Equality
func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if actual != expected:
		failure_count += 1
		var exp_str = str(expected) if (expected is Object) else var_to_str(expected)
		var act_str = str(actual) if (actual is Object) else var_to_str(actual)
		var detail = "Expected %s (type %s), got %s (type %s)" % [
			exp_str, typeof(expected),
			act_str, typeof(actual)
		]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Value Inequality
func assert_ne(actual: Variant, expected: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if actual == expected:
		failure_count += 1
		var act_str = str(actual) if (actual is Object) else var_to_str(actual)
		var detail = "Expected values to differ, but both equal %s" % [act_str]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Approximate Floating-Point Equality
func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, msg: String = "") -> bool:
	assertion_count += 1
	var diff = abs(actual - expected)
	if diff > tolerance:
		failure_count += 1
		var detail = "Expected ~%s (±%s), got %s (diff: %s)" % [
			str(expected), str(tolerance), str(actual), str(diff)
		]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Key / Element presence in dictionary, array, or string
func assert_has(container: Variant, key: Variant, msg: String = "") -> bool:
	assertion_count += 1
	var found = false
	if container is Dictionary:
		found = (container as Dictionary).has(key)
	elif container is Array:
		found = (container as Array).has(key)
	elif container is String:
		found = (container as String).contains(str(key))
	else:
		found = false
	
	if not found:
		failure_count += 1
		var detail = "Container does not contain key/element %s" % [var_to_str(key)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: All keys / elements present
func assert_has_all(container: Variant, keys: Array, msg: String = "") -> bool:
	assertion_count += 1
	var missing: Array = []
	for k in keys:
		var found = false
		if container is Dictionary:
			found = (container as Dictionary).has(k)
		elif container is Array:
			found = (container as Array).has(k)
		if not found:
			missing.append(k)
	
	if not missing.is_empty():
		failure_count += 1
		var detail = "Container missing expected keys: %s" % [str(missing)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Null check
func assert_null(val: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if val != null:
		failure_count += 1
		var detail = "Expected null, got %s" % [var_to_str(val)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Not-null check
func assert_not_null(val: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if val == null:
		failure_count += 1
		var detail = "Expected non-null value, got null"
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Greater than
func assert_gt(a: Variant, b: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if not (a > b):
		failure_count += 1
		var detail = "Expected %s > %s" % [str(a), str(b)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Greater than or equal to
func assert_gte(a: Variant, b: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if not (a >= b):
		failure_count += 1
		var detail = "Expected %s >= %s" % [str(a), str(b)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Less than
func assert_lt(a: Variant, b: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if not (a < b):
		failure_count += 1
		var detail = "Expected %s < %s" % [str(a), str(b)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true

# Assertion: Less than or equal to
func assert_lte(a: Variant, b: Variant, msg: String = "") -> bool:
	assertion_count += 1
	if not (a <= b):
		failure_count += 1
		var detail = "Expected %s <= %s" % [str(a), str(b)]
		var reason = "%s - %s" % [detail, msg] if msg != "" else detail
		var formatted = "[%s] FAIL: %s" % [current_test_name, reason]
		failures.append(formatted)
		_test_failures.append(formatted)
		return false
	return true
