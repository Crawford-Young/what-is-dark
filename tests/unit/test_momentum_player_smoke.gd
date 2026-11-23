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


# Issue #20: is_on_floor() describes the last move_and_slide, so right after a
# teleport it still says "grounded" and the first tick used to apply ground
# friction to the spawn velocity (18 -> 17.4 m/s at 120 Hz).
const SPAWN_SPEED := 18.0


func _floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	return body


func _land(player: CharacterBody3D) -> void:
	for i in 240:
		await wait_physics_frames(1)
		if player.is_on_floor():
			return


func test_first_tick_after_a_grounded_teleport_keeps_the_spawn_speed() -> void:
	add_child_autofree(_floor())
	var player: MomentumPlayer = load("res://scenes/momentum_player.tscn").instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0, 1, 0)
	await _land(player)
	assert_true(player.is_on_floor(), "precondition: the player landed")
	player.teleport(Vector3(0, 0.95, 0), Vector3(0, 0, -1))
	player.velocity = Vector3(0, 0, -SPAWN_SPEED)
	await wait_physics_frames(1)
	var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(horizontal, SPAWN_SPEED, 0.0001, "no ground friction on the first tick")
