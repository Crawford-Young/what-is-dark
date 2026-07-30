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
	var survey := _survey({"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0}]})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": "NoSuchWall", "entry_height": 2.5, "along_speed": 11.0
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_wall"] as Array[String])


func test_a_wall_shorter_than_the_span_it_crosses_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0}],
		"walls": [{"name": "W", "length": 8.0, "extent": 20.0, "normal_y": 0.0}],
	})
	var decls := {
		"A>B": {"decl": "wall_ride", "wall": "W", "entry_height": 2.5, "along_speed": 11.0}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_span"] as Array[String])


func test_a_wall_too_short_vertically_for_the_ride_sink_fails() -> void:
	var survey := _survey({
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0}],
		"walls": [{"name": "W", "length": 18.0, "extent": 4.0, "normal_y": 0.0}],
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
		"spans": [{"id": "A>B", "span": 8.5, "landing_width": 12.0}],
		"walls": [{"name": "W", "length": 18.0, "extent": 20.0, "normal_y": 0.0}],
	})
	var decls := {
		"A>B": {
			"decl": "wall_ride", "wall": "W", "entry_height": 2.5,
			"along_speed": WallrunLogic.MIN_FORWARD_SPEED
		}
	}
	assert_eq(_laws(CourseSweep.sweep(survey, decls)), ["wall_ride_entry"] as Array[String])


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
		"spans": [{"id": "K>Far", "span": 6.0, "landing_width": 12.0, "drop": -2.0}],
		"surfaces": [{"name": "K", "role": "kicker"}],
	})
	assert_eq(CourseSweep.sweep(survey, {"K>Far": {"decl": "bare_run"}}).size(), 0)


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
