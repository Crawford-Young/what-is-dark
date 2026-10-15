extends GutTest


func test_lab_scene_instantiates_with_player() -> void:
	var lab: Node3D = load("res://scenes/surf_lab.tscn").instantiate()
	add_child_autofree(lab)
	assert_eq(lab.name, "SurfLab")
	assert_not_null(lab.get_node_or_null("Player"))
