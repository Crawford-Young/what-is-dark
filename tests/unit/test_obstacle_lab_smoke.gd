extends GutTest
## Obstacle lab smoke + the parent §5.3 lines floor, read off the BUILT colliders
## (not the ROWS table that built them): every row leaves 2-3 viable lines at both
## bite levels.

const ROW_LABELS := ["PILLAR-1", "HURDLE-3", "ARCH-1", "PILLAR-2", "HURDLE-2", "ARCH-PILLAR"]


func _lab() -> Node3D:
	var lab: Node3D = load("res://scenes/obstacle_lab.tscn").instantiate()
	add_child_autofree(lab)
	return lab


func _capsule(lab: Node3D) -> CapsuleShape3D:
	return lab.get_node("Player/Collider").shape


## The rider's vertical extent passing a row: standing on the speed-cost floor, or
## anywhere on a jump arc from lip level up to its apex over the hard-stop void.
func _band(lab: Node3D, section: String) -> Vector2:
	var height := _capsule(lab).height
	if section == "speed_cost":
		return Vector2(0.0, height)
	var apex := SourceMove.JUMP_SPEED * SourceMove.JUMP_SPEED / (2.0 * SourceMove.GRAVITY)
	return Vector2(0.0, apex + height)


## Widths of the lateral clear gaps across the lane at a row: a body blocks when its
## box overlaps the rider's vertical band.
func _clear_widths(bodies: Array, lane_x: float, lane_width: float, band: Vector2) -> Array:
	var blocked := []
	for body in bodies:
		var size: Vector3 = (body.get_node("Col").shape as BoxShape3D).size
		var p: Vector3 = body.position
		if p.y - size.y / 2.0 < band.y and p.y + size.y / 2.0 > band.x:
			blocked.append([p.x - lane_x - size.x / 2.0, p.x - lane_x + size.x / 2.0])
	blocked.sort_custom(func(a, b): return a[0] < b[0])
	var widths := []
	var cursor := -lane_width / 2.0
	for span in blocked:
		if span[0] - cursor > 0.001:
			widths.append(span[0] - cursor)
		cursor = maxf(cursor, span[1])
	if lane_width / 2.0 - cursor > 0.001:
		widths.append(lane_width / 2.0 - cursor)
	return widths


## Lines through a row; -1 when a gap is passable but narrower than a line (an
## ambiguous squeeze the lines law could not classify).
func _lines(widths: Array, line_min: float, capsule_diameter: float) -> int:
	var lines := 0
	for w in widths:
		if w >= line_min - 0.001:
			lines += 1
		elif w >= capsule_diameter:
			return -1
	return lines


func _box(centre: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.position = centre
	var col := CollisionShape3D.new()
	col.name = "Col"
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = size
	body.add_child(col)
	return body


func test_lab_scene_instantiates_with_player() -> void:
	var lab := _lab()
	assert_eq(lab.name, "ObstacleLab")
	assert_not_null(lab.get_node_or_null("Player"))


func test_both_sections_carry_every_row() -> void:
	var lab := _lab()
	for section in ["speed_cost", "hard_stop"]:
		var labels := []
		for c in lab.CLUSTERS:
			if c["section"] == section:
				labels.append(c["label"])
		assert_eq(labels, ROW_LABELS, section)


func test_obstacles_are_named_obs_and_carry_no_metadata() -> void:
	var lab := _lab()
	var named := 0
	for node in lab.get_node("Geometry").get_children():
		if (node.name as String).begins_with("Obs"):
			named += 1
	var listed := 0
	for c in lab.CLUSTERS:
		for body in c["bodies"]:
			listed += 1
			assert_true((body.name as String).begins_with("Obs"), body.name)
			assert_eq(body.get_meta_list().size(), 0, "%s carries metadata" % body.name)
	assert_eq(named, listed, "every Obs* body belongs to a row")
	assert_gt(listed, 0)


func test_lines_counter_catches_a_blocked_row_and_a_squeeze() -> void:
	var full := [_box(Vector3(0.0, 0.25, 0.0), Vector3(8.4, 0.5, 0.3))]
	assert_eq(_lines(_clear_widths(full, 0.0, 8.4, Vector2(0.0, 1.8)), 1.6, 0.7), 0)
	var squeeze := [_box(Vector3(0.5, 1.5, 0.0), Vector3(7.4, 3.0, 0.6))]  # leaves 1.0 m at -x
	assert_eq(_lines(_clear_widths(squeeze, 0.0, 8.4, Vector2(0.0, 1.8)), 1.6, 0.7), -1)


func test_every_row_leaves_two_or_three_lines_at_both_bite_levels() -> void:
	var lab := _lab()
	var diameter := _capsule(lab).radius * 2.0
	for c in lab.CLUSTERS:
		var widths := _clear_widths(c["bodies"], c["x"], lab.LANE_WIDTH, _band(lab, c["section"]))
		var lines := _lines(widths, lab.LINE_MIN_WIDTH, diameter)
		var where := "%s %s widths=%s" % [c["section"], c["label"], widths]
		assert_between(lines, 2, 3, where)


func test_hard_stop_rows_stand_over_void_and_speed_cost_rows_on_floor() -> void:
	var lab := _lab()
	var floors := lab.get_tree().get_nodes_in_group(&"lab_floor")
	for c in lab.CLUSTERS:
		var covered := false
		for f in floors:
			var half: float = (f.get_node("Col").shape as BoxShape3D).size.z / 2.0
			if absf(f.position.x - c["x"]) < 0.01 and absf(f.position.z - c["z"]) <= half:
				covered = true
		assert_eq(covered, c["section"] == "speed_cost", "%s %s" % [c["section"], c["label"]])


func test_hard_stop_gap_is_clearable_from_a_bare_run() -> void:
	var lab := _lab()
	var airtime := 2.0 * SourceMove.JUMP_SPEED / SourceMove.GRAVITY
	assert_lt(lab.GAP_LENGTH, SourceMove.RUN_SPEED * airtime)


func test_hard_stop_fall_respawns_at_the_last_station_reached() -> void:
	var lab := _lab()
	var player: Player = lab.get_node("Player")
	var hs1: int = -1
	for i in lab.STATIONS.size():
		if lab.STATIONS[i]["section"] == "hard_stop":
			hs1 = i
			break
	lab._station = hs1
	lab._reset_to_station()
	var hs2: Dictionary = lab.STATIONS[hs1 + 1]
	var hs2_spawn: Vector3 = hs2["spawn"]
	player.teleport(Vector3(hs2_spawn.x, 0.0, hs2_spawn.z - 1.0), hs2["face"])
	await wait_physics_frames(10)
	assert_eq(lab._station, hs1 + 1, "landing past HS-2's spawn makes it the checkpoint")
	player.teleport(Vector3(hs2_spawn.x, lab._kill_y - 1.0, hs2_spawn.z - 20.0), hs2["face"])
	await wait_physics_frames(2)
	assert_lt(player.global_position.distance_to(hs2_spawn), 1.0, "respawned at HS-2")


func test_reset_spawns_the_rider_at_speed() -> void:
	var lab := _lab()
	var player: Player = lab.get_node("Player")
	player.velocity = Vector3.ZERO
	lab._reset_to_station()
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), lab.SPAWN_SPEED, 0.01)
