extends GutTest

const EXPECTED_STATIONS := {
	"RETRACT-15": ["retract", GateLogic.NO_RECLOSE],
	"RETRACT-20": ["retract", GateLogic.NO_RECLOSE],
	"RETRACT-30": ["retract", GateLogic.NO_RECLOSE],
	"RETRACT-40": ["retract", GateLogic.NO_RECLOSE],
	"DEPLOY-15": ["deploy", GateLogic.NO_RECLOSE],
	"DEPLOY-20": ["deploy", GateLogic.NO_RECLOSE],
	"DEPLOY-30": ["deploy", GateLogic.NO_RECLOSE],
	"DEPLOY-40": ["deploy", GateLogic.NO_RECLOSE],
	"TIMED-50": ["retract", 1.5],
}


func _hidden_gate() -> GateNode:
	var gate := GateNode.new()
	gate.start_hidden = true
	add_child_autofree(gate)
	return gate


func test_lab_scene_instantiates_with_player_and_nine_stations() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	assert_eq(lab.name, "GateLab")
	assert_not_null(lab.get_node_or_null("Player"))
	assert_eq(lab.STATIONS.size(), 9)


func test_each_station_has_a_gate_of_the_right_kind_and_window() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	for s in lab.STATIONS:
		var label: String = s["label"]
		assert_true(EXPECTED_STATIONS.has(label), "unexpected station %s" % label)
		var gate: GateNode = s["gate"]
		assert_eq(gate.kind, EXPECTED_STATIONS[label][0], label)
		assert_eq(gate.timed_window, EXPECTED_STATIONS[label][1], label)
		assert_false(gate.is_revealed(), "%s starts hidden" % label)


func test_crossing_the_approach_line_reveals_the_gate_and_restart_hides_it() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	var s: Dictionary = lab.STATIONS[0]
	var gate: GateNode = s["gate"]
	var spawn: Vector3 = s["spawn"]
	lab.get_node("Player").teleport(Vector3(spawn.x, 1.0, s["line_z"] - 1.0), s["face"])
	await wait_physics_frames(2)
	assert_true(gate.is_revealed())
	lab._reset_to_station()
	assert_false(gate.is_revealed())


func _wall_spans(lab: Node3D, x: float) -> Array:
	var spans := []  ## [near_z, far_z] of each wall on the lane at x
	for wall in lab.get_tree().get_nodes_in_group(&"lab_wall"):
		if absf(wall.position.x - x) < lab.LANE_WIDTH:
			var half: float = (wall.get_child(0).shape as BoxShape3D).size.z / 2.0
			spans.append([wall.position.z + half, wall.position.z - half])
	return spans


func test_deploy_gate_uses_the_deploy_gap() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	for s in lab.STATIONS:
		if (s["gate"] as GateNode).kind == "deploy":
			assert_eq((s["gate"] as GateNode).gap_length, lab.DEPLOY_GAP, s["label"])


func test_retract_lane_has_unbroken_walls_on_both_sides() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	var s: Dictionary = lab.STATIONS[0]
	var gate: GateNode = s["gate"]
	var spans := _wall_spans(lab, gate.position.x)
	assert_eq(spans.size(), 2, "one wall per side")
	for span in spans:
		assert_true(span[0] >= s["spawn"].z and span[1] <= gate.position.z - lab.RUNOUT_LENGTH + 0.01,
			"covers spawn to past the gate")


func test_deploy_lane_walls_leave_the_void_open() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	var gate: GateNode
	for s in lab.STATIONS:
		if (s["gate"] as GateNode).kind == "deploy":
			gate = s["gate"]
			break
	var spans := _wall_spans(lab, gate.position.x)
	assert_eq(spans.size(), 4, "approach + landing wall per side")
	var void_near := gate.position.z
	var void_far: float = gate.position.z - lab.DEPLOY_GAP
	for span in spans:
		assert_true(span[1] >= void_near - 0.01 or span[0] <= void_far + 0.01, "wall overlaps the void")


func test_reset_spawns_the_rider_at_speed() -> void:
	var lab: Node3D = load("res://scenes/gate_lab.tscn").instantiate()
	add_child_autofree(lab)
	var player: Player = lab.get_node("Player")
	player.velocity = Vector3.ZERO
	lab._reset_to_station()
	var horiz := Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(horiz, lab.SPAWN_SPEED, 0.01)


func test_resolve_gate_from_direct_child() -> void:
	var gate: GateNode = autofree(GateNode.new())
	var child := Node3D.new()
	gate.add_child(child)
	assert_eq(GateNode.resolve_gate(child), gate)


func test_resolve_gate_from_nested_grandchild() -> void:
	var gate: GateNode = autofree(GateNode.new())
	var child := Node3D.new()
	var grandchild := Node3D.new()
	gate.add_child(child)
	child.add_child(grandchild)
	assert_eq(GateNode.resolve_gate(grandchild), gate)


func test_resolve_gate_on_non_gate_tree_is_null() -> void:
	var root: Node3D = autofree(Node3D.new())
	var child := Node3D.new()
	root.add_child(child)
	assert_null(GateNode.resolve_gate(child))


func test_hidden_gate_rejects_activation_until_revealed() -> void:
	var gate := _hidden_gate()
	var target := gate.get_node("Target")
	assert_false(gate.try_activate_from(target))
	assert_eq(gate.logic.state, GateLogic.State.SHUT)
	gate.reveal()
	assert_true(gate.try_activate_from(target))


func test_only_the_target_activates_the_gate() -> void:
	var gate := _hidden_gate()
	gate.reveal()
	assert_false(gate.try_activate_from(gate.get_node("Barrier")))
	assert_eq(gate.logic.state, GateLogic.State.SHUT)
	assert_true(gate.try_activate_from(gate.get_node("Target")))


func test_reset_returns_to_shut_and_hidden() -> void:
	var gate := _hidden_gate()
	gate.reveal()
	gate.try_activate_from(gate.get_node("Target"))
	gate.logic.tick(GateLogic.ANIM_DURATION)
	gate.reset()
	assert_eq(gate.logic.state, GateLogic.State.SHUT)
	assert_eq(gate.logic.openness(), 0.0)
	assert_false(gate.is_revealed())
	assert_false(gate.try_activate_from(gate.get_node("Target")))
