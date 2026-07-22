class_name WallrunLogic
extends RefCounted
## Wall-run = airborne slide along a side wall with gentle capped sink.

const MIN_FORWARD_SPEED := 4.0
const SINK_RATE := 1.5
const SINK_CAP := -2.0
const PUSH_AWAY_SPEED := 6.0
const PUSH_UP_SPEED := 6.5


static func can_wallrun(on_floor: bool, has_wall: bool, forward_speed: float) -> bool:
	return not on_floor and has_wall and forward_speed > MIN_FORWARD_SPEED


static func wallrun_velocity(velocity: Vector3, wall_normal: Vector3, delta: float) -> Vector3:
	var v := velocity.slide(wall_normal)
	v.y = maxf(velocity.y - SINK_RATE * delta, SINK_CAP)
	return v


static func walljump_velocity(velocity: Vector3, wall_normal: Vector3) -> Vector3:
	var v := velocity + wall_normal * PUSH_AWAY_SPEED
	v.y = PUSH_UP_SPEED
	return v
