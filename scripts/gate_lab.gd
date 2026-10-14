extends Node3D
## Gate lab (4.1 T7): one straight lane per gate variant, side by side on x,
## for T8's sightline campaign. Lane (travel along -Z, floor top y = 0):
##   spawn -> RUN_UP_LENGTH of bhop run-up -> approach-start line (a visible
##   floor strip) -> D m -> gate near edge -> runout (retract) or a void gap of
##   the bridge's gap_length then a landing floor (deploy).
## Every gate starts hidden and is revealed the tick the rider crosses its
## lane's approach line (user ruling, T7) -- so D is the true sightline budget.
## Station cycling follows the surf_lab pattern.
## Keys: N/P = next/previous station, R = restart the current station.

const GATE_DISTANCES := [30.0, 40.0, 50.0, 60.0]  ## approach line -> gate near edge, m
const TIMED_DISTANCE := 50.0  ## the timed gate's fixed approach distance
const TIMED_WINDOW := 1.5  ## initial timed re-close window, s (T8 sweeps it)
const RUN_UP_LENGTH := 300.0  ## spawn -> approach line. Generous on purpose: room to
## strafe-hop from RUN_SPEED 11 up to ~25 m/s with distance to spare; the rider
## verifies the reached speed on the HUD SpeedLabel.
const SPAWN_BACK := 4.0  ## floor extends this far behind the spawn (+z)
const RUNOUT_LENGTH := 60.0  ## floor past a retract gate
const LANDING_LENGTH := 40.0  ## landing floor past a deploy gate's void gap
const LANE_WIDTH := 16.0  ## floor width = gate corridor width: no way around a barrier
const LANE_SPACING := 40.0  ## lane centre-to-centre on x
const FLOOR_THICKNESS := 1.0
const LINE_DEPTH := 0.5  ## approach-line strip z-length
const FACE_FORWARD := Vector3(0.0, 0.0, -1.0)

var _station := 0
var _lowest_geometry_y := INF
var _kill_y := -1000.0

var STATIONS: Array = []  ## populated by _build_lanes(): [{"label","spawn","face","gate","line_z"}, ...]

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


## Teleport to the station spawn and put its gate back to SHUT + hidden.
func _reset_to_station() -> void:
	var s: Dictionary = STATIONS[_station]
	_player.teleport(s["spawn"], s["face"])
	(s["gate"] as GateNode).reset()
	_station_label.text = s["label"]


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
	gate.position = Vector3(x, 0.0, gate_z)
	$Geometry.add_child(gate)

	var far_z := gate_z - RUNOUT_LENGTH
	if kind == "deploy":
		far_z = gate_z  # the approach floor ends at the near lip; the bridge spans the void
		var landing_near := gate_z - gate.gap_length
		_add_floor(x, landing_near, landing_near - LANDING_LENGTH)
	_add_floor(x, SPAWN_BACK, far_z)
	_add_line_strip(x, line_z)

	STATIONS.append({"label": label, "spawn": Vector3(x, 1.0, 0.0), "face": FACE_FORWARD,
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
