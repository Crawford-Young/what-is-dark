extends GutTest


# --- apply_friction ---

func test_friction_decays_speed_above_stopspeed() -> void:
	# speed 4 > STOP_SPEED 3.5: drop = 4 * 4.0 * 0.1 = 1.6 -> 2.4
	var v := SourceMove.apply_friction(Vector3(4, 0, 0), 0.1)
	assert_true(v.is_equal_approx(Vector3(2.4, 0, 0)))


func test_friction_uses_stopspeed_floor_below_it() -> void:
	# speed 3 < STOP_SPEED 3.5: drop = 3.5 * 4.0 * 0.1 = 1.4 -> new_speed 1.6 (scaled onto the 3-magnitude vector)
	var v := SourceMove.apply_friction(Vector3(3, 0, 0), 0.1)
	assert_almost_eq(v.x, 1.6, 0.0001)
	assert_almost_eq(v.z, 0.0, 0.0001)


func test_friction_clamps_to_zero_when_drop_exceeds_speed() -> void:
	# drop = 3.5 * 4.0 * 0.2 = 2.8 > 0.5
	var v := SourceMove.apply_friction(Vector3(0.5, 0, 0), 0.2)
	assert_true(v.is_equal_approx(Vector3.ZERO))


func test_friction_zeroes_sub_hundredth_speeds() -> void:
	var v := SourceMove.apply_friction(Vector3(0.005, 0, 0.005), 0.016)
	assert_almost_eq(v.x, 0.0, 0.000001)
	assert_almost_eq(v.z, 0.0, 0.000001)


func test_friction_preserves_vertical() -> void:
	# horiz speed 5 > STOP_SPEED 3.5: drop = 5 * 4.0 * 0.1 = 2.0 -> 3; y untouched
	var v := SourceMove.apply_friction(Vector3(5, 7, 0), 0.1)
	assert_true(v.is_equal_approx(Vector3(3, 7, 0)))


# --- accelerate ---

func test_accelerate_from_rest_ground() -> void:
	# accelspeed = 5.5 * 11.0 * 0.1 = 6.05 < add 11.0
	var v := SourceMove.accelerate(Vector3.ZERO, Vector3(0, 0, -1), SourceMove.RUN_SPEED, SourceMove.GROUND_ACCEL, 0.1)
	assert_true(v.is_equal_approx(Vector3(0, 0, -6.05)))


func test_accelerate_never_overshoots_wishspeed_along_wishdir() -> void:
	# add = 11.0 - 10.5 = 0.5 < accelspeed 6.05 -> exactly 11.0
	var v := SourceMove.accelerate(Vector3(0, 0, -10.5), Vector3(0, 0, -1), SourceMove.RUN_SPEED, SourceMove.GROUND_ACCEL, 0.1)
	assert_true(v.is_equal_approx(Vector3(0, 0, -11.0)))


func test_accelerate_noop_when_current_exceeds_wishspeed() -> void:
	# current 12.0 > wishspeed 11.0 -> add_speed negative, no-op
	var v := SourceMove.accelerate(Vector3(0, 0, -12.0), Vector3(0, 0, -1), SourceMove.RUN_SPEED, SourceMove.GROUND_ACCEL, 0.1)
	assert_true(v.is_equal_approx(Vector3(0, 0, -12.0)))


func test_air_strafe_gains_past_cap_via_perpendicular_add() -> void:
	# THE mechanic: moving -z at 10, wish pure -x. current = dot = 0 -> add 1.5
	# accelspeed = 150 * 1.5 * 0.1 = 22.5 -> clamped to 1.5
	var v := SourceMove.accelerate(Vector3(0, 0, -10), Vector3(-1, 0, 0), minf(SourceMove.RUN_SPEED, SourceMove.AIR_CAP), SourceMove.AIR_ACCEL, 0.1)
	assert_true(v.is_equal_approx(Vector3(-1.5, 0, -10)))
	assert_gt(Vector3(v.x, 0, v.z).length(), 10.0)


func test_accelerate_preserves_vertical() -> void:
	var v := SourceMove.accelerate(Vector3(0, 3, 0), Vector3(1, 0, 0), SourceMove.RUN_SPEED, SourceMove.GROUND_ACCEL, 0.1)
	assert_almost_eq(v.y, 3.0, 0.0001)


# --- clip_velocity ---

func test_clip_redirects_fall_along_45_ramp() -> void:
	# n = (-sqrt2/2, sqrt2/2, 0); v (0,-10,0): dot = -7.0711 -> v' = (-5,-5,0)
	var n := Vector3(-sqrt(2) / 2, sqrt(2) / 2, 0)
	var v := SourceMove.clip_velocity(Vector3(0, -10, 0), n)
	assert_true(v.is_equal_approx(Vector3(-5, -5, 0)))


func test_clip_flattens_against_floor_normal() -> void:
	var v := SourceMove.clip_velocity(Vector3(3, -2, 0), Vector3.UP)
	assert_true(v.is_equal_approx(Vector3(3, 0, 0)))


func test_clip_leaves_parallel_motion_unchanged() -> void:
	var v := SourceMove.clip_velocity(Vector3(1, 0, 0), Vector3.UP)
	assert_true(v.is_equal_approx(Vector3(1, 0, 0)))


# --- clip_multi ---

func test_clip_multi_single_normal_delegates_to_clip() -> void:
	# Same case as the 45-degree single-plane test, routed through clip_multi.
	var n := Vector3(-sqrt(2) / 2, sqrt(2) / 2, 0)
	var normals: Array[Vector3] = [n]
	var v := SourceMove.clip_multi(Vector3(0, -10, 0), normals)
	assert_true(v.is_equal_approx(Vector3(-5, -5, 0)))


func test_clip_multi_valley_crease_preserves_along_pipe_component() -> void:
	# Half-pipe V: n1 = left-wall inner normal, n2 = right-wall inner normal (50-degree faces).
	# v (0,-10,-5): dot n1 = -6.43 < 0 -> clip -> v1 = (4.925,-5.866,-5);
	# v1.dot(n2) = -7.545 < 0 -> clip -> v2 = (-0.855,-1.015,-5);
	# v2.dot(n1) = -1.31 < -0.001 -> crease fires: crease = n1 x n2 = (0,0,1) (normalized);
	# result = crease * v2.dot(crease) = (0,0,-5) -- only the along-pipe component survives.
	var n1 := Vector3(sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0)), 0)
	var n2 := Vector3(-sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0)), 0)
	var normals: Array[Vector3] = [n1, n2]
	var v := SourceMove.clip_multi(Vector3(0, -10, -5), normals)
	assert_almost_eq(v.x, 0.0, 0.0001)
	assert_almost_eq(v.y, 0.0, 0.0001)
	assert_almost_eq(v.z, -5.0, 0.0001)


func test_clip_multi_noop_when_not_moving_into_any_plane() -> void:
	var normals: Array[Vector3] = [Vector3.UP]
	var v := SourceMove.clip_multi(Vector3(1, 0, 0), normals)
	assert_true(v.is_equal_approx(Vector3(1, 0, 0)))


func test_clip_multi_dedupes_same_plane_contacts() -> void:
	# Up-kicker (X-rotated panel): move_and_slide reports two float-noise-perturbed samples of
	# the SAME face normal. Undeduped, their near-zero cross normalizes to an arbitrary tangent
	# and velocity collapses onto it (observed bug: forward -z speed flips POSITIVE, rider
	# reverses into the pit). Deduped, this must reduce to one plain single-plane clip.
	var n := Vector3(0.0, cos(deg_to_rad(50.0)), sin(deg_to_rad(50.0)))
	var n_perturbed := Vector3(0.0, 0.6423, 0.766453).normalized()
	assert_gt(n.dot(n_perturbed), 0.999, "perturbed sample must read as the same plane")
	var velocity := Vector3(0.0, -11.83, -29.0)
	var normals: Array[Vector3] = [n, n_perturbed]
	var v := SourceMove.clip_multi(velocity, normals)
	var single := SourceMove.clip_velocity(velocity, n)
	assert_almost_eq(v.x, single.x, 0.001)
	assert_almost_eq(v.y, single.y, 0.001)
	assert_almost_eq(v.z, single.z, 0.001)
	assert_lt(v.z, 0.0, "forward (-z) motion must stay forward, not reflect into the pit")


func test_clip_multi_bitidentical_duplicates() -> void:
	# Ordinary ramp case: move_and_slide reports the exact same normal twice for one face.
	var n := Vector3(-sqrt(2) / 2, sqrt(2) / 2, 0)
	var normals: Array[Vector3] = [n, n]
	var v := SourceMove.clip_multi(Vector3(0, -10, 0), normals)
	assert_true(v.is_equal_approx(Vector3(-5, -5, 0)))


# --- jump / gravity ---

func test_jump_replaces_y_keeps_horizontal() -> void:
	var v := SourceMove.jump(Vector3(3, -2, -5))
	assert_true(v.is_equal_approx(Vector3(3, 13.29, -5)))


func test_gravity_reduces_y() -> void:
	# 0 - GRAVITY(35.2) * 0.5 = -17.6
	var v := SourceMove.apply_gravity(Vector3(1, 0, 2), 0.5)
	assert_true(v.is_equal_approx(Vector3(1, -17.6, 2)))
