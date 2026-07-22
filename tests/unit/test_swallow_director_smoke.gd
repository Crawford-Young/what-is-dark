extends GutTest


func test_slice_scene_instantiates_with_swallow_director() -> void:
	var slice: Slice = load("res://scenes/slice.tscn").instantiate()
	add_child_autofree(slice)
	await wait_frames(2)
	assert_not_null(slice.get_node("SwallowDirector"))
	assert_true(slice.catch_armed)
