class_name ErosionLogic
extends RefCounted
## Erosion v3 (phase 3b, ruling #14): the player never erodes — movement
## constants are immutable across loops forever. Pressure is world-side
## instead: a per-loop scale ramping 0→1 as loops accumulate, consumed by
## world systems (void creep speedup here; platform/fog application in a
## later task) rather than by scaling the player's own acceleration.

const PLATEAU_LOOP := 5


static func world_scale(loop: int, plateau_loop: int = PLATEAU_LOOP) -> float:
	return clampf(float(loop) / float(plateau_loop), 0.0, 1.0)
