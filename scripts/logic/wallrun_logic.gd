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
const RIDE_MAX_NORMAL_Y := 0.2  ## ride gate: |normal.y| <= 0.2 = surface within ~11.5
## deg of vertical. Surf ramps (45-55 deg, normal.y 0.574-0.707) never engage the
## ride/sink-cap; the 38 deg floor limit (normal.y 0.788) sits strictly above ramp range.


static func can_wallrun(on_floor: bool, has_wall: bool, forward_speed: float) -> bool:
	return not on_floor and has_wall and forward_speed > MIN_FORWARD_SPEED


static func ride_velocity(velocity: Vector3, wall_normal: Vector3) -> Vector3:
	var v := velocity
	if v.dot(wall_normal) < 0.0:  # clip only motion INTO the wall — the tick after a
		# kick the ray still sees the wall, and an unguarded clip erases the launch
		v = SourceMove.clip_velocity(v, wall_normal)
	v.y = maxf(v.y, SINK_CAP)
	return v


static func kick_velocity(velocity: Vector3, wall_normal: Vector3) -> Vector3:
	var v := velocity + wall_normal * PUSH_AWAY_SPEED
	v.y = maxf(v.y, WALL_JUMP_VY)
	return v


static func jump_pressed(was_down: bool, down: bool) -> bool:
	return down and not was_down


static func is_rideable_normal(normal: Vector3) -> bool:
	return normal != Vector3.ZERO and absf(normal.y) <= RIDE_MAX_NORMAL_Y


## A RayCast3D reports the PREVIOUS frame's collision for one physics frame after any
## position set, so a respawn that preserves velocity (shift_to) can otherwise ride or
## kick off a wall it is no longer near. Issue #35.
static func wall_normal_after_shift(rays_stale: bool, normal: Vector3) -> Vector3:
	return Vector3.ZERO if rays_stale else normal
