class_name ErosionLogic
extends RefCounted
## Erosion v2 (Phase 3a spec §4): recovery fails per loop — acceleration decays
## at BOTH ground and air call sites (player.gd scales GROUND_ACCEL and AIR_ACCEL).
## Speed already carried never bleeds; top speed never erodes. Capped — the game
## never forces the ending (parent spec §3).

const ACCEL_DECAY_PER_LOOP := 0.12
const ACCEL_FLOOR := 0.52


static func accel_multiplier(loop: int) -> float:
	return maxf(1.0 - ACCEL_DECAY_PER_LOOP * maxi(loop, 0), ACCEL_FLOOR)
