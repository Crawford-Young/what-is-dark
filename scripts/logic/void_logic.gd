class_name VoidLogic
extends RefCounted
## The dark's pursuit as one float along the course. Spec §2: creep speed is
## posture-sensitive — fastest at your back, slow when watched, never zero.

const CREEP_SPEEDS := {
	Posture.AWAY: 4.0,
	Posture.GLANCING: 1.5,
	Posture.FACING: 0.5,
}
const RESET_GAP := 12.0

var progress: float = 0.0


func _init(start_progress: float = 0.0) -> void:
	progress = start_progress


func advance(posture: int, delta: float) -> void:
	progress += CREEP_SPEEDS[posture] * delta


func has_caught(player_progress: float) -> bool:
	return progress >= player_progress


func reset_behind(marker_progress: float) -> void:
	progress = maxf(marker_progress - RESET_GAP, 0.0)
