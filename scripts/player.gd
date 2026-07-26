class_name Player
extends CharacterBody3D
## Node layer: reads input + raycasts, delegates all math to logic scripts.
## Source movement core (momentum lab, ADOPTED 2026-07-24): YawDrain-buffered
## yaw, auto-hop on held jump, pre-slide surf clip on steep contacts.

const MOUSE_SENS := 0.002
const GLANCE_TURN_SPEED := 18.0
const FLOOR_LIMIT_DEG := 38.0  ## lab-parity classification boundary: steeper than
## this = wall (surfable in 3b). Every existing lap floor is flat (normal y = 1.0),
## so nothing reclassifies; 38° must hold so future pitched ramps read as walls.

var frozen := false
var glancing := false
var accel_scale := 1.0
var _jump_was_down := false

var _yaw := 0.0
var _pitch := 0.0
var _glance_amount := 0.0
var _yaw_drain := YawDrain.new()  ## drains render-rate mouse yaw across physics
## ticks in a bounded window; camera facing uses the same smoothed yaw as the
## wish direction (single rotation path — see YawDrain docstring)

@onready var _head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.0
	wall_min_slide_angle = 0.0
	floor_max_angle = deg_to_rad(FLOOR_LIMIT_DEG)


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseMotion:
		_yaw_drain.add_delta(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 1.2)
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if frozen:
		return
	_yaw += _yaw_drain.drain_tick()
	rotation.y = _yaw
	glancing = Input.is_action_pressed(&"glance")
	_glance_amount = move_toward(_glance_amount, PI if glancing else 0.0, GLANCE_TURN_SPEED * delta)
	_head.rotation.y = _glance_amount
	_head.rotation.x = _pitch if not glancing else -_pitch

	var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var jump_down := Input.is_action_pressed(&"jump")
	var wish_dir := transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)
	wish_dir.y = 0.0
	if wish_dir.length_squared() > 0.000001:
		wish_dir = wish_dir.normalized()
	var forward_speed := -(transform.basis.inverse() * velocity).z

	var wall_normal := _wall_normal()
	var on_wall := WallrunLogic.is_rideable_normal(wall_normal)
	var air_wish_speed := minf(SourceMove.RUN_SPEED, SourceMove.AIR_CAP)

	if WallrunLogic.can_wallrun(is_on_floor(), on_wall, forward_speed):
		velocity = SourceMove.apply_gravity(velocity, delta)
		velocity = WallrunLogic.ride_velocity(velocity, wall_normal)
		if WallrunLogic.jump_pressed(_jump_was_down, jump_down):
			velocity = WallrunLogic.kick_velocity(velocity, wall_normal)
	elif is_on_floor() and jump_down:
		# Auto-hop: jump fires on the landing frame, friction never bites.
		velocity = SourceMove.jump(velocity)
		velocity = SourceMove.accelerate(velocity, wish_dir, air_wish_speed, SourceMove.AIR_ACCEL * accel_scale, delta)
	elif is_on_floor():
		velocity = SourceMove.apply_friction(velocity, delta)
		velocity = SourceMove.accelerate(velocity, wish_dir, SourceMove.RUN_SPEED, SourceMove.GROUND_ACCEL * accel_scale, delta)
	else:
		velocity = SourceMove.accelerate(velocity, wish_dir, air_wish_speed, SourceMove.AIR_ACCEL * accel_scale, delta)
		velocity = SourceMove.apply_gravity(velocity, delta)

	var pre_slide_velocity := velocity
	move_and_slide()
	var steep: Array[Vector3] = []
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.dot(Vector3.UP) < cos(deg_to_rad(FLOOR_LIMIT_DEG)):  # steeper than floor_max_angle
			steep.append(normal)
	if steep.size() > 0 and not is_on_floor():
		# Godot GROUNDED move_and_slide deletes horizontal-into-wall velocity on
		# steep walls (anti-climb). Recompute from the pre-slide velocity with
		# Source clip semantics (lab lesson, 9822c47).
		velocity = SourceMove.clip_multi(pre_slide_velocity, steep)
	_jump_was_down = jump_down


func _wall_normal() -> Vector3:
	if $RayWallLeft.is_colliding():
		return $RayWallLeft.get_collision_normal()
	if $RayWallRight.is_colliding():
		return $RayWallRight.get_collision_normal()
	return Vector3.ZERO


func camera_forward() -> Vector3:
	return -($Head/Camera as Camera3D).global_transform.basis.z


func teleport(pos: Vector3, face_dir: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = atan2(-face_dir.x, -face_dir.z)
	rotation.y = _yaw
	_pitch = 0.0
	_glance_amount = 0.0
	_jump_was_down = false
	_yaw_drain.reset()


func shift_to(pos: Vector3) -> void:
	global_position = pos
