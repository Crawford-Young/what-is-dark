extends Node3D
## Surf lab: a range rig (one runway, one ramp, one striped landing field) plus
## the T2 seam-sweep arrays. The rig measures real flight distance -- the
## player flies off the ramp's lip carrying full velocity (no kicker) and
## reads how far they land off the field's distance stripes; a real hop
## chain's gaps get authored from THAT measured data later, never from a
## law-predicted range (range-rig ruling, 2026-08-02, supersedes the earlier
## 5-ramp ballistic-transfer chain).
## Station cycling follows the momentum_lab pattern (there N/1/2/3, here N/P).
## Keys: N/P = next/previous station.

## T3 law: exit = ETA * sqrt(v_in^2 + 2 * GRAVITY * drop); GRAVITY 35.2 -> 70.4 factor.
## Still governs every ramp's exit speed (the range rig's single ramp included) --
## only the CHAIN geometry between ramps has changed across rulings. Kickers
## REMOVED 2026-08-02 (feel gate): a 42deg plate off a 12deg spine is a 54deg
## direction change, and clip retains only ~cos(54deg) ~= 0.59 of speed --
## measured 11 vs law 17 m/s. Kickers are now a deliberate speed-kill tool for
## future course design, never used in this lab.
const ETA := 0.95
const FACE_ANGLE_DEG := 51.34   # ramp face steepness (surfable: |normal.y| = cos(51.34deg) ~ 0.62,
								 # above FLOOR_LIMIT_DEG 38 so it classifies wall, and >> RIDE_MAX_NORMAL_Y
								 # 0.2 so it never enters the wall-ride path -> pure clip_multi)
const SPINE_PITCH_DEG := 12.0   # along-path descent (T3: "~12 deg along-path descent")
const RAMP_DROP := 3.0          # m vertical drop per ramp -> path = DROP / sin(12deg) = 14.43 m,
								 # above the T3 12 m path-length design floor by construction
const SEAM_RAMP_DROP := 6.0     # m vertical drop per SEAM-CLUSTER ramp. Raised from RAMP_DROP's
								 # 3.0 on 2026-09-14: the 3 m ramp starves strafe time (same user ruling
								 # that deepened the transfer rig on 2026-08-03, which was scoped to that
								 # rig alone and never reached the T2-era seam array). 6.0 m is the
								 # measured transfer-unit minimum (issue #12). Flat, not progressive: the
								 # seam rig's design is that spine pitch is the ONLY swept parameter, so a
								 # varying drop would make a seam result unattributable to the lip.
								 # NOTE: at 12deg the path is 6/sin(12) = 28.9 m, but the steep half of a
								 # cluster shortens -- Delta>=20 falls under the 12 m path floor (32deg =
								 # 11.3 m, 42deg = 9.0 m). Those are the clusters the checklist already
								 # calls known-bad by construction (4.1b negative controls), so the floor
								 # breach is expected there -- but it is NOT a clean ride, and any
								 # Delta>=20 seam result carries that caveat into the T3 table.
								 # Band A's LEAD-IN deliberately keeps RAMP_DROP 3.0: it is a speed-setter
								 # for the 17.31 m/s entry, and 6.0 there gives 22.1 m/s, across the
								 # 22 m/s binning edge that separates the bands.
const BAND_B_LEADIN_DROP := 9.9 # single-ramp Band B lead-in drop (law: 0.95*sqrt(11^2+70.4*9.9)
								 # = 27.17, replaces the old 4-ramp kicker-terminated chain)
const FACE_FORWARD := Vector3(0.0, 0.0, -1.0)

const HALF_WIDTH := 6.0         ## hop-chain trough half-width (narrower than momentum_lab's
## 18 m surf run -- this is a single-line hop chain, not a wide carve field).
const PAD_CLEARANCE := 0.5      ## entry pads sit above the ramp entry centreline (3b #15);
## pads end FLUSH at the ramp entry (fixed 2026-08-02 -- a ramp starting at its pad's
## CENTER buried the pad's far half under the trough's top; ramps now start at the
## pad's far edge, jump distances unchanged, only the ramp start shifted).
const PAD_LEN := 6.0            ## entry-pad z-length, widened 4.0 -> 6.0 at the same 2026-08-02
## feel gate -- landing window vs void on both sides. Under CS-surf transfers every
## runway pad is a STATION SPAWN ONLY, never a landing target -- the ballistic arc
## clears each pad by ~3.4 m at its near edge and lands on the next ramp's trough.

## T2 seam array (R1 #23 sanctioned rig): lip-to-lip ramp seams swept across a
## spine-pitch delta, at two entry-speed bands. Face angle stays FACE_ANGLE_DEG
## throughout -- only the pitch changes, so the seam risk under measurement is
## purely the along-path direction change at the lip.
const SEAM_DELTAS_DEG := [5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
const BAND_A_ENTRY_X := 60.0    ## Band A (~17 m/s) clusters, spaced away from the T1 chain at x=0.
const BAND_B_ENTRY_X := -60.0   ## Band B (~27 m/s) clusters, opposite side.
const CLUSTER_X_SPACING := 50.0 ## lateral spread from FACE_ANGLE_DEG banking is ~20 m at most;
## 50 m keeps every cluster clear of its neighbours.
## Rounded seam set (user pick 2026-09-22, issue #16: measure sharp AND rounded):
## the same 12 clusters with every seam crease replaced by a tangent circular arc,
## past the CHAIN lane (x=370) on one side and the sharp Band B set on the other.
const ROUNDED_A_ENTRY_X := 430.0
const ROUNDED_B_ENTRY_X := -370.0
const SEAM_FILLET_LEN := 6.0    ## arc length of each rounded seam. Sized to the shortest ramp:
## the D30 steep ramp's 9.0 m path takes a 3.07 m tangent at each end, leaving 2.9 m
## straight. Radius = length / D (68.8 m at D5, 11.5 m at D30) -- a rider still leaves
## the face above sqrt(g_n * R) (~15.5 m/s at D30), so rounded is gentler, not launch-proof.
const FILLET_STEP := 0.25       ## arc sampling, metres along the path

var _station := 0
var _lowest_geometry_y := INF
var _kill_y := -1000.0

## DEBUG PROBE — remove before gates (T3 seam measurement campaign).
var _probe_tick := 0
var _probe_header_done := false
var _probe_cluster_label := ""
var _probe_seam_lips: Array = []  # [{"id": "A-5°#1", "pos": Vector3}, ...]
var _probe_file: FileAccess  ## DEBUG PROBE — CSV sink so captures need no console redirect

var STATIONS: Array = []  ## populated by _build_range_rig() + _build_seam_array(): [{"label","spawn","face"}, ...]

@onready var _player: Player = $Player
@onready var _speed_label: Label = $HUD/SpeedLabel
@onready var _station_label: Label = $HUD/StationLabel


func _ready() -> void:
	_build_range_rig()
	_build_transfer_lane()
	_build_chain_lane()
	_build_seam_array()
	# Default spawn: the first seam cluster, where the T3 campaign starts. The
	# range lanes (RAMP/RAMP-L) stay built -- issue #11's curved ramps will need
	# the exit law RE-MEASURED, not derived, so the rig has future use, and
	# changing it would make issue #12's banked numbers non-reproducible. But
	# they are closed-campaign geometry at RAMP_DROP 3.0 and should not be the
	# first thing a rider meets.
	for i in range(STATIONS.size()):
		if str(STATIONS[i]["label"]).begins_with("A-"):
			_station = i
			break
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
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		DirAccess.make_dir_recursive_absolute("user://probe")
		_probe_file = FileAccess.open("user://probe/seam_%s.csv" % stamp, FileAccess.WRITE)
		var criteria := "PROBE-CRITERIA: RETENTION := v_out / sqrt(v_in^2 + 2*35.2*drop_w), energy form, drop_w = measured window y-descent from position rows; RETENTION_MIN 0.98/seam; SEAM_WINDOW 24 ticks @ 120 Hz centred on the lip-crossing tick; STALL_FRAME = any window tick with h_speed < 0.5 * window-entry h_speed; RUNS_PER_CELL 5 (actual N reported per cell); entry speeds binned at 22 m/s by MEASURED entry speed"
		print(criteria)
		if _probe_file:
			_probe_file.store_line(criteria)
	var _probe_nearest := ""
	var _probe_dist := INF
	for lip in _probe_seam_lips:
		var d: float = _player.global_position.distance_to(lip["pos"])
		if d < _probe_dist:
			_probe_dist = d
			_probe_nearest = lip["id"]
	var row := "PROBE,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s,%.3f" % [_probe_tick, _player.global_position.x, _player.global_position.y, _player.global_position.z, _player.velocity.length(), speed, _probe_nearest, _probe_dist]
	if _probe_file:
		_probe_file.store_line(row)
		if _probe_tick % 240 == 0:
			_probe_file.flush()
	_probe_tick += 1


func _reset_to_station() -> void:
	var s: Dictionary = STATIONS[_station]
	_player.teleport(s["spawn"], s["face"])
	_station_label.text = s["label"]
	print("PROBE-RUN: station=%s ticks_captured=%d" % [s["label"], _probe_tick])  ## DEBUG PROBE — remove before gates
	if _probe_file:  ## DEBUG PROBE — remove before gates
		_probe_file.store_line("PROBE-RUN: station=%s ticks_captured=%d" % [s["label"], _probe_tick])
		_probe_file.flush()
	_probe_tick = 0  ## DEBUG PROBE — remove before gates


## Range rig (replaces the 5-ramp authored chain, 2026-08-02 ruling round 4):
## two lanes -- the standard 3.0 m ramp (station "RAMP", x=0) and a long lane
## using the Band B lead-in drop (9.9 m, station "RAMP-L", x=-30, to
## demonstrate max flight) -- each a runway + one ramp + an open striped
## landing field. The player flies off the lip carrying full velocity (no
## kicker, no authored gap) and reads their flight distance straight off the
## stripes; a real hop chain's gaps get authored from THAT measured data
## later, never from a law-predicted range.
func _build_range_rig() -> void:
	_build_range_lane(0.0, RAMP_DROP, 12, "RAMP")
	_build_range_lane(-30.0, BAND_B_LEADIN_DROP, 20, "RAMP-L")


## One range-rig lane: a runway + one ramp of `ramp_drop` vertical drop + a
## striped landing field of `n_stripes` 10 m segments. Parameterized so both
## lanes share identical construction -- only lane x, drop, and stripe count
## differ.
func _build_range_lane(lane_x: float, ramp_drop: float, n_stripes: int, station_label: String) -> void:
	var start_y := 30.0

	# Runway: 12 m of flush ground so the player reaches RUN_SPEED (bhop timing)
	# before the ramp entry. Spans z=12 (spawn end) to z=0 (ramp entry, flush).
	_add_box(Vector3(lane_x, start_y + PAD_CLEARANCE - 0.5, 6.0), Vector3(HALF_WIDTH * 2.0, 1.0, 12.0), Color(0.5, 0.4, 0.3))
	STATIONS.append({"label": station_label, "spawn": Vector3(lane_x, start_y + 1.0, 12.0), "face": FACE_FORWARD})

	# One ramp: entry flush at z=0 (the runway's far edge), lip below.
	var path_len := ramp_drop / sin(deg_to_rad(SPINE_PITCH_DEG))
	var horiz_span := path_len * cos(deg_to_rad(SPINE_PITCH_DEG))
	var peak_mid_z := -horiz_span / 2.0
	var peak_mid_y := start_y - ramp_drop / 2.0
	_ramp_pair(lane_x, peak_mid_z, FACE_ANGLE_DEG, peak_mid_y, HALF_WIDTH, path_len, SPINE_PITCH_DEG)

	var low_z := -horiz_span  # the lip
	var low_y := start_y - ramp_drop

	# Landing field: open, no authored gap -- n_stripes abutting 10 m stripes
	# (alternating dark/light) so flight distance reads directly off the
	# ground. The first stripe boundary is the lip's own z, so
	# distance-from-lip = stripes crossed.
	var field_drop := 4.0  # field top sits this far below the lip -- tunable, not a law
	var field_top := low_y - field_drop
	var stripe_len := 10.0
	for i in range(n_stripes):
		var stripe_center_z := low_z - i * stripe_len - stripe_len / 2.0
		var color := Color(0.3, 0.3, 0.3) if i % 2 == 0 else Color(0.55, 0.55, 0.55)
		_add_box(Vector3(lane_x, field_top - 0.5, stripe_center_z), Vector3(30.0, 1.0, stripe_len), color)


## Transfer rig: measures ramp-to-ramp CS-surf momentum carry -- fly off
## ramp-1's lip, clear an 8.0 m gap (measured min flight in this speed band is
## 10.1 m, so the min clears), land in ramp-2's trough, ride out, and fly onto
## an open striped range field. Station "XFER". Modeled on
## _build_range_lane's conventions (runway top, spawn at +z end, striped
## field, _track_lowest via every _add_box*/_ramp_pair call) but built
## directly rather than through that helper -- the two-ramp-plus-gap shape
## doesn't fit its single-ramp parameterization.
func _build_transfer_lane() -> void:
	var cx := 30.0
	var start_y := 30.0
	var drop := 6.0  # deepened from RAMP_DROP's 3.0 -- user feedback 2026-08-03: 3 m gave too
	## little face time to strafe. Both transfer-rig ramps only; the range lanes keep RAMP_DROP.

	# Runway: identical construction to _build_range_lane's, shifted to cx.
	_add_box(Vector3(cx, start_y + PAD_CLEARANCE - 0.5, 6.0), Vector3(HALF_WIDTH * 2.0, 1.0, 12.0), Color(0.5, 0.4, 0.3))
	STATIONS.append({"label": "XFER", "spawn": Vector3(cx, start_y + 1.0, 12.0), "face": FACE_FORWARD})

	# Ramp-1: same construction as the RAMP lane's ramp -- entry flush at z=0.
	var path_len := drop / sin(deg_to_rad(SPINE_PITCH_DEG))
	var horiz_span := path_len * cos(deg_to_rad(SPINE_PITCH_DEG))
	var peak1_mid_z := -horiz_span / 2.0
	var peak1_mid_y := start_y - drop / 2.0
	_ramp_pair(cx, peak1_mid_z, FACE_ANGLE_DEG, peak1_mid_y, HALF_WIDTH, path_len, SPINE_PITCH_DEG)

	var lip1_z := -horiz_span              # -28.2278
	var lip1_y := start_y - drop           # 24.0

	# Gap: 8.0 m of nothing -- measured min flight in this speed band is
	# 10.1 m, so the min clears.
	var gap := 8.0
	var entry2_z := lip1_z - gap           # -36.2278
	var entry2_y := lip1_y - 2.0           # 22.0 -- user pick 2026-08-03: 4.0 read as too far down for an 8 m gap

	# Ramp-2: HALF_WIDTH 10.0, not 6.0 -- measured landing-x drift from
	# airstrafe spans ~9 m either side; the wide trough is deliberate
	# measurement-rig latitude. _ramp_pair already takes half_width as a
	# parameter (it does not hardcode HALF_WIDTH), so no signature change
	# was needed to widen just this one ramp.
	var peak2_mid_z := entry2_z - horiz_span / 2.0
	var peak2_mid_y := entry2_y - drop / 2.0
	_ramp_pair(cx, peak2_mid_z, FACE_ANGLE_DEG, peak2_mid_y, 10.0, path_len, SPINE_PITCH_DEG)

	var lip2_z := entry2_z - horiz_span     # -64.4556
	var lip2_y := entry2_y - drop           # 16.0

	# Field: striped, same two colors as the other lanes' fields, top 4.0 m
	# below lip-2. Spans z=[-28.2278,-184.4556] -- back under the gap and
	# ramp-2 (so a short flight lands measurable instead of dying in void;
	# ramp-2's plates sit at y=16-22, well above the field's y=12.0). The
	# stripe grid is anchored on lip2_z (a boundary lands exactly there, for
	# a distance-past-lip-2 readout), which puts one short lead-in stripe
	# nearest the ramp and full 10 m stripes after it.
	var field_top := lip2_y - 4.0           # 12.0
	var stripe_len := 10.0
	var field_near_z := lip1_z              # -28.2278
	var field_far_z := lip2_z - 120.0       # -184.4556, 12 full stripes past lip-2

	var boundaries: Array[float] = [field_near_z]
	var k: int = floori((field_near_z - lip2_z) / stripe_len)
	var b: float = lip2_z + stripe_len * k
	while b > field_far_z + 0.001:
		boundaries.append(b)
		b -= stripe_len
	boundaries.append(field_far_z)

	for i in range(boundaries.size() - 1):
		var seg_len: float = boundaries[i] - boundaries[i + 1]
		var seg_center_z: float = (boundaries[i] + boundaries[i + 1]) / 2.0
		var color := Color(0.3, 0.3, 0.3) if i % 2 == 0 else Color(0.55, 0.55, 0.55)
		_add_box(Vector3(cx, field_top - 0.5, seg_center_z), Vector3(30.0, 1.0, seg_len), color)


## Chain rig: the 5-ramp CHAIN station, built from the measured transfer unit
## (issue #12, user-approved option A -- constant gaps). Drops are a
## PROGRESSIVE schedule, not constant 6.0 -- measured per-hop launch h
## climbing 33.9/41/47/51 m/s through the chain, drop_i = 6.0 * v_i/v_1, so
## face TIME holds ~0.85 s as chain speed builds rather than shrinking on
## faster ramps. Gap 8.0 m, each next entry 2.0 m below the previous lip
## (unchanged). Built with a loop, not five copies of the same math -- ramp 1
## uses HALF_WIDTH (matches the measured launch condition), ramps 2-5 use
## 10.0 (measured drift catch, same rationale as XFER's ramp-2). One striped
## catch field spans the whole lane -- stripes under the ramps/gaps double as
## the catch floor, so a missed transfer anywhere lands measurable.
func _build_chain_lane() -> void:
	var cx := 370.0
	var start_y := 30.0
	var drops := [6.0, 7.3, 8.3, 9.1, 9.8]  # progressive schedule, see doc comment above
	var gap := 8.0
	var n_ramps := 5

	# Runway: same convention as XFER, shifted to cx.
	_add_box(Vector3(cx, start_y + PAD_CLEARANCE - 0.5, 6.0), Vector3(HALF_WIDTH * 2.0, 1.0, 12.0), Color(0.5, 0.4, 0.3))
	STATIONS.append({"label": "CHAIN", "spawn": Vector3(cx, start_y + 1.0, 12.0), "face": FACE_FORWARD})

	# Chain rule: entry_1 = (0, start_y); for i>=2, entry_i = (lip_(i-1).z -
	# gap, lip_(i-1).y - 2.0). Each ramp's own horizontal run is now
	# drop_i / tan(12deg) -- no longer constant across the chain, so path_len/
	# horiz_span are computed per-iteration from drops[i].
	var entry_z := 0.0
	var entry_y := start_y
	var lip_z := 0.0
	var lip_y := 0.0
	var lip1_z := 0.0  # ramp-1's lip, snapshotted before later iterations overwrite lip_z
	for i in range(n_ramps):
		var drop: float = drops[i]
		var path_len := drop / sin(deg_to_rad(SPINE_PITCH_DEG))
		var horiz_span := path_len * cos(deg_to_rad(SPINE_PITCH_DEG))
		var half_width := HALF_WIDTH if i == 0 else 10.0
		var peak_mid_z := entry_z - horiz_span / 2.0
		var peak_mid_y := entry_y - drop / 2.0
		_ramp_pair(cx, peak_mid_z, FACE_ANGLE_DEG, peak_mid_y, half_width, path_len, SPINE_PITCH_DEG)

		lip_z = entry_z - horiz_span
		lip_y = entry_y - drop
		if i == 0:
			lip1_z = lip_z

		entry_z = lip_z - gap
		entry_y = lip_y - 2.0

	# Field: one striped catch field for the whole lane, top 4.0 m below
	# lip-5 (y=-22.5). Stripe grid anchored on lip-5's z (-222.5375, a
	# boundary lands exactly there, for a distance-past-lip-5 readout); the
	# far edge (-342.5375) is an exact 10 m multiple past it, same
	# boundary-list construction as XFER's field.
	var field_top := lip_y - 4.0
	var stripe_len := 10.0
	var field_near_z := lip1_z  # ramp-1's lip -- catches misses under the whole chain
	var lip5_z := lip_z
	var field_far_z := lip5_z - 120.0

	var boundaries: Array[float] = [field_near_z]
	var k: int = floori((field_near_z - lip5_z) / stripe_len)
	var b: float = lip5_z + stripe_len * k
	while b > field_far_z + 0.001:
		boundaries.append(b)
		b -= stripe_len
	boundaries.append(field_far_z)

	for i in range(boundaries.size() - 1):
		var seg_len: float = boundaries[i] - boundaries[i + 1]
		var seg_center_z: float = (boundaries[i] + boundaries[i + 1]) / 2.0
		var color := Color(0.3, 0.3, 0.3) if i % 2 == 0 else Color(0.55, 0.55, 0.55)
		_add_box(Vector3(cx, field_top - 0.5, seg_center_z), Vector3(30.0, 1.0, seg_len), color)


## T2 seam array: builds both bands' six angle clusters. Each cluster is its
## own entry pad + ONE continuous lead-in ramp joined lip-to-lip into the
## Δ-cluster (CS-surf rework, 2026-08-02 -- no kicker, no gap, no pad between
## the lead-in and the cluster's first seam). Station labels: "A-5°".."A-30°",
## "B-5°".."B-30°".
func _build_seam_array() -> void:
	for j in range(SEAM_DELTAS_DEG.size()):
		_build_band_cluster("A", BAND_A_ENTRY_X + j * CLUSTER_X_SPACING, SEAM_DELTAS_DEG[j], RAMP_DROP, 0.0)
	for j in range(SEAM_DELTAS_DEG.size()):
		_build_band_cluster("B", BAND_B_ENTRY_X - j * CLUSTER_X_SPACING, SEAM_DELTAS_DEG[j], BAND_B_LEADIN_DROP, 0.0)
	for j in range(SEAM_DELTAS_DEG.size()):
		_build_band_cluster("AR", ROUNDED_A_ENTRY_X + j * CLUSTER_X_SPACING, SEAM_DELTAS_DEG[j], RAMP_DROP, SEAM_FILLET_LEN)
	for j in range(SEAM_DELTAS_DEG.size()):
		_build_band_cluster("BR", ROUNDED_B_ENTRY_X - j * CLUSTER_X_SPACING, SEAM_DELTAS_DEG[j], BAND_B_LEADIN_DROP, SEAM_FILLET_LEN)


## One band+angle cluster: entry pad, then a single lead-in ramp of
## `lead_in_drop` vertical drop (RAMP_DROP=3.0 for Band A's exit-17.31 lead-in,
## BAND_B_LEADIN_DROP=9.9 for Band B's exit-27.17 lead-in), same face angle and
## 12deg spine pitch as every other ramp. The lead-in's low end IS the
## cluster's first lip -- no gap, no pad, no kicker between them.
## `fillet_len` > 0 rounds every seam crease into a tangent arc of that length.
func _build_band_cluster(label_prefix: String, x: float, delta_deg: float, lead_in_drop: float, fillet_len: float) -> void:
	var y := 30.0
	var z := 0.0
	var entry_speed := 11.0  # SourceMove.RUN_SPEED -- entry_1 (source_move.gd:9)

	STATIONS.append({"label": "%s-%d°" % [label_prefix, int(delta_deg)], "spawn": Vector3(x, y + 1.0, z + 2.0), "face": FACE_FORWARD})
	_add_box(Vector3(x, y + PAD_CLEARANCE - 0.5, z + 2.0), Vector3(HALF_WIDTH * 2.0, 1.0, PAD_LEN), Color(0.5, 0.4, 0.3))
	z += 2.0 - PAD_LEN / 2.0  # lead-in ramp starts at the entry pad's far edge, not its centre

	var path_len := lead_in_drop / sin(deg_to_rad(SPINE_PITCH_DEG))
	var horiz_span := path_len * cos(deg_to_rad(SPINE_PITCH_DEG))
	var spine: Array[Vector3] = [Vector3(x, y, z)]

	var low_z := z - horiz_span
	var low_y := y - lead_in_drop
	spine.append(Vector3(x, low_y, low_z))
	var exit_speed: float = ETA * sqrt(entry_speed * entry_speed + 70.4 * lead_in_drop)

	_probe_cluster_label = "%s-%d°" % [label_prefix, int(delta_deg)]  ## DEBUG PROBE — remove before gates
	_build_seam_cluster(x, low_y, low_z, exit_speed, delta_deg, spine)
	if fillet_len > 0.0:
		spine = _fillet_spine(spine, fillet_len)
	_add_surf_strip(spine, FACE_ANGLE_DEG, HALF_WIDTH * 2.0, Color(0.45, 0.3, 0.5))


## The measurement rig itself (R1 #23 sanctioned exemption): 4 ramps sharing
## lips (no gaps, no kickers between them), spine pitches
## SPINE_PITCH_DEG -> +delta -> SPINE_PITCH_DEG -> +delta so every ramp still
## descends (R2 #11) and each of the 3 seams is a ±delta step. Face angle
## stays FACE_ANGLE_DEG throughout -- pitch is the only swept parameter.
## Exit speed at drop SEAM_RAMP_DROP is independent of pitch (T3's energy-
## normalized law), so entry speed climbs through the cluster exactly as it
## would through any other T1-style chain -- no control ramp needed (R3 M1/M2).
## Appends each ramp's low end to `spine`; the caller builds the surface.
func _build_seam_cluster(x: float, y: float, z: float, entry_speed: float, delta_deg: float, spine: Array[Vector3]) -> void:
	var pitches := [SPINE_PITCH_DEG, SPINE_PITCH_DEG + delta_deg, SPINE_PITCH_DEG, SPINE_PITCH_DEG + delta_deg]
	var _probe_i := 0  ## DEBUG PROBE — remove before gates
	for pitch in pitches:
		if _probe_i > 0:  ## DEBUG PROBE — remove before gates: seam lip = entry of ramps 2/3/4
			_probe_seam_lips.append({"id": "%s#%d" % [_probe_cluster_label, _probe_i], "pos": Vector3(x, y, z)})
		_probe_i += 1  ## DEBUG PROBE — remove before gates
		var path_len: float = SEAM_RAMP_DROP / sin(deg_to_rad(pitch))
		var horiz_span: float = path_len * cos(deg_to_rad(pitch))
		spine.append(Vector3(x, y - SEAM_RAMP_DROP, z - horiz_span))

		entry_speed = ETA * sqrt(entry_speed * entry_speed + 70.4 * SEAM_RAMP_DROP)
		z -= horiz_span
		y -= SEAM_RAMP_DROP


## Rounded seams: replaces every interior pitch change of a straight-segment
## spine with a circular arc of arc length `fillet_len`, tangent to both
## neighbouring segments, so the slope stays continuous through the seam
## instead of creasing. Arcs live in the vertical plane of the path (x fixed).
func _fillet_spine(spine: Array[Vector3], fillet_len: float) -> Array[Vector3]:
	var out: Array[Vector3] = [spine[0]]
	for i in range(1, spine.size() - 1):
		var p := spine[i]
		var d1 := (p - spine[i - 1]).normalized()
		var d2 := (spine[i + 1] - p).normalized()
		var phi1 := atan2(-d1.y, -d1.z)  # pitch below horizontal, travelling -z
		var phi2 := atan2(-d2.y, -d2.z)
		var theta := absf(phi2 - phi1)
		if theta < 0.001:
			out.append(p)
			continue
		var r := fillet_len / theta
		var tangent := r * tan(theta / 2.0)
		assert(tangent <= minf(p.distance_to(spine[i - 1]), p.distance_to(spine[i + 1])) / 2.0)
		var t1 := p - d1 * tangent
		var sgn := signf(phi2 - phi1)
		var n_steps := maxi(2, ceili(fillet_len / FILLET_STEP))
		for k in range(n_steps + 1):
			var phi := lerpf(phi1, phi2, float(k) / n_steps)
			var du := sgn * r * (sin(phi) - sin(phi1))  # along-path (-z) offset from t1
			var dy := sgn * r * (cos(phi) - cos(phi1))
			out.append(Vector3(p.x, t1.y + dy, t1.z - du))
	out.append(spine[spine.size() - 1])
	return out


## Seam-cluster surface: both faces of a surf peak extruded along a bent spine
## polyline as ONE trimesh. Every face quad is (P_i, P_i+1) plus the SAME
## lateral vector, so neighbouring ramps share their junction edge exactly --
## _ramp_pair's rolled-then-pitched boxes swing their end edges apart whenever
## pitch changes (issue #15: up to 1.2 m steps and holes at the seam lips). The
## face angle holds in the vertical cross-section across the path (CS-style
## extruded profile): |n.y| 0.619 at the 12deg base pitch vs _ramp_pair's 0.611.
func _add_surf_strip(spine: Array[Vector3], angle_deg: float, face_width: float, color: Color) -> void:
	var a := deg_to_rad(angle_deg)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for side in [-1.0, 1.0]:
		var lateral := Vector3(side * cos(a), -sin(a), 0.0) * face_width
		for i in range(spine.size() - 1):
			var p0 := spine[i]
			var p1 := spine[i + 1]
			var n := (p1 - p0).cross(lateral).normalized()
			if n.y < 0.0:
				n = -n
			for v in [p0, p1, p1 + lateral, p0, p1 + lateral, p0 + lateral]:
				verts.append(v)
				normals.append(n)
			_track_lowest(p1.y + lateral.y)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	shape.backface_collision = true  # winding-agnostic: either side of a face collides
	col.shape = shape
	body.add_child(col)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = mesh
	body.add_child(mesh_inst)
	$Geometry.add_child(body)


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
