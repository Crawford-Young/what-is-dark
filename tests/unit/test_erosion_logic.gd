extends GutTest


func test_accel_multiplier_decays_and_floors() -> void:
	assert_almost_eq(ErosionLogic.accel_multiplier(0), 1.0, 0.0001)
	assert_almost_eq(ErosionLogic.accel_multiplier(1), 0.88, 0.0001)
	assert_almost_eq(ErosionLogic.accel_multiplier(4), 0.52, 0.0001)
	assert_almost_eq(ErosionLogic.accel_multiplier(9), 0.52, 0.0001)


func test_landing_retention_decays_and_floors() -> void:
	assert_almost_eq(ErosionLogic.landing_retention(0), 1.0, 0.0001)
	assert_almost_eq(ErosionLogic.landing_retention(2), 0.9, 0.0001)
	assert_almost_eq(ErosionLogic.landing_retention(4), 0.8, 0.0001)
	assert_almost_eq(ErosionLogic.landing_retention(9), 0.8, 0.0001)


func test_negative_loop_clamps_to_no_erosion() -> void:
	assert_almost_eq(ErosionLogic.accel_multiplier(-3), 1.0, 0.0001)
	assert_almost_eq(ErosionLogic.landing_retention(-3), 1.0, 0.0001)
