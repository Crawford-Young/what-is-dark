class_name MoveMath
extends RefCounted
## Pure velocity math. No nodes, no Input, no scene tree.


static func accel_horizontal(velocity: Vector3, wish_dir: Vector3, target_speed: float, accel: float, delta: float) -> Vector3:
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var target := Vector3.ZERO
	if wish_dir.length_squared() > 0.000001:
		target = wish_dir.normalized() * target_speed
	horiz = horiz.move_toward(target, accel * delta)
	return Vector3(horiz.x, velocity.y, horiz.z)


static func apply_gravity(velocity: Vector3, gravity: float, delta: float) -> Vector3:
	return Vector3(velocity.x, velocity.y - gravity * delta, velocity.z)


static func jump(velocity: Vector3, jump_speed: float) -> Vector3:
	return Vector3(velocity.x, jump_speed, velocity.z)


static func land(velocity: Vector3, retention: float) -> Vector3:
	return Vector3(velocity.x * retention, velocity.y, velocity.z * retention)
