class_name CourseAudit
extends RefCounted
## Method A of the course-law harness: read the shipped geometry off the box metadata of a LIVE
## `Course` and hand `CourseSweep` numbers to apply the laws to. Takes a scene, so it is not pure
## and does not belong in `scripts/logic/`; it is dev tooling, hence `scripts/dev/`.
##
## Two rules govern every extraction here.
##
## **Nothing is derived that the manifest states.** Wall and ramp classification is role-declared,
## because a 3b recon child's own slope formula mislabelled yaw-only vertical walls as FLOOR and
## the audit inherited a false map of its own course. Lane membership is declared for the same
## reason: a lane read off a node-name suffix is a parse, not a measurement.
##
## **Nothing is assumed that can be read.** The capsule diameter comes off the player's own shape,
## the erosion state off `apply_erosion()`, the shipped span off loop 0. `assert_setup()` is the
## guard for the one failure mode none of that survives — a scene whose `_ready` never ran reports
## the shipped size at every loop, confidently and wrongly.

## Role lookup resolves against the body for the 155 single-`Col` bodies and against the collision
## node for the 15 multi-shape aggregates (shells, prop clusters, the door frame) — issue #9. The
## manifest's `"CBed1": {"role": "prop"}` is the second form.
const COL_NAME := "Col"

const ROLE_WALL := "ride_wall"
const ROLE_RAMP := "surf_ramp"
const ROLE_PROP := "prop"
const ROLE_CEILING := "ceiling"

## Subtrees that are not course geometry: the player carries the capsule the laws measure against,
## and the void wall is a moving hazard, not a surface anyone stands on.
const SKIP_NODES: Array[String] = ["Player", "VoidWall"]

## A box is wall-like when it stands taller than its own footprint. Slope alone cannot make this
## call (a yaw-only wall has a level top face), and role alone cannot either — the shell ribs the
## anti-skip cap is about are never declared, because declaring them would not make them
## chainable.
const WALL_ASPECT := 1.0

## Respawn offsets along z — 5 samples reproducing 3b's "24 markers × 5 dz offsets". On z because
## that is the axis the lanes split and the holes open along.
const MARKER_OFFSETS: Array[float] = [0.0, -0.5, 0.5, -1.0, 1.0]

## Method B's grid: the interior of every span is walked at this step looking for a foreign
## collider filling the gap — the one defect two box-metadata reads share a blind spot on.
const RAY_STEP := 0.05
## How far inside a surface a reference ray starts, and how far below a lip a fill counts.
const RAY_MARGIN := 0.5
const RAY_FILL_DEPTH := 0.4

var _course: Course
var _manifest: Dictionary
var _rays_cast := 0


static func load_manifest(path: String) -> Dictionary:
	var manifest := {"spans": {}, "surfaces": {}, "floors": {}, "landing_bands": []}
	if not FileAccess.file_exists(path):
		# A fresh checkout reports every span undeclared instead of crashing — that report is the
		# authoring worklist, so an empty manifest is a legal state, not an error.
		return manifest
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		return manifest
	var source: Dictionary = parsed
	for key in manifest:
		if source.has(key):
			manifest[key] = source[key]
	return manifest


## `manifest` defaults to the course's own declarations file, named by its `CourseSpec`; the GUT
## cases pass a fixture instead.
func _init(course: Course, manifest: Variant = null) -> void:
	_course = course
	if manifest == null and course != null:
		manifest = load_manifest(course.course_spec().declarations_path)
	if manifest is Dictionary:
		_manifest = manifest
	else:
		if manifest != null:
			push_error(
				"CourseAudit: manifest must be a Dictionary, got %s" % type_string(typeof(manifest))
			)
		_manifest = {}


func declarations() -> Dictionary:
	return _manifest.get("spans", {}) as Dictionary


## Non-empty when a read from this collector would not be evidence. The CLI and the GUT gate both
## call it FIRST and abort on non-empty.
func assert_setup() -> Array[String]:
	var errors: Array[String] = []
	if _course == null:
		errors.append("no course")
		return errors

	if _course.erodable_count() == 0:
		errors.append(
			"the erodable cache is empty — `_ready` has not run, so every box reads its shipped "
			+ "size at every loop"
		)

	var world_env := _course.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null or world_env.environment == null:
		errors.append("no WorldEnvironment — `apply_erosion()` cannot complete")

	var path := _course.get_node_or_null("CoursePath") as Path3D
	if path == null or path.curve == null or path.curve.get_baked_length() <= 0.0:
		errors.append("the course curve has no baked length — no marker z can be resolved")

	if _capsule_diameter() <= 0.0:
		errors.append("the player capsule could not be read — every width law loses its unit")

	return errors


## Sets the loop count and re-applies erosion. Idempotent by `apply_erosion()`'s own contract:
## every dimension is recomputed from the cached shipped geometry, never from the current size.
func set_loop(loop: int) -> void:
	_course.loop_logic.loop_count = loop
	_course.apply_erosion()


func survey_boxes(loop: int) -> Dictionary:
	set_loop(loop)

	var boxes := _collect_boxes()
	var surfaces := _surfaces(boxes)
	var floor_boxes := _floor_boxes(boxes, surfaces)
	var spans := _spans(floor_boxes, boxes)
	var floors := _floors(boxes)
	var chasms := _chasms(floors, boxes)

	return {
		"method": "box",
		"loop": loop,
		# Fixed by construction from three counts that erosion cannot move: the boxes read, the
		# floor surfaces each offered one successor, and the declared tiles examined. A count that
		# drifts between loops means the probe window moved and no number from the run is evidence.
		"sample_count": boxes.size() + floor_boxes.size() + _declared_tile_count(),
		"capsule_diameter": _capsule_diameter(),
		"surfaces": surfaces,
		"spans": spans,
		"walls": _walls(boxes),
		"ramps": _ramps(boxes),
		"chasms": chasms,
		"markers": _markers(floor_boxes),
		"floors": floors,
		"props": _props(boxes, floors),
		"landing_bands": _manifest.get("landing_bands", []) as Array,
		"shell_runs": _shell_runs(boxes),
	}


## Method B: the same spans and markers, measured against the LIVE physics space instead of box
## metadata. The two reads share a blind spot when both consult the same numbers, so nothing here
## reads a `BoxShape3D.size` — every edge is bisected with identity-checked rays and every gap
## interior is walked for foreign colliders. What rays cannot measure is intent: roles and the
## floors map are declarations, so `surfaces` and `walls` are carried over for the span laws to
## reference, and the manifest-topology families (`floors`, `chasms`, `props`, `ramps`,
## `shell_runs`) stay empty — the box pass owns their laws, and the CLI dedups across passes.
func survey_rays(loop: int) -> Dictionary:
	set_loop(loop)
	# Two physics frames: the first carries the eroded sizes into the physics server, the second
	# guarantees the space sits between steps when the queries run.
	await _course.get_tree().physics_frame
	await _course.get_tree().physics_frame

	_rays_cast = 0
	var space := _course.get_world_3d().direct_space_state
	var boxes := _collect_boxes()
	var surfaces := _surfaces(boxes)
	var floor_boxes := _floor_boxes(boxes, surfaces)
	var by_name := {}
	for row in boxes:
		by_name[str(row["name"])] = row

	var spans: Array[Dictionary] = []
	for row in _spans(floor_boxes, boxes):
		var box_span: Dictionary = row
		var id := str(box_span["id"])
		var near: Dictionary = by_name.get(id.get_slice(">", 0), {})
		var far: Dictionary = by_name.get(id.get_slice(">", 1), {})
		if near.is_empty() or far.is_empty():
			continue
		spans.append(_ray_span(space, id, box_span, near, far))

	var floors := _floors(boxes)
	return {
		"method": "ray",
		"loop": loop,
		"sample_count": _rays_cast,
		"capsule_diameter": _capsule_diameter(),
		"surfaces": surfaces,
		"spans": spans,
		"walls": _walls(boxes),
		"ramps": [],
		"chasms": _ray_chasms(space, _chasms(floors, boxes), floors),
		"markers": _ray_markers(space),
		"floors": [],
		"props": [],
		"landing_bands": _manifest.get("landing_bands", []) as Array,
		"shell_runs": [],
	}


func disagreements(box_survey: Dictionary, ray_survey: Dictionary) -> Array[Dictionary]:
	return CourseSweep.disagreements(box_survey, ray_survey)


## The measured fields (`span`, `landing_width` — exactly the two the diff compares) come from
## rays; the topology fields ride along from the box pairing, because a span's identity is which
## two surfaces it separates, and the diff matches by id.
func _ray_span(
	space: PhysicsDirectSpaceState3D, id: String, box_span: Dictionary, near: Dictionary,
	far: Dictionary
) -> Dictionary:
	var x := _span_probe_x(near, far)

	# Each lip is the physics edge of its OWN body, found by bisecting an identity-checked ray
	# between a point ON its face at the probe x (a hit — the face z MID there, because on a
	# diagonal face the box's z centre can lie off the face entirely) and the gap's midpoint
	# (a miss on a healthy course). A body secretly extending into the gap drags its lip with
	# it, which is the point.
	# Lip to lip and nothing else: that is the distance the reach laws consume, and it is what
	# the box read reports. A ramp, kicker or lip legitimately standing INSIDE the gap does not
	# shorten the jump — the first version of this method walked the interior for fillers and
	# disagreed with the shipped course on 21 spans, every one of them course furniture doing its
	# job (issue #13). The fill walk lives on where the two-method rule was born: the chasms.
	var gap_mid := (float(near["z_min"]) + float(far["z_max"])) * 0.5
	var near_anchor := (
		_face_edge_z(near, x, true) + _face_edge_z(near, x, false)
	) * 0.5
	var far_anchor := (
		_face_edge_z(far, x, true) + _face_edge_z(far, x, false)
	) * 0.5
	var near_lip := _bisect_z(space, near, x, near_anchor, gap_mid)
	var far_lip := _bisect_z(space, far, x, far_anchor, gap_mid)
	var span := near_lip - far_lip

	# Landing width along the shared `_landing_z` line, edges bisected on the far body's
	# identity — the box pass measures the same line, so the two reads stay comparable on
	# rotated faces too.
	var x_centre := (float(far["x_min"]) + float(far["x_max"])) * 0.5
	var z_land := _landing_z(far, far_lip)
	var left := _bisect_x(space, far, z_land, x_centre, float(far["x_min"]) - 1.0)
	var right := _bisect_x(space, far, z_land, x_centre, float(far["x_max"]) + 1.0)

	return {
		"id": id,
		"span": span,
		"drop": box_span["drop"],
		"landing_width": absf(right - left),
		# From this pass's OWN bisected lips (cold-review finding 3): the sweep runs over both
		# surveys, and a ray row defaulting these to 0.0 would manufacture hundreds-of-metres
		# chain gaps and a spurious ride FAIL at every loop. Populating from the lips also keeps
		# the two-method comparison honest for chain geometry.
		"z_from": near_lip,
		"z_to": far_lip,
		"void_punished": box_span["void_punished"],
		"marker_break_before": box_span["marker_break_before"],
	}


## The E6 rule, live: a chasm's opening is confirmed by walking every lane's aligned range with
## rays at lip height, because "any OTHER collider silently filling a chasm reads as open" to any
## number of box-metadata reads. The gap reported is the most-filled lane's clear run — a chasm is
## only as open as its worst lane — so a foreign filler shrinks the ray gap and the two methods'
## chasm rows stop matching.
func _ray_chasms(
	space: PhysicsDirectSpaceState3D, box_chasms: Array[Dictionary], floors: Array[Dictionary]
) -> Array[Dictionary]:
	var chasms: Array[Dictionary] = []
	var loop := _course.loop_logic.loop_count

	for row in box_chasms:
		var box_chasm: Dictionary = row
		var from := float(box_chasm["from"])
		var to := float(box_chasm["to"])
		var owner := _floor_covering(floors, from, to)
		if owner.is_empty():
			continue

		var gap := from - to
		var full_width := true
		for lane_row in owner["lanes"] as Array:
			var lane: Dictionary = lane_row
			var x := (float(lane["x_min"]) + float(lane["x_max"])) * 0.5
			var lip := float(owner["top"])
			var clear := _clear_run(space, x, lip, from, to)
			gap = minf(gap, clear)
			if clear < (from - to) - 2.0 * RAY_STEP:
				full_width = false

		chasms.append({
			"id": box_chasm["id"],
			"gap": gap,
			"per_loop": (gap / float(loop) if loop > 0 else 0.0),
			"from": from,
			"to": to,
			"runout": box_chasm["runout"],
			"full_width": full_width,
		})
	return chasms


func _clear_run(
	space: PhysicsDirectSpaceState3D, x: float, lip: float, from: float, to: float
) -> float:
	var longest := 0.0
	var run := 0.0
	var z := from - RAY_STEP
	while z > to:
		if _ray_hits(space, x, z, lip + 1.0, lip - RAY_FILL_DEPTH, null):
			run = 0.0
		else:
			run += RAY_STEP
			longest = maxf(longest, run)
		z -= RAY_STEP
	return minf(longest + RAY_STEP, from - to)


func _floor_covering(floors: Array[Dictionary], from: float, to: float) -> Dictionary:
	for row in floors:
		var floor_row: Dictionary = row
		if from <= float(floor_row["to"]) + CourseLaw.EPS and to >= float(floor_row["from"]) - CourseLaw.EPS:
			var top := -INF
			for lane_row in floor_row["lanes"] as Array:
				top = maxf(top, float((lane_row as Dictionary).get("top", -INF)))
			var out := floor_row.duplicate()
			out["top"] = top
			return out
	return {}


## The 3b respawn sweep, live: a ray at every offset of every marker, in the running physics
## space, so a collider the metadata never mentioned still counts as ground.
func _ray_markers(space: PhysicsDirectSpaceState3D) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for i in _course.marker_progresses.size():
		var at := _course.respawn_position(i)
		var hit := 0
		for dz in MARKER_OFFSETS:
			# Ground counts down to the game's own fall plane: the respawn point rides 1 m above
			# the path curve, and the curve's height above its floor varies per zone — a fixed
			# shallow window under-reached every Grief and Depression marker on the first run.
			if _ray_hits(space, at.x, at.z + dz, at.y + 0.5, _course.fall_y, null):
				hit += 1
		markers.append({
			"index": i,
			"z": at.z,
			"offsets_hit": hit,
			"offsets_total": MARKER_OFFSETS.size(),
		})
	return markers


func _ray_hits(
	space: PhysicsDirectSpaceState3D, x: float, z: float, y_from: float, y_to: float,
	target: Variant
) -> bool:
	_rays_cast += 1
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, y_from, z), Vector3(x, y_to, z))
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	return target == null or hit["collider"] == target


## A vertical probe window hugging the body's own top face. The window STARTS 2 cm above the
## face rather than a metre up, and that offset is load-bearing: a prop resting on the surface
## (the G5 gurneys) would intercept a taller ray and the identity test would never see its own
## target — the ray's origin sits INSIDE the resting occluder instead, which `intersect_ray`
## ignores (`hit_from_inside` defaults off), so the probe reaches the face beneath. Without this,
## the bisection start on an occupied tile is false and the lip collapses to mid-tile.
##
## The window is SHALLOW below the face too (T8a): `surface_y_at` tracks the face exactly, so
## depth buys nothing on the face itself — what a deep window did buy, wrongly, was hits on the
## SIDE silhouette of a rotated box past the face lip, which read as "still on the face" and
## dragged the bisected lip up to a thickness-term away from where the top face actually ends.
## Both passes must mean the same edge: the top face's.
const _FACE_ABOVE := 0.02
const _FACE_BELOW := 0.1


## Both bisections recompute the window PER PROBE from `surface_y_at` (cold-review finding 2):
## a fixed `top`-anchored window fails on a sloped box from step 0, because the identity anchor
## sits at the box's centre where a rising face puts the surface above `edge + 0.02` — the ray
## origin lands inside the body, `hit_from_inside` is off, and the anchor reads MISS.
func _bisect_z(
	space: PhysicsDirectSpaceState3D, body_row: Dictionary, x: float, z_hit: float, z_miss: float
) -> float:
	var target: Variant = body_row["node"]
	for i in 20:
		var mid := (z_hit + z_miss) * 0.5
		var face := surface_y_at(body_row, mid, x)
		if _ray_hits(space, x, mid, face + _FACE_ABOVE, face - _FACE_BELOW, target):
			z_hit = mid
		else:
			z_miss = mid
	return (z_hit + z_miss) * 0.5


func _bisect_x(
	space: PhysicsDirectSpaceState3D, body_row: Dictionary, z: float, x_hit: float, x_miss: float
) -> float:
	var target: Variant = body_row["node"]
	for i in 20:
		var mid := (x_hit + x_miss) * 0.5
		var face := surface_y_at(body_row, z, mid)
		if _ray_hits(space, mid, z, face + _FACE_ABOVE, face - _FACE_BELOW, target):
			x_hit = mid
		else:
			x_miss = mid
	return (x_hit + x_miss) * 0.5


# --- box collection --------------------------------------------------------------------------


## One row per `BoxShape3D` collider in the course, with its role resolved and its world-space
## extents already reduced to the numbers every family below needs. Read AFTER `apply_erosion()`.
func _collect_boxes() -> Array[Dictionary]:
	var boxes: Array[Dictionary] = []
	for body in _bodies(_course):
		var cols: Array[CollisionShape3D] = []
		for child in body.get_children():
			var col := child as CollisionShape3D
			if col != null and col.shape is BoxShape3D:
				cols.append(col)
		var aggregate := cols.size() > 1 or (cols.size() == 1 and cols[0].name != COL_NAME)
		for col in cols:
			var box_name := str(col.name) if aggregate else str(body.name)
			boxes.append(_box_row(box_name, body, col, aggregate))
	return boxes


func _bodies(node: Node) -> Array[StaticBody3D]:
	var bodies: Array[StaticBody3D] = []
	for child in node.get_children():
		if SKIP_NODES.has(str(child.name)):
			continue
		var body := child as StaticBody3D
		if body != null:
			bodies.append(body)
		bodies.append_array(_bodies(child))
	return bodies


func _box_row(
	box_name: String, body: StaticBody3D, col: CollisionShape3D, aggregate: bool
) -> Dictionary:
	var shape := col.shape as BoxShape3D
	var basis := col.global_transform.basis
	var centre := col.global_position
	var size := shape.size
	# Half-extents along the world axes, so a yaw-rotated box still reports the footprint it
	# actually occupies rather than its local size.
	var half := Vector3(
		absf(basis.x.x * size.x) + absf(basis.y.x * size.y) + absf(basis.z.x * size.z),
		absf(basis.x.y * size.x) + absf(basis.y.y * size.y) + absf(basis.z.y * size.z),
		absf(basis.x.z * size.x) + absf(basis.y.z * size.y) + absf(basis.z.z * size.z),
	) * 0.5

	var up := basis.y.normalized()
	return {
		"name": box_name,
		"body": str(body.name),
		# Transient scene ref for the ray pass's identity checks — never copied into survey output.
		"node": body,
		"role": str((_manifest.get("surfaces", {}) as Dictionary).get(box_name, {}).get("role", "")),
		"aggregate": aggregate,
		"erodable": body.is_in_group(Course.EROSION_GROUP),
		"size": size,
		"level": up.dot(Vector3.UP) > 1.0 - CourseLaw.EPS,
		"normal_y": up.y,
		"top": centre.y + half.y,
		"bottom": centre.y - half.y,
		"x_min": centre.x - half.x,
		"x_max": centre.x + half.x,
		"z_min": centre.z - half.z,
		"z_max": centre.z + half.z,
		"basis": basis,
	}


func _capsule_diameter() -> float:
	var player := _course.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return 0.0
	for child in player.get_children():
		var col := child as CollisionShape3D
		if col != null and col.shape is CapsuleShape3D:
			return (col.shape as CapsuleShape3D).radius * 2.0
	return 0.0


# --- surfaces, walls, ramps, props ------------------------------------------------------------


## The course's own surfaces: one row per single-`Col` body. The aggregates are reached through
## `props` and the shell scan instead — issue #9. Erosion metadata lives on the body, and role is
## a property of a surface, not of a collider.
##
## Membership is VALIDATION membership, not graph membership (T8a, cold-review finding 5): every
## roled box gets a row — `ride_wall` and `ceiling` included — because `validate_surface` and the
## erodable-legality check run over these rows and nothing else; a role excluded here was a role
## the laws could never reach. Un-roled boxes get a row when the course can stand on them (level,
## or a walkable slope), which is what puts them on the authoring worklist demanding a role.
## Graph exclusion lives wholly in `_floor_boxes`.
func _surfaces(boxes: Array[Dictionary]) -> Array[Dictionary]:
	var surfaces: Array[Dictionary] = []
	for row in boxes:
		if bool(row["aggregate"]):
			continue
		if str(row["role"]) == "" and not bool(row["level"]) and not _traversable(row):
			continue
		var floors_map := _manifest.get("floors", {}) as Dictionary
		var declared: Dictionary = (_manifest.get("surfaces", {}) as Dictionary).get(row["name"], {})
		var surface := {
			"name": row["name"],
			"erodable": row["erodable"],
			"perforated": _floor_of(str(row["name"]), floors_map) != "",
			"supports": _supports(row, boxes),
			"width": float((row["size"] as Vector3).x),
		}
		for key in ["role", "width_shrink"]:
			if declared.has(key):
				surface[key] = declared[key]
		surfaces.append(surface)
	return surfaces


## Issue #19's query: does this shrink target carry anything? A scene-tree fact no review can be
## trusted to see. A box counts as carried when it rests within `EPS` of this surface's top face
## and its footprint overlaps in x and z.
func _supports(surface: Dictionary, boxes: Array[Dictionary]) -> Array[String]:
	var supports: Array[String] = []
	if not bool(surface["erodable"]):
		return supports
	for row in boxes:
		if row["name"] == surface["name"]:
			continue
		if absf(float(row["bottom"]) - float(surface["top"])) > CourseLaw.EPS:
			continue
		if not _overlaps(row, surface, "x_min", "x_max"):
			continue
		if not _overlaps(row, surface, "z_min", "z_max"):
			continue
		supports.append(str(row["name"]))
	return supports


func _is_wall(row: Dictionary) -> bool:
	return str(row["role"]) == ROLE_WALL


func _walls(boxes: Array[Dictionary]) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	for row in boxes:
		if not _is_wall(row):
			continue
		var size: Vector3 = row["size"]
		walls.append({
			"name": row["name"],
			# The long horizontal axis: a ride runs along the wall, never up it.
			"length": maxf(size.x, size.z),
			"extent": size.y,
			# The face normal is the wall's own short horizontal axis, so its y component is the
			# basis column for that axis — level on an unrotated wall, which is what the ride gate
			# (|normal.y| ≤ 0.2) is measured against.
			"normal_y": _face_normal_y(row),
			# T8a part 3: the chain law's gap arithmetic needs each wall's course-axis extent.
			"z_min": row["z_min"],
			"z_max": row["z_max"],
		})
	return walls


func _ramps(boxes: Array[Dictionary]) -> Array[Dictionary]:
	var ramps: Array[Dictionary] = []
	for row in boxes:
		if str(row["role"]) != ROLE_RAMP:
			continue
		var size: Vector3 = row["size"]
		var up: Vector3 = (row["basis"] as Basis).y.normalized()
		ramps.append({
			"name": row["name"],
			"angle_deg": rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0))),
			# Along the sloped face, which is the box's own long horizontal axis in local space —
			# the rotation is what turns that length into a climb.
			"path_len": maxf(size.x, size.z),
			"normal_y": up.y,
		})
	return ramps


func _face_normal_y(row: Dictionary) -> float:
	var size: Vector3 = row["size"]
	var basis: Basis = row["basis"]
	return (basis.x.normalized().y if size.x < size.z else basis.z.normalized().y)


## Props block holes, so each collider carries its own z extent: a bed is one obstacle, not the
## bounding box of the whole cluster it happens to be authored under.
func _props(boxes: Array[Dictionary], floors: Array[Dictionary]) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	for row in boxes:
		if str(row["role"]) != ROLE_PROP:
			continue
		props.append({
			"name": row["name"],
			"lane": _lane_at(floors, float(row["x_min"]), float(row["x_max"])),
			"from": row["z_min"],
			"to": row["z_max"],
		})
	return props


## A prop belongs to the lane whose x footprint it overlaps; "" means every lane, which is the
## conservative reading and the right one for a prop standing clear of any declared floor.
func _lane_at(floors: Array[Dictionary], x_min: float, x_max: float) -> String:
	for floor_row in floors:
		for lane_row in floor_row["lanes"] as Array:
			var lane: Dictionary = lane_row
			if x_min < float(lane["x_max"]) and x_max > float(lane["x_min"]):
				return str(lane["id"])
	return ""


# --- spans -----------------------------------------------------------------------------------


## Floor tops in course order (−z): every traversable surface the graph may route across.
## `ride_wall` and `ceiling` are excluded by ROLE — a ride's budget must never compete with a
## bare-run reach on the same geometry — and everything else by the traversable test below.
func _floor_boxes(boxes: Array[Dictionary], surfaces: Array[Dictionary]) -> Array[Dictionary]:
	var by_name := {}
	for row in surfaces:
		by_name[str(row["name"])] = true

	var floor_boxes: Array[Dictionary] = []
	for row in boxes:
		if not by_name.has(str(row["name"])):
			continue
		var role := str(row["role"])
		if role == ROLE_WALL or role == ROLE_CEILING:
			continue
		if not _traversable(row):
			continue
		floor_boxes.append(row)
	floor_boxes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["z_max"]) > float(b["z_max"]))
	return floor_boxes


## T8a (issue #15): a box the course crosses ON — walkably tilted (the threshold reuses
## `RAMP_MIN_DEG` because it mirrors the game's own `FLOOR_LIMIT_DEG`, so the collector is
## exactly as strict as the game it audits) or a declared surf ramp, ridden at any angle. The
## aspect test is what stops a yaw-only wall from entering the span graph as a floor; an
## un-roled steep slope stays out, exactly as before.
func _traversable(row: Dictionary) -> bool:
	var size: Vector3 = row["size"]
	if size.y >= minf(size.x, size.z) * WALL_ASPECT:
		return false
	if str(row["role"]) == ROLE_RAMP:
		return true
	return float(row["normal_y"]) >= cos(deg_to_rad(CourseLaw.RAMP_MIN_DEG))


## Each floor surface offers exactly one successor: the nearest floor ahead along −z whose x
## extent overlaps it. One candidate per surface keeps `sample_count` loop-invariant even though
## erosion changes which candidates survive the filters.
func _spans(floor_boxes: Array[Dictionary], boxes: Array[Dictionary]) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	var floors_map := _manifest.get("floors", {}) as Dictionary
	var marker_zs := _marker_zs()

	for i in floor_boxes.size():
		var near: Dictionary = floor_boxes[i]
		var far := _successor(floor_boxes, i)
		if far.is_empty():
			continue

		# Measured face lip to face lip at the same x the ray pass probes: the AABB footprint
		# overstates a tilted box by its thickness term (sy·sinθ), and a yawed face's lip is
		# DIAGONAL, so the physical gap is a function of x. The successor CLASSIFICATION above
		# stays on the AABB — conservative — but the measurement must match the physics.
		var probe_x := _span_probe_x(near, far)
		var z_from := _face_edge_z(near, probe_x, true)
		var z_to := _face_edge_z(far, probe_x, false)
		var length := z_from - z_to
		if length < CourseLaw.MIN_SPAN:
			continue
		# Two tiles of one logical floor are a seam, not a span — the perforation laws own them,
		# and without this filter T8 would have to declare hundreds of degenerate spans.
		var near_floor := _floor_of(str(near["name"]), floors_map)
		if near_floor != "" and near_floor == _floor_of(str(far["name"]), floors_map):
			continue

		spans.append({
			"id": "%s>%s" % [str(near["name"]), str(far["name"])],
			"span": length,
			# Collector sign convention, consumed by `level_kick_span_ok`: POSITIVE = descending.
			# Sloped endpoints feed their AABB `top` here — a documented approximation (T8a design
			# part 1); the only law reading a collector drop is scoped to `bare_run`, which never
			# legitimately launches onto a ramp face.
			"drop": float(near["top"]) - float(far["top"]),
			"landing_width": (
				_face_edge_x(far, _landing_z(far, z_to), false)
				- _face_edge_x(far, _landing_z(far, z_to), true)
			),
			"z_from": z_from,
			"z_to": z_to,
			"void_punished": _void_between(near, far, boxes),
			"marker_break_before": _marker_between(marker_zs, near, far),
		})
	return spans


## The handoff rule (T8a design part 1). Walking candidates ahead in z_max-descending order,
## the first x-overlapping one that is not skipped decides:
## - abuts/overlaps in z AND the top faces meet at the shared edge → HANDOFF: the course
##   continues on foot, `near` offers no span at all;
## - abuts/overlaps WITHOUT height abutment → stacked geometry (a catch ledge below, a raised
##   lip above): neither an endpoint nor a terminator — skip and keep searching, or the real
##   span past the ledge is silently deleted (cold-review finding 1);
## - clear z gap → the span.
func _successor(floor_boxes: Array[Dictionary], index: int) -> Dictionary:
	var near: Dictionary = floor_boxes[index]
	for j in range(index + 1, floor_boxes.size()):
		var far: Dictionary = floor_boxes[j]
		if not _overlaps(near, far, "x_min", "x_max"):
			continue
		if float(far["z_max"]) >= float(near["z_min"]) - CourseLaw.MIN_SPAN:
			if _faces_meet(near, far):
				return {}
			continue
		return far
	return {}


## Face heights are linear in x at fixed z, so the interval over the x overlap is spanned by
## its two ends; the faces meet when the two intervals come within `METHOD_TOLERANCE` (its
## "two reads agree" semantics — the course is authored to abut exactly, the tolerance covers
## float drift and the face computation). The interval form, not a centre-line sample, is what
## lets a roll-tilted surf ramp hand off to the level floor its LOW edge feeds.
func _faces_meet(near: Dictionary, far: Dictionary) -> bool:
	var x_lo := maxf(float(near["x_min"]), float(far["x_min"]))
	var x_hi := minf(float(near["x_max"]), float(far["x_max"]))
	var near_a := INF
	var near_b := -INF
	var far_a := INF
	var far_b := -INF
	for x in [x_lo, x_hi]:
		# Heights read at near's FACE lip for this x, never at its AABB edge: a tilted box's
		# AABB overhangs the face by its thickness term, and the plane extrapolated there
		# overstates the lip height by tanθ times that overhang.
		var edge := _face_edge_z(near, float(x), true)
		var near_h := surface_y_at(near, edge, float(x))
		var far_h := surface_y_at(far, edge, float(x))
		near_a = minf(near_a, near_h)
		near_b = maxf(near_b, near_h)
		far_a = minf(far_a, far_h)
		far_b = maxf(far_b, far_h)
	return (
		near_a <= far_b + CourseLaw.METHOD_TOLERANCE
		and far_a <= near_b + CourseLaw.METHOD_TOLERANCE
	)


## The top face's height at a footprint point, from the box basis: `top` for a level box, the
## face plane elsewhere. Both coordinates are clamped into the footprint so an edge query never
## extrapolates past the face. The x term is a deliberate extension of the design's z-only
## signature: the shipped surf ramps carry compound rotations, and on a rolled face the height
## varies across x by metres — a z-only read misses the probe point by up to the half-width.
func surface_y_at(row: Dictionary, z: float, x: float) -> float:
	var up: Vector3 = (row["basis"] as Basis).y.normalized()
	if bool(row["level"]) or absf(up.y) < CourseLaw.EPS:
		return float(row["top"])
	var size: Vector3 = row["size"]
	var face := Vector3(
		(float(row["x_min"]) + float(row["x_max"])) * 0.5,
		(float(row["top"]) + float(row["bottom"])) * 0.5,
		(float(row["z_min"]) + float(row["z_max"])) * 0.5,
	) + up * (size.y * 0.5)
	var cx := clampf(x, float(row["x_min"]), float(row["x_max"]))
	var cz := clampf(z, float(row["z_min"]), float(row["z_max"]))
	return face.y - (up.x * (cx - face.x) + up.z * (cz - face.z)) / up.y


## The top face's plan-projected boundary z at a given x — the physical lip a span departs
## from (`toward_min` true, the −z side) or arrives at (false, the +z side). Identical to the
## AABB for an unrotated box; for a rotated one the face projects to a parallelogram narrower
## than the AABB (by the thickness term on a tilted box, diagonally on a yawed one).
func _face_edge_z(row: Dictionary, x: float, toward_min: bool) -> float:
	return _face_edge(row, x, true, toward_min)


## The transpose: the face's boundary x at a given z — the physical width of a landing line.
func _face_edge_x(row: Dictionary, z: float, toward_min: bool) -> float:
	return _face_edge(row, z, false, toward_min)


## The face's plan projection is the parallelogram `fc ± u ± v` (u, v its half-axes in plan).
## The boundary along one axis at a fixed value of the other is found by clipping that line
## against the (a, b) ∈ [−1, 1]² parameter square: the output is linear along the clipped
## segment, so its extremes sit at the segment's ends. A probe outside the face's own plan
## range clamps to the nearest boundary point.
func _face_edge(row: Dictionary, at: float, solve_x: bool, toward_min: bool) -> float:
	var basis: Basis = row["basis"]
	var up := basis.y.normalized()
	var lo_key := "z_min" if solve_x else "x_min"
	var hi_key := "z_max" if solve_x else "x_max"
	if absf(basis.x.x) > 1.0 - CourseLaw.EPS and up.y > 1.0 - CourseLaw.EPS:
		return float(row[lo_key]) if toward_min else float(row[hi_key])

	var size: Vector3 = row["size"]
	var fcx := (float(row["x_min"]) + float(row["x_max"])) * 0.5 + up.x * size.y * 0.5
	var fcz := (float(row["z_min"]) + float(row["z_max"])) * 0.5 + up.z * size.y * 0.5
	# S = the axis the probe fixes, O = the axis whose boundary is reported.
	var fc_s := fcx if solve_x else fcz
	var fc_o := fcz if solve_x else fcx
	var u_s := (basis.x.x if solve_x else basis.x.z) * size.x * 0.5
	var u_o := (basis.x.z if solve_x else basis.x.x) * size.x * 0.5
	var v_s := (basis.z.x if solve_x else basis.z.z) * size.z * 0.5
	var v_o := (basis.z.z if solve_x else basis.z.x) * size.z * 0.5
	# Solve the fixed axis with the parameter that actually moves it; the other sweeps.
	if absf(u_s) < absf(v_s):
		var swap_s := u_s
		var swap_o := u_o
		u_s = v_s
		u_o = v_o
		v_s = swap_s
		v_o = swap_o

	var d := at - fc_s
	var out_lo := INF
	var out_hi := -INF
	if absf(u_s) < CourseLaw.EPS:
		# The projection is degenerate along the fixed axis — a line; extremes at b = ±1.
		for b in [-1.0, 1.0]:
			var out := fc_o + float(b) * v_o
			out_lo = minf(out_lo, out)
			out_hi = maxf(out_hi, out)
	else:
		var b_lo := -1.0
		var b_hi := 1.0
		if absf(v_s) >= CourseLaw.EPS:
			b_lo = clampf(minf((d - u_s) / v_s, (d + u_s) / v_s), -1.0, 1.0)
			b_hi = clampf(maxf((d - u_s) / v_s, (d + u_s) / v_s), -1.0, 1.0)
		for b in [b_lo, b_hi]:
			var a := clampf((d - float(b) * v_s) / u_s, -1.0, 1.0)
			var out := fc_o + a * u_o + float(b) * v_o
			out_lo = minf(out_lo, out)
			out_hi = maxf(out_hi, out)
	return out_lo if toward_min else out_hi


## The x both passes measure a span along: the middle of the two FACES' plan x overlap. The
## AABB overlap is wrong on a rotated endpoint — its extra thickness width admits probe lines
## the face never reaches, where a ray has nothing to hit and the box read returns a corner
## clamp; the G2 pads' right edge against the diagonal G2Ramp1 face is the shipped case.
func _span_probe_x(near: Dictionary, far: Dictionary) -> float:
	var near_range := _face_x_range(near)
	var far_range := _face_x_range(far)
	return (maxf(near_range.x, far_range.x) + minf(near_range.y, far_range.y)) * 0.5


## The face's overall plan x extent — the AABB's for an unrotated box, the parallelogram's
## (`fcx ± (|ux| + |vx|)`) otherwise.
func _face_x_range(row: Dictionary) -> Vector2:
	var basis: Basis = row["basis"]
	var up := basis.y.normalized()
	if absf(basis.x.x) > 1.0 - CourseLaw.EPS and up.y > 1.0 - CourseLaw.EPS:
		return Vector2(float(row["x_min"]), float(row["x_max"]))
	var size: Vector3 = row["size"]
	var fcx := (float(row["x_min"]) + float(row["x_max"])) * 0.5 + up.x * size.y * 0.5
	var half := absf(basis.x.x) * size.x * 0.5 + absf(basis.z.x) * size.z * 0.5
	return Vector2(fcx - half, fcx + half)


## Where a landing width is measured: half a metre inside the arrival lip for a plain level
## box, the face's own plan centre-line for a rotated one — a lip-hugging line on a diagonal
## face runs straight off it. BOTH methods measure this same line, or their widths diverge by
## construction.
func _landing_z(far: Dictionary, lip: float) -> float:
	var basis: Basis = far["basis"]
	if absf(basis.x.x) > 1.0 - CourseLaw.EPS and bool(far["level"]):
		return lip - RAY_MARGIN
	var up := basis.y.normalized()
	return (
		(float(far["z_min"]) + float(far["z_max"])) * 0.5
		+ up.z * (far["size"] as Vector3).y * 0.5
	)


## A gap is void-punished when nothing catches a short landing: no box reaching into the OPEN
## interval between the two lips at or below lip height. A lower ledge makes the same gap a
## mistake rather than a reset, and only the reset kind counts toward ruling #7's chain.
##
## The two endpoint surfaces are excluded explicitly. Without that they satisfy their own opening —
## `near` starts at or before its own far edge and ends after `far`'s near edge — so every span in
## the course read as caught and `void_punished` was false 78 times out of 78. A law that never
## fires and a law that was never wired up are indistinguishable from the outside.
func _void_between(near: Dictionary, far: Dictionary, boxes: Array[Dictionary]) -> bool:
	var lip := minf(float(near["top"]), float(far["top"]))
	for row in boxes:
		if row["name"] == near["name"] or row["name"] == far["name"]:
			continue
		if float(row["top"]) > lip + CourseLaw.EPS:
			continue
		# Strictly inside the opening, at either end or across it.
		if float(row["z_min"]) >= float(near["z_min"]) - CourseLaw.EPS:
			continue
		if float(row["z_max"]) <= float(far["z_max"]) + CourseLaw.EPS:
			continue
		if not _overlaps(near, row, "x_min", "x_max"):
			continue
		return false
	return true


## Ruling #27: a checkpoint is relief. Markers stand ON floors, not in gaps, so the window
## runs from the near surface's BACK edge through the gap — a gap-only test (`z_min`) left
## every on-floor checkpoint invisible to ruling #7's chain (marker 16 on `G7Exit` is what
## isolates #34's triple).
func _marker_between(marker_zs: Array[float], near: Dictionary, far: Dictionary) -> bool:
	for z in marker_zs:
		if z <= float(near["z_max"]) + CourseLaw.EPS and z >= float(far["z_max"]) - CourseLaw.EPS:
			return true
	return false


# --- markers ---------------------------------------------------------------------------------


func _marker_zs() -> Array[float]:
	var zs: Array[float] = []
	for i in _course.marker_progresses.size():
		zs.append(_course.respawn_position(i).z)
	return zs


## Every respawn point must stand up at every loop, at every offset. A marker over a hole is a
## softlock, it passes every other gate, and the geometry under it is authored by later tasks
## than the one that placed it.
func _markers(floor_boxes: Array[Dictionary]) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for i in _course.marker_progresses.size():
		var at := _course.respawn_position(i)
		var hit := 0
		for dz in MARKER_OFFSETS:
			if _standable(floor_boxes, at.x, at.z + dz, at.y):
				hit += 1
		markers.append({
			"index": i,
			"z": at.z,
			"offsets_hit": hit,
			"offsets_total": MARKER_OFFSETS.size(),
		})
	return markers


func _standable(floor_boxes: Array[Dictionary], x: float, z: float, y: float) -> bool:
	for row in floor_boxes:
		if float(row["top"]) > y + CourseLaw.EPS:
			continue
		if x < float(row["x_min"]) or x > float(row["x_max"]):
			continue
		if z < float(row["z_min"]) or z > float(row["z_max"]):
			continue
		return true
	return false


# --- perforated floors and chasms -------------------------------------------------------------


## One row per declared logical floor, its lanes and the holes open in each at this loop. Hole
## edges come from exact interval arithmetic on the tile boxes, never from a sampling grid: loop 0
## must reproduce the shipped solid box to `EPS`, and a grid can only do that by luck of alignment.
func _floors(boxes: Array[Dictionary]) -> Array[Dictionary]:
	var by_name := {}
	for row in boxes:
		by_name[str(row["name"])] = row

	var floors: Array[Dictionary] = []
	for floor_id in (_manifest.get("floors", {}) as Dictionary):
		var lanes_decl: Dictionary = (_manifest["floors"] as Dictionary)[floor_id]
		var lanes: Array[Dictionary] = []
		var solid := 0.0
		var extent := 0.0
		var floor_min := INF
		var floor_max := -INF

		for lane_id in lanes_decl:
			var tiles: Array[Dictionary] = []
			for tile_name in lanes_decl[lane_id] as Array:
				if by_name.has(str(tile_name)):
					tiles.append(by_name[str(tile_name)])
			if tiles.is_empty():
				continue
			var lane := _lane(str(lane_id), tiles)
			lanes.append(lane)
			solid += float(lane["solid"])
			extent += float(lane["to"]) - float(lane["from"])
			floor_min = minf(floor_min, float(lane["from"]))
			floor_max = maxf(floor_max, float(lane["to"]))

		if lanes.is_empty():
			continue
		# Both measured live, and that is the point: the outer tiles pin the floor's outer edges,
		# so the lane EXTENT is erosion-invariant by design while the solid metres inside it shrink.
		# Comparing the two is therefore a real seam check at loop 0 rather than a value compared
		# against a cached copy of itself — which is what a "shipped span" captured on the first
		# survey would have been, in whatever loop order the caller happened to use.
		floors.append({
			"id": str(floor_id),
			"lanes": lanes,
			"from": floor_min,
			"to": floor_max,
			"solid_span": solid,
			"shipped_span": extent,
		})
	return floors


func _lane(lane_id: String, tiles: Array[Dictionary]) -> Dictionary:
	tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["z_max"]) > float(b["z_max"]))

	var holes: Array[Dictionary] = []
	var solid := 0.0
	var x_min := INF
	var x_max := -INF
	for i in tiles.size():
		var tile: Dictionary = tiles[i]
		solid += float(tile["z_max"]) - float(tile["z_min"])
		x_min = minf(x_min, float(tile["x_min"]))
		x_max = maxf(x_max, float(tile["x_max"]))
		if i + 1 >= tiles.size():
			continue
		var next: Dictionary = tiles[i + 1]
		var opening := float(tile["z_min"]) - float(next["z_max"])
		if opening > CourseLaw.EPS:
			holes.append({
				"from": float(tile["z_min"]),
				"to": float(next["z_max"]),
				"near_tile": str(tile["name"]),
				"far_tile": str(next["name"]),
			})

	var top := -INF
	for tile in tiles:
		top = maxf(top, float(tile["top"]))
	return {
		"id": lane_id,
		"holes": holes,
		"tiles": tiles.size(),
		"solid": solid,
		"x_min": x_min,
		"x_max": x_max,
		"top": top,
		"from": float((tiles[tiles.size() - 1] as Dictionary)["z_min"]),
		"to": float((tiles[0] as Dictionary)["z_max"]),
	}


## A chasm is a z range where EVERY lane of one floor is open at once — the floor parts edge to
## edge and the only way across is a jump. The per-loop growth is measured from the opening rather
## than read off the declaration, so a mis-authored seam cannot certify itself.
func _chasms(floors: Array[Dictionary], boxes: Array[Dictionary]) -> Array[Dictionary]:
	var chasms: Array[Dictionary] = []
	var loop := _course.loop_logic.loop_count

	for floor_row in floors:
		var lanes := floor_row["lanes"] as Array
		if lanes.is_empty():
			continue
		var aligned := _aligned_openings(lanes)
		for opening_row in aligned:
			var opening: Dictionary = opening_row
			var from := float(opening["from"])
			var to := float(opening["to"])
			var gap := from - to
			if gap < CourseLaw.MIN_SPAN:
				continue
			chasms.append({
				"id": str(opening["lips"]),
				"gap": gap,
				"per_loop": (gap / float(loop) if loop > 0 else 0.0),
				"from": from,
				"to": to,
				"runout": _runout(lanes, to, boxes),
				"full_width": true,
			})
	return chasms


## Openings shared by every lane, intersected pairwise: an opening one lane does not have is a
## staggered hole, and those answer to the telegraph law instead.
func _aligned_openings(lanes: Array) -> Array[Dictionary]:
	var shared: Array[Dictionary] = []
	var first: Dictionary = lanes[0]
	for hole_row in first["holes"] as Array:
		var hole: Dictionary = hole_row
		var from := float(hole["from"])
		var to := float(hole["to"])
		var in_all := true
		for i in range(1, lanes.size()):
			var lane: Dictionary = lanes[i]
			var overlap := _hole_overlap(lane, from, to)
			if overlap.is_empty():
				in_all = false
				break
			from = minf(from, float(overlap["from"]))
			to = maxf(to, float(overlap["to"]))
		if in_all:
			shared.append({"from": from, "to": to, "lips": _lips(lanes, from, to)})
	return shared


## Course order runs toward −z, so a hole's `from` is its near (greater) edge and `to` its far
## (lesser) one. Two openings overlap when each starts before the other ends.
func _hole_overlap(lane: Dictionary, from: float, to: float) -> Dictionary:
	for hole_row in lane["holes"] as Array:
		var hole: Dictionary = hole_row
		if float(hole["to"]) < from - CourseLaw.EPS and float(hole["from"]) > to + CourseLaw.EPS:
			return hole
	return {}


## Span ids read `<near>><far>`, so a chasm names the two tiles forming its lips. The reference is
## the lane crossing x = 0 — every marker in this course sits in the middle lane, so that is the
## line the id should describe.
func _lips(lanes: Array, from: float, to: float) -> String:
	var reference: Dictionary = lanes[0]
	for lane_row in lanes:
		var lane: Dictionary = lane_row
		if float(lane["x_min"]) <= 0.0 and float(lane["x_max"]) >= 0.0:
			reference = lane
			break
	var hole := _hole_overlap(reference, from, to)
	if hole.is_empty():
		return str(reference["id"])
	return "%s>%s" % [str(hole["near_tile"]), str(hole["far_tile"])]


## Full-width solid metres past the far lip. A chasm landing into a staggered hole is the issue
## #23 compound trap, so the runout stops at the first z where any lane is open again.
func _runout(lanes: Array, far_lip: float, boxes: Array[Dictionary]) -> float:
	var end := far_lip
	for lane_row in lanes:
		var lane: Dictionary = lane_row
		var lane_end := float(lane["from"])
		for hole_row in lane["holes"] as Array:
			var hole: Dictionary = hole_row
			if float(hole["from"]) < far_lip - CourseLaw.EPS:
				lane_end = maxf(lane_end, float(hole["from"]))
		end = maxf(end, lane_end)
	var solid := far_lip - end

	# The floor may simply end; whatever continues past it counts only while it is full width.
	for row in boxes:
		if not bool(row["level"]):
			continue
		if absf(float(row["z_max"]) - end) > CourseLaw.EPS:
			continue
		solid += float(row["z_max"]) - float(row["z_min"])
		break
	return solid


func _floor_of(surface_name: String, floors_map: Dictionary) -> String:
	for floor_id in floors_map:
		for lane_id in floors_map[floor_id] as Dictionary:
			if (floors_map[floor_id][lane_id] as Array).has(surface_name):
				return str(floor_id)
	return ""


func _declared_tile_count() -> int:
	var count := 0
	for floor_id in (_manifest.get("floors", {}) as Dictionary):
		for lane_id in (_manifest["floors"] as Dictionary)[floor_id] as Dictionary:
			count += ((_manifest["floors"] as Dictionary)[floor_id][lane_id] as Array).size()
	return count


# --- shell containment ------------------------------------------------------------------------


## The anti-skip cap: the longest unbroken lateral wall run per side, so no wall-jump chain buys a
## zone skip. Merged z intervals over every wall-like box on that side — no sampling grid, no
## height band, no floor requirement (issue #11).
##
## Three properties, and each one is why the method is this and not a probe. It is **exact**, so
## there is no window to drift and no step to alias against. It is **loop-invariant by
## construction**, because a run can only lengthen if a wall resizes and no wall is tagged
## erodable. And it is **conservative**: merging can only ever over-report a run, so it may raise a
## false `shell_segment` finding but can never hide a real one — the correct direction of error for
## a safety cap. 3b's two figures were both artifacts of a probe that had none of the three.
func _shell_runs(boxes: Array[Dictionary]) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for side in ["+x", "-x"]:
		runs.append({"side": side, "length": _longest_run(boxes, side)})
	return runs


func _longest_run(boxes: Array[Dictionary], side: String) -> float:
	var spans: Array[Vector2] = []
	for row in boxes:
		var size: Vector3 = row["size"]
		if size.y < minf(size.x, size.z) * WALL_ASPECT:
			continue
		var centre := (float(row["x_min"]) + float(row["x_max"])) * 0.5
		if (centre >= 0.0) != (side == "+x"):
			continue
		spans.append(Vector2(float(row["z_min"]), float(row["z_max"])))
	if spans.is_empty():
		return 0.0

	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var longest := 0.0
	var lo := spans[0].x
	var hi := spans[0].y
	for i in range(1, spans.size()):
		# Walls that touch are one run: a chain does not care that two boxes authored it.
		if spans[i].x <= hi + CourseLaw.EPS:
			hi = maxf(hi, spans[i].y)
			continue
		longest = maxf(longest, hi - lo)
		lo = spans[i].x
		hi = spans[i].y
	return maxf(longest, hi - lo)


# --- shared ----------------------------------------------------------------------------------


func _overlaps(a: Dictionary, b: Dictionary, min_key: String, max_key: String) -> bool:
	return (
		float(a[min_key]) < float(b[max_key]) - CourseLaw.EPS
		and float(a[max_key]) > float(b[min_key]) + CourseLaw.EPS
	)
