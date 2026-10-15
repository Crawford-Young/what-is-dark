extends Node3D
## Obstacle lab (4.1 T11): parent §5.3's obstacle vocabulary at both bite levels,
## two lanes side by side on x. No new mechanic code -- the collision solver
## supplies the punishment. Lane (travel along -Z, floor top y = 0):
##   SPEED-COST: one solid walled straight with an obstacle row every
##     CLUSTER_SPACING. A clip scrubs speed and breaks the hop chain; the rider
##     keeps moving.
##   HARD-STOP: the same rows, each standing mid-gap over a GAP_LENGTH void at
##     lip level. A clip kills horizontal speed over the drop -> kill plane ->
##     respawn (the lab's stand-in for the course's existing fall/reset path).
## Every row leaves 2-3 viable lines at both bite levels (parent §5.3's
## >=2-lines floor, plan R2 #12). A line is a lateral clear passage of at least
## LINE_MIN_WIDTH inside the lane. Hurdle bars count as blocking (jumping one is
## not counted as a line), and over the void an arch's opening is no line: a
## jump arc mid-gap always reaches its lintel.
## Obstacle bodies are named Obs* and carry no metadata -- the `obstacle` role is
## declared in 4.1b's lab fixture manifests (plan R1 #16).
## Station cycling follows the gate_lab pattern. The hard-stop lane has one
## station per row, advanced automatically as the rider lands past each one, so
## a fall respawns before the row that caused it.
## Keys: N/P = next/previous station, R = restart the current station.

const PILLAR_SIZE := Vector3(0.6, 3.0, 0.6)
const ARCH_OPENING := Vector2(1.6, 2.2)  ## w x h between the pillars, under the lintel
const HURDLE_HEIGHT := 0.5  ## jumpable: there is no crouch/slide verb
const HURDLE_DEPTH := 0.3
const LANE_WIDTH := 8.4  ## exactly three arch footprints (0.6 + 1.6 + 0.6 m each)
const LINE_MIN_WIDTH := 1.6  ## narrowest passage counted as a line = the arch opening

## One row per cluster, the same rows in both sections. Shapes: ["pillar", x] and
## ["arch", x] by centre, ["hurdle", x_left, x_right]; x is lane-relative and the
## lane edges sit at +-LANE_WIDTH / 2. Every clear gap is either 0 or a full line.
const ROWS := [
	{"label": "PILLAR-1", "shapes": [["pillar", 0.0]]},  ## lines: 2 speed-cost / 2 hard-stop
	{"label": "HURDLE-3", "shapes": [["hurdle", -2.0, -0.8], ["hurdle", 0.8, 2.0]]},  ## 3 / 3
	{"label": "ARCH-1", "shapes": [["arch", 0.0]]},  ## 3 / 2
	{"label": "PILLAR-2", "shapes": [["pillar", -1.4], ["pillar", 1.4]]},  ## 3 / 3
	{"label": "HURDLE-2",
		"shapes": [["hurdle", -4.2, -2.4], ["hurdle", -0.8, 0.8], ["hurdle", 2.4, 4.2]]},  ## 2 / 2
	{"label": "ARCH-PILLAR", "shapes": [["arch", -2.8], ["pillar", 1.4]]},  ## 3 / 2
]

const RUN_UP_LENGTH := 40.0  ## spawn -> first row
const CLUSTER_SPACING := 30.0  ## row to row
const RUNOUT_LENGTH := 30.0  ## floor past the last row (hard-stop: past its far lip)
const GAP_LENGTH := 6.0  ## hard-stop void, row centred in it; under the 8.31 m flat jump
## reach at RUN_SPEED, so every hard-stop gap is clearable from a bare run
const SPAWN_SPEED := 18.0  ## m/s along the lane at every spawn -- inside the 15-19 m/s
## natural speed the user kept in the gate lab (2026-10-14)
const SPAWN_HEIGHT := 1.5  ## spawn origin (feet) y: the rider starts airborne, as in gate_lab
const SPAWN_BACK := 4.0  ## floor extends this far behind the spawn (+z)
const STATION_INSET := 2.0  ## a hard-stop row station spawns this far past the previous far lip
const WALL_HEIGHT := 12.0  ## side walls, out of wall-kick reach (gate_lab value)
const WALL_THICKNESS := 1.0
const LANE_SPACING := 40.0  ## lane centre-to-centre on x
const FLOOR_THICKNESS := 1.0
const FACE_FORWARD := Vector3(0.0, 0.0, -1.0)

var _station := 0
var _lowest_geometry_y := INF
var _kill_y := -1000.0

var STATIONS: Array = []  ## [{"label","spawn","face","section"}, ...]
var CLUSTERS: Array = []  ## [{"section","label","x","z","bodies"}, ...] -- every Obs* body, by row

@onready var _player: Player = $Player
@onready var _speed_label: Label = $HUD/SpeedLabel
@onready var _station_label: Label = $HUD/StationLabel


func _ready() -> void:
	_build_speed_cost(0.0)
	_build_hard_stop(LANE_SPACING)
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
	_advance_checkpoint()


func _reset_to_station() -> void:
	var s: Dictionary = STATIONS[_station]
	_player.teleport(s["spawn"], s["face"])
	_player.velocity = (s["face"] as Vector3) * SPAWN_SPEED  # teleport() zeroes velocity
	_station_label.text = s["label"]


## Landing past the next station's spawn on the same lane makes it the current
## station, so a later fall respawns there rather than at the lane start.
func _advance_checkpoint() -> void:
	var next := _station + 1
	if next >= STATIONS.size() or STATIONS[next]["section"] != STATIONS[_station]["section"]:
		return
	if _player.is_on_floor() and _player.global_position.z <= (STATIONS[next]["spawn"] as Vector3).z:
		_station = next
		_station_label.text = STATIONS[_station]["label"]


func _row_z(index: int) -> float:
	return -(RUN_UP_LENGTH + index * CLUSTER_SPACING)


func _build_speed_cost(x: float) -> void:
	var far_z := _row_z(ROWS.size() - 1) - RUNOUT_LENGTH
	_add_floor(x, SPAWN_BACK, far_z)
	_add_walls(x, SPAWN_BACK, far_z)
	for i in ROWS.size():
		_build_row("speed_cost", "SC", i, x)
	STATIONS.append({"label": "SPEED-COST", "spawn": Vector3(x, SPAWN_HEIGHT, 0.0),
		"face": FACE_FORWARD, "section": "speed_cost"})


## Floor segments run lip to lip with a GAP_LENGTH void centred on each row.
## Walls follow the floor only: a wall over the void would be wall-rideable
## past the row (the gate_lab deploy-lane ruling).
func _build_hard_stop(x: float) -> void:
	var near_z := SPAWN_BACK
	var spawn_z := 0.0
	for i in ROWS.size():
		var near_lip := _row_z(i) + GAP_LENGTH / 2.0
		_add_floor(x, near_z, near_lip)
		_add_walls(x, near_z, near_lip)
		_build_row("hard_stop", "HS", i, x)
		STATIONS.append({"label": "HS-%d %s" % [i + 1, ROWS[i]["label"]],
			"spawn": Vector3(x, SPAWN_HEIGHT, spawn_z), "face": FACE_FORWARD, "section": "hard_stop"})
		near_z = near_lip - GAP_LENGTH
		spawn_z = near_z - STATION_INSET
	_add_floor(x, near_z, near_z - RUNOUT_LENGTH)
	_add_walls(x, near_z, near_z - RUNOUT_LENGTH)


## Builds ROWS[index] across the lane at x, every box its own Obs* body named
## Obs<section tag><row number><shape><shape letter>[part], e.g. ObsHS6ArchAPillarL.
func _build_row(section: String, tag: String, index: int, x: float) -> void:
	var z := _row_z(index)
	var bodies: Array = []
	var shapes: Array = ROWS[index]["shapes"]
	for n in shapes.size():
		var shape: Array = shapes[n]
		var obs_name := "Obs%s%d%s%s" % [tag, index + 1, (shape[0] as String).capitalize(), String.chr(65 + n)]
		match shape[0]:
			"pillar":
				bodies.append(_add_obstacle(obs_name, Vector3(x + shape[1], PILLAR_SIZE.y / 2.0, z), PILLAR_SIZE))
			"arch":
				var offset := (ARCH_OPENING.x + PILLAR_SIZE.x) / 2.0
				for side in [["L", -1.0], ["R", 1.0]]:
					bodies.append(_add_obstacle(obs_name + "Pillar" + side[0],
						Vector3(x + shape[1] + side[1] * offset, PILLAR_SIZE.y / 2.0, z), PILLAR_SIZE))
				var lintel := Vector3(ARCH_OPENING.x, PILLAR_SIZE.y - ARCH_OPENING.y, PILLAR_SIZE.z)
				bodies.append(_add_obstacle(obs_name + "Lintel",
					Vector3(x + shape[1], ARCH_OPENING.y + lintel.y / 2.0, z), lintel))
			"hurdle":
				var size := Vector3(shape[2] - shape[1], HURDLE_HEIGHT, HURDLE_DEPTH)
				bodies.append(_add_obstacle(obs_name,
					Vector3(x + (shape[1] + shape[2]) / 2.0, HURDLE_HEIGHT / 2.0, z), size))
	CLUSTERS.append({"section": section, "label": ROWS[index]["label"], "x": x, "z": z, "bodies": bodies})


func _add_obstacle(obs_name: String, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := _box_body(centre, size, Color(0.85, 0.45, 0.15))
	body.name = obs_name
	$Geometry.add_child(body)
	return body


## A floor slab of LANE_WIDTH, top at y = 0, spanning near_z down to far_z.
## Grouped "lab_floor" so tests can check which rows stand over void.
func _add_floor(x: float, near_z: float, far_z: float) -> void:
	var body := _box_body(Vector3(x, -FLOOR_THICKNESS / 2.0, (near_z + far_z) / 2.0),
		Vector3(LANE_WIDTH, FLOOR_THICKNESS, near_z - far_z), Color(0.4, 0.4, 0.42))
	body.add_to_group(&"lab_floor")
	$Geometry.add_child(body)
	_track_lowest(-FLOOR_THICKNESS)


## Both side walls over [far_z, near_z]: inner faces flush with the floor edge.
func _add_walls(x: float, near_z: float, far_z: float) -> void:
	var size := Vector3(WALL_THICKNESS, WALL_HEIGHT, near_z - far_z)
	for side in [-1.0, 1.0]:
		var centre := Vector3(x + side * (LANE_WIDTH + WALL_THICKNESS) / 2.0, WALL_HEIGHT / 2.0,
			(near_z + far_z) / 2.0)
		$Geometry.add_child(_box_body(centre, size, Color(0.3, 0.3, 0.34)))


## A StaticBody3D with `Col` + `Mesh` children, the course's body contract.
func _box_body(centre: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = centre
	var col := CollisionShape3D.new()
	col.name = "Col"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = box
	body.add_child(mesh)
	return body


## Kill-plane tracking (surf_lab R1 #14): the plane sits below every built surface.
func _track_lowest(y: float) -> void:
	_lowest_geometry_y = minf(_lowest_geometry_y, y)
