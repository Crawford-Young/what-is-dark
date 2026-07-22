class_name CourseLogic
extends RefCounted
## Marker bookkeeping along the course. Progress = meters along the Path3D curve.

var marker_progresses: Array[float] = []


func _init(markers: Array[float] = [] as Array[float]) -> void:
	marker_progresses = markers


func nearest_passed_marker(player_progress: float) -> int:
	var idx := -1
	for i in marker_progresses.size():
		if marker_progresses[i] <= player_progress:
			idx = i
	return idx


func setback_index(player_progress: float, setback: int) -> int:
	return maxi(nearest_passed_marker(player_progress) - setback, 0)
