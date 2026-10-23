class_name CourseLaw
extends RefCounted
## The course's laws as pure arithmetic. Every threshold that CAN be derived from a
## shipped constant IS derived here, so a movement retune moves the laws with it.

const EPS := 0.001
const METHOD_TOLERANCE := 0.10  ## box-read vs ray-grid agreement: 2x the 0.05 m ray step
const MIN_SPAN := 0.05  ## below this two surfaces abut; not a span at all

## Flat-jump airtime and the reach it buys at RUN_SPEED. 2*v/g is the up-and-down time
## of a jump landing at its launch height; apex is v^2/2g.
const AIRTIME := 2.0 * SourceMove.JUMP_SPEED / SourceMove.GRAVITY
const FLAT_REACH := SourceMove.RUN_SPEED * AIRTIME
const JUMP_APEX := SourceMove.JUMP_SPEED * SourceMove.JUMP_SPEED / (2.0 * SourceMove.GRAVITY)

const CHASM_GROWTH_MAX := 1.5  ## m per loop
const CHASM_PLATEAU_MAX := 7.5  ## m at plateau — hard fairness ceiling under FLAT_REACH
const CHASM_RUNOUT_MIN := 3.0  ## m of FULL-WIDTH solid floor past the far lip (issue #23)
const STAGGERED_GROWTH := 1.0  ## m per loop — hole length in metres = loop number
const MAX_UNBROKEN_SHELL := 25.0  ## m; the wall-jump chain must never buy a zone skip
const MAX_PRECISION_CHAIN := 3  ## ruling #7: consecutive void-punished precision jumps


static func span_ok_bare_run(span: float) -> bool:
	return span <= FLAT_REACH + EPS


## A barrier is a gap built NOT to be crossed on foot (#23 kitchen ruling), so it holds only
## while it stays wider than the flat reach; at or inside it, it is a route.
static func barrier_holds(span: float) -> bool:
	return span > FLAT_REACH + EPS


static func required_entry_speed(span: float) -> float:
	return span / AIRTIME


static func span_ok_carried(span: float, entry_speed: float) -> bool:
	return entry_speed * AIRTIME + EPS >= span


## Ground accel tops out at RUN_SPEED, so a declared entry speed above it is a premise
## about an upstream SOURCE (kick, surf exit, kicker) — never about running faster.
static func ground_entry_speed_ok(entry_speed: float) -> bool:
	return entry_speed <= SourceMove.RUN_SPEED + EPS


static func chasm_gap(per_loop: float, loop: int) -> float:
	return per_loop * float(loop)


static func chasm_growth_ok(per_loop: float) -> bool:
	return per_loop <= CHASM_GROWTH_MAX + EPS


static func chasm_plateau_ok(per_loop: float, plateau_loop: int) -> bool:
	var gap := chasm_gap(per_loop, plateau_loop)
	return gap <= CHASM_PLATEAU_MAX + EPS and gap < FLAT_REACH


static func chasm_runout_ok(solid_past_lip: float) -> bool:
	return solid_past_lip >= CHASM_RUNOUT_MIN - EPS


static func precision_chain_ok(consecutive: int) -> bool:
	return consecutive <= MAX_PRECISION_CHAIN


## Issues #34 / #28 are forward-looking rules: the stretch is legal, and has no room for
## another gap. A current-state harness cannot emit "do not add one" — it emits "this
## stretch is at the cap", which is the same information a later wave needs.
static func precision_chain_at_cap(consecutive: int) -> bool:
	return consecutive == MAX_PRECISION_CHAIN


static func staggered_hole_length_ok(length: float, loop: int) -> bool:
	return absf(length - STAGGERED_GROWTH * float(loop)) <= 0.05


static func shell_segment_ok(length: float) -> bool:
	return length <= MAX_UNBROKEN_SHELL + EPS


const RAMP_MIN_DEG := 38.0  ## mirrors Player.FLOOR_LIMIT_DEG — shallower reads as floor.
## Asserted equal in the test rather than referenced, so this module keeps no dependency
## on a node script.
const RAMP_TARGET_MIN_DEG := 45.0
const RAMP_TARGET_MAX_DEG := 55.0
const RAMP_PATH_MIN := 12.0  ## m of ramp path — T3 surf-table design floor
const SURF_ETA := 0.95  ## design efficiency; clean ride 0.98-1.0, sloppy floor 0.92
const SURF_TRANSFER_FACTOR_MAX := 0.9  ## T3: 0.85 on a chain's first run, 0.9 on the second
const RIDE_EXTENT_MARGIN := 1.0
## Issue #16's level press-kick reach, derived: airtime 2*8.63/35.2 = 0.4903 s at RUN_SPEED.
const LEVEL_KICK_REACH := (
	SourceMove.RUN_SPEED * 2.0 * WallrunLogic.WALL_JUMP_VY / SourceMove.GRAVITY
)


static func sink_over_ride(length: float, along_speed: float) -> float:
	return absf(WallrunLogic.SINK_CAP) * length / along_speed


static func required_wall_extent(entry_height: float, length: float, along_speed: float) -> float:
	return entry_height + sink_over_ride(length, along_speed) + RIDE_EXTENT_MARGIN


static func ride_extent_ok(
	extent: float, entry_height: float, length: float, along_speed: float
) -> bool:
	return extent + EPS >= required_wall_extent(entry_height, length, along_speed)


static func ride_entry_speed_ok(along_speed: float) -> bool:
	return along_speed > WallrunLogic.MIN_FORWARD_SPEED


## T3 law: exit = eta * sqrt(v_in^2 + 2*g*drop). The table's 70.4 is 2*GRAVITY.
static func surf_exit_speed(entry_speed: float, drop: float, eta: float = SURF_ETA) -> float:
	return eta * sqrt(entry_speed * entry_speed + 2.0 * SourceMove.GRAVITY * drop)


## Transfer gaps take the HORIZONTAL component, never total speed (spec 5.1). A kicker
## restores the flat arc (issue #12), so there the two are equal; any other exit needs a
## measured value, and the sweep WARNs when one is absent rather than guessing.
static func exit_horizontal_speed(
	exit_total: float, kicker_terminated: bool, declared_h: float
) -> float:
	return exit_total if kicker_terminated else declared_h


static func transfer_span_ok(
	span: float, exit_h_speed: float, factor: float = SURF_TRANSFER_FACTOR_MAX
) -> bool:
	return exit_h_speed * AIRTIME * factor + EPS >= span


static func transfer_factor_ok(factor: float) -> bool:
	return factor <= SURF_TRANSFER_FACTOR_MAX + EPS


static func ramp_angle_ok(angle_deg: float) -> bool:
	return angle_deg > RAMP_MIN_DEG + EPS


static func ramp_in_target_band(angle_deg: float) -> bool:
	return angle_deg >= RAMP_TARGET_MIN_DEG - EPS and angle_deg <= RAMP_TARGET_MAX_DEG + EPS


static func ramp_path_ok(path_length: float) -> bool:
	return path_length >= RAMP_PATH_MIN - EPS


static func ramp_never_rideable(normal_y: float) -> bool:
	return absf(normal_y) > WallrunLogic.RIDE_MAX_NORMAL_Y


## drop follows the collector convention (`course_audit.gd` `_spans`): drop = near.top −
## far.top, POSITIVE when the far lip sits BELOW the kick. Only the level case has a
## measured law; a descending span is legal and audited by its declared drop. An
## ascending span (negative drop) is harder than level and stays under the law.
static func level_kick_span_ok(span: float, drop: float) -> bool:
	if drop > EPS:
		return true
	return span <= LEVEL_KICK_REACH + EPS


## Issue #23's standing remediation: gap and width are audited JOINTLY, because the
## compound case is what kills. Neither half fails alone — an 8.3 m gap is legal (under
## FLAT_REACH) and a 1.6 m strip is legal (over the capsule floor); landing one on the
## other at plateau is the case that needs a human ruling. Hence WARN, not FAIL.
const COMPOUND_GAP_FRACTION := 0.9  ## of FLAT_REACH = 7.48 m
const COMPOUND_WIDTH_MAX := 5.0  ## m of landing width
const LANDING_WIDTH_CAPSULE_FACTOR := 2.0


## The hard floor: a landing narrower than two capsule diameters is not a landing.
## capsule_diameter is READ from the player scene by the collector, never hardcoded.
static func landing_width_ok(width: float, capsule_diameter: float) -> bool:
	return width + EPS >= LANDING_WIDTH_CAPSULE_FACTOR * capsule_diameter


static func compound_landing(span: float, landing_width: float) -> bool:
	return (
		span >= COMPOUND_GAP_FRACTION * FLAT_REACH - EPS
		and landing_width <= COMPOUND_WIDTH_MAX + EPS
	)
