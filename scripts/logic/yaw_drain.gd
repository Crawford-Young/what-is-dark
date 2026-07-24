class_name YawDrain
extends RefCounted
## Buffers mouse-yaw deltas (render-rate, variable cadence) and drains them across physics
## ticks (fixed rate) in a bounded, deterministic-latency window. Fixes "render-rate
## staleness": applying a mouse delta directly to yaw the instant it arrives means every OTHER
## physics tick (the ones with no fresh mouse event) strafes along a stale wish direction, then
## the NEXT tick applies a full double-sized step -- diagnosed as the mechanism that collapsed
## the air-circle-strafe test (same nominal turn rate flipped from a flat result to a real
## speed loss purely from HOW the yaw reached the physics tick, not the turn-rate math itself).
##
## Scheme: tick-count split over WINDOW_TICKS physics ticks -- deterministic latency bound,
## no live frame-rate read (Engine.get_frames_per_second() is unreliable headless). At 120 Hz,
## WINDOW_TICKS=2 bounds latency to ~16.7 ms, matching one render frame at a common 60 Hz
## refresh, without needing to know or measure the actual render rate at runtime.

const WINDOW_TICKS := 2

var pending := 0.0
var _ticks_remaining := 0


## Merge a newly-arrived render-rate yaw delta into the buffer. Starts a fresh WINDOW_TICKS
## countdown only if no window is currently active -- a delta arriving mid-window joins the
## CURRENT countdown, so it never waits longer than whatever is already in flight.
func add_delta(delta: float) -> void:
	pending += delta
	if _ticks_remaining <= 0 and pending != 0.0:
		_ticks_remaining = WINDOW_TICKS


## Call once per physics tick. Returns the yaw step to apply this tick: an equal share of
## whatever is currently pending, split across the ticks remaining in the window. A full
## drain always lands in exactly WINDOW_TICKS ticks from when the window opened, and
## conservation holds exactly -- the sum of every step returned since the buffer was last
## empty equals every delta added since then (each tick's step + leftover reconstructs the
## pre-tick pending exactly; the final tick's ticks_remaining==1 divisor makes the leftover
## exactly zero, no floating-point residue).
func drain_tick() -> float:
	if _ticks_remaining <= 0 or pending == 0.0:
		pending = 0.0
		_ticks_remaining = 0
		return 0.0
	var step := pending / float(_ticks_remaining)
	pending -= step
	_ticks_remaining -= 1
	return step


## Clears the buffer and any in-flight countdown -- call on teleport so a leftover buffered
## turn from before the jump doesn't apply itself after landing somewhere else.
func reset() -> void:
	pending = 0.0
	_ticks_remaining = 0
