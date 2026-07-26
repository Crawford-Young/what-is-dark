class_name MomentumPlayer
extends CharacterBody3D
## Lab-only player: Source movement via SourceMove. No wallrun, no glance, no erosion.

const MOUSE_SENS := 0.002
const FLOOR_LIMIT_DEG := 38.0  ## must classify the pitched ramps' peak-side edge faces (normal
## y = sin(51.34°)·cos(12°) ≈ 0.764) as WALLS; cos(38°) ≈ 0.788 gives margin; nothing legit in
## the lab slopes between 0° and 45° — all real floors are flat, normal y = 1.0

var _yaw := 0.0
var _pitch := 0.0
var _yaw_drain := YawDrain.new()  ## drains render-rate mouse yaw across physics ticks in a
## bounded window -- see YawDrain docstring. Camera facing uses this SAME smoothed yaw as the
## wish direction (no split raw/smoothed paths): the resulting ~1-tick average look latency is
## imperceptible, and a single yaw feeding both keeps this script's one existing rotation path.
## Pitch stays immediate (unbuffered) -- it only drives the camera look, never the movement
## math the render-rate bug corrupted, so there's nothing for it to desync from.

@onready var _head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.0
	wall_min_slide_angle = 0.0
	floor_max_angle = deg_to_rad(FLOOR_LIMIT_DEG)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw_drain.add_delta(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 1.2)
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_yaw += _yaw_drain.drain_tick()
	rotation.y = _yaw
	_head.rotation.x = _pitch

	var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish_dir := transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)
	wish_dir.y = 0.0
	if wish_dir.length_squared() > 0.000001:
		wish_dir = wish_dir.normalized()

	var air_wish_speed := minf(SourceMove.RUN_SPEED, SourceMove.AIR_CAP)
	if is_on_floor() and Input.is_action_pressed(&"jump"):
		# Auto-hop: jump fires on the landing frame, friction never bites.
		velocity = SourceMove.jump(velocity)
		velocity = SourceMove.accelerate(velocity, wish_dir, air_wish_speed, SourceMove.AIR_ACCEL, delta)
	elif is_on_floor():
		velocity = SourceMove.apply_friction(velocity, delta)
		velocity = SourceMove.accelerate(velocity, wish_dir, SourceMove.RUN_SPEED, SourceMove.GROUND_ACCEL, delta)
	else:
		velocity = SourceMove.accelerate(velocity, wish_dir, air_wish_speed, SourceMove.AIR_ACCEL, delta)
		velocity = SourceMove.apply_gravity(velocity, delta)

	var pre_slide_velocity := velocity
	move_and_slide()
	var steep: Array[Vector3] = []
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.dot(Vector3.UP) < cos(deg_to_rad(FLOOR_LIMIT_DEG)):  # steeper than floor_max_angle → surf surface
			steep.append(normal)
	if steep.size() > 0 and not is_on_floor():
		# Godot GROUNDED move_and_slide deletes horizontal-into-wall velocity on
		# steep walls (anti-climb) instead of sliding along the plane. Recompute
		# from the pre-slide velocity with Source clip semantics.
		velocity = SourceMove.clip_multi(pre_slide_velocity, steep)
	_probe_sample(delta)  # DEBUG PROBE — remove before gates


## DEBUG PROBE — remove before gates (phase-3b T3 surf measurement).
## Per-tick position/velocity samples to user://surf_probe.csv; rates are
## post-processed from POSITION deltas over spans, never per-tick strides.
var _probe_file: FileAccess = null
var _probe_t := 0.0
var _probe_ticks := 0


func _probe_sample(delta: float) -> void:
	if _probe_file == null:
		_probe_file = FileAccess.open("user://surf_probe.csv", FileAccess.WRITE)
		_probe_file.store_line("t,x,y,z,vx,vy,vz,on_floor")
	_probe_t += delta
	_probe_file.store_line("%.5f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d" % [
		_probe_t, global_position.x, global_position.y, global_position.z,
		velocity.x, velocity.y, velocity.z, 1 if is_on_floor() else 0])
	_probe_ticks += 1
	if _probe_ticks % 120 == 0:
		_probe_file.flush()


func teleport(pos: Vector3, face_dir: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = atan2(-face_dir.x, -face_dir.z)
	rotation.y = _yaw
	_pitch = 0.0
	_yaw_drain.reset()
