extends GutTest


func test_player_scene_instantiates_and_readies() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child_autofree(player)
	assert_not_null(player)
	assert_false(player.frozen)
	assert_true(player.camera_forward().is_normalized())


# Issue #20, same rule as the lab player: no stale floor state after teleport.
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


func test_first_tick_after_a_grounded_teleport_keeps_the_spawn_speed() -> void:
	add_child_autofree(_floor())
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0, 1, 0)
	for i in 240:
		await wait_physics_frames(1)
		if player.is_on_floor():
			break
	assert_true(player.is_on_floor(), "precondition: the player landed")
	player.teleport(Vector3(0, 0.95, 0), Vector3(0, 0, -1))
	player.velocity = Vector3(0, 0, -SPAWN_SPEED)
	await wait_physics_frames(1)
	var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
	assert_almost_eq(horizontal, SPAWN_SPEED, 0.0001, "no ground friction on the first tick")
