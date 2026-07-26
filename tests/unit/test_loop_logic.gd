extends GutTest


func test_door_not_crossed_before_boundary() -> void:
	assert_false(LoopLogic.has_crossed_door(1794.9))


func test_door_crossed_at_exact_boundary() -> void:
	assert_true(LoopLogic.has_crossed_door(1795.0))


func test_door_crossed_past_boundary() -> void:
	assert_true(LoopLogic.has_crossed_door(1800.0))


func test_advance_loop_increments() -> void:
	var loop := LoopLogic.new()
	assert_eq(loop.loop_count, 0)
	loop.advance_loop()
	loop.advance_loop()
	assert_eq(loop.loop_count, 2)
