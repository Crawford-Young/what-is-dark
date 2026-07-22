class_name VaultLogic
extends RefCounted
## Vault = instantaneous boost over a waist-high obstacle, triggered on jump
## input when the low ray is blocked and the high ray is clear.

const MIN_FORWARD_SPEED := 2.0


static func can_vault(low_blocked: bool, high_clear: bool, forward_speed: float) -> bool:
	return low_blocked and high_clear and forward_speed > MIN_FORWARD_SPEED


static func vault_velocity(velocity: Vector3, up_speed: float) -> Vector3:
	return Vector3(velocity.x, up_speed, velocity.z)
