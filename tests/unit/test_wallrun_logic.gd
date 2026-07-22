extends GutTest


func test_wallrun_requires_airborne_wall_and_speed() -> void:
	assert_true(WallrunLogic.can_wallrun(false, true, 5.0))
	assert_false(WallrunLogic.can_wallrun(true, true, 5.0), "on floor")
	assert_false(WallrunLogic.can_wallrun(false, false, 5.0), "no wall")
	assert_false(WallrunLogic.can_wallrun(false, true, 3.0), "too slow")


func test_wallrun_velocity_slides_along_wall() -> void:
	var v := WallrunLogic.wallrun_velocity(Vector3(1, 0, -8), Vector3(1, 0, 0), 0.016)
	assert_almost_eq(v.x, 0.0, 0.0001, "component into wall removed")
	assert_almost_eq(v.z, -8.0, 0.0001, "forward speed kept")


func test_wallrun_sinks_gently_and_caps() -> void:
	var v := WallrunLogic.wallrun_velocity(Vector3(0, 0, -8), Vector3(1, 0, 0), 1.0)
	assert_almost_eq(v.y, -1.5, 0.0001, "1s of sink at 1.5")
	var v2 := WallrunLogic.wallrun_velocity(Vector3(0, -10.0, -8), Vector3(1, 0, 0), 1.0)
	assert_almost_eq(v2.y, -2.0, 0.0001, "sink capped at -2")


func test_walljump_pushes_away_and_up() -> void:
	var v := WallrunLogic.walljump_velocity(Vector3(0, -1, -8), Vector3(1, 0, 0))
	assert_almost_eq(v.x, 6.0, 0.0001)
	assert_almost_eq(v.y, 6.5, 0.0001)
	assert_almost_eq(v.z, -8.0, 0.0001)
