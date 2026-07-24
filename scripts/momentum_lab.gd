extends Node3D
## Momentum lab: 3 stations (bhop runway, strafe field, surf run), HUD, hotkey teleports.
## Keys: 1/2/3 = station select+teleport, R = reset to current station.

const STATIONS := [
	{"label": "1 BHOP", "spawn": Vector3(0, 1.0, 5.0)},
	{"label": "2 STRAFE", "spawn": Vector3(40, 1.0, 0.0)},
	{"label": "3 SURF", "spawn": Vector3(90, 82, 24)},
]
const SURF_RAMP_ANGLE := 51.34  ## Momentum Mod 5:4-slope community build standard; descending
## stage — real surf maps never touch anything flat, speed comes from the descent itself
const KICKER_ANGLE := 50.0  ## up-kicker face angle (separate from the ramp angle); dot(UP) =
## cos(50) ≈ 0.643 < 0.7 — steep enough to launch, not walk

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
	# Utopia-style descending stage: 3 ramps ridden on their OUTER faces (peak-pair convention),
	# each lower than the last, with 20 m air-transfer gaps between them — the descent itself is
	# the speed source, nothing flat is ever touched until the final pit/landing.
	# Scaled up for a higher speed ceiling (physics/control constants untouched — geometry only).
	# Start platform: top y 81; player runs off -z edge onto ramp 1's peak region (peak_y 80, z 20).
	_add_box(Vector3(90, 80.5, 26), Vector3(8, 1, 8), 0.0, Color(0.5, 0.4, 0.3))
	# Ramp 1: peak_y 80, z span 20..-80. Bottom edges y ≈ 64.38 at x ≈ 90±12.49.
	_ramp_pair(-30.0, SURF_RAMP_ANGLE, 80.0, 10.0, 100.0)
	# Ramp 2: peak_y 58.9, z span -100..-200 (20 m transfer gap after R1). Bottom edges y ≈ 43.28.
	_ramp_pair(-150.0, SURF_RAMP_ANGLE, 58.9, 10.0, 100.0)
	# Ramp 3: peak_y 37.8, z span -220..-320 (20 m transfer gap after R2). Bottom edges y ≈ 22.18
	# (transfer relation preserved: next peak = previous bottom edge - 5.5, same 20 m gaps).
	_ramp_pair(-270.0, SURF_RAMP_ANGLE, 37.8, 10.0, 100.0)
	# Up-kicker: raised + moved close to R3's exit (only 8 m past it, was 36 m) so mid-speed riders
	# arrive shallow, not near-perpendicular -- clip retention depends on how parallel the arrival
	# is to the face, not just landing inside the band (see report's post-clip energy table).
	# Bottom edge (90,12,-328), top edge (90,18.89,-333.79). Face kept SHORT (9 m):
	# mid-speed pops (post-clip ~12 m/s) must contact near the top or they stall on
	# the climb and slide back (probe: 14 m face stalled a 35 m/s entry 0.7 m short);
	# 40+ m/s arrivals fly just over the top edge and carry straight to the platform.
	_add_box_x(Vector3(90, 15.45, -330.89), Vector3(12, 0.5, 9), KICKER_ANGLE, Color(0.9, 0.3, 0.3))
	# Landing platform: top y 4, spans z -336..-420 (near edge pulled in 4 m so the
	# slowest/steepest kicker exit lands the edge instead of pitting 1.25 m short).
	_add_box(Vector3(90, 3.5, -378), Vector3(24, 1, 84), 0.0, Color(0.5, 0.4, 0.3))
	# Pit: top y -12, spans x 65..115, z 50..-430. Touching it = obvious fail -> R reset.
	_add_box(Vector3(90, -12.5, -190), Vector3(50, 1, 480), 0.0, Color(0.08, 0.06, 0.08))


func _ramp_pair(z_center: float, angle_deg: float, peak_y: float, half_width: float, length: float) -> void:
	var a := deg_to_rad(angle_deg)
	for side in [-1.0, 1.0]:
		var center := Vector3(
			90.0 + side * half_width * cos(a),
			peak_y - half_width * sin(a),
			z_center)
		_add_box(center, Vector3(half_width * 2.0, 0.5, length), -side * angle_deg, Color(0.45, 0.3, 0.5))


func _add_box_x(pos: Vector3, size: Vector3, rot_x_deg: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.x = deg_to_rad(rot_x_deg)
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
