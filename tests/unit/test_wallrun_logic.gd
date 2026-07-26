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


func test_ride_preserves_outward_motion_after_kick() -> void:
	# Post-kick tick: ray still sees the wall but velocity points away —
	# ride must not clip the launch back off (unguarded clip ate the kick).
	var v := WallrunLogic.ride_velocity(Vector3(6.0, 8.63, -10.0), Vector3(1, 0, 0))
	assert_almost_eq(v.x, 6.0, 0.0001)
	assert_almost_eq(v.y, 8.63, 0.0001)
	assert_almost_eq(v.z, -10.0, 0.0001)


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


func test_jump_pressed_edge() -> void:
	assert_true(WallrunLogic.jump_pressed(false, true), "press edge")
	assert_false(WallrunLogic.jump_pressed(true, true), "still held")
	assert_false(WallrunLogic.jump_pressed(false, false), "never down")
	assert_false(WallrunLogic.jump_pressed(true, false), "release edge")


func test_rideable_normal_vertical_wall() -> void:
	assert_true(WallrunLogic.is_rideable_normal(Vector3(1, 0, 0)))


func test_rideable_normal_slight_lean_ok() -> void:
	assert_true(WallrunLogic.is_rideable_normal(Vector3(0.99, 0.15, 0).normalized()))
	assert_true(WallrunLogic.is_rideable_normal(Vector3(0.99, -0.15, 0).normalized()), "overhang lean")


func test_surf_ramp_normals_not_rideable() -> void:
	assert_false(WallrunLogic.is_rideable_normal(Vector3(sin(deg_to_rad(45.0)), cos(deg_to_rad(45.0)), 0.0)))
	assert_false(WallrunLogic.is_rideable_normal(Vector3(sin(deg_to_rad(51.34)), cos(deg_to_rad(51.34)), 0.0)))
	assert_false(WallrunLogic.is_rideable_normal(Vector3(sin(deg_to_rad(55.0)), cos(deg_to_rad(55.0)), 0.0)))


func test_rideable_normal_zero_is_not_wall() -> void:
	assert_false(WallrunLogic.is_rideable_normal(Vector3.ZERO))
