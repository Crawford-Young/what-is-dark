@abstract
class_name Zone
extends Course
## A Blender-exported place (issue #23): the art from its glb, the colliders and the line from its
## sidecar (`ZoneSpec`). The exporter already wrote both in the Godot frame, so the zone root
## stays identity.
##
## Built children: `Art` (the glb), `PLAY/<box name>` (one `StaticBody3D` per sidecar box, `Col`
## a `BoxShape3D`; eroding boxes carry the erodable-platform contract) and `CoursePath`. The scene
## supplies the rest of the `Course` contract: `Player`, `VoidWall`, `SwallowDirector`,
## `WorldEnvironment`. The door is a progress threshold on the line (`door_progress`), no box.
##
## Everything is built in `_init`: `Course` resolves `$CoursePath` before any `_ready` body runs,
## and a place's identity is its subclass's constants because `_spec` is built before any
## exported property could be set.

const ART_NODE := "Art"
const PLAY_NODE := "PLAY"
const PATH_NODE := "CoursePath"
const COL_NODE := "Col"
const MESH_NODE := "Mesh"

## Parsed ONCE, by `_parse_zone()` from the subclass's `_build_spec()` — which `Course` runs in a
## member initializer, before this class's own. So this member must carry NO initializer: GDScript
## would run it after `_build_spec()` and reset the parsed spec to null.
var _zone: ZoneSpec


## The sidecar this place is built from (`data/course/0N-<place>.json`).
@abstract func _sidecar_path() -> String
## The place's art: the exported glb, or any scene with the same `PLAY/<object>` layout.
@abstract func _art_path() -> String


## A place's `CourseSpec`: the parsed sidecar's line plus the place's own scene, declarations,
## void start and audit baseline. Sidecar defects ride along as `load_errors`, so `validate()`
## fails on them.
static func spec_for(
	zone: ZoneSpec, declarations_path: String, scene_path: String, void_start: float,
	baseline: Array[String]
) -> CourseSpec:
	var spec := zone.course_spec()
	spec.scene_path = scene_path
	spec.declarations_path = declarations_path
	spec.void_start = void_start
	spec.baseline = baseline
	return spec


## For the subclass's `_build_spec()`: parses the sidecar + declarations and keeps the result for
## the build in `_init`.
func _parse_zone(declarations_path: String) -> ZoneSpec:
	_zone = ZoneSpec.load_files(_sidecar_path(), declarations_path)
	return _zone


func _init() -> void:
	if _zone == null:
		push_error(
			"%s: _build_spec() must parse through _parse_zone()" % get_script().resource_path
		)
		_parse_zone(_spec.declarations_path)
	var materials := _build_art()
	_build_play(materials)
	_build_path()


func _ready() -> void:
	super._ready()
	_player.teleport(_zone.spawn, course_direction_at(0.0))


## Roles come from the sidecar, spans from the declarations file — `ZoneSpec` merges them.
func audit_manifest() -> Variant:
	return _zone.manifest()


## Instances the art and strips the meshes of eroding PLAY objects: a glb mesh is the loop-0
## shape and would stay that size while its colliders shrink. Returns each stripped object's
## material, for the box meshes that replace it.
func _build_art() -> Dictionary:
	var materials := {}
	var packed := load(_art_path()) as PackedScene
	if packed == null:
		push_error("%s: art %s did not load" % [name, _art_path()])
		return materials
	var art := packed.instantiate()
	art.name = ART_NODE
	add_child(art)
	var play := art.find_child(PLAY_NODE, true, false)
	for object in _zone.eroding_objects():
		var mesh := (play.find_child(object, true, false) if play else null) as MeshInstance3D
		if mesh == null:
			push_error("%s: eroding object %s has no mesh under the art's PLAY" % [name, object])
			continue
		materials[object] = mesh.get_active_material(0)
		mesh.free()
	return materials


func _build_play(materials: Dictionary) -> void:
	var play := Node3D.new()
	play.name = PLAY_NODE
	add_child(play)
	for box in _zone.boxes:
		var body := StaticBody3D.new()
		body.name = box["name"]
		body.position = box["center"]
		var col := CollisionShape3D.new()
		col.name = COL_NODE
		var shape := BoxShape3D.new()
		shape.size = box["size"]
		col.shape = shape
		body.add_child(col)
		var erode: Dictionary = box["erode"]
		# A stripped object's boxes are drawn here; every other box is drawn by its art. An eroding
		# box always gets its Mesh — the erodable contract needs one even if the art failed.
		if materials.has(box["object"]) or not erode.is_empty():
			var mesh_node := MeshInstance3D.new()
			mesh_node.name = MESH_NODE
			var mesh := BoxMesh.new()
			mesh.size = box["size"]
			mesh.material = materials.get(box["object"])
			mesh_node.mesh = mesh
			body.add_child(mesh_node)
		if not erode.is_empty():
			body.add_to_group(EROSION_GROUP)
			body.set_meta("erode_axis", erode["axis"])
			body.set_meta("erode_min", erode["min"])
			body.set_meta("erode_anchor", erode["anchor"])
		play.add_child(body)


func _build_path() -> void:
	var path := Path3D.new()
	path.name = PATH_NODE
	var curve := Curve3D.new()
	for point in _zone.path:
		curve.add_point(point)
	path.curve = curve
	add_child(path)
