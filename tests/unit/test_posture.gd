extends GutTest


func test_glance_held_wins_regardless_of_camera() -> void:
	assert_eq(Posture.evaluate(Vector3(0, 0, -1), Vector3(0, 0, 1), true), Posture.GLANCING)
	assert_eq(Posture.evaluate(Vector3(0, 0, 1), Vector3(0, 0, 1), true), Posture.GLANCING)


func test_camera_toward_void_is_facing() -> void:
	assert_eq(Posture.evaluate(Vector3(0, 0, 1), Vector3(0, 0, 1), false), Posture.FACING)


func test_camera_away_from_void_is_away() -> void:
	assert_eq(Posture.evaluate(Vector3(0, 0, -1), Vector3(0, 0, 1), false), Posture.AWAY)


func test_threshold_at_half_dot() -> void:
	var just_over := Vector3(0, 0, 1).rotated(Vector3.UP, 1.0)  # dot ≈ 0.54
	assert_eq(Posture.evaluate(just_over, Vector3(0, 0, 1), false), Posture.FACING)
	var just_under := Vector3(0, 0, 1).rotated(Vector3.UP, 1.1)  # dot ≈ 0.45
	assert_eq(Posture.evaluate(just_under, Vector3(0, 0, 1), false), Posture.AWAY)
