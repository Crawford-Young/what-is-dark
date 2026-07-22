class_name ErosionLogic
extends RefCounted
## Erosion v1 (Phase 2 spec §3): recovery fails per loop; top speed never does.
## Capped — the game never forces the ending (parent spec §3).

const ACCEL_DECAY_PER_LOOP := 0.12
const ACCEL_FLOOR := 0.52
const RETENTION_DECAY_PER_LOOP := 0.05
const RETENTION_FLOOR := 0.80


static func accel_multiplier(loop: int) -> float:
	return maxf(1.0 - ACCEL_DECAY_PER_LOOP * maxi(loop, 0), ACCEL_FLOOR)


static func landing_retention(loop: int) -> float:
	return maxf(1.0 - RETENTION_DECAY_PER_LOOP * maxi(loop, 0), RETENTION_FLOOR)
