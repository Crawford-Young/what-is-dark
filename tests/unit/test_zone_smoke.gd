extends GutTest
## A Blender-exported zone, built from a tiny fixture sidecar (`tests/fixtures/zone/`): one
## marker-floor slab, one eroding slab 2 m past it (z, anchor −1, 8 -> 4 m), one ride wall. The
## art stand-in mimics the glb's `PLAY/<object>` layout. Smoke-grade by the domain rule, but this
## is also the non-slice `Course` the audit and the gameplay wiring are proven against.

const FIXTURE := "res://tests/fixtures/zone/fixture_zone.tscn"
const PLATEAU := ErosionLogic.PLATEAU_LOOP

var _zone: Zone


func before_each() -> void:
	_zone = load(FIXTURE).instantiate() as Zone
	add_child_autofree(_zone)
	await wait_physics_frames(2)


func _body(box_name: String) -> StaticBody3D:
	return _zone.get_node("PLAY/%s" % box_name) as StaticBody3D


func test_every_sidecar_box_becomes_a_play_body_at_its_centre() -> void:
	var play := _zone.get_node("PLAY")
	assert_eq(play.get_child_count(), 3)
	var slab := _body("Slab_0")
	assert_eq(slab.position, Vector3(0, -0.2, -4))
	var shape := (slab.get_node("Col") as CollisionShape3D).shape as BoxShape3D
	assert_eq(shape.size, Vector3(4, 0.4, 12))


## The erodable-platform contract, exactly: group, `Col` + `Mesh`, and the three meta keys.
func test_an_eroding_box_carries_the_erodable_contract() -> void:
	var body := _body("Slab_1")
	assert_true(body.is_in_group(Course.EROSION_GROUP))
	assert_eq(body.get_meta("erode_axis"), 2)
	assert_eq(body.get_meta("erode_min"), 4.0)
	assert_eq(body.get_meta("erode_anchor"), -1.0)
	assert_true(body.get_node("Col").shape is BoxShape3D)
	assert_true((body.get_node("Mesh") as MeshInstance3D).mesh is BoxMesh)
	assert_false(_body("Slab_0").is_in_group(Course.EROSION_GROUP))
	assert_false(_body("Wall_0").is_in_group(Course.EROSION_GROUP))


## The glb mesh of an eroding object would show its loop-0 shape forever, so it goes, and every
## box of that object is drawn from its record. A non-eroding object keeps its (bevelled) art.
func test_an_eroding_objects_art_is_stripped_and_redrawn_from_its_boxes() -> void:
	assert_null(_zone.find_child("Slab", true, false), "the eroding object's art mesh is gone")
	assert_not_null(_zone.find_child("Wall", true, false), "the ride wall keeps its art")
	assert_true((_body("Slab_0").get_node("Mesh") as MeshInstance3D).mesh is BoxMesh)
	assert_null(_body("Wall_0").get_node_or_null("Mesh"), "art draws the wall; no second mesh")


func test_the_redrawn_boxes_wear_the_stripped_objects_material() -> void:
	var mesh := (_body("Slab_0").get_node("Mesh") as MeshInstance3D).mesh as BoxMesh
	assert_not_null(mesh.material)
	assert_eq(mesh.material.resource_name, "SlabMat")


func test_the_course_path_is_the_sidecar_line() -> void:
	var curve := (_zone.get_node("CoursePath") as Path3D).curve
	assert_eq(curve.point_count, 2)
	assert_eq(curve.get_point_position(1), Vector3(0, 0, -20))
	assert_almost_eq(curve.get_baked_length(), 20.0, 0.01)
	assert_almost_eq(_zone.respawn_position(1), Vector3(0, 1, -5), Vector3.ONE * 0.01)


func test_the_course_spec_comes_from_the_sidecar() -> void:
	assert_eq(_zone.marker_progresses, [0.0, 5.0] as Array[float])
	assert_eq(_zone.door_progress, 18.0)
	assert_eq(_zone.fall_y, -6.0)
	assert_eq(_zone.course_spec().validate(), [] as Array[String])


func test_the_player_starts_at_the_sidecar_spawn() -> void:
	var player := _zone.get_node("Player") as Player
	assert_almost_eq(player.global_position, Vector3(0, 1, 0), Vector3.ONE * 0.05)


func test_erosion_shrinks_the_eroding_box_toward_its_pinned_edge() -> void:
	assert_eq(_zone.erodable_count(), 1)
	_zone.loop_logic.loop_count = PLATEAU
	_zone.apply_erosion()
	var body := _body("Slab_1")
	var shape := (body.get_node("Col") as CollisionShape3D).shape as BoxShape3D
	assert_almost_eq(shape.size.z, 4.0, 0.001)
	assert_almost_eq(((body.get_node("Mesh") as MeshInstance3D).mesh as BoxMesh).size.z, 4.0, 0.001)
	# anchor −1 pins the low-z edge (−20), so the centre moves from −16 to −18.
	assert_almost_eq(body.position.z, -18.0, 0.001)


# --- the audit on a non-slice course ------------------------------------------------------------


func test_the_audit_sets_up_clean_on_a_zone() -> void:
	assert_eq(CourseAudit.new(_zone).assert_setup(), [] as Array[String])


## Roles live in the sidecar, spans in the declarations file — the audit sees both.
func test_the_audit_reads_sidecar_roles_and_declared_spans() -> void:
	var audit := CourseAudit.new(_zone)
	assert_eq(audit.declarations(), {"Slab_0>Slab_1": {"decl": "chasm", "per_loop": 0.8}})
	var roles := {}
	for surface in audit.survey_boxes(0)["surfaces"] as Array:
		roles[surface["name"]] = surface.get("role", "")
	assert_eq(roles["Slab_0"], "marker_floor")
	assert_eq(roles["Slab_1"], "floor")
	assert_eq(roles["Wall_0"], "ride_wall")


func test_the_audit_sees_the_gap_grow_from_2_to_6_metres() -> void:
	var audit := CourseAudit.new(_zone)
	for case in [[0, 2.0], [PLATEAU, 6.0]]:
		var spans := {}
		for row in audit.survey_boxes(int(case[0]))["spans"] as Array:
			spans[row["id"]] = row["span"]
		assert_almost_eq(float(spans.get("Slab_0>Slab_1", -1.0)), float(case[1]), 0.001)


# --- the kitchen -------------------------------------------------------------------------------


func test_the_kitchen_scene_builds_from_its_sidecar() -> void:
	var kitchen := load(Kitchen.SCENE_PATH).instantiate() as Kitchen
	add_child_autofree(kitchen)
	await wait_physics_frames(2)
	assert_eq(kitchen.course_spec().validate(), [] as Array[String])
	assert_eq(kitchen.get_node("PLAY").get_child_count(), 80)
	assert_eq(kitchen.erodable_count(), 6)
	for worktop in ["WorktopL0", "WorktopL1", "WorktopL2", "WorktopR0", "WorktopR1", "WorktopR2"]:
		assert_null(kitchen.get_node("Art").find_child(worktop, true, false), worktop)
	assert_not_null(kitchen.get_node("Art").find_child("Fridge", true, false))
	assert_eq(CourseAudit.new(kitchen).assert_setup(), [] as Array[String])
