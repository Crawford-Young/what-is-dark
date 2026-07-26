extends GutTest


func test_can_wallrun_conditions() -> void:
	assert_true(WallrunLogic.can_wallrun(false, true, 5.0))
	assert_false(WallrunLogic.can_wallrun(true, true, 5.0), "on floor")
	assert_false(WallrunLogic.can_wallrun(false, false, 5.0), "no wall")
	assert_false(WallrunLogic.can_wallrun(false, true, 3.0), "too slow")


func test_ride_preserves_along_wall_speed_and_caps_sink() -> void:
	var v := WallrunLogic.ride_velocity(Vector3(0, -8, -20), Vector3(1, 0, 0))
	assert_almost_eq(v.z, -20.0, 0.0001)
	assert_almost_eq(v.y, -2.0, 0.0001)


func test_ride_clips_into_wall_component() -> void:
	var v := WallrunLogic.ride_velocity(Vector3(-5, 0, -20), Vector3(1, 0, 0))
	assert_almost_eq(v.x, 0.0, 0.0001)
	assert_almost_eq(v.z, -20.0, 0.0001)


func test_ride_keeps_upward_carry() -> void:
	var v := WallrunLogic.ride_velocity(Vector3(0, 3, -15), Vector3(1, 0, 0))
	assert_almost_eq(v.y, 3.0, 0.0001)


func test_kick_preserves_horizontal_and_boosts_up() -> void:
	var v := WallrunLogic.kick_velocity(Vector3(0, -1, -30), Vector3(1, 0, 0))
	assert_almost_eq(v.x, 6.0, 0.0001)
	assert_almost_eq(v.z, -30.0, 0.0001)
	assert_almost_eq(v.y, 8.63, 0.0001)


func test_kick_keeps_higher_upward_speed() -> void:
	var v := WallrunLogic.kick_velocity(Vector3(0, 12, -10), Vector3(1, 0, 0))
	assert_almost_eq(v.y, 12.0, 0.0001)


func test_jump_released_edge() -> void:
	assert_true(WallrunLogic.jump_released(true, false), "release edge")
	assert_false(WallrunLogic.jump_released(true, true), "still held")
	assert_false(WallrunLogic.jump_released(false, false), "never held")
	assert_false(WallrunLogic.jump_released(false, true), "press edge")
