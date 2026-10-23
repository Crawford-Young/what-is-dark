class_name LoopLogic
extends RefCounted
## Lap counting + the false light-door trigger (Phase 2 spec §4).
## The door is a progress threshold, not an Area3D; each course states its own
## (`CourseSpec.door_progress`).

var loop_count := 0


static func has_crossed_door(progress: float, door_progress: float) -> bool:
	return progress >= door_progress


func advance_loop() -> void:
	loop_count += 1
