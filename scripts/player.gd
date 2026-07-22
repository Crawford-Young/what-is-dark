class_name Player
extends CharacterBody3D
## Node layer: reads input + raycasts, delegates all math to logic scripts.

const RUN_SPEED := 11.0
const GROUND_ACCEL := 80.0
const AIR_ACCEL := 25.0
const GRAVITY := 20.0
const JUMP_SPEED := 8.5
const MOUSE_SENS := 0.002
const GLANCE_TURN_SPEED := 18.0

var frozen := false
var glancing := false

var accel_scale := 1.0
var landing_retention := 1.0

var _was_airborne := false

var _yaw := 0.0
var _pitch := 0.0
var _glance_amount := 0.0

@onready var _head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 1.2)
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if frozen:
		return
	glancing = Input.is_action_pressed(&"glance")
	_glance_amount = move_toward(_glance_amount, PI if glancing else 0.0, GLANCE_TURN_SPEED * delta)

	rotation.y = _yaw
	_head.rotation.y = _glance_amount
	_head.rotation.x = _pitch if not glancing else -_pitch

	var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var wish_dir := (transform.basis * Vector3(input_2d.x, 0.0, input_2d.y))
	var forward_speed := -(transform.basis.inverse() * velocity).z

	var wall_normal := _wall_normal()
	var on_wall := wall_normal != Vector3.ZERO

	if WallrunLogic.can_wallrun(is_on_floor(), on_wall, forward_speed):
		velocity = WallrunLogic.wallrun_velocity(velocity, wall_normal, delta)
		if Input.is_action_just_pressed(&"jump"):
			velocity = WallrunLogic.walljump_velocity(velocity, wall_normal)
	else:
		var accel := (GROUND_ACCEL if is_on_floor() else AIR_ACCEL) * accel_scale
		velocity = MoveMath.accel_horizontal(velocity, wish_dir, RUN_SPEED, accel, delta)
		if not is_on_floor():
			velocity = MoveMath.apply_gravity(velocity, GRAVITY, delta)
		elif Input.is_action_just_pressed(&"jump"):
			velocity = MoveMath.jump(velocity, JUMP_SPEED)

	move_and_slide()
	if is_on_floor() and _was_airborne:
		velocity = MoveMath.land(velocity, landing_retention)
	_was_airborne = not is_on_floor()


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
