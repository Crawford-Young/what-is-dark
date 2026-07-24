class_name SourceMove
extends RefCounted
## Source movement math — game-scaled hybrid (Source mechanics at what-is-dark scale:
## run/jump/gravity = main game's player.gd values; STOP_SPEED and AIR_CAP scaled x2.31
## from CS2's originals; CS2-converted originals in git history).
## Caller's per-tick order: grounded -> [auto-hop ? jump : friction] -> accelerate(ground);
## airborne -> accelerate(air, wish_speed = minf(RUN_SPEED, AIR_CAP)) -> gravity. Then move_and_slide.

const RUN_SPEED := 11.0
const GRAVITY := 35.2  ## ratio match — along-face accel / run speed = 35.2*sin(51.34)/11 ≈
## 2.5/s = CS2's relative downhill gain (15.24*sin51.34/4.76); 20 was game parity but halved
## the felt punch (20*sin51.34/11 ≈ 1.42/s) — third user ask closed the question (2026-07-23)
const JUMP_SPEED := 13.29  ## airtime match over height parity: airtime = 2*13.29/35.2 ≈ 0.755s
## = CS's flat-jump airtime (301.99u/800), giving air-strafe a full 360° turn window in one hop
## (was 0.641s / ~300° max at 11.28). DELIBERATE height-parity break: jump height rises 1.81 ->
## 2.51 m (13.29^2/(2*35.2)) — user-approved tradeoff (R12d). Lab-scope only; main game's
## scripts/player.gd JUMP_SPEED is untouched.
const FRICTION := 4.0  ## surf-server sv_friction (CS2 matchmaking default is 5.2)
const STOP_SPEED := 3.5
const GROUND_ACCEL := 5.5
const AIR_ACCEL := 150.0  ## surf/bhop community-server value (CS2 matchmaking uses 12 — near-zero strafe gain by design)
const AIR_CAP := 0.75  ## unchanged under the GRAVITY ratio-match: per-tick hold-vs-slide ratio
## at 120 Hz = 0.75 / (35.2*sin51.34/120) ≈ 3.3:1, vs CS2's 0.57/(15.24*sin51.34/64) ≈ 3.1:1 —
## already matched; scaling this with GRAVITY would recreate the R4 pin-to-ramp bug
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
## a clipped plane pair, slide along their crease (intersection line). Same-plane contacts are
## deduped first: move_and_slide can report a single face as 2+ near-identical normals (float
## noise on rotated panels), and a tiny non-zero cross between near-duplicates normalizes to an
## arbitrary tangent, collapsing velocity onto it instead of a plain single-plane clip.
static func clip_multi(velocity: Vector3, normals: Array[Vector3]) -> Vector3:
	var unique: Array[Vector3] = []
	for n in normals:
		var dup := false
		for u in unique:
			if n.dot(u) > 0.999:  # same plane sampled twice (multi-contact on one face)
				dup = true
				break
		if not dup:
			unique.append(n)
	for n in unique:
		if velocity.dot(n) < 0.0:
			velocity = clip_velocity(velocity, n)
	if unique.size() >= 2:
		for i in unique.size():
			for j in range(i + 1, unique.size()):
				if velocity.dot(unique[i]) < -0.001 or velocity.dot(unique[j]) < -0.001:
					var crease := unique[i].cross(unique[j])
					if crease.length_squared() > 0.000001:
						crease = crease.normalized()
						velocity = crease * velocity.dot(crease)
	return velocity


static func jump(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, JUMP_SPEED, velocity.z)


static func apply_gravity(velocity: Vector3, delta: float) -> Vector3:
	return Vector3(velocity.x, velocity.y - GRAVITY * delta, velocity.z)
