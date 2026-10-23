class_name CourseSpec
extends RefCounted
## Per-course data: everything the gameplay wiring (`Course`) and the course-law audit need to
## know about one ridden course, so neither assumes the slice. The slice builds its spec from its
## own constants (`Slice.spec()`); Blender-exported zones build theirs from their sidecar.

## The course scene `just audit <course>` instantiates.
var scene_path := ""
## The span/surface declarations manifest the audit gates against.
var declarations_path := ""
## Respawn markers, metres along the course path, ascending; marker 0 is the loop respawn.
var markers: Array[float] = []
## Light-door threshold, metres along the path — crossing it ends the lap.
var door_progress := 0.0
## Fall plane: below this y the player is reset to the nearest passed marker.
var fall_y := 0.0
## Where the void starts each lap, metres along the path (behind marker 0).
var void_start := 0.0
## The audit's pinned `law:subject` finding set. Changing it is a ruling, never an append.
var baseline: Array[String] = []
## What went wrong building this spec from a file (a zone's sidecar parse). `validate()` reports
## these first, so a broken source fails every gate that validates the spec.
var load_errors: Array[String] = []


## Empty when the spec is usable. Every rule names the field it judges.
func validate() -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	for field in ["scene_path", "declarations_path"]:
		if not str(get(field)).begins_with("res://"):
			errors.append("%s must be a res:// path, got \"%s\"" % [field, get(field)])
	if markers.is_empty():
		errors.append("markers is empty — the loop respawn needs marker 0")
	else:
		for i in range(1, markers.size()):
			if markers[i] <= markers[i - 1]:
				errors.append(
					"markers must strictly ascend: [%d] %.2f after %.2f"
					% [i, markers[i], markers[i - 1]]
				)
		if door_progress <= markers[-1]:
			errors.append(
				"door_progress %.2f must lie past the last marker %.2f" % [door_progress, markers[-1]]
			)
		if void_start >= markers[0]:
			errors.append(
				"void_start %.2f must lie behind the first marker %.2f" % [void_start, markers[0]]
			)
	var seen := {}
	for key in baseline:
		if not key.contains(":"):
			errors.append("baseline key \"%s\" is not law:subject" % key)
		elif seen.has(key):
			errors.append("baseline key \"%s\" is a duplicate" % key)
		seen[key] = true
	return errors
