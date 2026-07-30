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
