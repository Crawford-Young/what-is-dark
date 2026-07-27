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


func test_eroded_size_returns_base_at_zero_scale() -> void:
	assert_almost_eq(ErosionLogic.eroded_size(14.0, 12.4, 0.0), 14.0, 0.0001)


func test_eroded_size_returns_min_at_full_scale() -> void:
	assert_almost_eq(ErosionLogic.eroded_size(14.0, 12.4, 1.0), 12.4, 0.0001)


func test_eroded_size_interpolates_between_base_and_min() -> void:
	assert_almost_eq(ErosionLogic.eroded_size(14.0, 12.4, 0.5), 13.2, 0.0001)
	assert_almost_eq(ErosionLogic.eroded_size(16.0, 5.0, 0.2), 13.8, 0.0001)


func test_eroded_size_clamps_scale_outside_unit_range() -> void:
	assert_almost_eq(ErosionLogic.eroded_size(14.0, 12.4, -2.0), 14.0, 0.0001)
	assert_almost_eq(ErosionLogic.eroded_size(14.0, 12.4, 3.0), 12.4, 0.0001)


func test_eroded_size_never_grows_a_platform() -> void:
	assert_almost_eq(ErosionLogic.eroded_size(8.0, 8.0, 1.0), 8.0, 0.0001)
	assert_almost_eq(ErosionLogic.eroded_size(8.0, 12.0, 1.0), 8.0, 0.0001)


func test_eroded_size_at_loop_zero_is_shipped_geometry() -> void:
	var scale := ErosionLogic.world_scale(0)
	assert_almost_eq(ErosionLogic.eroded_size(19.0, 18.3, scale), 19.0, 0.0001)
	assert_almost_eq(ErosionLogic.eroded_size(2.5, 1.4, scale), 2.5, 0.0001)


func test_anchored_origin_center_anchor_holds_position() -> void:
	assert_almost_eq(ErosionLogic.anchored_origin(-47.5, 14.0, 12.4, 0.0), -47.5, 0.0001)


func test_anchored_origin_positive_anchor_pins_high_edge() -> void:
	assert_almost_eq(ErosionLogic.anchored_origin(-24.5, 19.0, 18.3, 1.0), -24.15, 0.0001)


func test_anchored_origin_negative_anchor_pins_low_edge() -> void:
	assert_almost_eq(ErosionLogic.anchored_origin(-24.5, 19.0, 18.3, -1.0), -24.85, 0.0001)


func test_anchored_origin_unchanged_when_size_unchanged() -> void:
	assert_almost_eq(ErosionLogic.anchored_origin(-47.5, 14.0, 14.0, 1.0), -47.5, 0.0001)
	assert_almost_eq(ErosionLogic.anchored_origin(-47.5, 14.0, 14.0, -1.0), -47.5, 0.0001)


func test_fog_density_is_zero_at_zero_scale() -> void:
	assert_almost_eq(ErosionLogic.fog_density(0.0), 0.0, 0.000001)


func test_fog_density_reaches_max_at_full_scale() -> void:
	assert_almost_eq(ErosionLogic.fog_density(1.0), ErosionLogic.FOG_DENSITY_MAX, 0.000001)


func test_fog_density_ramps_linearly() -> void:
	assert_almost_eq(
		ErosionLogic.fog_density(0.4), ErosionLogic.FOG_DENSITY_MAX * 0.4, 0.000001
	)


func test_fog_density_clamps_scale_outside_unit_range() -> void:
	assert_almost_eq(ErosionLogic.fog_density(-1.0), 0.0, 0.000001)
	assert_almost_eq(ErosionLogic.fog_density(4.0), ErosionLogic.FOG_DENSITY_MAX, 0.000001)
