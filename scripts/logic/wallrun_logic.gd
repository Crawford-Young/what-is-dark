class_name WallrunLogic
extends RefCounted
## Wall-run = momentum-preserving ride along a side wall (Phase 3a spec §3):
## surf semantics on a vertical surface. Along-wall speed is frictionless
## (caller applies gravity; ride clips + caps sink); the kick keeps carried
## horizontal speed and redirects it instead of resetting to fixed values.

const MIN_FORWARD_SPEED := 4.0
const SINK_CAP := -2.0
const PUSH_AWAY_SPEED := 6.0
const WALL_JUMP_VY := 8.63  ## phase-1's 1.06 m rise reproduced at GRAVITY 35.2


static func can_wallrun(on_floor: bool, has_wall: bool, forward_speed: float) -> bool:
	return not on_floor and has_wall and forward_speed > MIN_FORWARD_SPEED


static func ride_velocity(velocity: Vector3, wall_normal: Vector3) -> Vector3:
	var v := SourceMove.clip_velocity(velocity, wall_normal)
	v.y = maxf(v.y, SINK_CAP)
	return v


static func kick_velocity(velocity: Vector3, wall_normal: Vector3) -> Vector3:
	var v := velocity + wall_normal * PUSH_AWAY_SPEED
	v.y = maxf(v.y, WALL_JUMP_VY)
	return v


static func jump_released(was_down: bool, down: bool) -> bool:
	return was_down and not down
