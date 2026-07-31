extends GutTest
## One case per law row of the wave plan's table, each built from a MINIMAL survey so a
## finding can only have come from the family under test. The default survey is clean and
## empty; `test_a_fully_populated_clean_survey_is_silent` is the counterweight that proves
## silence is not just emptiness.

const CAPSULE := 0.70


func _survey(overrides: Dictionary = {}) -> Dictionary:
	var survey := {
		"loop": 0,
		"method": "box",
		"sample_count": 1200,
		"capsule_diameter": CAPSULE,
		"spans": [],
		"surfaces": [],
		"walls": [],
		"ramps": [],
		"chasms": [],
		"markers": [],
		"shell_runs": [],
		"floors": [],
		"props": [],
		"landing_bands": [],
	}
	for key in overrides:
		survey[key] = overrides[key]
	return survey


func _laws(findings: Array) -> Array[String]:
	var laws: Array[String] = []
	for f in findings:
		laws.append(String(f["law"]))
	return laws


func _sev(findings: Array, law: String) -> String:
	for f in findings:
		if String(f["law"]) == law:
			return String(f["severity"])
	return "<absent>"


func _subjects(findings: Array) -> Array[String]:
	var subjects: Array[String] = []
	for f in findings:
		subjects.append(String(f["subject"]))
	return subjects


# --- baseline -----------------------------------------------------------------------------


func test_clean_survey_yields_no_findings() -> void:
	assert_eq(CourseSweep.sweep(_survey(), {}).size(), 0)


func test_a_fully_populated_clean_survey_is_silent() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.0, "landing_width": 12.0, "drop": 0.0}],
		"surfaces": [{"name": "A", "role": "floor", "erodable": true}],
		"walls": [{"name": "W", "length": 18.0, "extent": 20.0, "normal_y": 0.0}],
		"ramps": [{"name": "R", "angle_deg": 51.34, "path_len": 25.0, "normal_y": 0.6247}],
		"chasms": [{"id": "C>D", "per_loop": 1.5, "gap": 1.5, "runout": 3.4, "full_width": true}],
		"markers": [{"index": 0, "offsets_hit": 5, "offsets_total": 5, "z": 0.0}],
		"shell_runs": [{"side": "+x", "length": 24.75}],
	})
	var findings := CourseSweep.sweep(survey, {"A>B": {"decl": "bare_run"}})
	assert_eq(findings.size(), 0, "\n".join(_laws(findings)))


func test_zero_sample_count_is_a_failure_not_a_pass() -> void:
	var findings := CourseSweep.sweep(_survey({"sample_count": 0}), {})
	assert_eq(_laws(findings), ["sample_count"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "FAIL")


func test_a_finding_stamps_its_loop_and_method() -> void:
	var findings := CourseSweep.sweep(
		_survey({"loop": 5, "method": "ray", "sample_count": 0}), {}
	)
	assert_eq(int(findings[0]["loop"]), 5)
	assert_true(String(findings[0]["detail"]).contains("ray"), String(findings[0]["detail"]))
	assert_true(String(findings[0]["detail"]).contains("5"), String(findings[0]["detail"]))


# --- declarations -------------------------------------------------------------------------


func test_undeclared_span_is_a_failure() -> void:
	var survey := _survey({"spans": [{"id": "A>B", "span": 6.5, "landing_width": 12.0}]})
	assert_eq(_laws(CourseSweep.sweep(survey, {})), ["declaration"] as Array[String])


func test_a_surface_schema_error_is_a_failure() -> void:
	var survey := _survey({"surfaces": [{"name": "K", "role": "kicker", "erodable": true}]})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["surface_declaration"] as Array[String])
	assert_eq(_subjects(findings), ["K"] as Array[String])


# --- reach --------------------------------------------------------------------------------


func test_a_bare_run_span_past_flat_reach_fails() -> void:
	var survey := _survey({"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0}]})
	var decls := {"A>B": {"decl": "bare_run"}}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["bare_run_reach"] as Array[String])


func test_a_carried_span_beyond_its_declared_entry_speed_fails() -> void:
	var survey := _survey({"spans": [{"id": "A>B", "span": 9.5, "landing_width": 12.0}]})
	var decls := {"A>B": {"decl": "carried_speed", "entry_speed": 11.0, "source": "ground"}}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["carried_speed"] as Array[String])


func test_carried_speed_above_run_speed_from_ground_cannot_be_delivered() -> void:
	var survey := _survey({"spans": [{"id": "A>B", "span": 9.5, "landing_width": 12.0}]})
	var decls := {"A>B": {"decl": "carried_speed", "entry_speed": 12.6, "source": "ground"}}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["carried_source"] as Array[String])


func test_a_source_naming_no_declared_span_cannot_be_verified() -> void:
	var survey := _survey({"spans": [{"id": "A>B", "span": 6.0, "landing_width": 12.0}]})
	var decls := {"A>B": {"decl": "carried_speed", "entry_speed": 10.0, "source": "Z>Y"}}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["carried_source"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("Z>Y"), String(findings[0]["detail"]))


func test_carried_speed_from_a_declared_surf_source_is_verified_against_its_exit() -> void:
	var survey := _survey({
		"spans": [
			{"id": "R1>R2", "span": 11.0, "landing_width": 12.0},
			{"id": "R2>C", "span": 9.5, "landing_width": 12.0},
		],
	})
	var decls := {
		"R1>R2": {
			"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": true,
			"factor": 0.9
		},
		"R2>C": {"decl": "carried_speed", "entry_speed": 12.6, "source": "R1>R2"},
	}
	assert_eq(CourseSweep.sweep(survey, decls).size(), 0, "17.31 m/s exit covers 12.6")


# --- wall rides and kicks -----------------------------------------------------------------


func test_a_wall_ride_naming_no_surveyed_wall_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0, "z_from": 0.0, "z_to": -8.5}]
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": "NoSuchWall", "entry_height": 2.5, "along_speed": 11.0
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_wall"] as Array[String])


## The ride is entered by a FLOOR jump, so the flat-reach budget is the measured one for the
## hop from the launch lip onto the first wall. (The old wall-covers-span law this test used
## to exercise retired with the chain arithmetic — the exact per-gap form replaces it.)
func test_a_wall_starting_past_flat_reach_from_the_lip_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0, "z_from": 0.0, "z_to": -8.5}],
		"walls": [
			{
				"name": "W", "length": 8.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -9.0, "z_min": -17.0
			}
		],
	})
	var decls := {
		"A>B": {"decl": "wall_ride", "wall": "W", "entry_height": 2.5, "along_speed": 11.0}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_span"] as Array[String])


func test_a_wall_too_short_vertically_for_the_ride_sink_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0, "z_from": 0.0, "z_to": -8.5}],
		"walls": [
			{
				"name": "W", "length": 18.0, "extent": 4.0, "normal_y": 0.0,
				"z_max": -0.2, "z_min": -18.2
			}
		],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": "W", "entry_height": CourseLaw.JUMP_APEX,
			"along_speed": 11.0
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_extent"] as Array[String])


func test_a_ride_entered_at_or_below_the_minimum_forward_speed_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0, "z_from": 0.0, "z_to": -8.5}],
		"walls": [
			{
				"name": "W", "length": 18.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -0.2, "z_min": -18.2
			}
		],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": "W", "entry_height": 2.5,
			"along_speed": WallrunLogic.MIN_FORWARD_SPEED
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_entry"] as Array[String])


func test_a_single_wall_ride_with_sound_geometry_is_silent() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -8.0}],
		"walls": [
			{
				"name": "W", "length": 18.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -0.2, "z_min": -18.2
			}
		],
	})
	var decls := {
		"A>B": {"decl": "wall_ride", "wall": "W", "entry_height": 2.5, "along_speed": 11.0}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), [] as Array[String])


## Declared out of ride order on purpose — the sweep sorts the chain by z_max descending, so
## declaration order carries no geometry.
func test_a_two_wall_chain_with_tight_gaps_is_silent() -> void:
	var survey := _survey({
		"spans": [
			{"id": "A>B", "span": 20.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -20.0}
		],
		"walls": [
			{
				"name": "W1", "length": 9.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -1.0, "z_min": -10.0
			},
			{
				"name": "W2", "length": 9.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -12.0, "z_min": -21.0
			},
		],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": ["W2", "W1"], "entry_height": 2.5, "along_speed": 11.0
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), [] as Array[String])


## 5.39 m is the measured LEVEL press-kick reach; wall-to-wall contact can legitimately
## exceed it (contact happens below launch height) and no lab measurement of wall-contact
## reach exists — so an over-budget inter-wall gap surfaces as WARN for a human ruling,
## never a FAIL on a derived-only ceiling.
func test_an_inter_wall_gap_past_the_kick_reach_warns() -> void:
	var survey := _survey({
		"spans": [
			{"id": "A>B", "span": 23.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -23.0}
		],
		"walls": [
			{
				"name": "W1", "length": 9.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -1.0, "z_min": -10.0
			},
			{
				"name": "W2", "length": 8.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -16.0, "z_min": -24.0
			},
		],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": ["W1", "W2"], "entry_height": 2.5, "along_speed": 11.0
		}
	}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["wall_chain_gap"] as Array[String])
	assert_eq(_sev(findings, "wall_chain_gap"), "WARN")
	assert_true(String(findings[0]["detail"]).contains("W1"), String(findings[0]["detail"]))
	assert_true(String(findings[0]["detail"]).contains("W2"), String(findings[0]["detail"]))


## The exit from the last wall is a WALL KICK (vy 8.63) — the same unmeasured wall-contact
## mechanic as the inter-wall hop, so the same WARN-for-a-human treatment.
func test_an_exit_gap_past_the_kick_reach_warns() -> void:
	var survey := _survey({
		"spans": [
			{"id": "A>B", "span": 16.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -16.0}
		],
		"walls": [
			{
				"name": "W", "length": 9.8, "extent": 20.0, "normal_y": 0.0,
				"z_max": -0.2, "z_min": -10.0
			}
		],
	})
	var decls := {
		"A>B": {"decl": "wall_ride", "wall": "W", "entry_height": 2.5, "along_speed": 11.0}
	}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["wall_chain_gap"] as Array[String])
	assert_eq(_sev(findings, "wall_chain_gap"), "WARN")
	assert_true(String(findings[0]["detail"]).contains("exit"), String(findings[0]["detail"]))


func test_a_chain_naming_an_unsurveyed_wall_fails_before_any_geometry() -> void:
	var survey := _survey({
		"spans": [
			{"id": "A>B", "span": 20.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -20.0}
		],
		"walls": [
			{
				"name": "W1", "length": 9.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -1.0, "z_min": -10.0
			}
		],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": ["W1", "Ghost"], "entry_height": 2.5,
			"along_speed": 11.0
		}
	}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["wall_ride_wall"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("Ghost"), String(findings[0]["detail"]))


func test_an_empty_or_malformed_wall_chain_declares_no_usable_wall() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -8.0}],
		"walls": [
			{
				"name": "W", "length": 18.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -0.2, "z_min": -18.2
			}
		],
	})
	for bad_wall in [[], [12.0], ["W", 3]]:
		var decls := {
			"A>B": {
				"decl": "wall_ride", "wall": bad_wall, "entry_height": 2.5, "along_speed": 11.0
			}
		}
		var findings := CourseSweep.sweep(survey, decls)
		assert_eq(_laws(findings), ["wall_ride_wall"] as Array[String], str(bad_wall))
		assert_true(
			String(findings[0]["detail"]).contains("no usable wall"), String(findings[0]["detail"])
		)


## The declared entry_height applies to EVERY wall in the chain — a mid-chain kick re-entry
## never enters higher than the initial entry (kick vy 8.63 < jump vy 13.29, and the chain
## descends under sink).
func test_a_chain_member_too_short_vertically_is_named_in_the_finding() -> void:
	var survey := _survey({
		"spans": [
			{"id": "A>B", "span": 20.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -20.0}
		],
		"walls": [
			{
				"name": "W1", "length": 9.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -1.0, "z_min": -10.0
			},
			{
				"name": "W2", "length": 9.0, "extent": 1.0, "normal_y": 0.0,
				"z_max": -12.0, "z_min": -21.0
			},
		],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": ["W1", "W2"], "entry_height": 2.5, "along_speed": 11.0
		}
	}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["wall_ride_extent"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("W2"), String(findings[0]["detail"]))


## The near surface's ROLE is what marks a span as kick-launched — span ids are `<near>><far>`
## by convention, so the launch geometry is readable without a new declaration key.
func test_a_level_kick_span_past_the_measured_kick_reach_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "K>Far", "span": 6.0, "landing_width": 12.0, "drop": 0.0}],
		"surfaces": [{"name": "K", "role": "kicker"}],
	})
	var decls := {"K>Far": {"decl": "bare_run"}}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["wall_cross_reach"] as Array[String])
	assert_true(
		String(findings[0]["detail"]).contains("5.39"),
		"the finding must quote the measured reach it applied"
	)


func test_a_descending_kick_span_is_not_the_level_law() -> void:
	var survey := _survey({
		"spans": [{"id": "K>Far", "span": 6.0, "landing_width": 12.0, "drop": 2.0}],
		"surfaces": [{"name": "K", "role": "kicker"}],
	})
	assert_eq(CourseSweep.sweep(survey, {"K>Far": {"decl": "bare_run"}}).size(), 0)


## Issue #17: the 5.39 m press-kick reach was measured for the BARE-RUN-off-a-kicker case
## (3b #16). A span declared surf_transfer off a kicker is governed by its own T3 arithmetic
## with the declared factor, not by the press-kick budget.
func test_a_surf_declared_kicker_span_is_not_the_level_kick_law() -> void:
	var survey := _survey({
		"spans": [{"id": "K>Far", "span": 7.0, "landing_width": 12.0, "drop": 0.0}],
		"surfaces": [{"name": "K", "role": "kicker"}],
	})
	var decls := {
		"K>Far": {
			"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": true,
			"factor": 0.9
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), [] as Array[String])


# --- surf transfers -----------------------------------------------------------------------


func test_a_transfer_span_beyond_its_exit_speed_fails() -> void:
	var survey := _survey({"spans": [{"id": "R1>R2", "span": 12.5, "landing_width": 12.0}]})
	var decls := {
		"R1>R2": {
			"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": true,
			"factor": 0.9
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["surf_transfer"] as Array[String])


func test_a_transfer_factor_above_the_measured_ceiling_fails() -> void:
	var survey := _survey({"spans": [{"id": "R1>R2", "span": 5.0, "landing_width": 12.0}]})
	var decls := {
		"R1>R2": {
			"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": true,
			"factor": 0.95
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["transfer_factor"] as Array[String])


func test_non_kicker_transfer_without_a_measured_exit_warns() -> void:
	var survey := _survey({"spans": [{"id": "R1>R2", "span": 11.0, "landing_width": 12.0}]})
	var decls := {
		"R1>R2": {
			"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": false,
			"factor": 0.9
		}
	}
	var findings := CourseSweep.sweep(survey, decls)
	assert_eq(_laws(findings), ["surf_exit_unmeasured"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "WARN")


func test_a_measured_non_kicker_transfer_is_checked_against_its_measurement() -> void:
	var survey := _survey({"spans": [{"id": "R1>R2", "span": 11.0, "landing_width": 12.0}]})
	var decls := {
		"R1>R2": {
			"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": false,
			"factor": 0.9, "exit_h_speed": 9.0
		}
	}
	assert_eq(
		_laws(CourseSweep.sweep(survey, decls)),
		["surf_transfer"] as Array[String],
		"9 m/s horizontal buys 6.12 m, not 11 — the measurement convicts the span"
	)


# --- chasms -------------------------------------------------------------------------------


## `chasm_plateau` cannot fire alone at PLATEAU_LOOP 5: the growth ceiling is 1.5 m/loop and
## 1.5 x 5 is exactly the 7.5 m plateau ceiling, so any gap that breaks the plateau law has
## already broken the growth law. The two are pinned together deliberately.
func test_a_chasm_growing_too_fast_breaks_growth_and_plateau_together() -> void:
	var survey := _survey({
		"chasms": [
			{"id": "C>D", "per_loop": 1.6, "gap": 1.6, "runout": 3.4, "full_width": true}
		],
	})
	assert_eq(
		_laws(CourseSweep.sweep(survey, {})),
		["chasm_growth", "chasm_plateau"] as Array[String]
	)


func test_a_chasm_without_its_runout_fails() -> void:
	var survey := _survey({
		"chasms": [
			{"id": "C>D", "per_loop": 1.5, "gap": 1.5, "runout": 2.5, "full_width": true}
		],
	})
	assert_eq(_laws(CourseSweep.sweep(survey, {})), ["chasm_runout"] as Array[String])


func test_a_chasm_that_is_not_full_width_fails() -> void:
	var survey := _survey({
		"chasms": [
			{"id": "C>D", "per_loop": 1.5, "gap": 1.5, "runout": 3.4, "full_width": false}
		],
	})
	assert_eq(_laws(CourseSweep.sweep(survey, {})), ["chasm_full_width"] as Array[String])


# --- ramps --------------------------------------------------------------------------------


## Same coupling as the chasm pair: nothing shallower than the 38 deg floor limit can sit in
## the 45-55 deg measured band, so `ramp_angle` never fires without `ramp_band`.
func test_a_ramp_shallower_than_the_floor_limit_fails_and_warns() -> void:
	var survey := _survey({
		"ramps": [{"name": "R", "angle_deg": 30.0, "path_len": 25.0, "normal_y": 0.866}],
	})
	assert_eq(
		_laws(CourseSweep.sweep(survey, {})), ["ramp_angle", "ramp_band"] as Array[String]
	)


func test_a_ramp_path_under_the_design_floor_fails() -> void:
	var survey := _survey({
		"ramps": [{"name": "R", "angle_deg": 50.0, "path_len": 8.0, "normal_y": 0.643}],
	})
	assert_eq(_laws(CourseSweep.sweep(survey, {})), ["ramp_path"] as Array[String])


func test_a_ramp_shallow_enough_to_ride_fails() -> void:
	var survey := _survey({
		"ramps": [{"name": "R", "angle_deg": 50.0, "path_len": 25.0, "normal_y": 0.1}],
	})
	assert_eq(_laws(CourseSweep.sweep(survey, {})), ["ramp_rideable"] as Array[String])


func test_a_ramp_outside_the_measured_band_only_warns() -> void:
	var survey := _survey({
		"ramps": [{"name": "R", "angle_deg": 60.0, "path_len": 25.0, "normal_y": 0.5}],
	})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["ramp_band"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "WARN")


# --- markers and shell --------------------------------------------------------------------


func test_a_marker_with_any_offset_unstandable_fails() -> void:
	var survey := _survey({
		"markers": [{"index": 3, "offsets_hit": 4, "offsets_total": 5, "z": -100.0}],
	})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["marker_standable"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "FAIL")


func test_an_unbroken_shell_run_past_the_cap_fails() -> void:
	var survey := _survey({"shell_runs": [{"side": "+x", "length": 26.0}]})
	assert_eq(_laws(CourseSweep.sweep(survey, {})), ["shell_segment"] as Array[String])


# --- precision chains ---------------------------------------------------------------------


func _chain_spans(count: int, break_at: int) -> Array:
	var spans: Array[Dictionary] = []
	for i in count:
		spans.append({
			"id": "P%d>P%d" % [i, i + 1], "span": 8.0, "landing_width": 12.0,
			"void_punished": true, "marker_break_before": i == break_at,
		})
	return spans


func _chain_decls(spans: Array) -> Dictionary:
	var decls := {}
	for s in spans:
		decls[s["id"]] = {"decl": "bare_run"}
	return decls


func test_marker_break_resets_the_precision_chain_per_ruling_27() -> void:
	var spans := _chain_spans(4, 2)
	var laws := _laws(CourseSweep.sweep(_survey({"spans": spans}), _chain_decls(spans)))
	assert_false(laws.has("precision_chain"), "ruling #27: the marker breaks the chain")
	assert_false(laws.has("precision_chain_at_cap"), "two runs of two — neither is at cap")


func test_four_unbroken_void_punished_jumps_still_fail() -> void:
	var spans := _chain_spans(4, -1)
	var findings := CourseSweep.sweep(_survey({"spans": spans}), _chain_decls(spans))
	assert_eq(_laws(findings), ["precision_chain"] as Array[String])
	assert_eq(_subjects(findings), ["P0>P1"] as Array[String], "subject is the run's first span")


func test_a_stretch_at_the_cap_warns_once() -> void:
	var spans := _chain_spans(3, -1)
	var findings := CourseSweep.sweep(_survey({"spans": spans}), _chain_decls(spans))
	assert_eq(_laws(findings), ["precision_chain_at_cap"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "WARN")


func test_a_soft_landing_also_breaks_the_chain() -> void:
	var spans := _chain_spans(4, -1)
	spans[2]["void_punished"] = false
	var laws := _laws(CourseSweep.sweep(_survey({"spans": spans}), _chain_decls(spans)))
	assert_false(laws.has("precision_chain"), "two then one — no run reaches the cap")


## Parallel lanes are ALTERNATIVE lines, not consecutive jumps: three disjoint void-punished
## spans share no surface, so no chain forms. Row-order counting glued these into a phantom
## at-cap run, which is why the #34 gate's at_cap row was unreachable on any multi-lane
## course (wave issue #23).
func test_parallel_lane_spans_form_no_chain() -> void:
	var spans: Array[Dictionary] = []
	for lane in ["L", "M", "R"]:
		spans.append({
			"id": "%s0>%s1" % [lane, lane], "span": 8.0, "landing_width": 12.0,
			"void_punished": true, "marker_break_before": false,
		})
	var laws := _laws(CourseSweep.sweep(_survey({"spans": spans}), _chain_decls(spans)))
	assert_false(laws.has("precision_chain"), "disjoint spans are not consecutive")
	assert_false(laws.has("precision_chain_at_cap"), "disjoint spans are not consecutive")


## Ruling #28's count stops "before the wall-ride verb takes over": a declared ride closes
## the chain and never counts as a jump itself.
func test_a_declared_wall_ride_terminates_the_chain_uncounted() -> void:
	var spans: Array[Dictionary] = []
	for id in ["J0>J1", "J1>J2", "J2>J3", "J3>J4", "J4>J5"]:
		spans.append({
			"id": id, "span": 6.0, "landing_width": 12.0, "z_from": 0.0, "z_to": -6.0,
			"void_punished": true, "marker_break_before": false,
		})
	var decls := _chain_decls(spans)
	decls["J1>J2"] = {
		"decl": "wall_ride", "wall": "W", "entry_height": 2.5, "along_speed": 11.0
	}
	var survey := _survey({
		"spans": spans,
		"walls": [
			{
				"name": "W", "length": 18.0, "extent": 20.0, "normal_y": 0.0,
				"z_max": -0.2, "z_min": -18.2
			}
		],
	})
	var findings := CourseSweep.sweep(survey, decls)
	var laws := _laws(findings)
	assert_false(laws.has("precision_chain"), "the ride is relief — no five-run exists")
	assert_true(laws.has("precision_chain_at_cap"), "J2>J3 through J4>J5 is exactly three")
	for f in findings:
		if str(f["law"]) == "precision_chain_at_cap":
			assert_eq(str(f["subject"]), "J2>J3", "the chain restarts after the ride")


## A surf transfer's ramp contact is relief for whatever came before it — but the kicker
## jump is itself a void-punished commitment, so the transfer seeds a fresh chain.
func test_a_transfer_closes_the_chain_and_seeds_a_new_one() -> void:
	var spans: Array[Dictionary] = []
	for id in ["A>B", "B>C", "C>D", "D>E", "E>F"]:
		spans.append({
			"id": id, "span": 6.0, "landing_width": 12.0,
			"void_punished": true, "marker_break_before": false,
		})
	var decls := _chain_decls(spans)
	decls["B>C"] = {
		"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.5,
		"kicker": true, "factor": 0.85
	}
	var findings := CourseSweep.sweep(_survey({"spans": spans}), decls)
	assert_eq(_laws(findings), ["precision_chain"] as Array[String])
	assert_eq(_subjects(findings), ["B>C"] as Array[String], "the kicker jump heads the chain")
	assert_true(
		String(findings[0]["detail"]).contains("4 consecutive"), String(findings[0]["detail"])
	)


## #27 and #28 both count the chasm's must-jump as a chain link, and the same-floor filter
## dissolves that seam from the span graph — so the chain walk restores it from the lane
## holes aligned with a chasm seam. Staggered holes stay out: a sidestep is not commitment.
func test_a_chasm_jump_counts_in_the_chain_through_its_lane() -> void:
	var floors := [
		{
			"id": "F", "shipped_span": 30.0, "solid_span": 28.5,
			"lanes": [
				{
					"id": "L", "tiles": 2,
					"holes": [
						{"from": -10.0, "to": -11.5, "near_tile": "L2", "far_tile": "L3"}
					]
				},
			],
		}
	]
	var spans: Array[Dictionary] = []
	for row in [["L3>S1", -12.0], ["S1>S2", -20.0]]:
		spans.append({
			"id": str(row[0]), "span": 6.0, "landing_width": 12.0,
			"z_from": float(row[1]), "z_to": float(row[1]) - 6.0,
			"void_punished": true, "marker_break_before": false,
		})
	var survey := _survey({
		"loop": 1,
		"spans": spans,
		"floors": floors,
		"chasms": [
			{
				"id": "L2>L3", "per_loop": 1.5, "gap": 1.5, "runout": 3.4,
				"full_width": true, "from": -10.0, "to": -11.5,
			}
		],
	})
	var findings := CourseSweep.sweep(survey, _chain_decls(spans))
	assert_eq(_laws(findings), ["precision_chain_at_cap"] as Array[String])
	assert_eq(_subjects(findings), ["L2>L3"] as Array[String], "the chasm heads the chain")


## Fan-in: two chains converging on one surface continue as ONE line counted at its longest;
## the shorter branch's total is strictly below the longest's, so it is subsumed, never
## separately reported.
func test_fan_in_counts_the_longest_line_once() -> void:
	var spans: Array[Dictionary] = []
	for id in ["P0>P1", "P1>P2", "Q0>P2", "P2>P3"]:
		spans.append({
			"id": id, "span": 8.0, "landing_width": 12.0,
			"void_punished": true, "marker_break_before": false,
		})
	var findings := CourseSweep.sweep(_survey({"spans": spans}), _chain_decls(spans))
	assert_eq(_laws(findings), ["precision_chain_at_cap"] as Array[String])
	assert_eq(_subjects(findings), ["P0>P1"] as Array[String], "the longest line's first span")


# --- width --------------------------------------------------------------------------------


func test_the_issue_23_compound_case_warns_and_does_not_fail() -> void:
	var survey := _survey({
		"loop": 5,
		"spans": [{
			"id": "D2Exit>D2StripB", "span": 8.2, "landing_width": 1.6,
			"void_punished": true, "marker_break_before": false,
		}],
	})
	var findings := CourseSweep.sweep(survey, {"D2Exit>D2StripB": {"decl": "bare_run"}})
	assert_eq(_laws(findings), ["compound_landing"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "WARN")


func test_a_landing_narrower_than_two_capsules_fails() -> void:
	var survey := _survey({
		"loop": 5,
		"spans": [{
			"id": "A>B", "span": 8.2, "landing_width": 1.2,
			"void_punished": true, "marker_break_before": false,
		}],
	})
	var findings := CourseSweep.sweep(survey, {"A>B": {"decl": "bare_run"}})
	var laws := _laws(findings)
	assert_true(laws.has("landing_width"))
	assert_true(laws.has("compound_landing"))
	assert_eq(_sev(findings, "landing_width"), "FAIL")
	assert_eq(_sev(findings, "compound_landing"), "WARN")


## Width became law-bearing at T2b, so an ABSENT width is a collector regression and must be
## loud. Silence here is the exact shape of the Critical-1 gap: a field in the schema that no
## law ever reads.
func test_a_span_with_no_surveyed_landing_width_fails() -> void:
	var survey := _survey({"spans": [{"id": "A>B", "span": 4.0}]})
	var findings := CourseSweep.sweep(survey, {"A>B": {"decl": "bare_run"}})
	assert_eq(_laws(findings), ["landing_width"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("no landing width"), "")


func test_the_width_floor_reads_the_surveyed_capsule_not_a_constant() -> void:
	var spans := [{"id": "A>B", "span": 4.0, "landing_width": 1.5}]
	var decls := {"A>B": {"decl": "bare_run"}}
	assert_eq(CourseSweep.sweep(_survey({"spans": spans}), decls).size(), 0)
	var fat := _survey({"spans": spans, "capsule_diameter": 1.0})
	assert_eq(
		_laws(CourseSweep.sweep(fat, decls)),
		["landing_width"] as Array[String],
		"a wider capsule must move the floor — the law may never hardcode 0.70"
	)


# --- perforation invariants ---------------------------------------------------------------
#
# Every law here is an invariant E4/E5/E6 established by hand and nothing has enforced since.
# The floors below use THREE lanes, because a hole on a two-lane floor always leaves one solid
# lane and so always trips `viable_lines` — see the two-lane case for that, deliberately.


func _lane(lane_id: String, holes: Array) -> Dictionary:
	return {"id": lane_id, "holes": holes}


func _hole(from: float, to: float) -> Dictionary:
	return {"from": from, "to": to}


func _floor(lanes: Array, shipped := 90.0, solid := 90.0) -> Dictionary:
	return {"id": "D6Floor", "shipped_span": shipped, "solid_span": solid, "lanes": lanes}


## Three staggered 1 m holes: legal at loop 1, and the fixture every placement case builds on.
func _staggered_lanes(length: float) -> Array:
	return [
		_lane("L", [_hole(-10.0, -10.0 + length)]),
		_lane("M", [_hole(-20.0, -20.0 + length)]),
		_lane("R", [_hole(-30.0, -30.0 + length)]),
	]


func test_a_broken_seam_in_the_shipped_course_fails_at_loop_zero() -> void:
	var survey := _survey({"floors": [_floor([_lane("L", []), _lane("M", [])], 90.0, 89.0)]})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["contiguity"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("89"), String(findings[0]["detail"]))


func test_an_intact_loop_zero_floor_is_silent() -> void:
	var survey := _survey({"floors": [_floor([_lane("L", []), _lane("M", [])])]})
	assert_eq(CourseSweep.sweep(survey, {}).size(), 0, "loop 0 has no holes by definition")


func test_contiguity_is_a_loop_zero_law_only() -> void:
	var survey := _survey({
		"loop": 3,
		"floors": [_floor(_staggered_lanes(3.0), 90.0, 81.0)],
	})
	var laws := _laws(CourseSweep.sweep(survey, {}))
	assert_false(laws.has("contiguity"), "erosion is SUPPOSED to remove solid span after loop 0")
	assert_eq(laws.size(), 0, "\n".join(laws))


func test_a_hole_free_lane_at_a_shrunk_loop_is_a_bypass() -> void:
	var lanes := [
		_lane("L", [_hole(-10.0, -9.0)]),
		_lane("M", [_hole(-20.0, -19.0)]),
		_lane("R", []),
	]
	var findings := CourseSweep.sweep(_survey({"loop": 1, "floors": [_floor(lanes)]}), {})
	assert_eq(_laws(findings), ["hole_free_lane"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("R"), String(findings[0]["detail"]))


func test_every_lane_carrying_a_hole_is_silent() -> void:
	var survey := _survey({"loop": 1, "floors": [_floor(_staggered_lanes(1.0))]})
	assert_eq(CourseSweep.sweep(survey, {}).size(), 0)


## A single-tile lane can never open an intra-lane seam, so the hole law's premise excludes
## it: the x-finger triples perforate by width shrink and their anti-bypass mechanism is the
## jump BETWEEN pad rows (wave issue #22). An ABSENT tile count keeps the law armed — a
## collector regression dropping the field must not retire the law silently (issue #12's class).
func test_a_single_tile_lane_is_exempt_from_the_hole_law() -> void:
	var lanes := [{"id": "L", "holes": [], "tiles": 1}]
	var survey := _survey({"loop": 1, "floors": [_floor(lanes)]})
	assert_eq(CourseSweep.sweep(survey, {}).size(), 0)


func test_a_hole_whose_length_does_not_telegraph_the_loop_fails() -> void:
	var lanes := _staggered_lanes(3.0)
	lanes[0] = _lane("L", [_hole(-10.0, -9.0)])
	var findings := CourseSweep.sweep(_survey({"loop": 3, "floors": [_floor(lanes)]}), {})
	assert_eq(_laws(findings), ["staggered_telegraph"] as Array[String])
	assert_true(
		String(findings[0]["detail"]).contains("1.00"),
		"the finding must quote the length it measured"
	)


## A hole that is part of a chasm seam follows the chasm growth law, not the telegraph
## convention — 1.5 m per loop, aligned across every lane, which is the whole point of a chasm.
func test_a_chasm_seam_is_exempt_from_the_telegraph_and_the_lane_law() -> void:
	var lanes := [
		_lane("L", [_hole(-104.5, -100.0)]),
		_lane("M", [_hole(-104.5, -100.0)]),
		_lane("R", [_hole(-104.5, -100.0)]),
	]
	var survey := _survey({
		"loop": 3,
		"floors": [_floor(lanes, 90.0, 85.5)],
		"chasms": [{
			"id": "A>B", "per_loop": 1.5, "gap": 4.5, "runout": 3.4, "full_width": true,
			"from": -104.5, "to": -100.0,
		}],
	})
	assert_eq(CourseSweep.sweep(survey, {}).size(), 0)


func test_aligned_holes_leave_no_viable_line() -> void:
	var lanes := [
		_lane("L", [_hole(-10.0, -8.0)]),
		_lane("M", [_hole(-10.0, -8.0)]),
		_lane("R", [_hole(-10.0, -8.0)]),
	]
	var findings := CourseSweep.sweep(_survey({"loop": 2, "floors": [_floor(lanes)]}), {})
	assert_eq(_laws(findings), ["viable_lines"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "FAIL")


func test_a_single_lane_floor_is_skipped_not_failed() -> void:
	var survey := _survey({"loop": 1, "floors": [_floor([_lane("L", [_hole(-10.0, -9.0)])])]})
	assert_eq(
		CourseSweep.sweep(survey, {}).size(),
		0,
		"the law is unsatisfiable on one lane, and such a floor is not a perforation grid"
	)


## Consequence of the law, worth pinning: perforation needs THREE lanes. On two lanes any hole
## leaves a single solid line, so `viable_lines` fires on every hole — one finding per hole.
func test_a_two_lane_floor_cannot_be_perforated_and_stay_fair() -> void:
	var lanes := [_lane("L", [_hole(-10.0, -9.0)]), _lane("M", [_hole(-20.0, -19.0)])]
	var findings := CourseSweep.sweep(_survey({"loop": 1, "floors": [_floor(lanes)]}), {})
	assert_eq(_laws(findings), ["viable_lines", "viable_lines"] as Array[String])


func test_a_hole_opening_under_a_prop_fails() -> void:
	var survey := _survey({
		"loop": 1,
		"floors": [_floor(_staggered_lanes(1.0))],
		"props": [{"name": "CBed1", "from": -9.5, "to": -8.0, "lane": "L"}],
	})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["hole_over_prop"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("CBed1"), String(findings[0]["detail"]))


func test_a_prop_in_another_lane_is_not_over_the_hole() -> void:
	var survey := _survey({
		"loop": 1,
		"floors": [_floor(_staggered_lanes(1.0))],
		"props": [{"name": "CBed1", "from": -9.5, "to": -8.0, "lane": "R"}],
	})
	assert_eq(CourseSweep.sweep(survey, {}).size(), 0, "a hole only threatens its own lane")


func test_a_hole_opening_under_a_declared_landing_band_fails() -> void:
	var survey := _survey({
		"loop": 1,
		"floors": [_floor(_staggered_lanes(1.0))],
		"landing_bands": [{"id": "D4RampOut", "from": -20.5, "to": -18.0, "lane": "M"}],
	})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["hole_over_prop"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("D4RampOut"), String(findings[0]["detail"]))


## A marker has no lane: a respawn point over a hole is a softlock in whichever lane it opens.
func test_a_hole_opening_under_a_respawn_marker_fails() -> void:
	var survey := _survey({
		"loop": 1,
		"floors": [_floor(_staggered_lanes(1.0))],
		"markers": [{"index": 5, "offsets_hit": 5, "offsets_total": 5, "z": -9.2}],
	})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["hole_over_prop"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("marker"), String(findings[0]["detail"]))


func test_an_erodable_surface_may_not_carry_anything() -> void:
	var survey := _survey({
		"surfaces": [
			{"name": "D2StripA", "role": "floor", "erodable": true, "supports": ["CBed1"]}
		],
	})
	var findings := CourseSweep.sweep(survey, {})
	assert_eq(_laws(findings), ["shrink_target_carries"] as Array[String])
	assert_true(String(findings[0]["detail"]).contains("CBed1"), String(findings[0]["detail"]))


func test_a_static_surface_may_carry_freely() -> void:
	var survey := _survey({
		"surfaces": [{"name": "Sh1FloorA", "role": "floor", "supports": ["CBed1", "CDesk2"]}],
	})
	assert_eq(CourseSweep.sweep(survey, {}).size(), 0, "only a SHRINKING target is the hazard")


# --- two-method disagreement --------------------------------------------------------------


func _pair(box_span: float, ray_span: float) -> Array:
	return [
		_survey({"spans": [{"id": "A>B", "span": box_span, "landing_width": 4.0}]}),
		_survey({
			"method": "ray",
			"spans": [{"id": "A>B", "span": ray_span, "landing_width": 4.0}],
		}),
	]


func test_methods_agreeing_within_tolerance_are_not_a_disagreement() -> void:
	var pair := _pair(8.30, 8.35)
	assert_eq(CourseSweep.disagreements(pair[0], pair[1]).size(), 0)


## Cold review, High: a box read and a 0.05 m ray grid cannot agree to 1 mm. Comparing at EPS
## would make every span in the course a disagreement and the whole second method worthless.
func test_eps_sized_differences_are_not_disagreements() -> void:
	var pair := _pair(8.30, 8.302)
	assert_eq(CourseSweep.disagreements(pair[0], pair[1]).size(), 0)


func test_a_span_difference_past_method_tolerance_is_a_failure() -> void:
	var pair := _pair(8.30, 8.55)
	var findings := CourseSweep.disagreements(pair[0], pair[1])
	assert_eq(_laws(findings), ["method_disagreement"] as Array[String])
	assert_eq(_subjects(findings), ["A>B"] as Array[String])
	assert_eq(String(findings[0]["severity"]), "FAIL")


func test_a_landing_width_difference_past_tolerance_is_also_a_failure() -> void:
	var box := _survey({"spans": [{"id": "A>B", "span": 8.30, "landing_width": 4.0}]})
	var ray := _survey({
		"method": "ray",
		"spans": [{"id": "A>B", "span": 8.30, "landing_width": 3.5}],
	})
	var findings := CourseSweep.disagreements(box, ray)
	assert_eq(_laws(findings), ["method_disagreement"] as Array[String])
	assert_true(
		String(findings[0]["detail"]).contains("landing_width"),
		"width is law-bearing since T2b — the diff must cover it"
	)


func test_a_span_seen_by_one_method_only_is_a_disagreement() -> void:
	var box := _survey({"spans": [{"id": "A>B", "span": 8.30, "landing_width": 4.0}]})
	var findings := CourseSweep.disagreements(box, _survey({"method": "ray"}))
	assert_eq(_laws(findings), ["method_disagreement"] as Array[String])
	assert_eq(_subjects(findings), ["A>B"] as Array[String])


func test_a_span_only_the_rays_found_is_also_a_disagreement() -> void:
	var ray := _survey({
		"method": "ray",
		"spans": [{"id": "A>B", "span": 8.30, "landing_width": 4.0}],
	})
	var findings := CourseSweep.disagreements(_survey(), ray)
	assert_eq(_subjects(findings), ["A>B"] as Array[String])
