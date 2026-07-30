extends GutTest
## Box-metadata survey (method A). Scene-level, so smoke-grade by the domain rule — but every
## law shipped at T2/T4 is applied to the numbers this collector reads, so the cases that earn
## their keep are the ones proving each family is actually POPULATED. Critical 3 of the cold
## review was four families with no collector at all, and a family that collects nothing reads
## exactly like a family that was never wired up.
##
## The fixture manifest is issue #10: `walls`, `ramps`, `chasms`, `floors` and `props` are all
## role- or floors-map-gated, the real manifest is authored at T8, and T7.3 requires it ABSENT
## until then. So the test supplies its own — roles are facts about the geometry, and `spans`
## stays empty so nothing here pre-empts T8's judgment about a span's intended verb.

const PLATEAU := ErosionLogic.PLATEAU_LOOP

var _slice: Slice


func before_each() -> void:
	_slice = load("res://scenes/slice.tscn").instantiate() as Slice
	add_child_autofree(_slice)
	# `_ready` must have run — `_cache_erodable()` fills the erosion cache there, and until it
	# has, every geometry read below is a confident-looking false negative.
	await wait_frames(2)


## Real shipped nodes, verified in `scenes/slice.tscn` on 2026-07-29. `Sh6Exit` is the one
## perforated floor declared here: lanes at x −4 / 0 / +4, the `anchor +1` tiles pulling back to
## z −427.5 and the `anchor −1` tiles to −435, so its aligned opening is the shipped 1.5 m/loop
## chasm recorded in repo `CLAUDE.md`.
func _fixture() -> Dictionary:
	return {
		"spans": {},
		"surfaces": {
			"Sh2RideL": {"role": "ride_wall"},
			"Sh2Ramp": {"role": "surf_ramp"},
			"CBed1": {"role": "prop"},
			"CDresser1": {"role": "prop"},
			"CStand1": {"role": "prop"},
		},
		"floors": {
			"Sh6Exit": {
				"L": ["Sh6ExitTileL1", "Sh6ExitTileL2"],
				"M": ["Sh6ExitTileM1", "Sh6ExitTileM2", "Sh6ExitTileM3"],
				"R": ["Sh6ExitTileR1", "Sh6ExitTileR2", "Sh6ExitTileR3"],
			},
		},
		"landing_bands": [],
	}


func _audit() -> CourseAudit:
	return CourseAudit.new(_slice, _fixture())


func _rows(survey: Dictionary, key: String) -> Array:
	return survey[key] as Array


func _by_id(survey: Dictionary, key: String, id_key: String) -> Dictionary:
	var by_id := {}
	for row in _rows(survey, key):
		var entry: Dictionary = row
		by_id[str(entry[id_key])] = entry
	return by_id


# --- setup assertion -------------------------------------------------------------------------


func test_setup_assertion_is_clean_on_the_real_scene() -> void:
	assert_eq(_audit().assert_setup(), [] as Array[String])


## The whole point of `assert_setup`: a negative result from a probe whose setup never ran is not
## evidence. A `Slice` never added to the tree has no erosion cache, so every box it reports is
## the shipped size at every loop — and nothing else would have said so.
func test_setup_assertion_fails_on_a_slice_that_never_entered_the_tree() -> void:
	var orphan := load("res://scenes/slice.tscn").instantiate() as Slice
	autofree(orphan)
	var errors := CourseAudit.new(orphan, _fixture()).assert_setup()
	assert_gt(errors.size(), 0, "an un-readied slice must not pass setup")
	assert_true("\n".join(errors).contains("erod"), "\n".join(errors))


func test_the_capsule_diameter_is_read_from_the_player_not_assumed() -> void:
	assert_almost_eq(float(_audit().survey_boxes(0)["capsule_diameter"]), 0.70, CourseLaw.EPS)


# --- manifest --------------------------------------------------------------------------------


func test_a_missing_manifest_loads_as_all_empty() -> void:
	var manifest := CourseAudit.load_manifest("res://data/does_not_exist.json")
	for key in ["spans", "surfaces", "floors"]:
		assert_eq((manifest[key] as Dictionary).size(), 0, key)
	assert_eq((manifest["landing_bands"] as Array).size(), 0)


func test_declarations_are_the_manifests_span_map() -> void:
	var manifest := _fixture()
	manifest["spans"] = {"A>B": {"decl": "bare_run"}}
	assert_eq(CourseAudit.new(_slice, manifest).declarations(), {"A>B": {"decl": "bare_run"}})


# --- the pass itself -------------------------------------------------------------------------


func test_the_box_pass_names_its_method_and_loop_and_samples_something() -> void:
	var survey := _audit().survey_boxes(0)
	assert_eq(str(survey["method"]), "box")
	assert_eq(int(survey["loop"]), 0)
	assert_gt(int(survey["sample_count"]), 0)


## Fixed by construction, and this is why it matters: revision 1 defined the count partly from
## hole samples and then asserted loop-0 == plateau, which cannot both hold. A count that moves
## between loops means a probe window drifted, and no number from that run is trustworthy.
func test_the_sample_count_is_loop_invariant() -> void:
	var audit := _audit()
	assert_eq(
		int(audit.survey_boxes(0)["sample_count"]),
		int(audit.survey_boxes(PLATEAU)["sample_count"])
	)


# --- the eight families ----------------------------------------------------------------------


func test_every_family_is_populated_at_every_loop() -> void:
	var audit := _audit()
	for loop in [0, PLATEAU]:
		var survey := audit.survey_boxes(loop)
		for family in ["surfaces", "spans", "walls", "ramps", "shell_runs", "floors", "props"]:
			assert_gt(
				_rows(survey, family).size(), 0, "%s empty at loop %d" % [family, loop]
			)


func test_the_declared_wall_and_ramp_are_the_ones_surveyed() -> void:
	var survey := _audit().survey_boxes(0)
	var walls := _by_id(survey, "walls", "name")
	assert_true(walls.has("Sh2RideL"), str(walls.keys()))
	var wall: Dictionary = walls["Sh2RideL"]
	# shape_w18 is 1.2 × 16 × 18 — the long horizontal axis is z, the extent is y.
	assert_almost_eq(float(wall["length"]), 18.0, CourseLaw.EPS)
	assert_almost_eq(float(wall["extent"]), 16.0, CourseLaw.EPS)
	assert_almost_eq(float(wall["normal_y"]), 0.0, CourseLaw.EPS, "an unrotated wall face is level")

	var ramps := _by_id(survey, "ramps", "name")
	assert_true(ramps.has("Sh2Ramp"), str(ramps.keys()))
	assert_gt(float((ramps["Sh2Ramp"] as Dictionary)["angle_deg"]), 0.0)


## Classification is role-declared, never slope-derived: a 3b recon child's own slope formula
## mislabelled yaw-only vertical walls as FLOOR. A declared wall is therefore not also a span
## endpoint, or the ride's budget would compete with a bare-run reach on the same geometry.
func test_a_declared_wall_is_not_also_surveyed_as_a_course_surface() -> void:
	var surfaces := _by_id(_audit().survey_boxes(0), "surfaces", "name")
	assert_false(surfaces.has("Sh2RideL"), "a ride wall is not a floor")
	assert_false(surfaces.has("Sh2Ramp"), "a surf ramp is not a floor")


func test_props_carry_their_own_z_extent_so_a_hole_cannot_open_under_one() -> void:
	var props := _by_id(_audit().survey_boxes(0), "props", "name")
	assert_true(props.has("CBed1"), str(props.keys()))
	var bed: Dictionary = props["CBed1"]
	# d_s04 is 2.2 × 0.6 × 4 at z −1580, so the bed occupies −1582 .. −1578.
	assert_almost_eq(float(bed["from"]), -1582.0, CourseLaw.EPS)
	assert_almost_eq(float(bed["to"]), -1578.0, CourseLaw.EPS)


# --- erosion is observable -------------------------------------------------------------------


## Ruling #7's chain law reads `void_punished` and nothing else, so a survey that answers the same
## way for every span in the course silently retires it. Asserted in BOTH directions: the first
## implementation here let each endpoint surface satisfy its own opening and returned false 78 times
## out of 78, which is indistinguishable from a law that was never wired up.
func test_spans_are_split_between_void_punished_and_caught() -> void:
	var punished := 0
	var caught := 0
	for row in _rows(_audit().survey_boxes(0), "spans"):
		var span: Dictionary = row
		if bool(span["void_punished"]):
			punished += 1
		else:
			caught += 1
	assert_gt(punished, 0, "a course of narrow floors over void must punish SOME gap")
	assert_gt(caught, 0, "a lower ledge under a gap makes it a mistake, not a reset")


func test_at_least_one_span_widens_by_plateau() -> void:
	var audit := _audit()
	var shipped := _by_id(audit.survey_boxes(0), "spans", "id")
	var eroded := _by_id(audit.survey_boxes(PLATEAU), "spans", "id")
	var widened := 0
	for id in shipped:
		if not eroded.has(id):
			continue
		var was := float((shipped[id] as Dictionary)["span"])
		var now := float((eroded[id] as Dictionary)["span"])
		if now > was + CourseLaw.EPS:
			widened += 1
	assert_gt(widened, 0, "erosion must be observable in the survey or the survey is blind")


## `apply_erosion()` is idempotent by contract — every dimension is recomputed from the cached
## shipped geometry — so a survey at loop 0 taken after a plateau visit must be the shipped
## course exactly. A collector that mutated the cache instead of reading it fails here.
func test_returning_to_loop_zero_reproduces_the_shipped_spans() -> void:
	var audit := _audit()
	var first := _by_id(audit.survey_boxes(0), "spans", "id")
	audit.survey_boxes(PLATEAU)
	var again := _by_id(audit.survey_boxes(0), "spans", "id")
	assert_eq(again.keys().size(), first.keys().size())
	for id in first:
		assert_almost_eq(
			float((again[id] as Dictionary)["span"]),
			float((first[id] as Dictionary)["span"]),
			CourseLaw.EPS,
			"span %s moved after a plateau visit" % id
		)


# --- the chasm negative control --------------------------------------------------------------


## The control the whole erosion family rests on: at the shipped course the perforated floor is
## one solid box, so a chasm found at loop 0 means the seam arithmetic is wrong, not that the
## course has a hole. Reshaped from the plan's "exactly 5" by issue #10 — the other four floors
## are declared at T8.4, which now owns that count.
func test_no_chasm_exists_at_loop_zero() -> void:
	assert_eq(_rows(_audit().survey_boxes(0), "chasms").size(), 0)


func test_the_declared_floor_parts_edge_to_edge_at_plateau() -> void:
	var chasms := _rows(_audit().survey_boxes(PLATEAU), "chasms")
	assert_eq(chasms.size(), 1, str(chasms))
	var chasm: Dictionary = chasms[0]
	assert_true(str(chasm["id"]).contains("Sh6Exit"), str(chasm["id"]))
	assert_almost_eq(float(chasm["gap"]), 7.5, CourseLaw.EPS, "lips −427.5 and −435")
	assert_almost_eq(float(chasm["per_loop"]), 1.5, CourseLaw.EPS, "measured, never declared")
	assert_true(bool(chasm["full_width"]), "a chasm may not be side-stepped")
	assert_gte(float(chasm["runout"]), CourseLaw.CHASM_RUNOUT_MIN)


func test_the_chasm_grows_at_the_shipped_rate_from_the_first_loop() -> void:
	var chasms := _rows(_audit().survey_boxes(1), "chasms")
	assert_eq(chasms.size(), 1, str(chasms))
	assert_almost_eq(float((chasms[0] as Dictionary)["gap"]), 1.5, CourseLaw.EPS)


## The binding invariant of the whole perforation design: at `world_scale(0)` the tiles abut
## exactly and reproduce the shipped solid box. Both numbers are measured live — the lane extent is
## erosion-invariant by design (outer tiles pin the outer edges) while the solid metres inside it
## shrink — so this compares two independent reads, not a value against a cached copy of itself.
func test_loop_zero_is_seamless_and_plateau_is_not() -> void:
	var audit := _audit()
	var shipped: Dictionary = _by_id(audit.survey_boxes(0), "floors", "id")["Sh6Exit"]
	for lane_row in shipped["lanes"] as Array:
		var lane: Dictionary = lane_row
		assert_eq(
			(lane["holes"] as Array).size(),
			0,
			"lane %s carries a hole in the SHIPPED course" % str(lane["id"])
		)
	assert_almost_eq(float(shipped["solid_span"]), float(shipped["shipped_span"]), CourseLaw.EPS)

	var eroded: Dictionary = _by_id(audit.survey_boxes(PLATEAU), "floors", "id")["Sh6Exit"]
	assert_lt(
		float(eroded["solid_span"]),
		float(eroded["shipped_span"]) - CourseLaw.EPS,
		"the floor must actually perforate, or contiguity passes for the wrong reason"
	)
	assert_almost_eq(
		float(eroded["shipped_span"]),
		float(shipped["shipped_span"]),
		CourseLaw.EPS,
		"the outer tiles pin the outer edges — a lane's extent may never move"
	)


# --- shell containment -----------------------------------------------------------------------


## 3b reported 24.75 m (+x) and 20.25 m (−x); both are artifacts of a reverted probe and neither
## is reproducible — issue #11. The geometry needs no probe: `G4RideL` and `G4RideR` are the SAME
## shape `g_s10` (1.2 × 13.5 × 24), mirrored at x ∓4.2, and each is the longest unbroken run on its
## own side. `CL860`, the rib that shares the −x run, sits at z −860.8..−859.2, inside `G4RideL`,
## so it adds nothing. Pinned exactly, because a merge of exact intervals has no tolerance to spend.
func test_the_longest_shell_run_is_one_shipped_ride_wall_on_each_side() -> void:
	var runs := _by_id(_audit().survey_boxes(0), "shell_runs", "side")
	assert_almost_eq(float((runs["+x"] as Dictionary)["length"]), 24.0, CourseLaw.EPS)
	assert_almost_eq(float((runs["-x"] as Dictionary)["length"]), 24.0, CourseLaw.EPS)


func test_every_shell_run_stays_under_the_anti_skip_cap() -> void:
	var audit := _audit()
	for loop in [0, PLATEAU]:
		for row in _rows(audit.survey_boxes(loop), "shell_runs"):
			var shell_run: Dictionary = row
			assert_true(
				CourseLaw.shell_segment_ok(float(shell_run["length"])),
				"%s run %.2f m at loop %d" % [str(shell_run["side"]), float(shell_run["length"]), loop]
			)


## Why the runs are loop-invariant, asserted structurally instead of by comparing two numbers:
## erosion can only lengthen a run by resizing a wall, and no wall is tagged. All 58 tagged
## bodies are floors, pads and tiles.
func test_erosion_never_touches_a_wall_or_a_ramp() -> void:
	var survey := _audit().survey_boxes(0)
	var erodable: Array[String] = []
	for row in _rows(survey, "surfaces"):
		var surface: Dictionary = row
		if bool(surface.get("erodable", false)):
			erodable.append(str(surface["name"]))
	assert_gt(erodable.size(), 0, "the fixture must see the erosion group at all")
	for name_of in ["Sh2RideL", "Sh2Ramp"]:
		assert_false(erodable.has(name_of), "%s must never erode" % name_of)
