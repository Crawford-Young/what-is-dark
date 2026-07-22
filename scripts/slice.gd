class_name Slice
extends Node3D
## Owns the course: projects player onto the path, evaluates posture,
## advances the void, detects the catch.

signal player_caught

const MARKER_PROGRESSES: Array[float] = [0.0, 25.0, 50.0, 75.0, 100.0, 130.0, 160.0, 190.0]
const FALL_Y := -6.0
const VOID_START := -20.0

var course := CourseLogic.new(MARKER_PROGRESSES)
var void_logic := VoidLogic.new(VOID_START)
var loop_logic := LoopLogic.new()
var catch_armed := true

@onready var _player: Player = $Player
@onready var _path: Path3D = $CoursePath
@onready var _void_wall: VoidWall = $VoidWall


func _ready() -> void:
	player_caught.connect(func() -> void:
		($SwallowDirector as SwallowDirector).begin_swallow(self, _player))


func player_progress() -> float:
	return _path.curve.get_closest_offset(_path.to_local(_player.global_position))


func _physics_process(delta: float) -> void:
	if _player.frozen:
		return
	if _player.global_position.y < FALL_Y:
		($SwallowDirector as SwallowDirector).begin_fall_reset(self, _player)
		return
	var progress := player_progress()
	var dir_to_void := _horizontal_dir(_void_wall.global_position - _player.global_position)
	var posture := Posture.evaluate(_player.camera_forward(), dir_to_void, _player.glancing)
	void_logic.advance(posture, delta)
	_void_wall.place_on_path(_path, void_logic.progress)
	if catch_armed and void_logic.has_caught(progress):
		catch_armed = false
		player_caught.emit()
	if not _player.frozen and LoopLogic.has_crossed_door(progress):
		($SwallowDirector as SwallowDirector).begin_loop(self, _player)


func sync_void_wall() -> void:
	_void_wall.place_on_path(_path, void_logic.progress)


func respawn_position(marker_index: int) -> Vector3:
	var offset := course.marker_progresses[marker_index]
	return _path.to_global(_path.curve.sample_baked(offset)) + Vector3.UP


func course_direction_at(offset: float) -> Vector3:
	var curve := _path.curve
	var here := curve.sample_baked(offset)
	var ahead := curve.sample_baked(minf(offset + 1.0, curve.get_baked_length()))
	return _horizontal_dir(_path.to_global(ahead) - _path.to_global(here))


func _horizontal_dir(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length_squared() > 0.000001 else Vector3.FORWARD


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		($SwallowDirector as SwallowDirector).begin_loop(self, _player)
