extends GutTest


func test_conservation_across_uneven_cadence() -> void:
	var d := YawDrain.new()
	var total_applied := 0.0
	d.add_delta(4.0)
	total_applied += d.drain_tick()  # fresh window (2 ticks): step 2.0, pending 2.0 left
	d.add_delta(3.0)  # mid-window arrival, joins the active countdown (1 tick left)
	total_applied += d.drain_tick()  # drains everything left in the window: (2.0+3.0)/1 = 5.0
	d.add_delta(10.0)  # window closed -> fresh window starts
	total_applied += d.drain_tick()
	total_applied += d.drain_tick()
	assert_almost_eq(total_applied, 17.0, 0.0001, "sum of applied steps must equal sum of deltas added (4+3+10)")


func test_fresh_delta_splits_evenly_no_double_step() -> void:
	var d := YawDrain.new()
	d.add_delta(8.0)
	var step1 := d.drain_tick()
	var step2 := d.drain_tick()
	assert_almost_eq(step1, 4.0, 0.0001, "first tick of a fresh window takes exactly half")
	assert_almost_eq(step2, 4.0, 0.0001, "second tick takes the remaining half -- no leftover double-step")
	assert_true(absf(step1) <= 8.0, "no single tick ever applies more than the whole buffered delta")


func test_zero_input_decays_to_empty() -> void:
	var d := YawDrain.new()
	for i in range(5):
		var step := d.drain_tick()
		assert_almost_eq(step, 0.0, 0.0001, "no input ever added -> every tick is a no-op")
	assert_almost_eq(d.pending, 0.0, 0.0001)


func test_zero_delta_is_a_noop_and_does_not_start_a_window() -> void:
	var d := YawDrain.new()
	d.add_delta(0.0)
	assert_almost_eq(d.pending, 0.0, 0.0001)
	assert_almost_eq(d.drain_tick(), 0.0, 0.0001)


func test_window_restarts_fresh_after_a_full_drain() -> void:
	var d := YawDrain.new()
	d.add_delta(6.0)
	d.drain_tick()
	d.drain_tick()  # fully drained, window closed
	d.add_delta(10.0)
	var step := d.drain_tick()
	assert_almost_eq(step, 5.0, 0.0001, "a new delta after a closed window gets its own fresh 2-tick split")


func test_mid_window_arrival_never_waits_longer_than_the_active_window() -> void:
	var d := YawDrain.new()
	d.add_delta(4.0)
	var step1 := d.drain_tick()  # 1 tick left in the window afterward
	d.add_delta(6.0)  # folds into the SAME countdown, does not reset it to a full window
	var step2 := d.drain_tick()  # only 1 tick remained -> drains everything in one shot
	assert_almost_eq(step1, 2.0, 0.0001)
	assert_almost_eq(step2, 8.0, 0.0001, "remaining 2.0 + newly-arrived 6.0, all due this tick")
	assert_almost_eq(step1 + step2, 10.0, 0.0001, "conservation: 4+6 == total applied")


func test_reset_clears_pending_and_countdown() -> void:
	var d := YawDrain.new()
	d.add_delta(4.0)
	d.drain_tick()
	d.reset()
	assert_almost_eq(d.pending, 0.0, 0.0001)
	assert_almost_eq(d.drain_tick(), 0.0, 0.0001, "reset must not leave a stale countdown that fires later")


func test_ticks_remaining_zero_with_stale_nonzero_pending_self_heals() -> void:
	# Contrived state a caller could reach only via direct manipulation (not through the public
	# add_delta/drain_tick contract) -- verifies drain_tick's OR-guard handles it defensively.
	var d := YawDrain.new()
	d._ticks_remaining = 0
	d.pending = 3.0
	var step := d.drain_tick()
	assert_almost_eq(step, 0.0, 0.0001, "a closed window (ticks_remaining<=0) never fires, even with stray pending")
	assert_almost_eq(d.pending, 0.0, 0.0001, "self-heals to a clean empty state")
