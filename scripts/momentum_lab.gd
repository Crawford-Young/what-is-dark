extends Node3D
## Momentum lab: 3 stations (bhop runway, strafe field, surf run), HUD, hotkey teleports.
## Keys: 1/2/3 = station select+teleport, R = reset to current station.

const STATIONS := [
	{"label": "1 BHOP", "spawn": Vector3(0, 1.0, 5.0)},
	{"label": "2 STRAFE", "spawn": Vector3(40, 1.0, 0.0)},
	{"label": "3 SURF", "spawn": Vector3(90, 113.5, 24)},
]
const SURF_RAMP_ANGLE := 51.34  ## Momentum Mod 5:4-slope community build standard; descending
## stage — real surf maps never touch anything flat, speed comes from the descent itself
const SPINE_PITCH := 12.0  ## descending-rail pitch; forward along-spine gravity gain =
## g*sin(12) ≈ 7.3 m/s²
const APRON_PITCH := 30.0  ## entry-apron pitch (steeper than the rail) — kills the exposed-
## start-lip edge-strike class (R11b Major): fast/shallow arrivals hit this steep face at
## low incidence (high retention) instead of grazing the next rail's physical start corner
const APRON_LENGTH := 12.0  ## apron spine length; short ramp bridging the transfer gap's
## underside, top-back end higher, low-front end coinciding with the next rail's start peak
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

	_speed_label.text = "%.2f m/s | 3d %.2f" % [speed, _player.velocity.length()]
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
	# Utopia-style descending stage: 3 rail-pitched ramps, each lower than the last, with 20 m
	# world-z air-transfer gaps between them. Every spine pitches SPINE_PITCH down along -z (a
	# compound X+Z rotation per panel: Z-roll gives the two-sided ramp cross-section, X-pitch
	# tilts the whole rolled rail) so gravity feeds FORWARD speed along the direction of travel,
	# orthogonal to an into-hill A/D hold — holding lateral position and gaining speed coexist.
	# Transfers are now end-of-rail forward flights (fly off the low/-z end into the next ramp's
	# start), not lateral fall-off through a face's bottom edge.
	# Start platform: top y 112.5; player runs off -z edge onto R1's start peak (90, 111.50, 20).
	_add_box(Vector3(90, 112.0, 26), Vector3(8, 1, 8), 0.0, Color(0.5, 0.4, 0.3))
	# Ramp 1: peak line start (90,111.50,20) -> end (90,90.71,-77.81); peak mid (90,101.105,-28.905).
	_ramp_pair(-28.905, SURF_RAMP_ANGLE, 101.105, 18.0, 100.0, SPINE_PITCH)
	# Entry apron before R2 (R11b Major fix): 12 m spine at 30 deg (steeper than the 12 deg
	# rail), low/front end coincides EXACTLY with R2's start peak (90,85.21,-97.81); back/high
	# end (90,91.21,-87.42). Kills the exposed-start-lip edge strike an active hold-into-wall
	# ride hits at the R1->R2 transfer (reviewer Major, verified: 93% forward-speed loss in one
	# tick striking the bare corner) -- fast/shallow arrivals now hit this steep face at low
	# incidence instead, then slide down the seam onto R2's own face.
	_ramp_pair(-92.614, SURF_RAMP_ANGLE, 88.21, 18.0, APRON_LENGTH, APRON_PITCH)
	# Ramp 2: peak line start (90,85.21,-97.81) -> end (90,64.42,-195.62) (20 m gap after R1);
	# peak mid (90,74.815,-146.715). Start peak = R1's end peak - 5.5 (transfer relation preserved).
	_ramp_pair(-146.715, SURF_RAMP_ANGLE, 74.815, 18.0, 100.0, SPINE_PITCH)
	# Entry apron before R3, same fix, low/front end coincides with R3's start peak
	# (90,58.92,-215.62); back/high end (90,64.92,-205.23).
	_ramp_pair(-210.424, SURF_RAMP_ANGLE, 61.92, 18.0, APRON_LENGTH, APRON_PITCH)
	# Ramp 3: peak line start (90,58.92,-215.62) -> end (90,38.13,-313.43) (20 m gap after R2);
	# peak mid (90,48.525,-264.525). Start peak = R2's end peak - 5.5.
	_ramp_pair(-264.525, SURF_RAMP_ANGLE, 48.525, 18.0, 100.0, SPINE_PITCH)
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
	# Pit: top y -12, widened to x 50..130 (margin past the new ±22.49 bottom edges), z 50..-430.
	# Touching it = obvious fail -> R reset.
	_add_box(Vector3(90, -12.5, -190), Vector3(80, 1, 480), 0.0, Color(0.08, 0.06, 0.08))


## peak_mid_z/peak_mid_y are the world coordinates of the peak LINE's midpoint (x=90); each
## panel's spine pitches pitch_deg down along -z, so the peak-to-center offset picks up a
## z-component (hw*sin(a)*sin(phi)) alongside the usual x/y roll offset. pitch_deg is a
## parameter (not just SPINE_PITCH) so the same builder serves both the main rails and the
## steeper entry aprons.
func _ramp_pair(peak_mid_z: float, angle_deg: float, peak_mid_y: float, half_width: float, length: float, pitch_deg: float) -> void:
	var a := deg_to_rad(angle_deg)
	var phi := deg_to_rad(pitch_deg)
	for side in [-1.0, 1.0]:
		var center := Vector3(
			90.0 + side * half_width * cos(a),
			peak_mid_y - half_width * sin(a) * cos(phi),
			peak_mid_z + half_width * sin(a) * sin(phi))
		_add_box_xz(center, Vector3(half_width * 2.0, 0.5, length),
			-pitch_deg, -side * angle_deg, Color(0.45, 0.3, 0.5))


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


## Compound X+Z rotation builder (Godot's default Euler order YXZ ⇒ Basis = Rx*Rz applied to a
## local vector — Z (face roll) applies first, then X (whole-rail pitch)). Used for pitched
## surf-ramp panels; kept separate from _add_box/_add_box_x so those two stay byte-identical.
func _add_box_xz(pos: Vector3, size: Vector3, rot_x_deg: float, rot_z_deg: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = Vector3(deg_to_rad(rot_x_deg), 0.0, deg_to_rad(rot_z_deg))
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
