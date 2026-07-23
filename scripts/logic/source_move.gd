class_name SourceMove
extends RefCounted
## Source-engine movement math (CS2 constants, 1 Hammer unit = 0.01905 m).
## Caller's per-tick order: grounded -> [auto-hop ? jump : friction] -> accelerate(ground);
## airborne -> accelerate(air, wish_speed = minf(RUN_SPEED, AIR_CAP)) -> gravity. Then move_and_slide.

const RUN_SPEED := 4.76
const GRAVITY := 15.24
const JUMP_SPEED := 5.75
const FRICTION := 5.2
const STOP_SPEED := 1.52
const GROUND_ACCEL := 5.5
const AIR_ACCEL := 12.0
const AIR_CAP := 0.57
const OVERBOUNCE := 1.0


static func apply_friction(velocity: Vector3, delta: float) -> Vector3:
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horiz.length()
	if speed < 0.01:
		return Vector3(0.0, velocity.y, 0.0)
	var control := maxf(speed, STOP_SPEED)
	var new_speed := maxf(0.0, speed - control * FRICTION * delta)
	horiz *= new_speed / speed
	return Vector3(horiz.x, velocity.y, horiz.z)


static func accelerate(velocity: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	var current := Vector3(velocity.x, 0.0, velocity.z).dot(wish_dir)
	var add_speed := wish_speed - current
	if add_speed <= 0.0:
		return velocity
	var accel_speed := minf(accel * wish_speed * delta, add_speed)
	return velocity + wish_dir * accel_speed


static func clip_velocity(velocity: Vector3, normal: Vector3) -> Vector3:
	return velocity - normal * velocity.dot(normal) * OVERBOUNCE


static func jump(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, JUMP_SPEED, velocity.z)


static func apply_gravity(velocity: Vector3, delta: float) -> Vector3:
	return Vector3(velocity.x, velocity.y - GRAVITY * delta, velocity.z)
