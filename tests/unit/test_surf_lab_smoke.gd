extends GutTest


func test_lab_scene_instantiates_with_player() -> void:
	var lab: Node3D = load("res://scenes/surf_lab.tscn").instantiate()
	add_child_autofree(lab)
	assert_eq(lab.name, "SurfLab")
	assert_not_null(lab.get_node_or_null("Player"))


func test_rounded_seam_arc_uses_1_5_m_facets() -> void:
	# one interior seam, 12 deg -> 17 deg pitch, both legs long enough for a 6 m arc
	var lab: Node3D = load("res://scenes/surf_lab.tscn").instantiate()
	add_child_autofree(lab)
	var seam := Vector3(0.0, 0.0, -20.0)
	var d1 := Vector3(0.0, -sin(deg_to_rad(12.0)), -cos(deg_to_rad(12.0)))
	var d2 := Vector3(0.0, -sin(deg_to_rad(17.0)), -cos(deg_to_rad(17.0)))
	var spine: Array[Vector3] = [seam - d1 * 20.0, seam, seam + d2 * 20.0]
	var out: Array[Vector3] = lab._fillet_spine(spine, 6.0)
	# first + last spine points around a 4-facet (5-sample) arc
	assert_eq(out.size(), 7, "6.0 m arc is 4 facets of 1.5 m")
	var arc: Array[Vector3] = out.slice(1, 6)
	var arc_len := 0.0
	for i in range(arc.size() - 1):
		var chord: float = arc[i].distance_to(arc[i + 1])
		assert_almost_eq(chord, 1.5, 0.01, "facet %d is ~1.5 m" % i)
		arc_len += chord
	assert_almost_eq(arc_len, 6.0, 0.05, "arc length preserved")
	# arc ends sit on the tangent lines of the original legs
	assert_almost_eq((arc[0] - seam).cross(d1).length(), 0.0, 0.001, "arc starts tangent to leg 1")
	assert_almost_eq((arc[4] - seam).cross(d2).length(), 0.0, 0.001, "arc ends tangent to leg 2")
