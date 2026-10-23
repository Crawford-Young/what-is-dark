extends GutTest
## Per-course data. Every ridden course (the slice now, Blender zones from #23 on) states its
## scene, its declarations, its markers, its door, its fall plane, its void start and its audit
## baseline in ONE spec, so the audit and the gameplay wiring read a course instead of assuming the
## slice. `validate()` is the guard: a spec that would softlock or silently mis-gate is rejected
## before a course is ridden or audited.


func _valid() -> CourseSpec:
	var spec := CourseSpec.new()
	spec.scene_path = "res://scenes/a.tscn"
	spec.declarations_path = "res://data/a.json"
	spec.markers = [0.0, 10.0, 20.0] as Array[float]
	spec.door_progress = 30.0
	spec.fall_y = -6.0
	spec.void_start = -20.0
	spec.baseline = ["law_a:A>B", "law_b:C"] as Array[String]
	return spec


func _joined(errors: Array[String]) -> String:
	return "\n".join(errors)


func test_a_well_formed_spec_validates_clean() -> void:
	assert_eq(_valid().validate(), [] as Array[String])


func test_an_empty_baseline_is_legal() -> void:
	# A fresh course with no ruled findings yet gates on the empty set — that is a state, not a bug.
	var spec := _valid()
	spec.baseline = [] as Array[String]
	assert_eq(spec.validate(), [] as Array[String])


func test_paths_must_be_resource_paths() -> void:
	var spec := _valid()
	spec.scene_path = "scenes/a.tscn"
	spec.declarations_path = ""
	var errors := spec.validate()
	assert_eq(errors.size(), 2, _joined(errors))
	assert_string_contains(_joined(errors), "scene_path")
	assert_string_contains(_joined(errors), "declarations_path")


## The loop respawn lands on marker 0, so a course without one cannot complete a lap.
func test_a_course_needs_at_least_one_marker() -> void:
	var spec := _valid()
	spec.markers = [] as Array[float]
	assert_string_contains(_joined(spec.validate()), "marker")


## `CourseLogic.nearest_passed_marker` walks the list in order; an unsorted list respawns the
## player at the wrong marker without any error.
func test_markers_must_strictly_ascend() -> void:
	var spec := _valid()
	spec.markers = [0.0, 20.0, 10.0] as Array[float]
	assert_string_contains(_joined(spec.validate()), "ascend")
	spec.markers = [0.0, 10.0, 10.0] as Array[float]
	assert_string_contains(_joined(spec.validate()), "ascend")


## A marker at or past the door can never be reached inside a lap — the door ends it first.
func test_the_door_must_lie_past_the_last_marker() -> void:
	var spec := _valid()
	spec.door_progress = 20.0
	assert_string_contains(_joined(spec.validate()), "door_progress")


## The void starts behind the player. A void that starts at or ahead of marker 0 catches the
## player on the first frame of every lap.
func test_the_void_must_start_behind_the_first_marker() -> void:
	var spec := _valid()
	spec.void_start = 0.0
	assert_string_contains(_joined(spec.validate()), "void_start")


## The audit gate compares deduped `law:subject` keys, so a malformed key can never match and a
## duplicate one hides a ruling count.
func test_baseline_keys_are_unique_law_subject_pairs() -> void:
	var spec := _valid()
	spec.baseline = ["no_colon", "law_a:A>B", "law_a:A>B"] as Array[String]
	var errors := spec.validate()
	assert_eq(errors.size(), 2, _joined(errors))
	assert_string_contains(_joined(errors), "no_colon")
	assert_string_contains(_joined(errors), "duplicate")


# --- the slice's own spec ----------------------------------------------------------------------


func test_the_slice_spec_validates_clean() -> void:
	assert_eq(Slice.spec().validate(), [] as Array[String])


func test_the_slice_spec_carries_the_slice_constants() -> void:
	var spec := Slice.spec()
	assert_eq(spec.scene_path, "res://scenes/slice.tscn")
	assert_eq(spec.declarations_path, "res://data/course_declarations.json")
	assert_eq(spec.markers, Slice.MARKER_PROGRESSES)
	assert_eq(spec.door_progress, 1795.0)
	assert_eq(spec.fall_y, -6.0)
	assert_eq(spec.void_start, -20.0)


## 46 ruled keys at T9 (repo CLAUDE.md, course-law harness). Changing this count is a ruling.
func test_the_slice_baseline_is_the_46_ruled_keys() -> void:
	assert_eq(Slice.spec().baseline.size(), 46)


func test_the_slice_spec_points_at_files_that_exist() -> void:
	var spec := Slice.spec()
	assert_true(ResourceLoader.exists(spec.scene_path), spec.scene_path)
	assert_true(FileAccess.file_exists(spec.declarations_path), spec.declarations_path)
