class_name MomentumPlayer
extends CharacterBody3D
## Lab-only player: Source movement via SourceMove. No wallrun, no glance, no erosion.

const MOUSE_SENS := 0.002

var _yaw := 0.0
var _pitch := 0.0

@onready var _head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = 0.0
	wall_min_slide_angle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 1.2)
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
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

	move_and_slide()
	var steep: Array[Vector3] = []
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.dot(Vector3.UP) < 0.7:  # steeper than floor_max_angle → surf surface
			steep.append(normal)
	if steep.size() > 0:
		velocity = SourceMove.clip_multi(velocity, steep)


func teleport(pos: Vector3, face_dir: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = atan2(-face_dir.x, -face_dir.z)
	rotation.y = _yaw
	_pitch = 0.0
