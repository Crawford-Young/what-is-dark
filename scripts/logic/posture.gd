class_name Posture
extends RefCounted
## The three stances toward the dark (spec §2). Pure math.

enum { AWAY, GLANCING, FACING }

const FACING_DOT_THRESHOLD := 0.5


static func evaluate(cam_forward: Vector3, dir_to_void: Vector3, glance_held: bool) -> int:
	if glance_held:
		return GLANCING
	var d := cam_forward.normalized().dot(dir_to_void.normalized())
	return FACING if d > FACING_DOT_THRESHOLD else AWAY
