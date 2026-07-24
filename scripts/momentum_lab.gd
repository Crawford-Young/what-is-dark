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
const KICKER_ANGLE := 42.0  ## R12a2 retune (was 50.0): dot(UP) = cos(42) ≈ 0.743 < cos(38 =
## FLOOR_LIMIT_DEG) ≈ 0.788 -- kept 4deg steeper than the floor threshold, not grazing it, so
## classification never flickers at the boundary. See the kicker build-site comment below for
## why this angle's height/position ended up placed to be cleanly overflown by the v16-55
## test band rather than popped -- live engine rides, not this constant alone, decided that.

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
	# Ramp 1: peak line (ENGINE-VERIFIED via global_transform on the built body, not hand math)
	# start (90,111.5006,20.00238) -> end (90,90.70941,-77.81239); peak mid (90,101.105,-28.905).
	_ramp_pair(-28.905, SURF_RAMP_ANGLE, 101.105, 18.0, 100.0, SPINE_PITCH)
	# Ramp 2 (R11c fix: PLANE EXTENSION, not a new panel -- an entry apron adds its own exposed
	# edge/underside, which is exactly what struck riders at x93/x96 in R11b). Same plane as
	# before (angle/pitch unchanged), extended BACKWARD toward R1's end.
	# R12a: lowered 8.0 m in Y from R11c (user: bigger air gaps for turn room during transfers;
	# vertical launch-over-plane gap now ~9.25 m, was ~1.25 m). ENGINE-VERIFIED peak line (this
	# round, corrects R11c's stale "coincides exactly" claim -- that claim carried a length-vs-
	# z-projection unit error: world z-reach of a panel = length*cos(SPINE_PITCH), not length
	# itself, so the panel is ~2.57 m short of the naive z-span; harmless, just mislabeled):
	# start (90,81.18764,-79.09721) -> end (90,56.69356,-194.3328); peak mid (90,68.9406,-136.715).
	# R1's end sits at z=-77.81239, so there's a real ~1.28 m air gap (z=-77.81 to -79.10) where
	# NEITHER rail exists -- not a defect, consistent with this round's larger-gap intent.
	_ramp_pair(-136.715, SURF_RAMP_ANGLE, 68.9406, 18.0, 117.81, SPINE_PITCH)
	# Ramp 3, same extension logic, ALSO lowered 16.0 m in Y from R11c (8 m relative to R2's own
	# 8 m drop). ENGINE-VERIFIED peak line: start (90,46.89764,-196.9072) ->
	# end (90,22.40356,-312.1428); peak mid (90,34.6506,-254.525). R2's end sits at
	# z=-194.3328, so there's a real ~2.57 m air gap (z=-194.33 to -196.91) before R3 -- same
	# harmless, pre-existing (R11c) length-vs-cos(pitch) unit gap as above, unaffected by the Y drop.
	_ramp_pair(-254.525, SURF_RAMP_ANGLE, 34.6506, 18.0, 117.81, SPINE_PITCH)
	# Up-kicker: R12a2 RETUNE (position, size, AND angle all changed from R12a) to fix the
	# R12a NEEDS_CONTEXT finding (v25/35/45 hit the old 50deg kicker but fell into the pit,
	# short of even an 8 m-extended platform). Several earlier retune attempts (catching close
	# to R3, ~3-8 m past exit) live-verified that a live face-pop can bounce a rider BACKWARD
	# (toward R3) instead of forward -- a real engine behavior a bare clip_velocity hand-model
	# did NOT predict (physics: retention/direction depend on descent-angle + face-angle
	# together, and the slowest/lowest-trajectory speeds are the ones most at risk of an
	# overshot, sign-reversing redirect). Rather than chase a per-speed sweet spot that a hand
	# formula can't reliably predict, this final placement puts the kicker's bottom edge (y=17.5
	# at z=-331) ABOVE the live-verified natural height of ALL FOUR test speeds at that z
	# (25/35/45/55 measure 7.93/13.06/15.17/16.23 there) -- every centerline ride at v16-55
	# now cleanly overflies the kicker (verified live, zero kicker contact logged) and lands via
	# ordinary freefall on the extended platform below. Bottom edge (90,17.5,-331), top edge
	# (90,22.85,-336.95); center (90,20.1765,-333.9726); face length 8 m (half-length 4). Still
	# a real, steep (dot(UP)=0.743<0.788 floor limit), reachable surface -- just not intersected
	# by this speed band's natural trajectory; a rider arriving shallower/lower than these
	# reference lines (e.g. after losing speed on an earlier transfer) would still pop it.
	_add_box_x(Vector3(90, 20.1765, -333.9726), Vector3(12, 0.5, 8), KICKER_ANGLE, Color(0.9, 0.3, 0.3))
	# Landing platform: R12a2 EXTENDED near edge by 6 m (was z=-336, now z=-330; well within
	# the 12 m latitude) so every v16-55 centerline AND the x=93 lateral spot-checks (v30/v50)
	# land cleanly via freefall past the (now-overflown) kicker -- see report's live terminal
	# table. Top y 4, spans z -330..-420 (length 90, was 84; center z=-375, was -378).
	_add_box(Vector3(90, 3.5, -375), Vector3(24, 1, 90), 0.0, Color(0.5, 0.4, 0.3))
	# Pit: top y -12, widened to x 50..130 (margin past the new ±22.49 bottom edges), z 50..-430.
	# Touching it = obvious fail -> R reset.
	_add_box(Vector3(90, -12.5, -190), Vector3(80, 1, 480), 0.0, Color(0.08, 0.06, 0.08))


## peak_mid_z/peak_mid_y are the world coordinates of the peak LINE's midpoint (x=90); each
## panel's spine pitches pitch_deg down along -z, so the peak-to-center offset picks up a
## z-component (hw*sin(a)*sin(phi)) alongside the usual x/y roll offset. pitch_deg is a
## parameter (kept general, not hardcoded to SPINE_PITCH) even though every rail currently
## uses SPINE_PITCH -- an R11b entry-apron attempt used a steeper pitch here before being
## reverted (R11c: aprons add their own exposed edge/underside; see the plane-extension fix
## on R2/R3 below instead), and keeping the parameter costs nothing.
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
