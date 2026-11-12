extends SceneTree

func _process(_delta: float) -> bool:
	var tb = load("res://Tests/test_base.gd").new()
	tb._start_test("test_intended_failure")
	tb.assert_eq(1, 2, "1 should equal 2")
	print("Failure count: %d" % tb.failure_count)
	quit(tb.failure_count)
	return true
