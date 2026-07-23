extends GutTest


func test_lab_scene_instantiates_with_player_and_stations() -> void:
	var lab: Node3D = load("res://scenes/momentum_lab.tscn").instantiate()
	add_child_autofree(lab)
	assert_not_null(lab.get_node_or_null("Player"))
	assert_gt(lab.get_node("Geometry").get_child_count(), 10, "stations built in _ready")
	assert_not_null(lab.get_node_or_null("HUD/SpeedLabel"))
