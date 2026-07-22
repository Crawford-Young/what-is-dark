extends GutTest


func test_player_scene_instantiates_and_readies() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate()
	add_child_autofree(player)
	assert_not_null(player)
	assert_false(player.frozen)
	assert_true(player.camera_forward().is_normalized())
