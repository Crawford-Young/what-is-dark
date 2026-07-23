class_name SourceMove
extends RefCounted
## Source movement math — game-scaled hybrid (Source mechanics at what-is-dark scale:
## run/jump/gravity = main game's player.gd values; STOP_SPEED and AIR_CAP scaled x2.31
## from CS2's originals; CS2-converted originals in git history).
## Caller's per-tick order: grounded -> [auto-hop ? jump : friction] -> accelerate(ground);
## airborne -> accelerate(air, wish_speed = minf(RUN_SPEED, AIR_CAP)) -> gravity. Then move_and_slide.

const RUN_SPEED := 11.0
const GRAVITY := 20.0  ## game parity restored: descent-based map structure supplies the build
## rate, not a gravity tuning lever — the surf ecosystem never tunes gravity (research 2026-07-23)
const JUMP_SPEED := 8.5  ## game parity restored alongside GRAVITY (see above)
const FRICTION := 4.0  ## surf-server sv_friction (CS2 matchmaking default is 5.2)
const STOP_SPEED := 3.5
const GROUND_ACCEL := 5.5
const AIR_ACCEL := 150.0  ## surf/bhop community-server value (CS2 matchmaking uses 12 — near-zero strafe gain by design)
const AIR_CAP := 0.75  ## gravity-consistent scale: 0.57 * 20/15.24 ≈ 0.75 — restores CS2's ~3:1
## gravity-slide vs strafe-hold ratio on 50° faces (the speed-scaled 1.32 pinned riders to ramps)
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


## Source TryPlayerMove multi-plane semantics — clip each opposing plane; if still moving into
## a clipped plane pair, slide along their crease (intersection line).
static func clip_multi(velocity: Vector3, normals: Array[Vector3]) -> Vector3:
	for n in normals:
		if velocity.dot(n) < 0.0:
			velocity = clip_velocity(velocity, n)
	if normals.size() >= 2:
		for i in normals.size():
			for j in range(i + 1, normals.size()):
				if velocity.dot(normals[i]) < -0.001 or velocity.dot(normals[j]) < -0.001:
					var crease := normals[i].cross(normals[j])
					if crease.length_squared() > 0.000001:
						crease = crease.normalized()
						velocity = crease * velocity.dot(crease)
	return velocity


static func jump(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, JUMP_SPEED, velocity.z)


static func apply_gravity(velocity: Vector3, delta: float) -> Vector3:
	return Vector3(velocity.x, velocity.y - GRAVITY * delta, velocity.z)
