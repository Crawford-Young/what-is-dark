class_name LoopLogic
extends RefCounted
## Lap counting + the false light-door trigger (Phase 2 spec §4).
## The door is a progress threshold, not an Area3D.

const DOOR_PROGRESS := 895.0

var loop_count := 0


static func has_crossed_door(progress: float) -> bool:
	return progress >= DOOR_PROGRESS


func advance_loop() -> void:
	loop_count += 1
