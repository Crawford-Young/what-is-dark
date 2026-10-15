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


# --- clip_multi on rounded-seam surf geometry (issue #14, candidate 2: crease collapse) ---
# Characterization only. Face normals are built exactly as surf_lab.gd._add_surf_strip does:
# (p1 - p0) x lateral, lateral = (side*cos(face), -sin(face), 0), flipped to +y. Pitch is the
# spine descent angle; the rider travels along the face in the spine direction.

const SURF_FACE_DEG := 51.34
const SURF_BASE_PITCH_DEG := 12.0
const SURF_SPEEDS := [15.0, 50.0]
const SURF_TICK := 1.0 / 120.0  # project.godot physics_ticks_per_second


func _spine_dir(pitch_deg: float) -> Vector3:
	var p := deg_to_rad(pitch_deg)
	return Vector3(0.0, -sin(p), -cos(p))


func _strip_normal(pitch_deg: float) -> Vector3:
	var a := deg_to_rad(SURF_FACE_DEG)
	var lateral := Vector3(-cos(a), -sin(a), 0.0)
	var n := _spine_dir(pitch_deg).cross(lateral).normalized()
	return n if n.y >= 0.0 else -n


func _pre_slide_velocity(pitch_deg: float, speed: float) -> Vector3:
	# along-ramp travel plus one tick of gravity, as player.gd hands to clip_multi
	return _spine_dir(pitch_deg) * speed + Vector3(0.0, -SourceMove.GRAVITY * SURF_TICK, 0.0)


func _seam_clip(pitch_a: float, pitch_b: float, speed: float) -> Vector3:
	var normals: Array[Vector3] = [_strip_normal(pitch_a), _strip_normal(pitch_b)]
	return SourceMove.clip_multi(_pre_slide_velocity(pitch_a, speed), normals)


func test_surf_strip_normals_match_the_measured_face() -> void:
	assert_almost_eq(_strip_normal(SURF_BASE_PITCH_DEG).y, 0.619, 0.001, "|n.y| at 12 deg pitch")
	# the dot margins any dedupe threshold has to separate (reported in #14)
	assert_almost_eq(_strip_normal(12.0).dot(_strip_normal(17.0)), 0.99839, 0.0001, "sharp seam d5")
	assert_almost_eq(_strip_normal(12.0).dot(_strip_normal(27.0)), 0.98453, 0.0001, "sharp seam d15")
	assert_almost_eq(_strip_normal(12.0).dot(_strip_normal(12.21)), 0.999997, 0.000001, "fillet facet, d5")


func test_clip_multi_fillet_facets_dedupe_to_single_plane_clip() -> void:
	# (a) adjacent fillet facets (0.25 m when authored; 1.5 m now, steps below are the old finer ones, still the tightest case): d5 arc = 0.21 deg pitch/step, d15 arc = 0.625 deg/step.
	for step: float in [0.21, 0.625]:
		var pitch_b := SURF_BASE_PITCH_DEG + step
		assert_gt(_strip_normal(SURF_BASE_PITCH_DEG).dot(_strip_normal(pitch_b)), 0.999, "reads as one plane")
		for speed: float in SURF_SPEEDS:
			var before := _pre_slide_velocity(SURF_BASE_PITCH_DEG, speed)
			var after := _seam_clip(SURF_BASE_PITCH_DEG, pitch_b, speed)
			var single := SourceMove.clip_velocity(before, _strip_normal(SURF_BASE_PITCH_DEG))
			assert_true(after.is_equal_approx(single), "single-plane clip, step %s speed %s" % [step, speed])
			var forward := after.dot(_spine_dir(SURF_BASE_PITCH_DEG))
			assert_gt(forward, speed * 0.999, "forward component kept (%.2f of %.2f)" % [forward, speed])


func test_clip_multi_three_degree_normal_pair_keeps_forward_speed() -> void:
	# (b) two kept normals 3 deg apart (past the 0.999 dedupe, ~2.56 deg), velocity into both.
	# Candidate 2 predicted a near-arbitrary crease collapse here; it does NOT happen. FLIP this
	# test's expectation only if clip_multi is changed on purpose.
	var n1 := _strip_normal(SURF_BASE_PITCH_DEG)
	var lateral := Vector3(-cos(deg_to_rad(SURF_FACE_DEG)), -sin(deg_to_rad(SURF_FACE_DEG)), 0.0)
	var rotations := {
		"lateral edge (strip seam)": lateral.normalized(),
		"travel axis (side tilt)": _spine_dir(SURF_BASE_PITCH_DEG),
		"vertex (diagonal)": (_spine_dir(SURF_BASE_PITCH_DEG) + Vector3.RIGHT).slide(n1).normalized(),
	}
	for label: String in rotations:
		var n2 := n1.rotated(rotations[label], deg_to_rad(3.0))
		assert_almost_eq(rad_to_deg(n1.angle_to(n2)), 3.0, 0.001, label)
		var normals: Array[Vector3] = [n1, n2]
		for speed: float in SURF_SPEEDS:
			# velocity tilted into the face so it points into BOTH planes
			var v := (_spine_dir(SURF_BASE_PITCH_DEG) * cos(deg_to_rad(4.0)) - n1 * sin(deg_to_rad(4.0))) * speed
			assert_lt(v.dot(n1), 0.0, label)
			assert_lt(v.dot(n2), 0.0, label)
			var after := SourceMove.clip_multi(v, normals)
			var forward := after.dot(_spine_dir(SURF_BASE_PITCH_DEG))
			assert_gt(after.length(), speed * 0.99, "%s: speed %.2f -> %.2f" % [label, speed, after.length()])
			assert_gt(forward, speed * 0.99, "%s: forward %.2f -> %.2f" % [label, speed, forward])


func test_clip_multi_sharp_seam_pairs_keep_forward_speed() -> void:
	# (c) the real pitch seams, both orders (convex = leaving the second face, concave = into it).
	# The concave d15 turn clips ~2.4% of 50 m/s (the plain single-plane loss of a 10 deg normal
	# change), not a collapse.
	for delta: float in [5.0, 15.0]:
		var hi := SURF_BASE_PITCH_DEG + delta
		for order: Array in [[SURF_BASE_PITCH_DEG, hi], [hi, SURF_BASE_PITCH_DEG]]:
			for speed: float in SURF_SPEEDS:
				var after := _seam_clip(order[0], order[1], speed)
				var forward := after.dot(_spine_dir(order[0]))
				assert_gt(after.length(), speed * 0.95, "d%s %s speed %s -> %.2f" % [delta, order, speed, after.length()])
				assert_gt(forward, speed * 0.95, "d%s %s forward %s -> %.2f" % [delta, order, speed, forward])


func test_clip_multi_acute_normals_never_reach_the_crease_branch() -> void:
	# Why (b) and (c) cannot collapse: while every pair has n_i.n_j > 0, a sequential clip only
	# RAISES v.n of already-clipped planes, so the "still moving into a plane" crease test never
	# fires. Fuzz 3 normals within 8 deg of the surf face and velocities pointing into the face.
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var base := _strip_normal(SURF_BASE_PITCH_DEG)
	for trial in 300:
		var normals: Array[Vector3] = []
		for k in 3:
			var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			normals.append(base.rotated(axis, deg_to_rad(rng.randf_range(0.0, 8.0))))
		var tilt := deg_to_rad(rng.randf_range(0.0, 6.0))
		var speed := rng.randf_range(15.0, 50.0)
		var v := (_spine_dir(SURF_BASE_PITCH_DEG) * cos(tilt) - base * sin(tilt)) * speed
		var after := SourceMove.clip_multi(v, normals)
		assert_gt(after.length(), speed * 0.9, "trial %d: %.2f -> %.2f" % [trial, speed, after.length()])
		assert_gt(after.dot(_spine_dir(SURF_BASE_PITCH_DEG)), speed * 0.9, "trial %d forward" % trial)


func test_clip_multi_crease_branch_needs_opposing_planes() -> void:
	# The branch's only live trigger: a valley whose planes face each other (n1.n2 < 0).
	# Velocity collapses onto the valley line, which here is the travel axis, so speed is kept.
	var n1 := Vector3(0.8, 0.6, 0.0)
	var n2 := Vector3(-0.8, 0.6, 0.0)
	assert_lt(n1.dot(n2), 0.0)
	var normals: Array[Vector3] = [n1, n2]
	var v := SourceMove.clip_multi(Vector3(0.0, -10.0, -20.0), normals)
	assert_true(v.is_equal_approx(Vector3(0.0, 0.0, -20.0)), "got %s" % v)


# --- jump / gravity ---

func test_jump_replaces_y_keeps_horizontal() -> void:
	var v := SourceMove.jump(Vector3(3, -2, -5))
	assert_true(v.is_equal_approx(Vector3(3, 13.29, -5)))


func test_gravity_reduces_y() -> void:
	# 0 - GRAVITY(35.2) * 0.5 = -17.6
	var v := SourceMove.apply_gravity(Vector3(1, 0, 2), 0.5)
	assert_true(v.is_equal_approx(Vector3(1, -17.6, 2)))
