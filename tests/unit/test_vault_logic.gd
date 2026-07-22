extends GutTest


func test_vault_requires_low_blocked_and_high_clear_and_speed() -> void:
	assert_true(VaultLogic.can_vault(true, true, 5.0))
	assert_false(VaultLogic.can_vault(false, true, 5.0), "nothing to vault over")
	assert_false(VaultLogic.can_vault(true, false, 5.0), "no clearance above")
	assert_false(VaultLogic.can_vault(true, true, 1.0), "too slow to vault")


func test_vault_velocity_sets_up_speed_keeps_horizontal() -> void:
	var v := VaultLogic.vault_velocity(Vector3(0, -1, -8), 6.0)
	assert_true(v.is_equal_approx(Vector3(0, 6.0, -8)))
