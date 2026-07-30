class_name CourseSweep
extends RefCounted
## Survey plus declarations in, findings out. Pure: no nodes, no scene tree, no I/O — the
## collector (`scripts/dev/course_audit.gd`) does the looking and hands the numbers here.
##
## Severity policy: FAIL means a law was broken. WARN means a human has to rule on it — the
## compound gap-and-width case, a chain sitting at its cap, an exit nobody has measured. The
## harness's job on those is to make the class visible, not to overturn a ruling already made.

const SEV_FAIL := "FAIL"
const SEV_WARN := "WARN"

## The declared source that means "the player arrives on foot".
const GROUND_SOURCE := "ground"

## Order is the reading order of the report: what the pass saw, then what the surfaces claim,
## then the spans in course order, then the standalone families. T4b inserts floors before
## the shell runs.
static func sweep(survey: Dictionary, declarations: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	findings.append_array(_sweep_samples(survey))
	findings.append_array(_sweep_surfaces(survey))
	findings.append_array(_sweep_spans(survey, declarations))
	findings.append_array(_sweep_ramps(survey))
	findings.append_array(_sweep_chasms(survey))
	findings.append_array(_sweep_markers(survey))
	findings.append_array(_sweep_floors(survey))
	findings.append_array(_sweep_shell(survey))
	return findings


## Two independent reads of the same course must agree, or neither is evidence. Compared at
## `METHOD_TOLERANCE`, never at `EPS`: a continuous box read and a 0.05 m ray grid cannot agree
## to a millimetre, and demanding that would make every span in the course a disagreement.
static func disagreements(box_survey: Dictionary, ray_survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var box := _rows_by_key(box_survey, "spans", "id")
	var ray := _rows_by_key(ray_survey, "spans", "id")

	var ids: Array[String] = []
	for id in box:
		ids.append(str(id))
	for id in ray:
		if not ids.has(str(id)):
			ids.append(str(id))

	for id in ids:
		if not box.has(id):
			findings.append(
				_disagreement(box_survey, id, "the rays found a span the box read never saw")
			)
			continue
		if not ray.has(id):
			findings.append(
				_disagreement(box_survey, id, "the box read found a span the rays never saw")
			)
			continue

		var box_row: Dictionary = box[id]
		var ray_row: Dictionary = ray[id]
		# One finding per span — the first disagreeing field is enough to distrust the pair.
		for field in ["span", "landing_width"]:
			var b := float(box_row.get(field, 0.0))
			var r := float(ray_row.get(field, 0.0))
			if absf(b - r) > CourseLaw.METHOD_TOLERANCE:
				findings.append(
					_disagreement(
						box_survey,
						id,
						(
							"%s: box %.3f m vs ray %.3f m, %.3f m apart, past the %.2f m tolerance"
							% [field, b, r, absf(b - r), CourseLaw.METHOD_TOLERANCE]
						)
					)
				)
				break

	return findings


# --- families -------------------------------------------------------------------------------


static func _sweep_samples(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if int(survey.get("sample_count", 0)) <= 0:
		findings.append(
			_finding(
				survey,
				"sample_count",
				str(survey.get("method", "?")),
				"the pass sampled nothing — no number from this run is evidence"
			)
		)
	return findings


static func _sweep_surfaces(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for row in _rows(survey, "surfaces"):
		var surface: Dictionary = row
		var surface_name := str(surface.get("name", "<unnamed>"))
		for error in CourseDecl.validate_surface(surface_name, surface):
			findings.append(_finding(survey, "surface_declaration", surface_name, error))

		# Section 4.0.3's second obligation, and issue #19's finding: "does this shrink target
		# carry anything?" is a scene-tree query, not something a review can be trusted to see.
		if bool(surface.get("erodable", false)):
			var supports := _rows(surface, "supports")
			if not supports.is_empty():
				findings.append(
					_finding(
						survey,
						"shrink_target_carries",
						surface_name,
						(
							"shrinks while carrying %s — the load has nowhere to go"
							% ", ".join(supports)
						)
					)
				)
	return findings


static func _sweep_spans(survey: Dictionary, declarations: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var roles := _roles_by_surface(survey)
	var walls := _rows_by_key(survey, "walls", "name")
	var capsule := float(survey.get("capsule_diameter", 0.0))
	var run: Array[String] = []

	for row in _rows(survey, "spans"):
		var span_row: Dictionary = row
		var id := str(span_row.get("id", "<unnamed>"))
		var length := float(span_row.get("span", 0.0))
		var drop := float(span_row.get("drop", 0.0))

		# Ruling #27 (2026-07-27): the marker breaks the chain. Solid floor between two gaps is
		# not a span, so resetting only on a soft landing would emit four consecutive jumps for
		# a stretch already adjudicated legal.
		if bool(span_row.get("marker_break_before", false)):
			findings.append_array(_close_run(survey, run))
			run = []

		var decl: Dictionary = declarations.get(id, {})
		var errors := CourseDecl.validate_span(id, decl)
		var unmeasured := CourseDecl.measured_exit_missing(decl)
		for error in errors:
			if unmeasured and error.contains(CourseDecl.MEASURED_EXIT_KEY):
				findings.append(
					_finding(
						survey,
						"surf_exit_unmeasured",
						id,
						(
							"non-kicker ramp exit with no measured %s — the transfer span goes "
							+ "unchecked until someone rides it"
						) % CourseDecl.MEASURED_EXIT_KEY,
						SEV_WARN
					)
				)
			else:
				findings.append(_finding(survey, "declaration", id, error))

		# A verb law can only be applied to a verb that was legally declared.
		if errors.is_empty():
			findings.append_array(_sweep_verb(survey, id, span_row, decl, walls, declarations))

		findings.append_array(_sweep_width(survey, id, span_row, capsule))

		# Span ids are `<near>><far>`, so the launch surface's role is readable without a new
		# declaration key: off a kicker, issue #16's measured level reach is the budget.
		if str(roles.get(_near_of(id), "")) == "kicker":
			if not CourseLaw.level_kick_span_ok(length, drop):
				findings.append(
					_finding(
						survey,
						"wall_cross_reach",
						id,
						(
							"%.2f m level kick span past the measured %.5f m level kick reach"
							% [length, CourseLaw.LEVEL_KICK_REACH]
						)
					)
				)

		if bool(span_row.get("void_punished", false)):
			run.append(id)
		else:
			findings.append_array(_close_run(survey, run))
			run = []

	findings.append_array(_close_run(survey, run))
	return findings


static func _sweep_verb(
	survey: Dictionary,
	id: String,
	span_row: Dictionary,
	decl: Dictionary,
	walls: Dictionary,
	declarations: Dictionary
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var length := float(span_row.get("span", 0.0))

	match str(decl.get("decl", "")):
		"bare_run":
			if not CourseLaw.span_ok_bare_run(length):
				findings.append(
					_finding(
						survey,
						"bare_run_reach",
						id,
						(
							"%.2f m on run speed alone; flat reach is %.5f m"
							% [length, CourseLaw.FLAT_REACH]
						)
					)
				)

		"carried_speed":
			var entry := float(decl.get("entry_speed", 0.0))
			if not CourseLaw.span_ok_carried(length, entry):
				findings.append(
					_finding(
						survey,
						"carried_speed",
						id,
						(
							"%.2f m needs %.3f m/s at the lip; the declaration carries %.3f"
							% [length, CourseLaw.required_entry_speed(length), entry]
						)
					)
				)
			findings.append_array(_sweep_carried_source(survey, id, entry, decl, declarations))

		"wall_ride":
			findings.append_array(_sweep_ride(survey, id, length, decl, walls))

		"surf_transfer":
			findings.append_array(_sweep_transfer(survey, id, length, decl))

		"chasm", "gate_deploy":
			# A chasm's laws run over the `chasms` rows, where the per-loop growth is measured
			# rather than declared. Gate laws are deferred to wave 4.1 with the verbs.
			pass

	return findings


static func _sweep_carried_source(
	survey: Dictionary, id: String, entry: float, decl: Dictionary, declarations: Dictionary
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var source := str(decl.get("source", ""))

	if source == GROUND_SOURCE:
		if not CourseLaw.ground_entry_speed_ok(entry):
			findings.append(
				_finding(
					survey,
					"carried_source",
					id,
					(
						"declares %.3f m/s off the ground; ground accel tops out at %.2f"
						% [entry, SourceMove.RUN_SPEED]
					)
				)
			)
		return findings

	if not declarations.has(source):
		findings.append(
			_finding(
				survey,
				"carried_source",
				id,
				'source "%s" names no declared span — the speed is self-certified' % source
			)
		)
		return findings

	var deliverable := _deliverable_speed(source, declarations)
	if deliverable + CourseLaw.EPS < entry:
		findings.append(
			_finding(
				survey,
				"carried_source",
				id,
				(
					'source "%s" delivers %.3f m/s, short of the declared %.3f'
					% [source, deliverable, entry]
				)
			)
		)
	return findings


static func _sweep_ride(
	survey: Dictionary, id: String, length: float, decl: Dictionary, walls: Dictionary
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var wall_name := str(decl.get("wall", ""))

	if not walls.has(wall_name):
		findings.append(
			_finding(
				survey,
				"wall_ride_wall",
				id,
				'declares wall "%s", which this pass never surveyed' % wall_name
			)
		)
		return findings

	var wall: Dictionary = walls[wall_name]
	var wall_length := float(wall.get("length", 0.0))
	var extent := float(wall.get("extent", 0.0))
	var entry_height := float(decl.get("entry_height", 0.0))
	var along := float(decl.get("along_speed", 0.0))

	if not CourseLaw.ride_covers_span(wall_length, length):
		findings.append(
			_finding(
				survey,
				"wall_ride_span",
				id,
				(
					'wall "%s" runs %.2f m against a %.2f m span'
					% [wall_name, wall_length, length]
				)
			)
		)

	if along > 0.0 and not CourseLaw.ride_extent_ok(extent, entry_height, wall_length, along):
		findings.append(
			_finding(
				survey,
				"wall_ride_extent",
				id,
				(
					'wall "%s" stands %.2f m; the ride needs %.2f m (entry %.3f + %.3f sink + %.1f margin)'
					% [
						wall_name,
						extent,
						CourseLaw.required_wall_extent(entry_height, wall_length, along),
						entry_height,
						CourseLaw.sink_over_ride(wall_length, along),
						CourseLaw.RIDE_EXTENT_MARGIN,
					]
				)
			)
		)

	if not CourseLaw.ride_entry_speed_ok(along):
		findings.append(
			_finding(
				survey,
				"wall_ride_entry",
				id,
				(
					"enters the ride at %.3f m/s; the gate needs more than %.2f"
					% [along, WallrunLogic.MIN_FORWARD_SPEED]
				)
			)
		)

	return findings


static func _sweep_transfer(
	survey: Dictionary, id: String, length: float, decl: Dictionary
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var entry := float(decl.get("entry_speed", 0.0))
	var drop := float(decl.get("drop", 0.0))
	var kicker := bool(decl.get("kicker", true))
	var factor := float(decl.get("factor", CourseLaw.SURF_TRANSFER_FACTOR_MAX))

	if not CourseLaw.transfer_factor_ok(factor):
		findings.append(
			_finding(
				survey,
				"transfer_factor",
				id,
				(
					"claims a %.2f transfer factor; the measured ceiling is %.2f"
					% [factor, CourseLaw.SURF_TRANSFER_FACTOR_MAX]
				)
			)
		)

	var exit_total := CourseLaw.surf_exit_speed(entry, drop)
	var exit_h := CourseLaw.exit_horizontal_speed(
		exit_total, kicker, float(decl.get(CourseDecl.MEASURED_EXIT_KEY, 0.0))
	)
	if not CourseLaw.transfer_span_ok(length, exit_h, factor):
		findings.append(
			_finding(
				survey,
				"surf_transfer",
				id,
				(
					"%.2f m off a %.3f m/s horizontal exit at factor %.2f buys %.3f m"
					% [length, exit_h, factor, exit_h * CourseLaw.AIRTIME * factor]
				)
			)
		)

	return findings


static func _sweep_width(
	survey: Dictionary, id: String, span_row: Dictionary, capsule: float
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []

	if not span_row.has("landing_width"):
		findings.append(
			_finding(
				survey,
				"landing_width",
				id,
				"no landing width surveyed — width is law-bearing and may not go unread"
			)
		)
		return findings

	var width := float(span_row["landing_width"])
	var length := float(span_row.get("span", 0.0))

	if capsule > 0.0 and not CourseLaw.landing_width_ok(width, capsule):
		findings.append(
			_finding(
				survey,
				"landing_width",
				id,
				(
					"%.2f m landing under the %.2f m floor (two %.2f m capsule diameters)"
					% [width, CourseLaw.LANDING_WIDTH_CAPSULE_FACTOR * capsule, capsule]
				)
			)
		)

	# Neither half fails alone; landing a near-ceiling gap on a narrow strip is the case that
	# needs a ruling, which is why it warns instead of failing (issues #23, #33).
	if CourseLaw.compound_landing(length, width):
		findings.append(
			_finding(
				survey,
				"compound_landing",
				id,
				(
					"%.2f m gap onto a %.2f m landing — near-ceiling gap on a narrow strip"
					% [length, width]
				),
				SEV_WARN
			)
		)

	return findings


static func _sweep_ramps(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	# `walls` carries no standalone law: a wall's budget is only meaningful against the ride
	# declared over it, so it is checked in `_sweep_ride` where both halves are in hand.
	for row in _rows(survey, "ramps"):
		var ramp: Dictionary = row
		var ramp_name := str(ramp.get("name", "<unnamed>"))
		var angle := float(ramp.get("angle_deg", 0.0))

		if not CourseLaw.ramp_angle_ok(angle):
			findings.append(
				_finding(
					survey,
					"ramp_angle",
					ramp_name,
					(
						"%.2f deg is at or under the %.1f deg floor limit — it reads as floor"
						% [angle, CourseLaw.RAMP_MIN_DEG]
					)
				)
			)

		var path := float(ramp.get("path_len", 0.0))
		if not CourseLaw.ramp_path_ok(path):
			findings.append(
				_finding(
					survey,
					"ramp_path",
					ramp_name,
					"%.2f m of ramp path under the %.1f m design floor" % [path, CourseLaw.RAMP_PATH_MIN]
				)
			)

		var normal_y := float(ramp.get("normal_y", 0.0))
		if not CourseLaw.ramp_never_rideable(normal_y):
			findings.append(
				_finding(
					survey,
					"ramp_rideable",
					ramp_name,
					(
						"normal.y %.3f is inside the ride gate (%.2f) — the ramp can be wall-ridden"
						% [normal_y, WallrunLogic.RIDE_MAX_NORMAL_Y]
					)
				)
			)

		if not CourseLaw.ramp_in_target_band(angle):
			findings.append(
				_finding(
					survey,
					"ramp_band",
					ramp_name,
					(
						"%.2f deg sits outside the measured %.0f-%.0f deg band"
						% [angle, CourseLaw.RAMP_TARGET_MIN_DEG, CourseLaw.RAMP_TARGET_MAX_DEG]
					),
					SEV_WARN
				)
			)

	return findings


static func _sweep_chasms(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for row in _rows(survey, "chasms"):
		var chasm: Dictionary = row
		var id := str(chasm.get("id", "<unnamed>"))
		var per_loop := float(chasm.get("per_loop", 0.0))

		if not CourseLaw.chasm_growth_ok(per_loop):
			findings.append(
				_finding(
					survey,
					"chasm_growth",
					id,
					(
						"grows %.2f m per loop, past the %.1f m ceiling"
						% [per_loop, CourseLaw.CHASM_GROWTH_MAX]
					)
				)
			)

		if not CourseLaw.chasm_plateau_ok(per_loop, ErosionLogic.PLATEAU_LOOP):
			findings.append(
				_finding(
					survey,
					"chasm_plateau",
					id,
					(
						"reaches %.2f m at plateau; the fairness ceiling is %.1f m under a %.5f m reach"
						% [
							CourseLaw.chasm_gap(per_loop, ErosionLogic.PLATEAU_LOOP),
							CourseLaw.CHASM_PLATEAU_MAX,
							CourseLaw.FLAT_REACH,
						]
					)
				)
			)

		var runout := float(chasm.get("runout", 0.0))
		if not CourseLaw.chasm_runout_ok(runout):
			findings.append(
				_finding(
					survey,
					"chasm_runout",
					id,
					(
						"%.2f m of runout past the far lip; %.1f m is the minimum"
						% [runout, CourseLaw.CHASM_RUNOUT_MIN]
					)
				)
			)

		if not bool(chasm.get("full_width", false)):
			findings.append(
				_finding(
					survey,
					"chasm_full_width",
					id,
					"does not span the full course width — a chasm may not be side-stepped"
				)
			)

	return findings


static func _sweep_markers(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for row in _rows(survey, "markers"):
		var marker: Dictionary = row
		var hit := int(marker.get("offsets_hit", 0))
		var total := int(marker.get("offsets_total", 0))
		if total > 0 and hit < total:
			findings.append(
				_finding(
					survey,
					"marker_standable",
					"marker %d" % int(marker.get("index", -1)),
					(
						"%d of %d respawn offsets stand up at z %.2f"
						% [hit, total, float(marker.get("z", 0.0))]
					)
				)
			)
	return findings


## Perforation invariants. Loop 0 is the shipped course and must be seamless; every later loop
## must stay crossable, readable, and clear of everything that has to stay standable.
static func _sweep_floors(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var loop := int(survey.get("loop", 0))
	var seams := _chasm_ranges(survey)
	var blockers := _hole_blockers(survey)

	for row in _rows(survey, "floors"):
		var floor_row: Dictionary = row
		var id := str(floor_row.get("id", "<unnamed>"))
		var lanes := _rows(floor_row, "lanes")

		# A tile's size and position may only change as a pair that preserves the seam. A broken
		# seam opens a hole in the SHIPPED course, the one thing loop 0 must never contain.
		if loop == 0:
			var shipped := float(floor_row.get("shipped_span", 0.0))
			var solid := float(floor_row.get("solid_span", 0.0))
			if absf(solid - shipped) > CourseLaw.EPS:
				findings.append(
					_finding(
						survey,
						"contiguity",
						id,
						(
							"%.2f m solid against a %.2f m shipped span — the seam is broken"
							% [solid, shipped]
						)
					)
				)

		for lane_row in lanes:
			var lane: Dictionary = lane_row
			var lane_id := str(lane.get("id", "?"))
			var holes := _rows(lane, "holes")

			if loop > 0 and holes.is_empty():
				findings.append(
					_finding(
						survey,
						"hole_free_lane",
						"%s lane %s" % [id, lane_id],
						"carries no hole at loop %d — a hole-free lane is a hold-W bypass" % loop
					)
				)

			for hole_row in holes:
				var hole: Dictionary = hole_row
				var from := minf(float(hole.get("from", 0.0)), float(hole.get("to", 0.0)))
				var to := maxf(float(hole.get("from", 0.0)), float(hole.get("to", 0.0)))

				# A hole that is part of a chasm seam answers to the chasm growth law instead:
				# 1.5 m per loop, aligned across every lane, which is what a chasm IS.
				if not _overlaps_any(seams, from, to):
					if not CourseLaw.staggered_hole_length_ok(to - from, loop):
						findings.append(
							_finding(
								survey,
								"staggered_telegraph",
								"%s lane %s" % [id, lane_id],
								(
									"%.2f m hole at loop %d; the convention reads %.2f m"
									% [to - from, loop, CourseLaw.STAGGERED_GROWTH * float(loop)]
								)
							)
						)

				for blocker_row in blockers:
					var blocker: Dictionary = blocker_row
					var blocker_lane := str(blocker["lane"])
					if blocker_lane != "" and blocker_lane != lane_id:
						continue
					if from > float(blocker["to"]) + CourseLaw.EPS:
						continue
					if to < float(blocker["from"]) - CourseLaw.EPS:
						continue
					findings.append(
						_finding(
							survey,
							"hole_over_prop",
							"%s lane %s" % [id, lane_id],
							(
								"opens %.2f..%.2f under %s %s"
								% [from, to, str(blocker["kind"]), str(blocker["name"])]
							)
						)
					)

		# The law is unsatisfiable on one lane, and a one-lane floor is not a perforation grid.
		if lanes.size() >= 2:
			findings.append_array(_sweep_viable_lines(survey, id, lanes, seams))

	return findings


## At least two lanes must stay solid at every z, so there is a line to pick. Evaluated at the
## midpoint of every interval between hole edges: holes are ranges, and any z where the count
## drops is inside one of those intervals.
static func _sweep_viable_lines(
	survey: Dictionary, id: String, lanes: Array, seams: Array
) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []

	var edges: Array[float] = []
	for lane_row in lanes:
		for hole_row in _rows(lane_row, "holes"):
			var hole: Dictionary = hole_row
			edges.append(minf(float(hole.get("from", 0.0)), float(hole.get("to", 0.0))))
			edges.append(maxf(float(hole.get("from", 0.0)), float(hole.get("to", 0.0))))
	if edges.size() < 2:
		return findings
	edges.sort()

	# Contiguous offending intervals merge into one finding: they are one unbroken stretch of
	# course with no line through it, and reporting each slice separately reads as several.
	var open_from := 0.0
	var open_to := 0.0
	var worst := lanes.size()
	var offending := false

	for i in edges.size() - 1:
		var lo := edges[i]
		var hi := edges[i + 1]
		if hi - lo <= CourseLaw.EPS:
			continue

		var mid := (lo + hi) * 0.5
		var solid := 0
		if not _covers_any(seams, mid):
			for lane_row in lanes:
				if not _lane_open_at(lane_row, mid):
					solid += 1

		if _covers_any(seams, mid) or solid >= 2:
			if offending:
				findings.append(_viable_finding(survey, id, open_from, open_to, worst, lanes))
				offending = false
			continue

		if offending and absf(lo - open_to) <= CourseLaw.EPS:
			open_to = hi
			worst = mini(worst, solid)
		else:
			if offending:
				findings.append(_viable_finding(survey, id, open_from, open_to, worst, lanes))
			open_from = lo
			open_to = hi
			worst = solid
			offending = true

	if offending:
		findings.append(_viable_finding(survey, id, open_from, open_to, worst, lanes))

	return findings


static func _viable_finding(
	survey: Dictionary, id: String, from: float, to: float, solid: int, lanes: Array
) -> Dictionary:
	return _finding(
		survey,
		"viable_lines",
		id,
		(
			"%.2f..%.2f leaves %d of %d lanes solid; two must stay"
			% [from, to, solid, lanes.size()]
		)
	)


static func _lane_open_at(lane_row: Dictionary, z: float) -> bool:
	for hole_row in _rows(lane_row, "holes"):
		var hole: Dictionary = hole_row
		var from := minf(float(hole.get("from", 0.0)), float(hole.get("to", 0.0)))
		var to := maxf(float(hole.get("from", 0.0)), float(hole.get("to", 0.0)))
		if z > from - CourseLaw.EPS and z < to + CourseLaw.EPS:
			return true
	return false


## Everything a hole may not open under. Props and landing bands belong to a lane; a marker does
## not, because a respawn point over a hole is a softlock in whichever lane it opens.
static func _hole_blockers(survey: Dictionary) -> Array[Dictionary]:
	var blockers: Array[Dictionary] = []

	for row in _rows(survey, "props"):
		var prop: Dictionary = row
		blockers.append({
			"kind": "prop",
			"name": str(prop.get("name", "?")),
			"lane": str(prop.get("lane", "")),
			"from": minf(float(prop.get("from", 0.0)), float(prop.get("to", 0.0))),
			"to": maxf(float(prop.get("from", 0.0)), float(prop.get("to", 0.0))),
		})

	for row in _rows(survey, "landing_bands"):
		var band: Dictionary = row
		blockers.append({
			"kind": "landing band",
			"name": str(band.get("id", "?")),
			"lane": str(band.get("lane", "")),
			"from": minf(float(band.get("from", 0.0)), float(band.get("to", 0.0))),
			"to": maxf(float(band.get("from", 0.0)), float(band.get("to", 0.0))),
		})

	for row in _rows(survey, "markers"):
		var marker: Dictionary = row
		var z := float(marker.get("z", 0.0))
		blockers.append({
			"kind": "respawn",
			"name": "marker %d" % int(marker.get("index", -1)),
			"lane": "",
			"from": z,
			"to": z,
		})

	return blockers


static func _chasm_ranges(survey: Dictionary) -> Array:
	var ranges: Array[Dictionary] = []
	for row in _rows(survey, "chasms"):
		var chasm: Dictionary = row
		if not (chasm.has("from") and chasm.has("to")):
			continue
		ranges.append({
			"from": minf(float(chasm["from"]), float(chasm["to"])),
			"to": maxf(float(chasm["from"]), float(chasm["to"])),
		})
	return ranges


static func _overlaps_any(ranges: Array, from: float, to: float) -> bool:
	for row in ranges:
		var span: Dictionary = row
		if from < float(span["to"]) + CourseLaw.EPS and to > float(span["from"]) - CourseLaw.EPS:
			return true
	return false


static func _covers_any(ranges: Array, z: float) -> bool:
	for row in ranges:
		var span: Dictionary = row
		if z > float(span["from"]) - CourseLaw.EPS and z < float(span["to"]) + CourseLaw.EPS:
			return true
	return false


static func _sweep_shell(survey: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for row in _rows(survey, "shell_runs"):
		var shell_run: Dictionary = row
		var length := float(shell_run.get("length", 0.0))
		if not CourseLaw.shell_segment_ok(length):
			findings.append(
				_finding(
					survey,
					"shell_segment",
					str(shell_run.get("side", "?")),
					(
						"%.2f m of unbroken shell, past the %.1f m cap — the wall-jump chain "
						+ "must never buy a zone skip"
					) % [length, CourseLaw.MAX_UNBROKEN_SHELL]
				)
			)
	return findings


# --- helpers --------------------------------------------------------------------------------


static func _close_run(survey: Dictionary, run: Array[String]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if run.is_empty():
		return findings

	if not CourseLaw.precision_chain_ok(run.size()):
		findings.append(
			_finding(
				survey,
				"precision_chain",
				run[0],
				(
					"%d consecutive void-punished jumps; ruling #7 caps the chain at %d"
					% [run.size(), CourseLaw.MAX_PRECISION_CHAIN]
				)
			)
		)
	elif CourseLaw.precision_chain_at_cap(run.size()):
		findings.append(
			_finding(
				survey,
				"precision_chain_at_cap",
				run[0],
				(
					"the chain sits at its %d-jump cap — no room to add another (issues #34, #28)"
					% CourseLaw.MAX_PRECISION_CHAIN
				),
				SEV_WARN
			)
		)

	return findings


static func _deliverable_speed(source: String, declarations: Dictionary) -> float:
	var src: Dictionary = declarations[source]
	if str(src.get("decl", "")) != "surf_transfer":
		# Every other verb is ground-limited: a kick, a bare run and a chasm approach all leave
		# the player at run speed, never above it.
		return SourceMove.RUN_SPEED

	var total := CourseLaw.surf_exit_speed(
		float(src.get("entry_speed", 0.0)), float(src.get("drop", 0.0))
	)
	return CourseLaw.exit_horizontal_speed(
		total,
		bool(src.get("kicker", true)),
		float(src.get(CourseDecl.MEASURED_EXIT_KEY, 0.0))
	)


static func _near_of(id: String) -> String:
	return id.get_slice(">", 0)


static func _rows(survey: Dictionary, key: String) -> Array:
	var value: Variant = survey.get(key, [])
	return value if value is Array else []


static func _rows_by_key(survey: Dictionary, family: String, key: String) -> Dictionary:
	var by_key := {}
	for row in _rows(survey, family):
		var entry: Dictionary = row
		by_key[str(entry.get(key, ""))] = entry
	return by_key


static func _roles_by_surface(survey: Dictionary) -> Dictionary:
	var roles := {}
	for row in _rows(survey, "surfaces"):
		var surface: Dictionary = row
		roles[str(surface.get("name", ""))] = str(surface.get("role", ""))
	return roles


static func _finding(
	survey: Dictionary, law: String, subject: String, detail: String, severity := SEV_FAIL
) -> Dictionary:
	var loop := int(survey.get("loop", 0))
	return {
		"law": law,
		"subject": subject,
		"loop": loop,
		"severity": severity,
		"detail": "loop %d %s: %s %s" % [loop, str(survey.get("method", "?")), subject, detail],
	}


static func _disagreement(survey: Dictionary, id: String, detail: String) -> Dictionary:
	var loop := int(survey.get("loop", 0))
	return {
		"law": "method_disagreement",
		"subject": id,
		"loop": loop,
		"severity": SEV_FAIL,
		"detail": "loop %d box vs ray: %s %s" % [loop, id, detail],
	}
