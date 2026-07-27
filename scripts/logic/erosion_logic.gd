class_name ErosionLogic
extends RefCounted
## Erosion v3 (phase 3b, ruling #14): the player never erodes — movement
## constants are immutable across loops forever. Pressure is world-side
## instead: a per-loop scale ramping 0→1 as loops accumulate, consumed by
## world systems (void creep speedup, hand-picked platform shrink, fog ramp)
## rather than by scaling the player's own acceleration.

const PLATEAU_LOOP := 5
const FOG_DENSITY_MAX := 0.025  ## plateau exponential-fog density: ~71% fogged at 50 m,
## ~31% at 15 m — the far course dissolves into the dark, the next landing stays legible


static func world_scale(loop: int, plateau_loop: int = PLATEAU_LOOP) -> float:
	return clampf(float(loop) / float(plateau_loop), 0.0, 1.0)


## Size of one box axis at the given world scale. Erosion only ever removes:
## a min_size at or above base_size is treated as "no erosion authored".
static func eroded_size(base_size: float, min_size: float, scale: float) -> float:
	if min_size >= base_size:
		return base_size
	return lerpf(base_size, min_size, clampf(scale, 0.0, 1.0))


## Box centre after shrinking one axis while holding one edge fixed.
## anchor -1 pins the low edge, +1 the high edge, 0 shrinks about the centre.
static func anchored_origin(
	base_origin: float, base_size: float, new_size: float, anchor: float
) -> float:
	return base_origin + anchor * (base_size - new_size) * 0.5


static func fog_density(scale: float) -> float:
	return FOG_DENSITY_MAX * clampf(scale, 0.0, 1.0)
