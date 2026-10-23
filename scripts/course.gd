@abstract
class_name Course
extends Node3D
## A ridden course: projects the player onto the path, evaluates posture, advances the void,
## detects the catch, ends the lap at the door and erodes the world per loop. Any course scene —
## the slice now, Blender-exported zones from #23 on — extends this and supplies its data through
## `_build_spec()`; nothing here reads a particular course's constants.
##
## Scene contract: children `Player`, `CoursePath` (Path3D), `VoidWall`, `WorldEnvironment` and
## `SwallowDirector`, plus any `StaticBody3D` in group `erodable` per the erodable-platform
## contract (repo CLAUDE.md).

signal player_caught

const EROSION_GROUP := "erodable"

## Built once at construction, before `_ready`, so the logic objects below can read it.
var _spec: CourseSpec = _build_spec()

var marker_logic := CourseLogic.new(_spec.markers)
var void_logic := VoidLogic.new(_spec.void_start)
var loop_logic := LoopLogic.new()
var catch_armed := true

var marker_progresses: Array[float]:
	get:
		return _spec.markers
var fall_y: float:
	get:
		return _spec.fall_y
var door_progress: float:
	get:
		return _spec.door_progress
var void_start: float:
	get:
		return _spec.void_start

var _erodable: Array[Dictionary] = []

@onready var _player: Player = $Player
@onready var _path: Path3D = $CoursePath
@onready var _void_wall: VoidWall = $VoidWall
@onready var _world_env: WorldEnvironment = $WorldEnvironment


## The course's data: scene, declarations, markers, door, fall plane, void start, audit baseline.
@abstract func _build_spec() -> CourseSpec


func course_spec() -> CourseSpec:
	return _spec


## The course-law audit's manifest, or null to have the audit load `course_spec()`'s
## declarations file itself. A `Zone` overrides this: its roles live in its sidecar.
func audit_manifest() -> Variant:
	return null


func _ready() -> void:
	for error in _spec.validate():
		push_error("%s: %s" % [name, error])
	player_caught.connect(func() -> void:
		($SwallowDirector as SwallowDirector).begin_swallow(self, _player))
	_cache_erodable()
	apply_erosion()


## Applies world erosion for the current loop: hand-picked margined floors shrink
## toward their authored plateau size and the fog closes in. Idempotent — every
## dimension is recomputed from the cached shipped geometry, so loop 0 is the
## shipped course exactly and re-applying at one loop changes nothing.
func apply_erosion() -> void:
	var scale := ErosionLogic.world_scale(loop_logic.loop_count)
	for entry in _erodable:
		_erode(entry, scale)
	var density := ErosionLogic.fog_density(scale)
	var env := _world_env.environment
	env.fog_density = density
	env.fog_enabled = density > 0.0


## How many bodies `_cache_erodable()` took. Zero after `_ready` means no erosion will run — the
## audit's setup guard reads this rather than trusting a probe of an un-readied course.
func erodable_count() -> int:
	return _erodable.size()


func _cache_erodable() -> void:
	for node in get_tree().get_nodes_in_group(EROSION_GROUP):
		var body := node as StaticBody3D
		# The group is tree-wide: a second course in the tree must not erode this one's floors.
		if body == null or not is_ancestor_of(body):
			continue
		var col := body.get_node_or_null("Col") as CollisionShape3D
		var mesh_node := body.get_node_or_null("Mesh") as MeshInstance3D
		if col == null or mesh_node == null:
			continue
		# Shapes and meshes are sub-resources SHARED across platforms (Sh1FloorB and
		# Sh3FloorA both use shape_f14) — erosion takes a private copy per body or it
		# would resize untagged siblings too.
		var shape := (col.shape as BoxShape3D).duplicate() as BoxShape3D
		var box := (mesh_node.mesh as BoxMesh).duplicate() as BoxMesh
		col.shape = shape
		mesh_node.mesh = box
		_erodable.append({
			"body": body,
			"shape": shape,
			"mesh": box,
			"axis": int(body.get_meta("erode_axis")),
			"min_size": float(body.get_meta("erode_min")),
			"anchor": float(body.get_meta("erode_anchor")),
			"base_size": shape.size,
			"base_origin": body.position,
		})


func _erode(entry: Dictionary, scale: float) -> void:
	var axis: int = entry["axis"]
	var base_size: Vector3 = entry["base_size"]
	var min_size: float = entry["min_size"]
	var anchor: float = entry["anchor"]
	var size := base_size
	size[axis] = ErosionLogic.eroded_size(base_size[axis], min_size, scale)
	(entry["shape"] as BoxShape3D).size = size
	(entry["mesh"] as BoxMesh).size = size
	var origin: Vector3 = entry["base_origin"]
	origin[axis] = ErosionLogic.anchored_origin(
		origin[axis], base_size[axis], size[axis], anchor
	)
	(entry["body"] as StaticBody3D).position = origin


func player_progress() -> float:
	return _path.curve.get_closest_offset(_path.to_local(_player.global_position))


func _physics_process(delta: float) -> void:
	if _player.frozen:
		return
	if _player.global_position.y < fall_y:
		($SwallowDirector as SwallowDirector).begin_fall_reset(self, _player)
		return
	var progress := player_progress()
	var dir_to_void := _horizontal_dir(_void_wall.global_position - _player.global_position)
	var posture := Posture.evaluate(_player.camera_forward(), dir_to_void, _player.glancing)
	void_logic.advance(posture, delta, loop_logic.loop_count)
	_void_wall.place_on_path(_path, void_logic.progress)
	if catch_armed and void_logic.has_caught(progress):
		catch_armed = false
		player_caught.emit()
	if not _player.frozen and LoopLogic.has_crossed_door(progress, door_progress):
		($SwallowDirector as SwallowDirector).begin_loop(self, _player)


func sync_void_wall() -> void:
	_void_wall.place_on_path(_path, void_logic.progress)


func respawn_position(marker_index: int) -> Vector3:
	var offset := marker_progresses[marker_index]
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
