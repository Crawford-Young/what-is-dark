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
	await wait_physics_frames(2)


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
			"G2Ramp1": {"role": "surf_ramp"},
			"G2Ramp2": {"role": "surf_ramp"},
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


## The `erodable` group is tree-wide. A second course in the tree must cache only its OWN bodies,
## or eroding it would resize the first course's floors too.
func test_a_second_course_in_the_tree_caches_only_its_own_erodables() -> void:
	var second := load("res://scenes/slice.tscn").instantiate() as Slice
	add_child_autofree(second)
	await wait_physics_frames(2)
	assert_gt(_slice.erodable_count(), 0)
	assert_eq(second.erodable_count(), _slice.erodable_count())


## A manifest that is not a Dictionary is a caller bug, never a silent empty manifest.
func test_a_non_dictionary_manifest_is_reported_not_dropped() -> void:
	var audit := CourseAudit.new(_slice, ["not", "a", "manifest"])
	assert_push_error("manifest")
	assert_eq(audit.declarations(), {})


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
## mislabelled yaw-only vertical walls as FLOOR. Since T8a a declared wall IS a validated
## surface — an `erodable` tag on it must fire, which it cannot from outside `_surfaces`
## (cold-review finding 5) — but it is never a floor-graph node: the ride's budget would
## compete with a bare-run reach on the same geometry. That is the property the old
## "not also surveyed" name actually guarded.
func test_a_declared_wall_is_validated_but_never_a_floor_graph_node() -> void:
	var survey := _audit().survey_boxes(0)
	var surfaces := _by_id(survey, "surfaces", "name")
	assert_true(surfaces.has("Sh2RideL"), "a roled box must reach validation — finding 5")
	for row in _rows(survey, "spans"):
		var id := str((row as Dictionary)["id"])
		assert_false(
			id.begins_with("Sh2RideL>") or id.ends_with(">Sh2RideL"),
			"a ride wall must never be a span endpoint: %s" % id
		)


# --- the traversable span graph (T8a, issue #15) -----------------------------------------------


## The defining defect of issue #15: the level-only graph read every walk lift as void, so the
## span jumped from the floor BELOW the lift to the lip ABOVE it and reported a 16-18 m "gap"
## the shipped course crosses on foot. A traversable slope joins the graph and hands off to its
## abutting neighbours, so the phantom ids must be gone — and gone the RIGHT way: the near
## floor hands off to the lift (no span at all), it does not re-key to a nearer far.
func test_a_walkable_lift_joins_the_graph_and_dissolves_the_phantom_span() -> void:
	var spans := _by_id(_audit().survey_boxes(0), "spans", "id")
	assert_false(spans.has("Sh1FloorC>Sh2Lip"), "Sh2Ramp fills this 16 m 'gap' — issue #15")
	assert_false(spans.has("Sh7Floor>Sh8Lip"), "Sh8Lift fills this 18 m 'gap' — issue #15")
	assert_false(spans.has("G1Floor>G2PadLeft"), "G2Lift fills this 16 m 'gap' — issue #15")
	for id in spans:
		assert_false(
			str(id).begins_with("Sh1FloorC>"),
			"Sh1FloorC abuts Sh2Ramp at height — a handoff, never a span: %s" % str(id)
		)


## The cold-review finding-1 guard, pinned on shipped geometry: the Sh8 tiles sit 6 m BELOW
## the lip and tuck under it in z. Stacked geometry with no height abutment must neither
## become the endpoint (their z-overlap makes any such span degenerate) nor terminate the
## search (that silently deletes the real span past the ledge).
func test_a_height_mismatched_overlap_is_skipped_not_handed_off() -> void:
	var spans := _by_id(_audit().survey_boxes(0), "spans", "id")
	var from_lip: Array[String] = []
	for id in spans:
		if str(id).begins_with("Sh8Lip>"):
			from_lip.append(str(id))
	assert_eq(from_lip.size(), 1, str(from_lip))
	for tile in ["Sh8FloorTileL1", "Sh8FloorTileM1", "Sh8FloorTileR1"]:
		assert_false(
			from_lip[0].ends_with(">" + tile),
			"a tile 6 m below the lip is stacked geometry, not the lip's continuation"
		)


## Surf spans re-key to ramp endpoints: the kicker's real flight lands on G2Ramp2 ~10 m out,
## not on G2Exit 26 m out past a ramp the level-only graph refused to see. The value is the
## FACE-lip distance at the probe line (the ray pass confirmed ~9.89 m); the raw AABB gap
## reads 9.04 because a tilted box's footprint carries its thickness term.
func test_a_surf_span_measures_the_real_flight_to_the_ramp() -> void:
	var spans := _by_id(_audit().survey_boxes(0), "spans", "id")
	assert_false(spans.has("G2Kick1>G2Exit"), "the 26 m 'span' skipped both surf ramps — issue #15")
	assert_true(spans.has("G2Kick1>G2Ramp2"), str(spans.keys()))
	assert_between(float((spans["G2Kick1>G2Ramp2"] as Dictionary)["span"]), 9.5, 10.5)


## Part 3's chain arithmetic consumes exact span z coordinates, and the sweep runs over BOTH
## surveys — a ray row without them would read z 0.0 and manufacture a spurious FAIL on every
## ride at every loop (cold-review finding 3).
func test_span_rows_carry_their_z_interval_under_both_methods() -> void:
	var audit := _audit()
	var box_row: Dictionary = _by_id(audit.survey_boxes(0), "spans", "id")["Sh1FloorA>Sh1FloorB"]
	assert_almost_eq(float(box_row["z_from"]), -34.0, CourseLaw.EPS)
	assert_almost_eq(float(box_row["z_to"]), -40.5, CourseLaw.EPS)

	var ray_survey: Dictionary = await audit.survey_rays(0)
	var ray_row: Dictionary = _by_id(ray_survey, "spans", "id")["Sh1FloorA>Sh1FloorB"]
	assert_almost_eq(float(ray_row["z_from"]), -34.0, CourseLaw.METHOD_TOLERANCE)
	assert_almost_eq(float(ray_row["z_to"]), -40.5, CourseLaw.METHOD_TOLERANCE)


func test_wall_rows_carry_their_z_extent() -> void:
	var walls := _by_id(_audit().survey_boxes(0), "walls", "name")
	var wall: Dictionary = walls["Sh2RideL"]
	assert_almost_eq(float(wall["z_max"]), -101.0, CourseLaw.EPS)
	assert_almost_eq(float(wall["z_min"]), -119.0, CourseLaw.EPS)


## Part 2 of the T8a design: a `ceiling` leaves the floor graph ONLY — it stays a validated
## surface, which is what makes an `erodable` tag on it finally fire (cold-review finding 5:
## an excluded role left `_surfaces` entirely, so the legality check was unreachable). Roles
## are manifest facts, so an erodable shipped tile stands in as the victim — no scene edit.
func test_a_ceiling_roled_box_is_validated_but_leaves_the_floor_graph() -> void:
	var manifest := _fixture()
	(manifest["surfaces"] as Dictionary)["Sh8FloorTileM2"] = {"role": "ceiling"}
	var survey := CourseAudit.new(_slice, manifest).survey_boxes(0)

	assert_true(_by_id(survey, "surfaces", "name").has("Sh8FloorTileM2"))
	for row in _rows(survey, "spans"):
		var id := str((row as Dictionary)["id"])
		assert_false(
			id.begins_with("Sh8FloorTileM2>") or id.ends_with(">Sh8FloorTileM2"),
			"a ceiling is never a floor-graph node: %s" % id
		)

	var fired := false
	for f in CourseSweep.sweep(survey, {}):
		var finding: Dictionary = f
		if str(finding["subject"]) == "Sh8FloorTileM2" and str(finding["detail"]).contains("erodable"):
			fired = true
	assert_true(fired, "an erodable tag on a ceiling must fire — cold-review finding 5")


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
## Ruling #27: a checkpoint is relief. Marker 16 stands ON `G7Exit`'s solid (z −1140, box
## −1138.2..−1157.2) between the G7 approach and the #34 triple, so the triple's first span
## carries the break even though no marker floats inside its gap — a gap-only marker test
## would leave every on-floor checkpoint invisible to ruling #7's chain.
func test_a_marker_on_the_near_surface_breaks_the_chain_before_its_span() -> void:
	var spans := _by_id(_audit().survey_boxes(0), "spans", "id")
	assert_true(
		bool((spans["G7Exit>G8PadALeft"] as Dictionary)["marker_break_before"]),
		"marker 16 stands on G7Exit"
	)
	assert_false(
		bool((spans["G8PadALeft>G8PadBLeft"] as Dictionary)["marker_break_before"]),
		"no marker on G8PadALeft — #34's triple runs unbroken"
	)


## The sweep's single-tile hole-law exemption (wave issue #22) reads this field; a lane row
## without it would fall back to the armed default and re-fire on every finger triple.
func test_lane_rows_carry_their_tile_count() -> void:
	var floor_row: Dictionary = _by_id(_audit().survey_boxes(0), "floors", "id")["Sh6Exit"]
	var counts := {}
	for lane_row in floor_row["lanes"] as Array:
		var lane: Dictionary = lane_row
		counts[str(lane["id"])] = int(lane["tiles"])
	assert_eq(counts, {"L": 2, "M": 3, "R": 3})


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


# --- method B: live physics rays -------------------------------------------------------------


func test_the_ray_pass_names_its_method_and_samples_something() -> void:
	var survey: Dictionary = await _audit().survey_rays(0)
	assert_eq(str(survey["method"]), "ray")
	assert_eq(int(survey["loop"]), 0)
	assert_gt(int(survey["sample_count"]), 0)


## Five samples along z, reproducing 3b's "24 markers × 5 dz offsets". Revision 1 asked for ±1.0
## in x AND z, which is 3 samples on the axis the lanes split and the holes open along — a coverage
## regression wearing the same name. The offsets are floats, so an x delta is unrepresentable.
func test_the_marker_offsets_are_five_samples_along_z() -> void:
	assert_eq(CourseAudit.MARKER_OFFSETS.size(), 5)
	assert_eq(CourseAudit.MARKER_OFFSETS[0], 0.0, "the marker itself is sampled first")
	for dz in [-1.0, -0.5, 0.5, 1.0]:
		assert_true(CourseAudit.MARKER_OFFSETS.has(dz), "missing offset %.1f" % dz)


## The softlock class: a respawn point over a hole passes every other gate, and the geometry under
## it is authored by later tasks than the one that placed it. Driven by real rays in the running
## physics space, so a collider the box metadata never mentioned is included.
func test_every_marker_stands_up_under_the_rays_at_every_loop() -> void:
	var audit := _audit()
	for loop in [0, PLATEAU]:
		var survey: Dictionary = await audit.survey_rays(loop)
		var markers := _rows(survey, "markers")
		assert_eq(markers.size(), Slice.MARKER_PROGRESSES.size())
		for row in markers:
			var marker: Dictionary = row
			assert_eq(
				int(marker["offsets_hit"]),
				int(marker["offsets_total"]),
				"marker %d at z %.2f, loop %d" % [int(marker["index"]), float(marker["z"]), loop]
			)


## Two reads of one course must agree or neither is evidence. A disagreement here is a finding
## about the COURSE — some other collider filling a gap the box read calls open — never a licence
## to tune whichever surveyor is more convenient.
func test_the_two_methods_agree_on_the_shipped_course() -> void:
	var audit := _audit()
	for loop in [0, PLATEAU]:
		var box := audit.survey_boxes(loop)
		var ray: Dictionary = await audit.survey_rays(loop)
		var diffs := audit.disagreements(box, ray)
		var detail := ""
		for row in diffs:
			detail += "\n" + str((row as Dictionary)["detail"])
		assert_eq(diffs.size(), 0, "loop %d:%s" % [loop, detail])


## The E6 two-method rule survives issue #13's restructure here: the ray pass confirms the
## declared chasm by walking every lane at lip height, so a foreign collider filling the seam —
## invisible to any number of box-metadata reads — shrinks the ray gap and the rows stop matching.
func test_the_chasm_reads_identically_under_both_methods() -> void:
	var audit := _audit()
	var ray0: Dictionary = await audit.survey_rays(0)
	assert_eq(_rows(ray0, "chasms").size(), 0, "the shipped course has no chasm to confirm")

	var box := audit.survey_boxes(PLATEAU)
	var ray: Dictionary = await audit.survey_rays(PLATEAU)
	var box_chasm: Dictionary = _rows(box, "chasms")[0]
	var chasms := _rows(ray, "chasms")
	assert_eq(chasms.size(), 1, str(chasms))
	var ray_chasm: Dictionary = chasms[0]
	assert_eq(str(ray_chasm["id"]), str(box_chasm["id"]))
	assert_almost_eq(
		float(ray_chasm["gap"]), float(box_chasm["gap"]), CourseLaw.METHOD_TOLERANCE,
		"the rays found the seam more filled or more open than the metadata claims"
	)
	assert_true(bool(ray_chasm["full_width"]), "every lane must confirm open")


## The negative control. `assert_gte`, not `assert_eq(1)`: an exact count fails the moment any
## second span also disagrees, which turns a control into a blocker.
func test_an_injected_delta_is_seen_by_the_diff() -> void:
	var audit := _audit()
	var box := audit.survey_boxes(0)
	var ray: Dictionary = await audit.survey_rays(0)
	var victim: Dictionary = (ray["spans"] as Array)[0]
	var id := str(victim["id"])
	victim["span"] = float(victim["span"]) + 2.0

	var diffs := audit.disagreements(box, ray)
	assert_gte(diffs.size(), 1, "a 2 m delta must not pass the tolerance")
	var subjects: Array[String] = []
	for row in diffs:
		subjects.append(str((row as Dictionary)["subject"]))
	assert_true(subjects.has(id), "%s absent from %s" % [id, str(subjects)])


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


## The baseline gate — builds the SAME deduped `law:subject` key set the CLI builds, including
## disagreements at every loop, against the real manifest (not the fixture). RED until T8 declares
## the course and T9 authors the baseline; do not weaken. The key-set construction duplicates
## `audit_cli.gd` VERBATIM on purpose: this copy is CI's independent pin of the CLI's gate, and
## DRYing the two into one helper would retire that independence.
func test_audit_findings_match_the_pinned_baseline() -> void:
	var audit := CourseAudit.new(_slice)
	assert_eq(audit.assert_setup(), [] as Array[String])
	var declarations := audit.declarations()
	var keys: Array[String] = []
	for loop in ErosionLogic.PLATEAU_LOOP + 1:
		var box := audit.survey_boxes(loop)
		var ray: Dictionary = await audit.survey_rays(loop)
		var findings: Array[Dictionary] = []
		for survey in [box, ray]:
			assert_gt(int(survey["sample_count"]), 0, "empty pass at loop %d" % loop)
			findings.append_array(CourseSweep.sweep(survey, declarations))
		findings.append_array(audit.disagreements(box, ray))
		for f in findings:
			var key := "%s:%s" % [f["law"], f["subject"]]
			if not keys.has(key):
				keys.append(key)
	keys.sort()
	var baseline: Array[String] = _slice.course_spec().baseline.duplicate()
	baseline.sort()
	assert_eq(keys, baseline, "a NEW finding fails the gate; the baselined ones do not")


## Pins the derivation `CourseLaw`'s comment claims — 2x the ray-grid step. The purity split
## forces the 0.10 literal in the law module; this is the one place both classes are in scope.
func test_method_tolerance_is_twice_the_ray_step() -> void:
	assert_eq(CourseLaw.METHOD_TOLERANCE, 2.0 * CourseAudit.RAY_STEP)
