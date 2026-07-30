extends GutTest
## Declaration schema tests. The point of this module is that an UNDECLARED span is itself a
## finding: every gap in the course must name the verb it expects, so the sweep has something
## to check the geometry against. Bookkeeping drift (#32) is what happens when it does not.


func _joined(errors: Array) -> String:
	return "\n".join(errors)


func test_declaration_enum_is_the_six_verbs() -> void:
	assert_eq(CourseDecl.DECLARATIONS.size(), 6)
	for decl_name in [
		"bare_run", "carried_speed", "wall_ride", "chasm", "surf_transfer", "gate_deploy"
	]:
		assert_true(CourseDecl.DECLARATIONS.has(decl_name), "missing declaration: %s" % decl_name)


func test_role_enum_is_the_nine_roles() -> void:
	assert_eq(CourseDecl.ROLES.size(), 9)
	for role_name in [
		"floor",
		"kicker",
		"surf_ramp",
		"ride_wall",
		"marker_floor",
		"feed_platform",
		"prop",
		"door",
		"gate_path"
	]:
		assert_true(CourseDecl.ROLES.has(role_name), "missing role: %s" % role_name)


func test_every_declaration_has_a_required_keys_entry() -> void:
	for decl_name in CourseDecl.DECLARATIONS:
		assert_true(
			CourseDecl.REQUIRED_KEYS.has(decl_name),
			"%s is declarable but REQUIRED_KEYS never mentions it" % decl_name
		)


func test_a_span_with_no_decl_key_is_undeclared() -> void:
	var errors := CourseDecl.validate_span("D2StripA_gap", {"length": 8.3})
	assert_eq(errors.size(), 1)
	assert_true(_joined(errors).contains("undeclared"), _joined(errors))
	assert_true(_joined(errors).contains("D2StripA_gap"), "an error must name its own span")


func test_an_unknown_declaration_names_itself() -> void:
	var errors := CourseDecl.validate_span("s1", {"decl": "rocket_jump"})
	assert_eq(errors.size(), 1)
	assert_true(_joined(errors).contains("rocket_jump"), _joined(errors))


func test_bare_run_requires_nothing_beyond_the_declaration() -> void:
	assert_eq(CourseDecl.validate_span("s1", {"decl": "bare_run"}).size(), 0)


func test_carried_speed_needs_both_the_speed_and_its_source() -> void:
	var errors := CourseDecl.validate_span("s1", {"decl": "carried_speed"})
	assert_eq(errors.size(), 2, _joined(errors))
	assert_true(_joined(errors).contains("entry_speed"), _joined(errors))
	assert_true(
		_joined(errors).contains("source"),
		"a carried span without a source is a self-certified number — cold review Critical 5"
	)


func test_a_complete_carried_speed_declaration_is_clean() -> void:
	var errors := CourseDecl.validate_span(
		"s1", {"decl": "carried_speed", "entry_speed": 12.6, "source": "ground"}
	)
	assert_eq(errors.size(), 0, _joined(errors))


func test_wall_ride_needs_three_keys() -> void:
	var errors := CourseDecl.validate_span("s1", {"decl": "wall_ride"})
	assert_eq(errors.size(), 3, _joined(errors))
	for key in ["wall", "entry_height", "along_speed"]:
		assert_true(_joined(errors).contains(key), "no error for missing %s" % key)


func test_chasm_needs_its_per_loop_growth() -> void:
	var errors := CourseDecl.validate_span("s1", {"decl": "chasm"})
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(_joined(errors).contains("per_loop"), _joined(errors))


func test_surf_transfer_needs_four_keys() -> void:
	var errors := CourseDecl.validate_span("s1", {"decl": "surf_transfer"})
	assert_eq(errors.size(), 4, _joined(errors))
	for key in ["entry_speed", "drop", "kicker", "factor"]:
		assert_true(_joined(errors).contains(key), "no error for missing %s" % key)


func test_a_kicker_terminated_transfer_needs_no_measured_horizontal() -> void:
	var errors := CourseDecl.validate_span(
		"s1",
		{"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": true, "factor": 0.9}
	)
	assert_eq(errors.size(), 0, _joined(errors))


func test_a_transfer_without_a_kicker_must_declare_its_measured_horizontal() -> void:
	var errors := CourseDecl.validate_span(
		"s1",
		{"decl": "surf_transfer", "entry_speed": 11.0, "drop": 3.0, "kicker": false, "factor": 0.9}
	)
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(
		_joined(errors).contains("exit_h_speed"),
		"only a kicker restores the flat arc (issue #12) — any other exit is a measurement"
	)


func test_a_measured_non_kicker_transfer_is_clean() -> void:
	var errors := CourseDecl.validate_span(
		"s1",
		{
			"decl": "surf_transfer",
			"entry_speed": 11.0,
			"drop": 3.0,
			"kicker": false,
			"factor": 0.9,
			"exit_h_speed": 12.0
		}
	)
	assert_eq(errors.size(), 0, _joined(errors))


func test_gate_deploy_is_reserved_and_asks_for_its_sightline() -> void:
	var errors := CourseDecl.validate_span("s1", {"decl": "gate_deploy"})
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(_joined(errors).contains("sightline_m"), _joined(errors))


func test_a_surface_with_no_role_is_an_error() -> void:
	var errors := CourseDecl.validate_surface("D2StripA", {"erodable": true})
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(_joined(errors).contains("role"), _joined(errors))
	assert_true(_joined(errors).contains("D2StripA"), "an error must name its own surface")


func test_an_unknown_role_is_an_error() -> void:
	var errors := CourseDecl.validate_surface("X", {"role": "trampoline"})
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(_joined(errors).contains("trampoline"), _joined(errors))


func test_a_plain_floor_surface_is_clean() -> void:
	assert_eq(CourseDecl.validate_surface("Sh1FloorA", {"role": "floor"}).size(), 0)


func test_erodable_is_legal_for_floor_only() -> void:
	assert_true(CourseDecl.erodable_legal_for_role("floor"))
	for role_name in CourseDecl.ROLES:
		if role_name == "floor":
			continue
		assert_false(
			CourseDecl.erodable_legal_for_role(role_name),
			"%s must never erode — only a plain floor may" % role_name
		)


func test_marker_floor_is_excluded_from_erosion_deliberately() -> void:
	assert_false(
		CourseDecl.erodable_legal_for_role("marker_floor"),
		"a shrinking respawn floor is the softlock class — issue #12 and 3b probe P3"
	)


func test_erodable_on_a_non_floor_role_is_an_error() -> void:
	var errors := CourseDecl.validate_surface("D2Kicker", {"role": "kicker", "erodable": true})
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(_joined(errors).contains("erodable"), _joined(errors))


func test_erodable_on_a_floor_is_clean() -> void:
	var errors := CourseDecl.validate_surface("D2StripA", {"role": "floor", "erodable": true})
	assert_eq(errors.size(), 0, _joined(errors))


func test_perforation_and_width_shrink_cannot_stack() -> void:
	var errors := CourseDecl.validate_surface(
		"Sh4FloorB", {"role": "floor", "perforated": true, "width_shrink": true}
	)
	assert_eq(errors.size(), 1, _joined(errors))
	assert_true(_joined(errors).contains("perforated"), _joined(errors))


func test_either_erosion_mode_alone_is_clean() -> void:
	assert_eq(
		CourseDecl.validate_surface("a", {"role": "floor", "perforated": true}).size(),
		0
	)
	assert_eq(
		CourseDecl.validate_surface("b", {"role": "floor", "width_shrink": true}).size(),
		0
	)
