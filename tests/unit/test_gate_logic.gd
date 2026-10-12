extends GutTest

const DT := 1.0 / 120.0
const TOL := 0.01


func _tick(gate: GateLogic, count: int) -> void:
	for i in count:
		gate.tick(DT)


func _crossing_ticks(duration: float) -> int:
	return int(ceil(duration / DT)) + 1


func _open_gate(gate: GateLogic) -> void:
	gate.try_activate()
	_tick(gate, _crossing_ticks(GateLogic.ANIM_DURATION))


func test_fresh_gate_is_shut() -> void:
	var gate := GateLogic.new()
	assert_eq(gate.state, GateLogic.State.SHUT)
	assert_eq(gate.openness(), 0.0)


func test_activate_from_shut_starts_opening() -> void:
	var gate := GateLogic.new()
	assert_true(gate.try_activate())
	assert_eq(gate.state, GateLogic.State.OPENING)


func test_activate_while_opening_is_rejected_and_keeps_progress() -> void:
	var gate := GateLogic.new()
	gate.try_activate()
	_tick(gate, 24)
	assert_false(gate.try_activate())
	assert_almost_eq(gate.openness(), 0.4, TOL)


func test_opening_completes_to_open() -> void:
	var gate := GateLogic.new()
	_open_gate(gate)
	assert_eq(gate.state, GateLogic.State.OPEN)
	assert_eq(gate.openness(), 1.0)


func test_no_reclose_gate_stays_open() -> void:
	var gate := GateLogic.new()
	_open_gate(gate)
	_tick(gate, int(100.0 / DT))
	assert_eq(gate.state, GateLogic.State.OPEN)


func test_timed_gate_recloses_after_window() -> void:
	var gate := GateLogic.new(1.5)
	_open_gate(gate)
	_tick(gate, _crossing_ticks(1.5))
	assert_eq(gate.state, GateLogic.State.RECLOSING)


func test_reclosing_completes_to_shut() -> void:
	var gate := GateLogic.new(1.5)
	_open_gate(gate)
	_tick(gate, _crossing_ticks(1.5))
	_tick(gate, _crossing_ticks(GateLogic.ANIM_DURATION))
	assert_eq(gate.state, GateLogic.State.SHUT)
	assert_eq(gate.openness(), 0.0)


func test_reactivate_during_reclosing_keeps_openness_continuous() -> void:
	var gate := GateLogic.new(1.5)
	_open_gate(gate)
	# Stop on the OPEN -> RECLOSING tick (it resets _t), so 24 more ticks land
	# exactly at openness 0.6; the bound turns a never-recloses bug into a fail.
	for i in _crossing_ticks(1.5):
		if gate.state != GateLogic.State.OPEN:
			break
		gate.tick(DT)
	assert_eq(gate.state, GateLogic.State.RECLOSING)
	_tick(gate, 24)
	assert_almost_eq(gate.openness(), 0.6, TOL)
	assert_true(gate.try_activate())
	assert_eq(gate.state, GateLogic.State.OPENING)
	assert_almost_eq(gate.openness(), 0.6, TOL)


func test_activate_from_open_is_rejected() -> void:
	var gate := GateLogic.new()
	_open_gate(gate)
	assert_false(gate.try_activate())


func test_openness_is_monotonic_while_opening() -> void:
	var gate := GateLogic.new()
	gate.try_activate()
	var previous := gate.openness()
	for i in 61:
		gate.tick(DT)
		var current := gate.openness()
		assert_gte(current, previous)
		previous = current
