extends Node3D
## Surf lab: T3 hop-chain array -- 5 kicker-terminated ramps, each a steep-FACE
## trough (momentum_lab.gd _ramp_pair style) descending RAMP_DROP along a
## shallow SPINE_PITCH_DEG spine, separated by air-transfer gaps computed from
## the T3 law so each transfer lands cleanly on the next ramp's entry pad.
## Station cycling follows the momentum_lab pattern (there N/1/2/3, here N/P).
## Keys: N/P = next/previous station.

## T3 law: exit = ETA * sqrt(v_in^2 + 2 * GRAVITY * drop); GRAVITY 35.2 -> 70.4 factor.
const ETA := 0.95
const FACE_ANGLE_DEG := 51.34   # ramp face steepness (surfable: |normal.y| = cos(51.34deg) ~ 0.62,
								 # above FLOOR_LIMIT_DEG 38 so it classifies wall, and >> RIDE_MAX_NORMAL_Y
								 # 0.2 so it never enters the wall-ride path -> pure clip_multi)
const SPINE_PITCH_DEG := 12.0   # along-path descent (T3: "~12 deg along-path descent")
const RAMP_DROP := 3.0          # m vertical drop per ramp -> path = DROP / sin(12deg) = 14.43 m,
								 # above the T3 12 m path-length design floor by construction
const GAP_FRACTION := 0.85      # authored gap = fraction of the 0.755*h_speed ceiling (T3 run-1 factor;
								 # commitment-first, feel gate tunes)
const N_HOP_RAMPS := 5
const FACE_FORWARD := Vector3(0.0, 0.0, -1.0)

const KICKER_ANGLE_DEG := 42.0  ## same value + reasoning as momentum_lab.gd KICKER_ANGLE:
## 4deg steeper than FLOOR_LIMIT_DEG (38, scripts/player.gd) so wall/floor classification
## never grazes the boundary -- reused as-is, not re-tuned (that's feel-gate scope, later).
const HALF_WIDTH := 6.0         ## hop-chain trough half-width (narrower than momentum_lab's
## 18 m surf run -- this is a single-line hop chain, not a wide carve field).
const PAD_CLEARANCE := 0.5      ## entry pads sit above the ramp entry centreline (3b #15).

## T2 seam array (R1 #23 sanctioned rig): lip-to-lip ramp seams swept across a
## spine-pitch delta, at two entry-speed bands. Face angle stays FACE_ANGLE_DEG
## throughout -- only the pitch changes, so the seam risk under measurement is
## purely the along-path direction change at the lip.
const SEAM_DELTAS_DEG := [5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
const BAND_A_ENTRY_X := 60.0    ## Band A (~17 m/s) clusters, spaced away from the T1 chain at x=0.
const BAND_B_ENTRY_X := -60.0   ## Band B (~27 m/s) clusters, opposite side.
const CLUSTER_X_SPACING := 50.0 ## lateral spread from FACE_ANGLE_DEG banking is ~20 m at most;
## 50 m keeps every cluster clear of its neighbours.

var _station := 0
var _lowest_geometry_y := INF
var _kill_y := -1000.0

## DEBUG PROBE — remove before gates (T3 seam measurement campaign).
var _probe_tick := 0
var _probe_header_done := false
var _probe_cluster_label := ""
var _probe_seam_lips: Array = []  # [{"id": "A-5°#1", "pos": Vector3}, ...]

var STATIONS: Array = []  ## populated by _build_hop_chain(): [{"label","spawn","face"}, ...]

@onready var _player: Player = $Player
@onready var _speed_label: Label = $HUD/SpeedLabel
@onready var _station_label: Label = $HUD/StationLabel


func _ready() -> void:
	_build_hop_chain()
	_build_seam_array()
	_kill_y = _lowest_geometry_y - 10.0  # recomputed from the FINAL built geometry (T1's
	## builder rule) -- Band B's lead-in alone descends ~12 m, R1 #14.
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


func _physics_process(_delta: float) -> void:
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	_speed_label.text = "%.2f m/s" % speed
	if _player.global_position.y < _kill_y:
		var s: Dictionary = STATIONS[_station]
		_player.teleport(s["spawn"], s["face"])
	## DEBUG PROBE — remove before gates: per-tick campaign telemetry (T3).
	if not _probe_header_done:
		_probe_header_done = true
		print("PROBE-CRITERIA: RETENTION := v_out / sqrt(v_in^2 + 2*35.2*drop_w), energy form, drop_w = measured window y-descent from position rows; RETENTION_MIN 0.98/seam; SEAM_WINDOW 24 ticks @ 120 Hz centred on the lip-crossing tick; STALL_FRAME = any window tick with h_speed < 0.5 * window-entry h_speed; RUNS_PER_CELL 5 (actual N reported per cell); entry speeds binned at 22 m/s by MEASURED entry speed")
	var _probe_nearest := ""
	var _probe_dist := INF
	for lip in _probe_seam_lips:
		var d: float = _player.global_position.distance_to(lip["pos"])
		if d < _probe_dist:
			_probe_dist = d
			_probe_nearest = lip["id"]
	print("PROBE,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%.3f" % [_probe_tick, _player.global_position.x, _player.global_position.y, _player.global_position.z, _player.velocity.length(), speed, _probe_nearest, _probe_dist])
	_probe_tick += 1


func _reset_to_station() -> void:
	var s: Dictionary = STATIONS[_station]
	_player.teleport(s["spawn"], s["face"])
	_station_label.text = s["label"]
	print("PROBE-RUN: station=%s ticks_captured=%d" % [s["label"], _probe_tick])  ## DEBUG PROBE — remove before gates
	_probe_tick = 0  ## DEBUG PROBE — remove before gates


## Builds the 5-ramp hop chain per the T3 law above: each ramp's exit speed
## feeds the next ramp as entry speed, the horizontal component of that exit
## speed (never total speed -- parent spec 5.1 rule 1) sets the transfer gap
## via GAP_FRACTION * 0.755 * h_i. Gaps: 10.9 / 13.4 / 15.4 / 17.0 / 18.3 m,
## monotonic by construction (asserted below, T1 Step 1 requirement).
func _build_hop_chain() -> void:
	var path_len := RAMP_DROP / sin(deg_to_rad(SPINE_PITCH_DEG))
	var horiz_span := path_len * cos(deg_to_rad(SPINE_PITCH_DEG))

	var entry_speed := 11.0  # SourceMove.RUN_SPEED -- entry_1 (source_move.gd:9)
	var gap_prev := -INF
	var x := 0.0
	var y := 30.0
	var z := 0.0

	STATIONS.append({"label": "START", "spawn": Vector3(x, y + 1.0, z + 2.0), "face": FACE_FORWARD})
	_add_box(Vector3(x, y + PAD_CLEARANCE - 0.5, z + 2.0), Vector3(HALF_WIDTH * 2.0, 1.0, 4.0), Color(0.5, 0.4, 0.3))

	for i in range(N_HOP_RAMPS):
		var exit_speed: float = ETA * sqrt(entry_speed * entry_speed + 70.4 * RAMP_DROP)
		var h_speed: float = exit_speed * cos(deg_to_rad(SPINE_PITCH_DEG))
		var gap: float = GAP_FRACTION * 0.755 * h_speed
		assert(gap > gap_prev, "hop-chain gaps must grow monotonically (T3 law)")
		gap_prev = gap

		var peak_mid_z := z - horiz_span / 2.0
		var peak_mid_y := y - RAMP_DROP / 2.0
		_ramp_pair(x, peak_mid_z, FACE_ANGLE_DEG, peak_mid_y, HALF_WIDTH, path_len, SPINE_PITCH_DEG)

		var low_z := z - horiz_span
		var low_y := y - RAMP_DROP
		_add_box_x(Vector3(x, low_y - 0.25, low_z - 1.5), Vector3(HALF_WIDTH * 2.0, 0.5, 3.0), KICKER_ANGLE_DEG, Color(0.9, 0.3, 0.3))

		var pad_z := low_z - gap
		_add_box(Vector3(x, low_y + PAD_CLEARANCE - 0.5, pad_z), Vector3(HALF_WIDTH * 2.0, 1.0, 4.0), Color(0.5, 0.4, 0.3))
		STATIONS.append({"label": "R%d" % (i + 1), "spawn": Vector3(x, low_y + 1.0, pad_z), "face": FACE_FORWARD})

		entry_speed = exit_speed
		z = pad_z
		y = low_y

	STATIONS.append({"label": "LANDING", "spawn": Vector3(x, y + 1.0, z - 4.0), "face": FACE_FORWARD})
	_add_box(Vector3(x, y - 0.5, z - 6.0), Vector3(HALF_WIDTH * 2.0, 1.0, 12.0), Color(0.24, 0.33, 0.27))


## T2 seam array: builds both bands' six angle clusters. Each cluster is its
## own entry pad + standard-T1-style lead-in (kicker-terminated, computed gap)
## feeding a lip-to-lip Δ-cluster -- no gaps once the seam sweep starts, that's
## the whole point of the rig. Station labels: "A-5°".."A-30°", "B-5°".."B-30°".
func _build_seam_array() -> void:
	for j in range(SEAM_DELTAS_DEG.size()):
		_build_band_cluster("A", BAND_A_ENTRY_X + j * CLUSTER_X_SPACING, SEAM_DELTAS_DEG[j], 1)
	for j in range(SEAM_DELTAS_DEG.size()):
		_build_band_cluster("B", BAND_B_ENTRY_X - j * CLUSTER_X_SPACING, SEAM_DELTAS_DEG[j], 4)


## One band+angle cluster: entry pad, `lead_in_count` standard T1 ramps (1 for
## Band A's exit-17.31 lead-in, 4 for Band B's exit-27.17 lead-in), then the
## lip-shared Δ-cluster fed by the lead-in's final exit speed.
func _build_band_cluster(label_prefix: String, x: float, delta_deg: float, lead_in_count: int) -> void:
	var y := 30.0
	var z := 0.0
	var entry_speed := 11.0  # SourceMove.RUN_SPEED -- entry_1 (source_move.gd:9)

	STATIONS.append({"label": "%s-%d°" % [label_prefix, int(delta_deg)], "spawn": Vector3(x, y + 1.0, z + 2.0), "face": FACE_FORWARD})
	_add_box(Vector3(x, y + PAD_CLEARANCE - 0.5, z + 2.0), Vector3(HALF_WIDTH * 2.0, 1.0, 4.0), Color(0.5, 0.4, 0.3))

	for _i in range(lead_in_count):
		var result := _build_lead_in_ramp(x, y, z, entry_speed)
		z = result["z"]
		y = result["y"]
		entry_speed = result["exit_speed"]

	_probe_cluster_label = "%s-%d°" % [label_prefix, int(delta_deg)]  ## DEBUG PROBE — remove before gates
	_build_seam_cluster(x, y, z, entry_speed, delta_deg)


## A single standard T1 ramp: pitch SPINE_PITCH_DEG, drop RAMP_DROP, face
## FACE_ANGLE_DEG, kicker-terminated, T3-law computed gap onto a landing pad.
## Same construction as _build_hop_chain()'s loop body, kept as its own
## function here rather than refactored into T1's tested loop (T2 modifies
## this file only to ADD the seam array, not to alter T1's built geometry).
func _build_lead_in_ramp(x: float, y: float, z: float, entry_speed: float) -> Dictionary:
	var path_len := RAMP_DROP / sin(deg_to_rad(SPINE_PITCH_DEG))
	var horiz_span := path_len * cos(deg_to_rad(SPINE_PITCH_DEG))
	var exit_speed: float = ETA * sqrt(entry_speed * entry_speed + 70.4 * RAMP_DROP)
	var h_speed: float = exit_speed * cos(deg_to_rad(SPINE_PITCH_DEG))
	var gap: float = GAP_FRACTION * 0.755 * h_speed

	var peak_mid_z := z - horiz_span / 2.0
	var peak_mid_y := y - RAMP_DROP / 2.0
	_ramp_pair(x, peak_mid_z, FACE_ANGLE_DEG, peak_mid_y, HALF_WIDTH, path_len, SPINE_PITCH_DEG)

	var low_z := z - horiz_span
	var low_y := y - RAMP_DROP
	_add_box_x(Vector3(x, low_y - 0.25, low_z - 1.5), Vector3(HALF_WIDTH * 2.0, 0.5, 3.0), KICKER_ANGLE_DEG, Color(0.9, 0.3, 0.3))

	var pad_z := low_z - gap
	_add_box(Vector3(x, low_y + PAD_CLEARANCE - 0.5, pad_z), Vector3(HALF_WIDTH * 2.0, 1.0, 4.0), Color(0.5, 0.4, 0.3))

	return {"z": pad_z, "y": low_y, "exit_speed": exit_speed}


## The measurement rig itself (R1 #23 sanctioned exemption): 4 ramps sharing
## lips (no gaps, no kickers between them), spine pitches
## SPINE_PITCH_DEG -> +delta -> SPINE_PITCH_DEG -> +delta so every ramp still
## descends (R2 #11) and each of the 3 seams is a ±delta step. Face angle
## stays FACE_ANGLE_DEG throughout -- pitch is the only swept parameter.
## Exit speed at drop RAMP_DROP is independent of pitch (T3's energy-
## normalized law), so entry speed climbs through the cluster exactly as it
## would through any other T1-style chain -- no control ramp needed (R3 M1/M2).
func _build_seam_cluster(x: float, y: float, z: float, entry_speed: float, delta_deg: float) -> void:
	var pitches := [SPINE_PITCH_DEG, SPINE_PITCH_DEG + delta_deg, SPINE_PITCH_DEG, SPINE_PITCH_DEG + delta_deg]
	var _probe_i := 0  ## DEBUG PROBE — remove before gates
	for pitch in pitches:
		if _probe_i > 0:  ## DEBUG PROBE — remove before gates: seam lip = entry of ramps 2/3/4
			_probe_seam_lips.append({"id": "%s#%d" % [_probe_cluster_label, _probe_i], "pos": Vector3(x, y, z)})
		_probe_i += 1  ## DEBUG PROBE — remove before gates
		var path_len: float = RAMP_DROP / sin(deg_to_rad(pitch))
		var horiz_span: float = path_len * cos(deg_to_rad(pitch))
		var peak_mid_z := z - horiz_span / 2.0
		var peak_mid_y := y - RAMP_DROP / 2.0
		_ramp_pair(x, peak_mid_z, FACE_ANGLE_DEG, peak_mid_y, HALF_WIDTH, path_len, pitch)

		entry_speed = ETA * sqrt(entry_speed * entry_speed + 70.4 * RAMP_DROP)
		z -= horiz_span
		y -= RAMP_DROP


## Compound X+Z rotation builder, same math as momentum_lab.gd's _ramp_pair
## (Godot's default Euler order YXZ => Basis = Rx*Rz applied to a local
## vector -- Z (face roll) applies first, then X (whole-rail pitch)).
func _ramp_pair(cx: float, peak_mid_z: float, angle_deg: float, peak_mid_y: float, half_width: float, length: float, pitch_deg: float) -> void:
	var a := deg_to_rad(angle_deg)
	var phi := deg_to_rad(pitch_deg)
	for side in [-1.0, 1.0]:
		var center := Vector3(
			cx + side * half_width * cos(a),
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
	_track_lowest(pos.y - size.y / 2.0)


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
	_track_lowest(pos.y - size.y / 2.0)


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
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
	_track_lowest(pos.y - size.y / 2.0)


## Kill-plane tracking (R1 #14): computed from the lowest authored geometry y,
## not a fixed constant, so the plane always sits below every built surface.
func _track_lowest(y: float) -> void:
	_lowest_geometry_y = minf(_lowest_geometry_y, y)
