class_name GateLogic
extends RefCounted
## Pure state machine for look-to-open gates (4.1 spec §4.2). A node wrapper
## (gate_node.gd) ticks it and drives geometry; no node code here.
## ANIM_DURATION is a measured input to the sightline budget (T8).

enum State { SHUT, OPENING, OPEN, RECLOSING }

const ANIM_DURATION := 0.5
const NO_RECLOSE := -1.0  ## timed_window value for gates that stay open

var state: int = State.SHUT
var timed_window: float
var _t := 0.0


func _init(window: float = NO_RECLOSE) -> void:
	timed_window = window


func try_activate() -> bool:
	## Valid from SHUT or RECLOSING only. RECLOSING re-activation resumes from
	## the current openness so the geometry never snaps: in OPENING,
	## openness() = _t / ANIM_DURATION, so continuity needs
	## _t = openness() * ANIM_DURATION.
	if state == State.SHUT:
		state = State.OPENING
		_t = 0.0
		return true
	if state == State.RECLOSING:
		_t = openness() * ANIM_DURATION
		state = State.OPENING
		return true
	return false


func tick(delta: float) -> void:
	_t += delta
	match state:
		State.OPENING:
			if _t >= ANIM_DURATION:
				state = State.OPEN
				_t = 0.0
		State.OPEN:
			if timed_window >= 0.0 and _t >= timed_window:
				state = State.RECLOSING
				_t = 0.0
		State.RECLOSING:
			if _t >= ANIM_DURATION:
				state = State.SHUT
				_t = 0.0


func openness() -> float:
	## 0 = fully shut, 1 = fully open; node wrapper maps this onto geometry.
	match state:
		State.OPEN:
			return 1.0
		State.OPENING:
			return clampf(_t / ANIM_DURATION, 0.0, 1.0)
		State.RECLOSING:
			return 1.0 - clampf(_t / ANIM_DURATION, 0.0, 1.0)
	return 0.0
