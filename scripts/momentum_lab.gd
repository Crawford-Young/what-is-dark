extends Node3D
## Momentum lab: 3 stations (bhop runway, strafe field, surf run), HUD, hotkey teleports.
## Keys: 1/2/3 = station select+teleport, R = reset to current station.

const STATIONS := [
	{"label": "1 BHOP", "spawn": Vector3(0, 1.0, 5.0)},
	{"label": "2 STRAFE", "spawn": Vector3(40, 1.0, 0.0)},
	{"label": "3 SURF", "spawn": Vector3(90, 13.0, 10.0)},
]
const RAMP_ANGLES := [50.0, 55.0, 60.0]
const RAMP_PEAK_Y := 10.0
const RAMP_HALF_WIDTH := 6.0

var _station := 0
var _peak_speed := 0.0
var _last_takeoff := 0.0
var _prev_takeoff := 0.0
var _was_on_floor := true

@onready var _player: MomentumPlayer = $Player
@onready var _speed_label: Label = $HUD/SpeedLabel
@onready var _peak_label: Label = $HUD/PeakLabel
@onready var _hop_label: Label = $HUD/HopLabel
@onready var _station_label: Label = $HUD/StationLabel


func _ready() -> void:
	_build_bhop_runway()
	_build_strafe_field()
	_build_surf_run()
	_reset_to_station()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_reset_to_station()
			KEY_1:
				_station = 0
				_reset_to_station()
			KEY_2:
				_station = 1
				_reset_to_station()
			KEY_3:
				_station = 2
				_reset_to_station()


func _physics_process(_delta: float) -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_peak_speed = maxf(_peak_speed, speed)
	var on_floor := _player.is_on_floor()
	if _was_on_floor and not on_floor:
		_prev_takeoff = _last_takeoff
		_last_takeoff = speed
	_was_on_floor = on_floor

	_speed_label.text = "%.2f m/s" % speed
	_peak_label.text = "peak %.2f" % _peak_speed
	_hop_label.text = "hop Δ %+.2f" % (_last_takeoff - _prev_takeoff)


func _reset_to_station() -> void:
	var s: Dictionary = STATIONS[_station]
	_player.teleport(s["spawn"], Vector3(0, 0, -1))
	_peak_speed = 0.0
	_last_takeoff = 0.0
	_prev_takeoff = 0.0
	_station_label.text = s["label"]


func _build_bhop_runway() -> void:
	_add_box(Vector3(0, -0.5, -95), Vector3(8, 1, 200), 0.0, Color(0.25, 0.28, 0.35))
	for i in range(7):
		var z := -20.0 - 25.0 * i
		_add_box(Vector3(0, 0.06, z), Vector3(8, 0.1, 0.4), 0.0, Color(0.9, 0.6, 0.2))


func _build_strafe_field() -> void:
	_add_box(Vector3(40, -0.5, -25), Vector3(60, 1, 60), 0.0, Color(0.24, 0.33, 0.27))


func _build_surf_run() -> void:
	_add_box(Vector3(90, -0.5, -90), Vector3(30, 1, 190), 0.0, Color(0.2, 0.2, 0.24))
	_add_box(Vector3(90, 11.5, 12), Vector3(6, 1, 6), 0.0, Color(0.5, 0.4, 0.3))
	for i in range(RAMP_ANGLES.size()):
		_ramp_pair(-5.0 - 40.0 * i, RAMP_ANGLES[i])


func _ramp_pair(z_center: float, angle_deg: float) -> void:
	var a := deg_to_rad(angle_deg)
	for side in [-1.0, 1.0]:
		var center := Vector3(
			90.0 + side * RAMP_HALF_WIDTH * cos(a),
			RAMP_PEAK_Y - RAMP_HALF_WIDTH * sin(a),
			z_center)
		_add_box(center, Vector3(RAMP_HALF_WIDTH * 2.0, 0.5, 30), -side * angle_deg, Color(0.45, 0.3, 0.5))


func _add_box(pos: Vector3, size: Vector3, rot_z_deg: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.z = deg_to_rad(rot_z_deg)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	mesh.mesh = box
	body.add_child(mesh)
	$Geometry.add_child(body)
