extends GutTest


func test_momentum_player_instantiates_and_readies() -> void:
	var player: MomentumPlayer = load("res://scenes/momentum_player.tscn").instantiate()
	add_child_autofree(player)
	assert_not_null(player)
	assert_eq(player.floor_snap_length, 0.0, "bhop must never floor-snap on landing frame")
	assert_eq(player.wall_min_slide_angle, 0.0, "surf ramps must slide at any wall angle")


func test_teleport_zeroes_velocity_and_faces_dir() -> void:
	var player: MomentumPlayer = load("res://scenes/momentum_player.tscn").instantiate()
	add_child_autofree(player)
	player.velocity = Vector3(5, 1, 5)
	player.teleport(Vector3(1, 2, 3), Vector3(0, 0, -1))
	assert_true(player.velocity.is_equal_approx(Vector3.ZERO))
	assert_almost_eq(player.rotation.y, 0.0, 0.0001)
