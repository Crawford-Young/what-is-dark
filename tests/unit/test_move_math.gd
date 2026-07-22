extends GutTest


func test_accel_moves_horizontal_velocity_toward_wish_dir() -> void:
	var v := MoveMath.accel_horizontal(Vector3.ZERO, Vector3(0, 0, -1), 8.0, 60.0, 0.1)
	assert_true(v.is_equal_approx(Vector3(0, 0, -6.0)), "0.1s at accel 60 caps at 6 m/s toward wish")


func test_accel_does_not_overshoot_target_speed() -> void:
	var v := MoveMath.accel_horizontal(Vector3(0, 0, -7.9), Vector3(0, 0, -1), 8.0, 60.0, 1.0)
	assert_true(v.is_equal_approx(Vector3(0, 0, -8.0)))


func test_accel_preserves_vertical_velocity() -> void:
	var v := MoveMath.accel_horizontal(Vector3(0, 5.0, 0), Vector3(1, 0, 0), 8.0, 60.0, 0.016)
	assert_almost_eq(v.y, 5.0, 0.0001)


func test_zero_wish_dir_decelerates_to_stop() -> void:
	var v := MoveMath.accel_horizontal(Vector3(4, 0, 0), Vector3.ZERO, 8.0, 60.0, 1.0)
	assert_true(v.is_equal_approx(Vector3.ZERO))


func test_gravity_reduces_y() -> void:
	var v := MoveMath.apply_gravity(Vector3(1, 0, 2), 18.0, 0.5)
	assert_true(v.is_equal_approx(Vector3(1, -9.0, 2)))


func test_jump_sets_y_keeps_horizontal() -> void:
	var v := MoveMath.jump(Vector3(3, -2, -5), 7.0)
	assert_true(v.is_equal_approx(Vector3(3, 7.0, -5)))
