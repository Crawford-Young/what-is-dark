extends GutTest


func test_creep_speed_depends_on_posture() -> void:
	var v := VoidLogic.new(0.0)
	v.advance(Posture.AWAY, 1.0)
	assert_almost_eq(v.progress, 4.0, 0.0001)
	v.advance(Posture.GLANCING, 1.0)
	assert_almost_eq(v.progress, 5.5, 0.0001)
	v.advance(Posture.FACING, 1.0)
	assert_almost_eq(v.progress, 6.0, 0.0001, "facing slows creep but never stops it")


func test_has_caught_at_or_past_player() -> void:
	var v := VoidLogic.new(10.0)
	assert_true(v.has_caught(10.0))
	assert_true(v.has_caught(9.0))
	assert_false(v.has_caught(11.0))


func test_reset_behind_leaves_gap() -> void:
	var v := VoidLogic.new(50.0)
	v.reset_behind(25.0)
	assert_almost_eq(v.progress, 13.0, 0.0001)


func test_reset_behind_goes_negative_at_first_marker() -> void:
	var v := VoidLogic.new(50.0)
	v.reset_behind(0.0)
	assert_almost_eq(v.progress, -12.0, 0.0001)
