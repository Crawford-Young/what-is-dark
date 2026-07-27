class_name VoidLogic
extends RefCounted
## The dark's pursuit as one float along the course. Spec §2: creep speed is
## posture-sensitive — fastest at your back, slow when watched, never zero.
## Ruling #14 (erosion v3): the world applies pressure, not the player —
## creep speed scales up with ErosionLogic.world_scale(loop), capped at
## CREEP_MULT_MAX at the plateau loop. Loop 0 (or no loop arg) reproduces
## the base CREEP_SPEEDS exactly.

const CREEP_SPEEDS := {
	Posture.AWAY: 6.0,
	Posture.GLANCING: 2.2,
	Posture.FACING: 0.7,
}
const CREEP_MULT_MAX := 1.6
const RESET_GAP := 18.0

var progress: float = 0.0


func _init(start_progress: float = 0.0) -> void:
	progress = start_progress


static func creep_speed(posture: int, loop: int) -> float:
	return CREEP_SPEEDS[posture] * (1.0 + ErosionLogic.world_scale(loop) * (CREEP_MULT_MAX - 1.0))


func advance(posture: int, delta: float, loop: int = 0) -> void:
	progress += creep_speed(posture, loop) * delta


func has_caught(player_progress: float) -> bool:
	return progress >= player_progress


func reset_behind(marker_progress: float) -> void:
	progress = marker_progress - RESET_GAP


func limit_behind(marker_progress: float, gap: float) -> void:
	progress = minf(progress, marker_progress - gap)
