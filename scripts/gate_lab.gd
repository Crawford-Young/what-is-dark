extends Node3D
## Gate lab (4.1 T7): one straight lane per gate variant, side by side on x,
## for T8's sightline campaign. Lane (travel along -Z, floor top y = 0):
##   spawn (already moving at SPAWN_SPEED) -> RUN_UP_LENGTH of run-up ->
##   approach-start line (a visible floor strip) -> D m -> gate near edge ->
##   runout (retract) or a DEPLOY_GAP void then a landing floor (deploy).
## Tall side walls (WALL_HEIGHT) flank every floor so a lane cannot be skirted.
## Retract lanes are walled unbroken; deploy lanes are walled up to the gate
## plane and again along the landing floor, but NOT over the void: a wall there
## would be wall-rideable and let a rider skip the bridge.
## Every gate starts hidden and is revealed the tick the rider crosses its
## lane's approach line (user ruling, T7) -- so D is the true sightline budget.
## Station cycling follows the surf_lab pattern.
## Keys: N/P = next/previous station, R = restart the current station.

const GATE_DISTANCES := [30.0, 40.0, 50.0, 60.0]  ## approach line -> gate near edge, m
const TIMED_DISTANCE := 50.0  ## the timed gate's fixed approach distance
const TIMED_WINDOW := 1.5  ## initial timed re-close window, s (T8 sweeps it)
const RUN_UP_LENGTH := 60.0  ## spawn -> approach line (the rider is already at speed)
const SPAWN_SPEED := 35.0  ## m/s along the lane at every spawn (measured line speed 34-39)
const SPAWN_HEIGHT := 1.5  ## spawn origin y: ~0.6 m above standing rest (capsule 1.8 m), so
## the rider starts airborne and ground friction (FRICTION 4 -> ~7%/tick) cannot bleed
## SPAWN_SPEED before the first hop lands.
const SPAWN_BACK := 4.0  ## floor extends this far behind the spawn (+z)
const RUNOUT_LENGTH := 60.0  ## floor past a retract gate
const LANDING_LENGTH := 40.0  ## landing floor past a deploy gate's void gap
const LANE_WIDTH := 16.0  ## floor width = gate corridor width: no way around a barrier
const DEPLOY_GAP := 35.0  ## void length of a deploy lane (GateNode.gap_length)
const WALL_HEIGHT := 12.0  ## side walls: well over the 6 m barrier, out of wall-kick reach
const WALL_THICKNESS := 1.0
const LANE_SPACING := 40.0  ## lane centre-to-centre on x
const FLOOR_THICKNESS := 1.0
const LINE_DEPTH := 0.5  ## approach-line strip z-length
const FACE_FORWARD := Vector3(0.0, 0.0, -1.0)

var _station := 0
var _lowest_geometry_y := INF
var _kill_y := -1000.0

var STATIONS: Array = []  ## populated by _build_lanes(): [{"label","spawn","face","gate","line_z"}, ...]

# DEBUG PROBE — remove before gates: per-run rider telemetry (T8 sightline probe + "obstacles are not hard" diagnosis).
const PROBE_CAPTURE_DIR := "res://tools/probe/captures"  ## DEBUG PROBE — git-excluded via tools/probe/
const PROBE_PASS_MARGIN := 5.0  ## DEBUG PROBE — a run ends this far (m) past the gate plane
const PROBE_SLAM_ZONE := 3.0  ## DEBUG PROBE — SLAM window: this many m before the gate plane
const PROBE_SLAM_DROP := 0.5  ## DEBUG PROBE — SLAM = zone min speed < this fraction of zone entry speed
const PROBE_FLUSH_TICKS := 30  ## DEBUG PROBE — CSV flush cadence (events flush immediately)
const PROBE_COLUMNS := "tick,station,x,y,z,hspeed,gate_state,openness,revealed,event"  ## DEBUG PROBE
var _probe_file: FileAccess  ## DEBUG PROBE
var _probe_path := ""  ## DEBUG PROBE
var _probe_cur := {}  ## DEBUG PROBE — station dict of the latest run (rows keep logging after a run ends)
var _probe_run := {}  ## DEBUG PROBE — active run record; empty = no run in flight


@onready var _player: Player = $Player
@onready var _speed_label: Label = $HUD/SpeedLabel
@onready var _station_label: Label = $HUD/StationLabel
@onready var _gate_label: Label = $HUD/GateLabel


func _ready() -> void:
	_build_lanes()
	_kill_y = _lowest_geometry_y - 10.0  # from the FINAL built geometry (T1's builder rule)
	_reset_to_station()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_N:
				_station = (_station + 1) % STATIONS.size()
				_reset_to_station()
			KEY_P:
				_station = (_station - 1 + STATIONS.size()) % STATIONS.size()
				_reset_to_station()
			KEY_R:
				_reset_to_station()


func _physics_process(_delta: float) -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_speed_label.text = "%.2f m/s" % speed
	if _player.global_position.y < _kill_y:
		_reset_to_station()
		return
	var s: Dictionary = STATIONS[_station]
	var gate: GateNode = s["gate"]
	if not gate.is_revealed() and _player.global_position.z <= s["line_z"]:
		gate.reveal()
	_gate_label.text = "%s / %s" % [GateLogic.State.keys()[gate.logic.state],
		"revealed" if gate.is_revealed() else "hidden"]
	_probe_tick(speed)  ## DEBUG PROBE


## Teleport to the station spawn and put its gate back to SHUT + hidden.
func _reset_to_station() -> void:
	_probe_on_reset()  ## DEBUG PROBE
	var s: Dictionary = STATIONS[_station]
	_player.teleport(s["spawn"], s["face"])
	_player.velocity = (s["face"] as Vector3) * SPAWN_SPEED  # teleport() zeroes velocity
	(s["gate"] as GateNode).reset()
	_station_label.text = s["label"]
	_probe_begin_run()  ## DEBUG PROBE


func _build_lanes() -> void:
	var lane := 0
	for kind in ["retract", "deploy"]:
		for d in GATE_DISTANCES:
			_build_lane(lane * LANE_SPACING, "%s-%d" % [kind.to_upper(), int(d)], kind, d, GateLogic.NO_RECLOSE)
			lane += 1
	_build_lane(lane * LANE_SPACING, "TIMED-%d" % int(TIMED_DISTANCE), "retract", TIMED_DISTANCE, TIMED_WINDOW)


func _build_lane(x: float, label: String, kind: String, distance: float, window: float) -> void:
	var line_z := -RUN_UP_LENGTH
	var gate_z := line_z - distance

	var gate := GateNode.new()
	gate.kind = kind
	gate.timed_window = window
	gate.corridor_width = LANE_WIDTH
	gate.start_hidden = true
	if kind == "deploy":
		gate.gap_length = DEPLOY_GAP
	gate.position = Vector3(x, 0.0, gate_z)
	$Geometry.add_child(gate)

	var far_z := gate_z - RUNOUT_LENGTH
	if kind == "deploy":
		far_z = gate_z  # the approach floor ends at the near lip; the bridge spans the void
		var landing_near := gate_z - gate.gap_length
		_add_floor(x, landing_near, landing_near - LANDING_LENGTH)
		_add_walls(x, landing_near, landing_near - LANDING_LENGTH)
	_add_floor(x, SPAWN_BACK, far_z)
	_add_walls(x, SPAWN_BACK, far_z)
	_add_line_strip(x, line_z)

	STATIONS.append({"label": label, "spawn": Vector3(x, SPAWN_HEIGHT, 0.0), "face": FACE_FORWARD,
		"gate": gate, "line_z": line_z})


## A floor slab of LANE_WIDTH, top at y = 0, spanning near_z down to far_z.
func _add_floor(x: float, near_z: float, far_z: float) -> void:
	var length := near_z - far_z
	var size := Vector3(LANE_WIDTH, FLOOR_THICKNESS, length)
	var body := StaticBody3D.new()
	body.position = Vector3(x, -FLOOR_THICKNESS / 2.0, (near_z + far_z) / 2.0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.add_child(_box_mesh(size, Color(0.4, 0.4, 0.42), false))
	$Geometry.add_child(body)
	_track_lowest(body.position.y - FLOOR_THICKNESS / 2.0)


## Both side walls over [far_z, near_z]: inner faces flush with the floor edge,
## top at WALL_HEIGHT. Grouped "lab_wall" so tests can inspect their extents.
func _add_walls(x: float, near_z: float, far_z: float) -> void:
	var size := Vector3(WALL_THICKNESS, WALL_HEIGHT, near_z - far_z)
	for side in [-1.0, 1.0]:
		var body := StaticBody3D.new()
		body.position = Vector3(x + side * (LANE_WIDTH + WALL_THICKNESS) / 2.0,
			WALL_HEIGHT / 2.0, (near_z + far_z) / 2.0)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		body.add_child(_box_mesh(size, Color(0.3, 0.3, 0.34), false))
		body.add_to_group(&"lab_wall")
		$Geometry.add_child(body)


## The approach-start line: visual only (no collider), so it never bumps a hop.
func _add_line_strip(x: float, z: float) -> void:
	var mesh := _box_mesh(Vector3(LANE_WIDTH, 0.02, LINE_DEPTH), Color(0.1, 1.0, 0.9), true)
	mesh.position = Vector3(x, 0.01, z)
	$Geometry.add_child(mesh)


func _box_mesh(size: Vector3, color: Color, unshaded: bool) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	return mesh


## Kill-plane tracking (surf_lab R1 #14): the plane sits below every built surface.
func _track_lowest(y: float) -> void:
	_lowest_geometry_y = minf(_lowest_geometry_y, y)


## DEBUG PROBE — opens the CSV sink once and prints the GATE_PROBE header.
func _probe_open() -> void:
	if _probe_path != "":
		return
	var dir := ProjectSettings.globalize_path(PROBE_CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_probe_path = "%s/gate_%s.csv" % [dir, stamp]
	_probe_file = FileAccess.open(_probe_path, FileAccess.WRITE)
	print("GATE_PROBE: capture=%s PASS_MARGIN=%.1f SLAM_ZONE=%.1f SLAM_DROP=%.2f FLUSH_TICKS=%d ACTIVATE_RANGE=%.0f OPEN_THRESHOLD=%.2f tick_hz=%d | outcome := OPEN_PASS (open at gate plane) / SHUT_PASS_AROUND (|x off| > corridor half-width) / SHUT_PASS_OVER (y > barrier_height) / SLAM (min speed in last SLAM_ZONE m before plane < SLAM_DROP * zone entry speed, plane never reached) / FALL (respawn) / NO_ARRIVAL (reset before plane); SHUT_PASS_OTHER = shut at plane, neither around nor over" % [
		_probe_path, PROBE_PASS_MARGIN, PROBE_SLAM_ZONE, PROBE_SLAM_DROP, PROBE_FLUSH_TICKS,
		Player.ACTIVATE_RANGE, GateNode.OPEN_THRESHOLD, Engine.physics_ticks_per_second])
	if _probe_file:
		_probe_file.store_line(PROBE_COLUMNS)
		_probe_file.flush()


## DEBUG PROBE — run record for the station the rider was just placed on.
func _probe_begin_run() -> void:
	_probe_cur = STATIONS[_station]
	var gate: GateNode = _probe_cur["gate"]
	_probe_run = {"gate_z": gate.global_position.z, "lane_x": gate.global_position.x,
		"line_tick": -1, "line_speed": 0.0, "click_tick": -1, "click_dist": 0.0,
		"click_hit": "NONE", "click_revealed": false, "clicks": 0, "plane_tick": -1,
		"plane_state": "", "plane_open": 0.0, "plane_xoff": 0.0, "plane_y": 0.0,
		"max_xoff": 0.0, "zone_speed": -1.0, "zone_min": 0.0}


## DEBUG PROBE — a reset/respawn ends the run in flight (called before the teleport).
func _probe_on_reset() -> void:
	_probe_open()
	if _probe_cur.is_empty():
		return
	var respawn := _player.global_position.y < _kill_y
	_probe_row("RESPAWN" if respawn else "RESET")
	if not _probe_run.is_empty():
		_probe_finish("FALL" if respawn else "")
	if _probe_file:
		_probe_file.flush()


## DEBUG PROBE — one CSV row per physics tick, plus run bookkeeping and click polling.
func _probe_tick(speed: float) -> void:
	if _probe_cur.is_empty():
		return
	var p := _player.global_position
	var tick := Engine.get_physics_frames()
	var events: Array = []
	if not _probe_run.is_empty():
		_probe_track(p, speed, tick, events)
	if Input.is_action_just_pressed(&"activate"):
		events.append("CLICK")
		_probe_click(p, tick)
	_probe_row("|".join(events))
	if not events.is_empty() or tick % PROBE_FLUSH_TICKS == 0:
		if _probe_file:
			_probe_file.flush()


## DEBUG PROBE — line crossing, gate-plane arrival, slam zone and run end.
func _probe_track(p: Vector3, speed: float, tick: int, events: Array) -> void:
	var r := _probe_run
	var gate: GateNode = _probe_cur["gate"]
	var gate_z: float = r["gate_z"]
	if r["line_tick"] < 0 and p.z <= float(_probe_cur["line_z"]):
		r["line_tick"] = tick
		r["line_speed"] = speed
		events.append("LINE_CROSS")
	if r["line_tick"] >= 0 and r["plane_tick"] < 0:
		r["max_xoff"] = maxf(r["max_xoff"], absf(p.x - r["lane_x"]))
	if r["plane_tick"] < 0 and p.z <= gate_z + PROBE_SLAM_ZONE and p.z > gate_z:
		if r["zone_speed"] < 0.0:
			r["zone_speed"] = speed
			r["zone_min"] = speed
		r["zone_min"] = minf(r["zone_min"], speed)
	if r["plane_tick"] < 0 and p.z <= gate_z:
		r["plane_tick"] = tick
		r["plane_state"] = GateLogic.State.keys()[gate.logic.state]
		r["plane_open"] = gate.logic.openness()
		r["plane_xoff"] = p.x - r["lane_x"]
		r["plane_y"] = p.y
		events.append("GATE_PLANE")
	if r["plane_tick"] >= 0 and p.z <= gate_z - PROBE_PASS_MARGIN:
		_probe_finish("")


## DEBUG PROBE — classifies the click; click_* fields record the OPENING click, `clicks` counts all.
func _probe_click(p: Vector3, tick: int) -> void:
	var gate: GateNode = _probe_cur["gate"]
	var hit_class := _probe_classify(gate)
	if _probe_run.is_empty():
		return
	var r := _probe_run
	r["clicks"] += 1
	# Opening click = first click after the line that is a TARGET hit while revealed
	# (only the Target body opens a gate); a miss or a barrier/bridge click is not it.
	if r["line_tick"] >= 0 and r["click_tick"] < 0 and hit_class == "TARGET" and gate.is_revealed():
		r["click_tick"] = tick
		r["click_dist"] = p.z - float(r["gate_z"])
		r["click_hit"] = hit_class
		r["click_revealed"] = gate.is_revealed()


## DEBUG PROBE — the same ray the player casts: TARGET / BARRIER / BRIDGE / OTHER / NONE.
func _probe_classify(gate: GateNode) -> String:
	var from := (_player.get_node("Head/Camera") as Camera3D).global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + _player.camera_forward() * Player.ACTIVATE_RANGE)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "NONE"
	var collider := hit.collider as Node
	if GateNode.resolve_gate(collider) != gate:
		return "OTHER"
	match String(collider.name):
		"Target":
			return "TARGET"
		"Barrier":
			return "BARRIER"
		"Bridge":
			return "BRIDGE"
	return "OTHER"


## DEBUG PROBE — outcome from the recorded run; forced is "FALL" on a respawn.
func _probe_outcome(forced: String) -> String:
	if forced != "":
		return forced
	var r := _probe_run
	var gate: GateNode = _probe_cur["gate"]
	if r["plane_tick"] < 0:
		var slam: bool = r["zone_speed"] >= 0.0 and r["zone_min"] < PROBE_SLAM_DROP * r["zone_speed"]
		return "SLAM" if slam else "NO_ARRIVAL"
	if r["plane_open"] >= GateNode.OPEN_THRESHOLD:
		return "OPEN_PASS"
	if absf(r["plane_xoff"]) > gate.corridor_width / 2.0:
		return "SHUT_PASS_AROUND"
	if r["plane_y"] > gate.barrier_height:
		return "SHUT_PASS_OVER"
	return "SHUT_PASS_OTHER"


## DEBUG PROBE — prints the one GATE_RUN summary line and closes the run.
func _probe_finish(forced: String) -> void:
	var r := _probe_run
	var hz := float(Engine.physics_ticks_per_second)
	var has_click: bool = r["click_tick"] >= 0
	var dt: int = r["click_tick"] - r["line_tick"]
	print("GATE_RUN station=%s outcome=%s line_speed=%s click_ticks=%s click_s=%s click_dist=%s click_hit=%s click_revealed=%s clicks=%d plane_state=%s plane_open=%s plane_xoff=%s plane_y=%s max_xoff=%.2f" % [
		_probe_cur["label"], _probe_outcome(forced),
		("%.2f" % r["line_speed"]) if r["line_tick"] >= 0 else "NA",
		str(dt) if has_click else "NA", ("%.3f" % (dt / hz)) if has_click else "NA",
		("%.2f" % r["click_dist"]) if has_click else "NA", r["click_hit"] if has_click else "NA",
		str(r["click_revealed"]) if has_click else "NA", r["clicks"],
		r["plane_state"] if r["plane_tick"] >= 0 else "NA",
		("%.2f" % r["plane_open"]) if r["plane_tick"] >= 0 else "NA",
		("%.2f" % r["plane_xoff"]) if r["plane_tick"] >= 0 else "NA",
		("%.2f" % r["plane_y"]) if r["plane_tick"] >= 0 else "NA", r["max_xoff"]])
	_probe_run = {}


## DEBUG PROBE — appends one CSV row; the event column joins same-tick events with "|".
func _probe_row(event: String) -> void:
	if _probe_file == null or _probe_cur.is_empty():
		return
	var gate: GateNode = _probe_cur["gate"]
	var p := _player.global_position
	_probe_file.store_line("%d,%s,%.4f,%.4f,%.4f,%.4f,%s,%.3f,%d,%s" % [
		Engine.get_physics_frames(), _probe_cur["label"], p.x, p.y, p.z,
		Vector2(_player.velocity.x, _player.velocity.z).length(),
		GateLogic.State.keys()[gate.logic.state], gate.logic.openness(),
		1 if gate.is_revealed() else 0, event])
