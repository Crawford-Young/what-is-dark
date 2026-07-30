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

# test_ramp_min_deg_mirrors_the_engine_floor_limit lands at T2 with RAMP_MIN_DEG itself:
# a reference to a missing const on a KNOWN class is a parse error, not a failed assert,
# so it would drop this whole script rather than showing one red case. See issue #5.
