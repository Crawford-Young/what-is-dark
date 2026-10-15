extends GutTest


func test_lab_scene_instantiates_with_player() -> void:
	var lab: Node3D = load("res://scenes/surf_lab.tscn").instantiate()
	add_child_autofree(lab)
	assert_eq(lab.name, "SurfLab")
	assert_not_null(lab.get_node_or_null("Player"))


## DEBUG PROBE — remove before gates (issue #14): rounded-seam contact probe tests.
## Rounded set = AR + BR bands x 6 deltas = 12 clusters; each spine has 4 interior
## vertices but the lead-in joins ramp 1 at the same 12deg pitch, so 3 arcs each.
const PROBE_ROUNDED_CLUSTERS := 12
const PROBE_ARCS_PER_CLUSTER := 3


func _probe_lab() -> Node3D:
	var lab: Node3D = load("res://scenes/surf_lab.tscn").instantiate()
	lab._probe_sink_enabled = false
	add_child_autofree(lab)
	return lab


func test_probe_registers_every_rounded_arc_at_the_fine_step() -> void:
	var lab := _probe_lab()
	assert_eq(lab._probe_fillet_step, 0.25)
	assert_eq(lab._probe_rounded.size(), PROBE_ROUNDED_CLUSTERS)
	for rec in lab._probe_rounded:
		assert_eq(rec["arcs"].size(), PROBE_ARCS_PER_CLUSTER, rec["label"])
		for arc in rec["arcs"]:
			assert_eq(arc["n"], 24, "6 m arc / 0.25 m step")
			assert_almost_eq(arc["step"], 0.25, 1e-6)


func test_probe_toggle_rebuilds_rounded_seams_at_the_coarse_step_and_back() -> void:
	var lab := _probe_lab()
	var old_bodies: Array = []
	for rec in lab._probe_rounded:
		old_bodies.append(rec["body"])
	lab._probe_toggle_fillet_step()
	assert_eq(lab._probe_fillet_step, 1.5)
	assert_string_contains(lab._probe_step_label.text, "1.50")
	assert_eq(lab._probe_rounded.size(), PROBE_ROUNDED_CLUSTERS)
	for i in lab._probe_rounded.size():
		var rec: Dictionary = lab._probe_rounded[i]
		assert_false(is_instance_valid(old_bodies[i]), "old 0.25 m strip freed")
		assert_true(is_instance_valid(rec["body"]) and rec["body"].is_inside_tree(), "new strip in tree")
		for arc in rec["arcs"]:
			assert_eq(arc["n"], 4, "6 m arc / 1.5 m step")
	lab._probe_toggle_fillet_step()
	assert_eq(lab._probe_fillet_step, 0.25)
	assert_string_contains(lab._probe_step_label.text, "0.25")
	assert_eq(lab._probe_rounded[0]["arcs"][0]["n"], 24)


func test_probe_arc_coordinate_puts_facet_vertices_on_step_multiples() -> void:
	var lab := _probe_lab()
	var rec: Dictionary = lab._probe_rounded[0]
	var arc: Dictionary = rec["arcs"][1]
	var spine: Array = rec["spine"]
	for k in [0, 1, 7, 12, 24]:
		var c: Dictionary = lab._probe_arc_coord(rec, spine[arc["i0"] + k].z)
		assert_eq(c["seam"], 2, "arc index 1 = seam #2")
		assert_almost_eq(c["s_in_arc"], k * 0.25, 1e-3)
		assert_almost_eq(c["boundary_dist"], 0.0, 1e-3)
	var mid: Dictionary = lab._probe_arc_coord(rec, spine[arc["i0"] + 12].z)
	assert_almost_eq(mid["s_from_lip"], 0.0, 1e-3, "lip = arc midpoint")
	var half_z: float = (spine[arc["i0"] + 3].z + spine[arc["i0"] + 4].z) / 2.0
	var half: Dictionary = lab._probe_arc_coord(rec, half_z)
	assert_eq(half["facet_k"], 3)
	assert_almost_eq(half["boundary_dist"], 0.125, 2e-3, "mid-facet = half a step from both edges")


func test_probe_face_hit_decodes_the_arc_facet_segment() -> void:
	var lab := _probe_lab()
	await wait_physics_frames(2)
	var rec: Dictionary = lab._probe_rounded[0]
	var arc: Dictionary = rec["arcs"][0]
	var spine: Array = rec["spine"]
	var seg: int = arc["i0"] + 5
	var a := deg_to_rad(lab.FACE_ANGLE_DEG)
	var on_face: Vector3 = (spine[seg] + spine[seg + 1]) / 2.0 + Vector3(cos(a), -sin(a), 0.0) * 3.0
	var hit: Dictionary = lab._probe_face_hit(on_face + Vector3.UP * 2.0, on_face - Vector3.UP * 2.0)
	assert_false(hit.is_empty(), "ray reaches the strip")
	assert_eq(hit["collider"], rec["body"])
	assert_eq(lab._probe_face_segment(rec, hit["face_index"]), seg)


func test_probe_reports_godot_physics_as_the_active_engine() -> void:
	var lab := _probe_lab()
	assert_eq(lab._probe_engine_name(), "GodotPhysics3D")


func test_probe_hard_stop_is_a_more_than_half_drop_from_a_moving_tick() -> void:
	var lab := _probe_lab()
	assert_true(lab._probe_is_hard_stop(20.0, 9.0))
	assert_false(lab._probe_is_hard_stop(20.0, 11.0))
	assert_false(lab._probe_is_hard_stop(1.5, 0.1), "standing-still noise is not a stop")


func test_probe_spawn_landing_on_a_flat_pad_is_not_a_hard_stop() -> void:
	var lab := _probe_lab()
	await wait_physics_frames(40)  # spawn sits 0.5 m over the A-5° pad: lands ~tick 20
	assert_eq(lab._probe_stops, 0, "a flat landing kills vertical speed, not a seam snag")
	for line in lab._probe_buffer:
		assert_false(line.begins_with("TICK,"), "no surf contact, no stop -> no row: " + line)


func test_probe_logs_tick_and_contact_rows_while_riding_a_rounded_face() -> void:
	var lab := _probe_lab()
	await wait_physics_frames(2)
	var rec: Dictionary = lab._probe_rounded[0]
	var arc: Dictionary = rec["arcs"][0]
	var spine: Array = rec["spine"]
	var a := deg_to_rad(lab.FACE_ANGLE_DEG)
	var on_face: Vector3 = spine[arc["i0"] + 12] + Vector3(cos(a), -sin(a), 0.0) * 3.0
	var hit: Dictionary = lab._probe_face_hit(on_face + Vector3.UP * 2.0, on_face - Vector3.UP * 2.0)
	lab._player.teleport(hit["position"] + hit["normal"] * 1.0, Vector3(0.0, 0.0, -1.0))
	await wait_physics_frames(60)  # ~0.3 m fall onto the face takes ~25 ticks; 60 leaves slide time
	var ticks := 0
	var surf_contacts := 0
	var cross_checked := 0
	for line in lab._probe_buffer:
		if line.begins_with("TICK,"):
			ticks += 1
		elif line.begins_with("CONTACT,") and line.contains(",%s," % rec["label"]):
			surf_contacts += 1
			# Two methods must agree off the facet edges: the ray's face_index segment
			# and the z-derived facet_k (cols: 14 face_seg, 19 seam, 22 facet_k, 23 boundary_dist).
			var c: PackedStringArray = line.split(",")
			if int(c[22]) >= 0 and float(c[23]) > 0.01:
				var i0: int = rec["arcs"][int(c[19]) - 1]["i0"]
				assert_eq(int(c[14]), i0 + int(c[22]), line)
				cross_checked += 1
	assert_gt(ticks, 0, "TICK rows while in contact")
	assert_gt(surf_contacts, 0, "CONTACT rows name the rounded cluster")
	assert_gt(cross_checked, 0, "at least one in-arc contact cross-checked")
	assert_true(lab._probe_buffer[0].begins_with("PROBE-META,"), "header first")
