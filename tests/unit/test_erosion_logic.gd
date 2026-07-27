extends GutTest


func test_world_scale_zero_at_loop_zero() -> void:
	assert_almost_eq(ErosionLogic.world_scale(0), 0.0, 0.0001)


func test_world_scale_ramps_linearly_to_plateau() -> void:
	assert_almost_eq(ErosionLogic.world_scale(1), 0.2, 0.0001)
	assert_almost_eq(ErosionLogic.world_scale(2), 0.4, 0.0001)
	assert_almost_eq(ErosionLogic.world_scale(4), 0.8, 0.0001)


func test_world_scale_reaches_one_at_plateau_loop() -> void:
	assert_almost_eq(ErosionLogic.world_scale(5), 1.0, 0.0001)


func test_world_scale_clamps_at_one_past_plateau() -> void:
	assert_almost_eq(ErosionLogic.world_scale(9), 1.0, 0.0001)


func test_world_scale_negative_loop_clamps_to_zero() -> void:
	assert_almost_eq(ErosionLogic.world_scale(-3), 0.0, 0.0001)


func test_world_scale_respects_custom_plateau_loop() -> void:
	assert_almost_eq(ErosionLogic.world_scale(1, 2), 0.5, 0.0001)
	assert_almost_eq(ErosionLogic.world_scale(2, 2), 1.0, 0.0001)
