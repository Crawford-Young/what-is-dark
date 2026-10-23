extends GutTest
## The derived-constant tests are the point of this file: they FAIL if a movement
## constant moves and the law module does not follow. That drift is what let a copied
## 8.31 outlive its own derivation for three waves.


func test_airtime_derives_from_jump_and_gravity() -> void:
	assert_almost_eq(
		CourseLaw.AIRTIME, 2.0 * SourceMove.JUMP_SPEED / SourceMove.GRAVITY, 0.000001
	)
	assert_almost_eq(CourseLaw.AIRTIME, 0.755114, 0.000001)


func test_flat_reach_derives_from_run_speed_and_airtime() -> void:
	assert_almost_eq(CourseLaw.FLAT_REACH, SourceMove.RUN_SPEED * CourseLaw.AIRTIME, 0.000001)
	assert_almost_eq(CourseLaw.FLAT_REACH, 8.30625, 0.0001)


func test_jump_apex_derives_from_jump_and_gravity() -> void:
	assert_almost_eq(
		CourseLaw.JUMP_APEX,
		SourceMove.JUMP_SPEED * SourceMove.JUMP_SPEED / (2.0 * SourceMove.GRAVITY),
		0.000001
	)
	assert_almost_eq(CourseLaw.JUMP_APEX, 2.508865, 0.0001)  # 13.29^2 / 70.4


func test_bare_run_span_at_reach_passes_and_just_past_fails() -> void:
	assert_true(CourseLaw.span_ok_bare_run(8.3))
	assert_true(CourseLaw.span_ok_bare_run(CourseLaw.FLAT_REACH))
	assert_false(CourseLaw.span_ok_bare_run(CourseLaw.FLAT_REACH + 0.01))


## A barrier (#23 kitchen ruling) is a gap built NOT to be crossed on foot, so it must stay wider
## than the flat reach: a barrier at or inside reach is a route someone will find.
func test_a_barrier_holds_only_past_flat_reach() -> void:
	assert_false(CourseLaw.barrier_holds(7.0))
	assert_false(CourseLaw.barrier_holds(CourseLaw.FLAT_REACH))
	assert_true(CourseLaw.barrier_holds(CourseLaw.FLAT_REACH + 0.01))


func test_required_entry_speed_is_span_over_airtime() -> void:
	assert_almost_eq(CourseLaw.required_entry_speed(9.5), 12.5810, 0.001)


func test_carried_span_needs_the_declared_entry_speed() -> void:
	assert_true(CourseLaw.span_ok_carried(9.5, 12.6))
	assert_false(CourseLaw.span_ok_carried(9.5, 12.0))


func test_ground_entry_speed_cannot_exceed_run_speed() -> void:
	assert_true(CourseLaw.ground_entry_speed_ok(SourceMove.RUN_SPEED))
	assert_false(
		CourseLaw.ground_entry_speed_ok(12.6),
		"ground cannot deliver above RUN_SPEED — a carried gap needs a real source"
	)


func test_chasm_gap_grows_one_and_a_half_per_loop_to_plateau() -> void:
	assert_almost_eq(CourseLaw.chasm_gap(1.5, 0), 0.0, 0.0001)
	assert_almost_eq(CourseLaw.chasm_gap(1.5, 1), 1.5, 0.0001)
	assert_almost_eq(CourseLaw.chasm_gap(1.5, 5), 7.5, 0.0001)


func test_chasm_growth_ceiling() -> void:
	assert_true(CourseLaw.chasm_growth_ok(1.5))
	assert_false(CourseLaw.chasm_growth_ok(1.6))


func test_chasm_plateau_ceiling_is_the_fairness_law() -> void:
	assert_true(CourseLaw.chasm_plateau_ok(1.5, ErosionLogic.PLATEAU_LOOP))
	assert_false(CourseLaw.chasm_plateau_ok(1.6, ErosionLogic.PLATEAU_LOOP))
	assert_true(
		CourseLaw.CHASM_PLATEAU_MAX < CourseLaw.FLAT_REACH,
		"7.5 m plateau must stay under flat reach — 0.81 m is the whole margin"
	)


func test_chasm_runout_needs_three_metres_full_width() -> void:
	assert_true(CourseLaw.chasm_runout_ok(3.0))
	assert_false(CourseLaw.chasm_runout_ok(2.9))


func test_precision_chain_cap_is_three() -> void:
	assert_true(CourseLaw.precision_chain_ok(3))
	assert_false(CourseLaw.precision_chain_ok(4))


func test_a_stretch_exactly_at_cap_is_flagged_for_a_ruling() -> void:
	assert_true(CourseLaw.precision_chain_at_cap(3), "issue #34: at cap = no headroom")
	assert_false(CourseLaw.precision_chain_at_cap(2))
	assert_false(CourseLaw.precision_chain_at_cap(4), "over cap is a FAIL, not an at-cap WARN")


func test_staggered_hole_length_equals_the_loop_number() -> void:
	assert_true(CourseLaw.staggered_hole_length_ok(1.0, 1))
	assert_true(CourseLaw.staggered_hole_length_ok(5.0, 5))
	assert_false(CourseLaw.staggered_hole_length_ok(2.5, 1), "telegraph convention broken")


func test_shell_segment_cap_is_twenty_five() -> void:
	assert_true(CourseLaw.shell_segment_ok(24.75), "3b measured 24.75 m on +x")
	assert_false(CourseLaw.shell_segment_ok(25.01))


func test_method_tolerance_is_not_eps() -> void:
	assert_almost_eq(CourseLaw.METHOD_TOLERANCE, 0.10, 0.0001)
	assert_true(
		CourseLaw.METHOD_TOLERANCE > CourseLaw.EPS * 50.0,
		"a box read and a 0.05 m ray grid cannot agree to 1 mm"
	)

func test_ramp_min_deg_mirrors_the_engine_floor_limit() -> void:
	assert_almost_eq(CourseLaw.RAMP_MIN_DEG, Player.FLOOR_LIMIT_DEG, 0.0001)


func test_sink_over_ride_uses_the_shipped_sink_cap() -> void:
	assert_almost_eq(
		CourseLaw.sink_over_ride(18.0, 11.0),
		absf(WallrunLogic.SINK_CAP) * 18.0 / 11.0,
		0.000001
	)
	assert_almost_eq(CourseLaw.sink_over_ride(10.0, 11.0), 1.818, 0.001)


func test_required_wall_extent_is_entry_plus_sink_plus_margin() -> void:
	assert_almost_eq(
		CourseLaw.required_wall_extent(CourseLaw.JUMP_APEX, 10.0, 11.0), 5.327, 0.01
	)


func test_ride_extent_gate() -> void:
	assert_true(CourseLaw.ride_extent_ok(8.0, CourseLaw.JUMP_APEX, 18.0, 11.0))
	assert_false(CourseLaw.ride_extent_ok(6.0, CourseLaw.JUMP_APEX, 18.0, 11.0))


func test_ride_entry_speed_gate_mirrors_min_forward_speed() -> void:
	assert_true(CourseLaw.ride_entry_speed_ok(4.1))
	assert_false(CourseLaw.ride_entry_speed_ok(WallrunLogic.MIN_FORWARD_SPEED))


func test_level_kick_reach_is_derived_not_copied() -> void:
	assert_almost_eq(
		CourseLaw.LEVEL_KICK_REACH,
		SourceMove.RUN_SPEED * 2.0 * WallrunLogic.WALL_JUMP_VY / SourceMove.GRAVITY,
		0.000001
	)
	assert_almost_eq(CourseLaw.LEVEL_KICK_REACH, 5.39375, 0.0001)


func test_surf_exit_speed_matches_the_t3_law() -> void:
	assert_almost_eq(CourseLaw.surf_exit_speed(11.0, 3.0), 17.315, 0.01)
	assert_almost_eq(CourseLaw.surf_exit_speed(17.31, 3.0), 21.472, 0.01)
	assert_almost_eq(
		CourseLaw.surf_exit_speed(11.0, 3.0, 1.0),
		sqrt(11.0 * 11.0 + 2.0 * SourceMove.GRAVITY * 3.0),
		0.000001
	)


func test_kicker_terminated_exit_is_all_horizontal() -> void:
	assert_almost_eq(CourseLaw.exit_horizontal_speed(17.31, true, 0.0), 17.31, 0.0001)


func test_non_kicker_exit_uses_the_declared_measured_horizontal() -> void:
	assert_almost_eq(CourseLaw.exit_horizontal_speed(17.31, false, 12.0), 12.0, 0.0001)


func test_transfer_span_carries_the_t3_safety_factor() -> void:
	# Exact boundary at a 17.31 m/s horizontal exit: 17.31 * 0.7551136 * 0.9 = 11.7639 m.
	assert_true(CourseLaw.transfer_span_ok(11.76, 17.31, 0.9))
	assert_false(
		CourseLaw.transfer_span_ok(11.8, 17.31, 0.9),
		"spec 5.1's illustrative 11.8 m rounds 0.04 m PAST its own stated rule — issue #7"
	)
	assert_false(
		CourseLaw.transfer_span_ok(13.0, 17.31, 0.9),
		"13.07 m is v*AIRTIME with no factor — the measured law forbids it"
	)


func test_transfer_factor_ceiling() -> void:
	assert_true(CourseLaw.transfer_factor_ok(0.85))
	assert_true(CourseLaw.transfer_factor_ok(0.9))
	assert_false(CourseLaw.transfer_factor_ok(0.95))


func test_ramp_angle_must_be_steeper_than_the_floor_limit() -> void:
	assert_false(CourseLaw.ramp_angle_ok(38.0))
	assert_true(CourseLaw.ramp_angle_ok(45.31))


func test_ramp_target_band_is_forty_five_to_fifty_five() -> void:
	assert_true(CourseLaw.ramp_in_target_band(45.31))
	assert_true(CourseLaw.ramp_in_target_band(51.34))
	assert_false(CourseLaw.ramp_in_target_band(44.0))
	assert_false(CourseLaw.ramp_in_target_band(56.0))


func test_ramp_path_floor_is_twelve_metres() -> void:
	assert_true(CourseLaw.ramp_path_ok(12.65))
	assert_false(CourseLaw.ramp_path_ok(11.9))


func test_ramp_normal_must_never_be_rideable() -> void:
	assert_true(CourseLaw.ramp_never_rideable(cos(deg_to_rad(51.34))))
	assert_false(CourseLaw.ramp_never_rideable(0.1))


func test_level_kick_span_law_from_issue_16() -> void:
	assert_true(CourseLaw.level_kick_span_ok(5.0, 0.0))
	assert_false(CourseLaw.level_kick_span_ok(7.0, 0.0))
	assert_true(
		CourseLaw.level_kick_span_ok(7.0, 2.0),
		"a descending kick span is not the level law — it declares its drop"
		+ " (collector convention: drop = near.top - far.top, POSITIVE descending)"
	)
	assert_false(
		CourseLaw.level_kick_span_ok(7.0, -2.0),
		"an ASCENDING span is harder than level — issue #17's sign collision let it pass free"
	)


func test_landing_width_fail_floor_is_two_capsule_diameters() -> void:
	assert_true(CourseLaw.landing_width_ok(1.6, 0.70), "D2's shipped 1.6 m plateau clears")
	assert_true(CourseLaw.landing_width_ok(1.40, 0.70))
	assert_false(CourseLaw.landing_width_ok(1.3, 0.70))


func test_compound_case_fires_on_issue_23_strips() -> void:
	for span in [8.0, 8.2, 8.3]:
		assert_true(
			CourseLaw.compound_landing(span, 1.6), "D2Strip at plateau: %s m onto 1.6 m" % span
		)


func test_compound_case_fires_on_issue_33_pad() -> void:
	assert_true(CourseLaw.compound_landing(7.50, 4.0), "Sh5FloorA in")
	assert_true(CourseLaw.compound_landing(7.85, 4.0), "Sh5FloorA out")


func test_compound_case_is_silent_on_a_wide_landing() -> void:
	assert_false(CourseLaw.compound_landing(8.3, 12.0))


func test_compound_case_is_silent_on_a_short_gap() -> void:
	assert_false(CourseLaw.compound_landing(6.5, 1.6))


func test_compound_gap_threshold_is_derived_from_flat_reach() -> void:
	assert_almost_eq(
		CourseLaw.COMPOUND_GAP_FRACTION * CourseLaw.FLAT_REACH, 7.4756, 0.001,
		"7.48 m — below both #33 gaps, above every rest-beat gap"
	)
