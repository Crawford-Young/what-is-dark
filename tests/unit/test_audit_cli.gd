extends GutTest
## `just audit [course]` argument handling and its course registry. The CLI itself is a
## SceneTree script; its decisions live in static functions so they can be pinned here.

const AuditCli := preload("res://scripts/dev/audit_cli.gd")


func _resolve(args: Array) -> Dictionary:
	return AuditCli.resolve_course(PackedStringArray(args), AuditCli.courses())


func test_no_argument_audits_the_slice() -> void:
	assert_eq(_resolve([]), {"course": "slice", "error": ""})


func test_a_registered_name_is_audited() -> void:
	assert_eq(_resolve(["kitchen"]), {"course": "kitchen", "error": ""})


func test_an_unknown_name_is_refused_with_the_known_list() -> void:
	var result := _resolve(["nonsense"])
	assert_eq(result["course"], "")
	assert_string_contains(str(result["error"]), "unknown course \"nonsense\"")
	assert_string_contains(str(result["error"]), "slice")
	assert_string_contains(str(result["error"]), "kitchen")


func test_more_than_one_argument_is_refused() -> void:
	var result := _resolve(["slice", "kitchen"])
	assert_eq(result["course"], "")
	assert_string_contains(str(result["error"]), "one course name, got 2 args")


func test_every_registered_spec_validates_and_points_at_real_files() -> void:
	var registry := AuditCli.courses()
	for course_name in registry:
		var spec: CourseSpec = (registry[course_name] as Callable).call()
		assert_eq(spec.validate(), [] as Array[String], course_name)
		assert_true(ResourceLoader.exists(spec.scene_path), spec.scene_path)
		assert_true(FileAccess.file_exists(spec.declarations_path), spec.declarations_path)
