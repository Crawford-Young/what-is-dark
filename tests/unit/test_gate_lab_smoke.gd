extends GutTest

const EXPECTED_STATIONS := {
	"RETRACT-30": ["retract", GateLogic.NO_RECLOSE],
	"RETRACT-40": ["retract", GateLogic.NO_RECLOSE],
	"RETRACT-50": ["retract", GateLogic.NO_RECLOSE],
	"RETRACT-60": ["retract", GateLogic.NO_RECLOSE],
	"DEPLOY-30": ["deploy", GateLogic.NO_RECLOSE],
	"DEPLOY-40": ["deploy", GateLogic.NO_RECLOSE],
	"DEPLOY-50": ["deploy", GateLogic.NO_RECLOSE],
	"DEPLOY-60": ["deploy", GateLogic.NO_RECLOSE],
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
