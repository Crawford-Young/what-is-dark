extends GutTest
## Sidecar v1 (`data/course/0N-<place>.json`, written by the Blender exporter) + its hand-authored
## declarations file -> box specs and course-spec values. Every defect comes back in `errors`;
## nothing is defaulted or silently skipped, because a dropped box is a hole in the course that no
## later gate can see.


func _box(box_name: String, role: String = "floor") -> Dictionary:
	return {
		"name": box_name, "object": box_name.get_slice("_", 0), "role": role,
		"center": [0, -0.2, -4], "size": [4, 0.4, 8], "solid": true,
	}


func _sidecar() -> Dictionary:
	var eroding := _box("Slab_1")
	eroding["center"] = [3, -0.2, -4]
	eroding["size"] = [2.5, 0.4, 8]
	eroding["erode"] = {"axis": 0, "min": 0.25, "anchor": -1}
	return {
		"version": 1, "place": "09-test", "frame": "godot",
		"boxes": [_box("Slab_0", "marker_floor"), eroding, _box("Wall_0", "ride_wall")],
		"path": [[0, 0, 0], [0, 0, -10], [6, 0, -10]],
		"spawn": [0, 1, 0],
		"markers": [0, 4.5],
		"door_progress": 15.0,
		"fall_y": -6,
	}


func _declarations() -> Dictionary:
	return {"spans": {"Slab_0>Slab_1": {"decl": "bare_run"}}}


func _joined(spec: ZoneSpec) -> String:
	return "\n".join(spec.errors)


func test_a_valid_sidecar_parses_clean() -> void:
	var spec := ZoneSpec.parse(_sidecar(), _declarations())
	assert_eq(spec.errors, [] as Array[String])
	assert_eq(spec.place, "09-test")
	assert_eq(spec.boxes.size(), 3)
	assert_true(spec.has_line)
	assert_eq(spec.markers, [0.0, 4.5] as Array[float])
	assert_eq(spec.door_progress, 15.0)
	assert_eq(spec.fall_y, -6.0)
	assert_eq(spec.spawn, Vector3(0, 1, 0))
	var line: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(6, 0, -10)]
	assert_eq(spec.path, line)


func test_a_box_carries_typed_geometry_and_its_erosion() -> void:
	var spec := ZoneSpec.parse(_sidecar(), _declarations())
	var eroding: Dictionary = spec.boxes[1]
	assert_eq(eroding["name"], "Slab_1")
	assert_eq(eroding["object"], "Slab")
	assert_eq(eroding["role"], "floor")
	assert_eq(eroding["center"], Vector3(3, -0.2, -4))
	assert_eq(eroding["size"], Vector3(2.5, 0.4, 8))
	assert_eq(eroding["solid"], true)
	assert_eq(eroding["erode"], {"axis": 0, "min": 0.25, "anchor": -1.0})
	assert_eq((spec.boxes[0] as Dictionary)["erode"], {}, "no erode key = a box that never erodes")


func test_an_unknown_role_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][2] as Dictionary)["role"] = "trampoline"
	var spec := ZoneSpec.parse(sidecar, _declarations())
	assert_string_contains(_joined(spec), "Wall_0")
	assert_string_contains(_joined(spec), "trampoline")


## The erodable-platform contract: `erode_axis` is 0 (x) or 2 (z). y is never an erosion axis.
func test_a_bad_erode_axis_is_an_error() -> void:
	for axis in [1, 3, "x"]:
		var sidecar := _sidecar()
		(sidecar["boxes"][1]["erode"] as Dictionary)["axis"] = axis
		var spec := ZoneSpec.parse(sidecar, _declarations())
		assert_string_contains(_joined(spec), "axis", "axis %s" % str(axis))


func test_an_anchor_off_the_three_pins_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][1]["erode"] as Dictionary)["anchor"] = 0.5
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "anchor")


func test_a_plateau_size_outside_the_box_is_an_error() -> void:
	for min_size in [0.0, 2.6]:
		var sidecar := _sidecar()
		(sidecar["boxes"][1]["erode"] as Dictionary)["min"] = min_size
		var spec := ZoneSpec.parse(sidecar, _declarations())
		assert_string_contains(_joined(spec), "min", "min %s" % str(min_size))


## Issue #12's standing law: only a plain floor erodes.
func test_an_eroding_marker_floor_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][1] as Dictionary)["role"] = "marker_floor"
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "marker_floor")


func test_a_duplicate_box_name_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"] as Array).append(_box("Slab_0"))
	var spec := ZoneSpec.parse(sidecar, _declarations())
	assert_string_contains(_joined(spec), "duplicate")
	assert_string_contains(_joined(spec), "Slab_0")


## The box name becomes the body's node name, and the audit looks roles up by node name. Godot
## rewrites characters a node name cannot hold (Blender's "Cube.001"), so such a box would lose
## its role without a word.
func test_a_box_name_godot_would_rewrite_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][2] as Dictionary)["name"] = "Wall.001"
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "Wall.001")


func test_a_malformed_vector_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][0] as Dictionary)["size"] = [4, 0.4]
	(sidecar["boxes"][2] as Dictionary)["center"] = "origin"
	var spec := ZoneSpec.parse(sidecar, _declarations())
	assert_string_contains(_joined(spec), "Slab_0")
	assert_string_contains(_joined(spec), "Wall_0")


func test_a_non_positive_size_is_an_error() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][0] as Dictionary)["size"] = [4, 0, 8]
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "size")


func test_a_missing_box_key_is_an_error_not_a_default() -> void:
	for key in ["name", "object", "role", "center", "size", "solid"]:
		var sidecar := _sidecar()
		(sidecar["boxes"][0] as Dictionary).erase(key)
		var spec := ZoneSpec.parse(sidecar, _declarations())
		assert_string_contains(_joined(spec), key, "missing %s" % key)


func test_an_invalid_box_is_dropped_and_reported() -> void:
	var sidecar := _sidecar()
	(sidecar["boxes"][2] as Dictionary)["role"] = "trampoline"
	var spec := ZoneSpec.parse(sidecar, _declarations())
	assert_eq(spec.boxes.size(), 2)
	assert_eq(spec.errors.size(), 1, _joined(spec))


func test_the_header_is_checked() -> void:
	var sidecar := _sidecar()
	sidecar["version"] = 2
	sidecar["frame"] = "blender"
	var spec := ZoneSpec.parse(sidecar, _declarations())
	assert_string_contains(_joined(spec), "version")
	assert_string_contains(_joined(spec), "frame")


func test_a_non_dictionary_sidecar_is_an_error() -> void:
	assert_string_contains(_joined(ZoneSpec.parse(["not", "a", "sidecar"], {})), "sidecar")


func test_missing_top_level_keys_are_errors_not_defaults() -> void:
	for key in ["boxes", "spawn", "fall_y", "path", "markers", "place"]:
		var sidecar := _sidecar()
		sidecar.erase(key)
		var spec := ZoneSpec.parse(sidecar, _declarations())
		assert_string_contains(_joined(spec), key, "missing %s" % key)


# --- the line ---------------------------------------------------------------------------------


## The school's sidecar today: it states "no line" with an empty path and no markers, and carries
## no door. That is a legal place (not yet ridable) — but only because the sidecar SAYS so.
func test_a_place_with_no_line_parses_when_it_says_so() -> void:
	var sidecar := _sidecar()
	sidecar["path"] = []
	sidecar["markers"] = []
	sidecar.erase("door_progress")
	var spec := ZoneSpec.parse(sidecar, {})
	assert_eq(spec.errors, [] as Array[String])
	assert_false(spec.has_line)


func test_a_lined_place_without_a_door_is_an_error() -> void:
	var sidecar := _sidecar()
	sidecar.erase("door_progress")
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "door_progress")


func test_a_door_on_a_place_with_no_line_is_an_error() -> void:
	var sidecar := _sidecar()
	sidecar["path"] = []
	sidecar["markers"] = []
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, {})), "door_progress")


func test_half_a_line_is_an_error() -> void:
	var sidecar := _sidecar()
	sidecar["markers"] = []
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "markers")
	sidecar = _sidecar()
	sidecar["path"] = []
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "path")


func test_a_one_point_path_is_an_error() -> void:
	var sidecar := _sidecar()
	sidecar["path"] = [[0, 0, 0]]
	assert_string_contains(_joined(ZoneSpec.parse(sidecar, _declarations())), "path")


# --- declarations -----------------------------------------------------------------------------


## Roles come only from the sidecar: the Blender builder tags each box, so a second role in the
## hand-authored file is a second source of truth that can silently disagree with the first.
func test_a_role_declared_in_both_files_is_an_error() -> void:
	var declarations := _declarations()
	declarations["surfaces"] = {"Slab_1": {"role": "floor"}}
	var spec := ZoneSpec.parse(_sidecar(), declarations)
	assert_string_contains(_joined(spec), "Slab_1")
	assert_string_contains(_joined(spec), "role")


func test_a_declaration_naming_an_unknown_box_is_an_error() -> void:
	var declarations := _declarations()
	declarations["spans"]["Slab_0>Ghost_0"] = {"decl": "bare_run"}
	declarations["surfaces"] = {"Phantom_0": {"width_shrink": true}}
	declarations["floors"] = {"F": {"L": ["Slab_1", "Missing_0"]}}
	var spec := ZoneSpec.parse(_sidecar(), declarations)
	for unknown in ["Ghost_0", "Phantom_0", "Missing_0"]:
		assert_string_contains(_joined(spec), unknown)


## Hand-authored values are type-checked before any cast: a malformed entry is a listed error,
## never a script error that leaves `errors` empty (GUT fails a case on an engine error).
func test_an_erode_record_missing_a_field_is_listed_not_raised() -> void:
	for case in [
		[{"axis": 0, "anchor": -1}, "min"],
		[{"axis": 0, "min": 0.25}, "anchor"],
		[{"axis": 0, "min": "x", "anchor": -1}, "min"],
	]:
		var sidecar := _sidecar()
		(sidecar["boxes"][1] as Dictionary)["erode"] = case[0]
		var spec := ZoneSpec.parse(sidecar, {})
		assert_string_contains(_joined(spec), str(case[1]), str(case[0]))
		assert_eq(spec.boxes.size(), 2, "the malformed box is dropped: %s" % str(case[0]))


func test_a_non_dictionary_surface_entry_is_listed() -> void:
	var declarations := _declarations()
	declarations["surfaces"] = {"Slab_1": 5, "Wall_0": {"role": "ride_wall"}}
	var spec := ZoneSpec.parse(_sidecar(), declarations)
	assert_string_contains(_joined(spec), "surface \"Slab_1\"")
	assert_string_contains(_joined(spec), "Wall_0 declares a role", "the other entries still check")
	assert_false((spec.manifest()["surfaces"]["Slab_1"] as Dictionary).has("5"))


func test_malformed_floor_and_lane_entries_are_listed() -> void:
	var declarations := _declarations()
	declarations["floors"] = {"F": 3, "G": {"L": 4}}
	var spec := ZoneSpec.parse(_sidecar(), declarations)
	assert_string_contains(_joined(spec), "floor \"F\"")
	assert_string_contains(_joined(spec), "lane \"L\"")
	assert_eq(spec.manifest()["floors"], {})


func test_malformed_span_and_landing_band_entries_are_listed() -> void:
	var declarations := _declarations()
	declarations["spans"]["Slab_1>Wall_0"] = "bare_run"
	declarations["landing_bands"] = [{"id": "B"}, 7]
	var spec := ZoneSpec.parse(_sidecar(), declarations)
	assert_string_contains(_joined(spec), "span \"Slab_1>Wall_0\"")
	assert_string_contains(_joined(spec), "landing band 1")
	assert_eq((spec.manifest()["spans"] as Dictionary).keys(), ["Slab_0>Slab_1"])
	assert_eq(spec.manifest()["landing_bands"], [{"id": "B"}])


func test_an_unknown_declarations_key_is_an_error() -> void:
	var declarations := _declarations()
	declarations["roles"] = {}
	assert_string_contains(_joined(ZoneSpec.parse(_sidecar(), declarations)), "roles")


func test_a_non_dictionary_declarations_file_is_an_error() -> void:
	assert_string_contains(_joined(ZoneSpec.parse(_sidecar(), [1, 2])), "declarations")


## The audit's manifest: spans/floors/landing bands from the declarations file, every box's role
## from the sidecar, plus any non-role surface keys the declarations add.
func test_the_manifest_merges_sidecar_roles_into_the_declarations() -> void:
	var declarations := _declarations()
	declarations["surfaces"] = {"Slab_1": {"width_shrink": true}}
	var manifest := ZoneSpec.parse(_sidecar(), declarations).manifest()
	assert_eq(manifest["spans"], {"Slab_0>Slab_1": {"decl": "bare_run"}})
	assert_eq(manifest["surfaces"], {
		"Slab_0": {"role": "marker_floor"},
		"Slab_1": {"role": "floor", "width_shrink": true},
		"Wall_0": {"role": "ride_wall"},
	})
	assert_eq(manifest["floors"], {})
	assert_eq(manifest["landing_bands"], [])


# --- products ---------------------------------------------------------------------------------


func test_eroding_objects_are_the_objects_owning_an_eroding_box() -> void:
	var sidecar := _sidecar()
	var second := _box("Slab_2")
	second["erode"] = {"axis": 2, "min": 4.0, "anchor": 1}
	(sidecar["boxes"] as Array).append(second)
	assert_eq(ZoneSpec.parse(sidecar, {}).eroding_objects(), ["Slab"] as Array[String])


func test_the_course_spec_carries_the_line_and_the_parse_errors() -> void:
	var course := ZoneSpec.parse(_sidecar(), _declarations()).course_spec()
	assert_eq(course.markers, [0.0, 4.5] as Array[float])
	assert_eq(course.door_progress, 15.0)
	assert_eq(course.fall_y, -6.0)
	assert_eq(course.load_errors, [] as Array[String])

	var sidecar := _sidecar()
	sidecar["version"] = 2
	var broken := ZoneSpec.parse(sidecar, _declarations()).course_spec()
	assert_eq(broken.load_errors.size(), 1)
	assert_string_contains(broken.validate()[0], "version")


func test_load_reports_a_missing_or_unparsable_file() -> void:
	var spec := ZoneSpec.load_files("res://tests/fixtures/zone/absent.json", "res://nowhere.json")
	assert_string_contains(_joined(spec), "absent.json")
	assert_string_contains(_joined(spec), "nowhere.json")


func test_load_reads_the_fixture_pair() -> void:
	var spec := ZoneSpec.load_files(
		"res://tests/fixtures/zone/sidecar.json", "res://tests/fixtures/zone/declarations.json"
	)
	assert_eq(spec.errors, [] as Array[String])
	assert_gt(spec.boxes.size(), 0)


## The shipped sidecars are the contract's real inputs; both must parse clean against it.
func test_the_shipped_kitchen_and_school_sidecars_parse_clean() -> void:
	var kitchen := ZoneSpec.load_files(
		"res://data/course/02-kitchen.json", "res://data/course/02-kitchen.declarations.json"
	)
	assert_eq(kitchen.errors, [] as Array[String])
	assert_true(kitchen.has_line)
	var school := ZoneSpec.parse(
		JSON.parse_string(FileAccess.get_file_as_string("res://data/course/01-school.json")), {}
	)
	assert_eq(school.errors, [] as Array[String])
	assert_false(school.has_line)
