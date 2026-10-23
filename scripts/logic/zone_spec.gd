class_name ZoneSpec
extends RefCounted
## Sidecar v1 -> box specs and course-spec values for a Blender-exported zone (issue #23).
##
## The sidecar (`data/course/0N-<place>.json`) is written by `art/course/build/export.py`, already
## in the Godot frame: every PLAY box with its role and erosion, the racing line, spawn, markers,
## door and fall plane. The declarations file (`0N-<place>.declarations.json`) is hand-authored:
## span verbs, floors, landing bands and non-role surface keys, keyed by box name.
##
## Every defect is returned in `errors` and nothing is defaulted: a box that fails validation is
## dropped AND reported, because a silently dropped box is a hole in the course no later gate sees.

const VERSION := 1
const FRAME := "godot"
## −1 pins the low edge, 0 the centre, +1 the high edge.
const ERODE_ANCHORS: Array[float] = [-1.0, 0.0, 1.0]
const BOX_KEYS: Array[String] = ["name", "object", "role", "center", "size", "solid"]
## Top-level keys every sidecar states. `door_progress` is not here: a place with no line has none.
const SIDECAR_KEYS: Array[String] = ["place", "boxes", "path", "spawn", "markers", "fall_y"]
const DECLARATION_KEYS: Array[String] = ["spans", "surfaces", "floors", "landing_bands"]

var place := ""
## `{name, object, role, center: Vector3, size: Vector3, solid: bool, erode}` — `erode` is `{}`
## for a box that never erodes, else `{axis: int, min: float, anchor: float}`.
var boxes: Array[Dictionary] = []
var path: Array[Vector3] = []
var spawn := Vector3.ZERO
var markers: Array[float] = []
var door_progress := 0.0
var fall_y := 0.0
## False when the sidecar states "no line" (`path: []`, `markers: []`, no door) — a place that
## cannot be ridden as a course yet, like the school today.
var has_line := false
var errors: Array[String] = []

var _declarations := {"spans": {}, "surfaces": {}, "floors": {}, "landing_bands": []}


static func parse(sidecar: Variant, declarations: Variant) -> ZoneSpec:
	var spec := ZoneSpec.new()
	if sidecar is not Dictionary:
		spec.errors.append("sidecar must be a JSON object, got %s" % type_string(typeof(sidecar)))
	else:
		spec._parse_sidecar(sidecar)
	if declarations is not Dictionary:
		spec.errors.append(
			"declarations must be a JSON object, got %s" % type_string(typeof(declarations))
		)
	else:
		spec._parse_declarations(declarations)
	return spec


static func load_files(sidecar_path: String, declarations_path: String) -> ZoneSpec:
	var load_errors: Array[String] = []
	var sidecar: Variant = _read_json(sidecar_path, load_errors)
	var declarations: Variant = _read_json(declarations_path, load_errors)
	if not load_errors.is_empty():
		var failed := ZoneSpec.new()
		failed.errors = load_errors
		return failed
	return parse(sidecar, declarations)


## The PLAY objects Godot must draw from box records: the glb mesh of an eroding object shows the
## loop-0 shape forever, so the Zone strips it and draws every one of its boxes instead.
func eroding_objects() -> Array[String]:
	var objects: Array[String] = []
	for box in boxes:
		if not (box["erode"] as Dictionary).is_empty() and not objects.has(str(box["object"])):
			objects.append(str(box["object"]))
	return objects


## The course-law audit's manifest: the declarations file with every box's role filled in from
## the sidecar, the one source of roles.
func manifest() -> Dictionary:
	var surfaces := {}
	var declared: Dictionary = _declarations["surfaces"]
	for box in boxes:
		var surface: Dictionary = (declared.get(box["name"], {}) as Dictionary).duplicate()
		surface["role"] = box["role"]
		surfaces[box["name"]] = surface
	return {
		"spans": _declarations["spans"],
		"surfaces": surfaces,
		"floors": _declarations["floors"],
		"landing_bands": _declarations["landing_bands"],
	}


## The sidecar's share of a `CourseSpec`; the place supplies the scene, the declarations path, the
## void start and the audit baseline. Parse errors ride along as `load_errors`.
func course_spec() -> CourseSpec:
	var spec := CourseSpec.new()
	spec.markers = markers.duplicate()
	spec.door_progress = door_progress
	spec.fall_y = fall_y
	spec.load_errors = errors.duplicate()
	return spec


# --- sidecar ---------------------------------------------------------------------------------


func _parse_sidecar(sidecar: Dictionary) -> void:
	if not _is_number(sidecar.get("version")) or float(sidecar["version"]) != VERSION:
		errors.append("sidecar version must be %d, got %s" % [VERSION, str(sidecar.get("version"))])
	if str(sidecar.get("frame", "")) != FRAME:
		errors.append("sidecar frame must be \"%s\", got %s" % [FRAME, str(sidecar.get("frame"))])
	for key in SIDECAR_KEYS:
		if not sidecar.has(key):
			errors.append("sidecar is missing \"%s\" — no key is defaulted" % key)
	place = str(sidecar.get("place", ""))

	if sidecar.has("boxes"):
		_parse_boxes(sidecar["boxes"])
	if sidecar.has("spawn"):
		var at: Variant = _vector(sidecar["spawn"])
		if at == null:
			errors.append("spawn must be [x, y, z], got %s" % str(sidecar["spawn"]))
		else:
			spawn = at
	if sidecar.has("fall_y"):
		if not _is_number(sidecar["fall_y"]):
			errors.append("fall_y must be a number, got %s" % str(sidecar["fall_y"]))
		else:
			fall_y = float(sidecar["fall_y"])
	if sidecar.has("path") and sidecar.has("markers"):
		_parse_line(sidecar)


## A line is all-or-nothing: path + markers + door, or the explicit "no line" of `path: []`,
## `markers: []` and no door. Anything in between is a half-exported place.
func _parse_line(sidecar: Dictionary) -> void:
	var raw_path: Variant = sidecar["path"]
	var raw_markers: Variant = sidecar["markers"]
	if raw_path is not Array or raw_markers is not Array:
		errors.append("path and markers must be arrays")
		return
	if (raw_path as Array).is_empty() and (raw_markers as Array).is_empty():
		if sidecar.has("door_progress"):
			errors.append("door_progress on a place with no line (empty path and markers)")
		return
	if (raw_path as Array).is_empty() or (raw_markers as Array).is_empty():
		errors.append(
			"path has %d points but markers has %d — a line needs both, \"no line\" neither"
			% [(raw_path as Array).size(), (raw_markers as Array).size()]
		)
		return

	has_line = true
	if (raw_path as Array).size() < 2:
		errors.append("path needs at least 2 points, got %d" % (raw_path as Array).size())
	for point in raw_path as Array:
		var at: Variant = _vector(point)
		if at == null:
			errors.append("path point must be [x, y, z], got %s" % str(point))
		else:
			path.append(at)
	for marker in raw_markers as Array:
		if not _is_number(marker):
			errors.append("marker must be a number, got %s" % str(marker))
		else:
			markers.append(float(marker))
	if not sidecar.has("door_progress"):
		errors.append("door_progress missing on a place with a line — the lap needs its door")
	elif not _is_number(sidecar["door_progress"]):
		errors.append("door_progress must be a number, got %s" % str(sidecar["door_progress"]))
	else:
		door_progress = float(sidecar["door_progress"])


func _parse_boxes(raw: Variant) -> void:
	if raw is not Array:
		errors.append("boxes must be an array")
		return
	var seen := {}
	for i in (raw as Array).size():
		var entry: Variant = raw[i]
		var label := "box %d" % i
		if entry is Dictionary and entry.get("name") is String:
			label = entry["name"]
		var box_errors: Array[String] = []
		var box := _parse_box(entry, box_errors)
		if box_errors.is_empty() and seen.has(box["name"]):
			box_errors.append("duplicate box name")
		for e in box_errors:
			errors.append("%s: %s" % [label, e])
		if box_errors.is_empty():
			seen[box["name"]] = true
			boxes.append(box)


func _parse_box(entry: Variant, box_errors: Array[String]) -> Dictionary:
	if entry is not Dictionary:
		box_errors.append("not a JSON object")
		return {}
	var raw: Dictionary = entry
	for key in BOX_KEYS:
		if not raw.has(key):
			box_errors.append("missing \"%s\"" % key)
	if not box_errors.is_empty():
		return {}

	# The name becomes the body's node name, and the audit resolves roles by node name: a name
	# Godot would rewrite (Blender's "Cube.001") would silently lose its role.
	var box_name := str(raw["name"])
	if box_name.is_empty() or box_name.validate_node_name() != box_name:
		box_errors.append("name \"%s\" is not a valid Godot node name" % box_name)
	var role := str(raw["role"])
	if not CourseDecl.ROLES.has(role):
		box_errors.append("unknown role \"%s\"" % role)
	var center: Variant = _vector(raw["center"])
	if center == null:
		box_errors.append("center must be [x, y, z], got %s" % str(raw["center"]))
	var size: Variant = _vector(raw["size"])
	if size == null:
		box_errors.append("size must be [x, y, z], got %s" % str(raw["size"]))
	elif (size as Vector3).x <= 0.0 or (size as Vector3).y <= 0.0 or (size as Vector3).z <= 0.0:
		box_errors.append("size must be positive on every axis, got %s" % str(size))
	if raw["solid"] is not bool:
		box_errors.append("solid must be true or false, got %s" % str(raw["solid"]))

	var erode := {}
	if raw.has("erode"):
		erode = _parse_erode(raw["erode"], role, size, box_errors)
	if not box_errors.is_empty():
		return {}
	return {
		"name": box_name,
		"object": str(raw["object"]),
		"role": role,
		"center": center,
		"size": size,
		"solid": raw["solid"],
		"erode": erode,
	}


func _parse_erode(
	raw: Variant, role: String, size: Variant, box_errors: Array[String]
) -> Dictionary:
	if raw is not Dictionary:
		box_errors.append("erode must be {axis, min, anchor}")
		return {}
	var erode: Dictionary = raw
	if not CourseDecl.erodable_legal_for_role(role):
		box_errors.append(
			"role \"%s\" erodes — only \"%s\" may erode (issue #12)"
			% [role, CourseDecl.EROD_ROLE]
		)
	var axis: Variant = erode.get("axis")
	if not _is_number(axis) or float(axis) not in [0.0, 2.0]:
		# The erodable-platform contract (repo CLAUDE.md): `erode_axis` 0 = x, 2 = z.
		box_errors.append("erode axis must be 0 (x) or 2 (z), got %s" % str(axis))
		return {}
	var anchor: Variant = erode.get("anchor")
	var anchor_ok := _is_number(anchor) and ERODE_ANCHORS.has(float(anchor))
	if not anchor_ok:
		box_errors.append("erode anchor must be -1, 0 or 1, got %s" % str(anchor))
	var min_size: Variant = erode.get("min")
	var min_ok := _is_number(min_size)
	if not min_ok:
		box_errors.append("erode min must be a number, got %s" % str(min_size))
	elif size != null and (min_size <= 0.0 or min_size > (size as Vector3)[int(axis)]):
		box_errors.append(
			"erode min %s must lie in (0, %s], the box's size on its axis"
			% [str(min_size), str((size as Vector3)[int(axis)])]
		)
	if not (anchor_ok and min_ok):
		return {}
	return {"axis": int(axis), "min": float(min_size), "anchor": float(anchor)}


# --- declarations ----------------------------------------------------------------------------


func _parse_declarations(raw: Dictionary) -> void:
	var names := {}
	for box in boxes:
		names[box["name"]] = true
	for key in raw:
		if not DECLARATION_KEYS.has(str(key)):
			errors.append("declarations: unknown key \"%s\" (known: %s)" % [
				key, ", ".join(DECLARATION_KEYS)
			])
	for key in DECLARATION_KEYS:
		if raw.has(key):
			var expected := TYPE_ARRAY if key == "landing_bands" else TYPE_DICTIONARY
			if typeof(raw[key]) != expected:
				errors.append("declarations: \"%s\" has the wrong type" % key)
	# Every entry is type-checked before it is read, and only well-formed entries reach the
	# manifest: the audit casts them without looking.
	_declarations["spans"] = _parse_spans(_section(raw, "spans", {}), names)
	_declarations["surfaces"] = _parse_surfaces(_section(raw, "surfaces", {}), names)
	_declarations["floors"] = _parse_floors(_section(raw, "floors", {}), names)
	var bands: Array = []
	for i in (_section(raw, "landing_bands", []) as Array).size():
		var band: Variant = raw["landing_bands"][i]
		if band is Dictionary:
			bands.append(band)
		else:
			errors.append("declarations: landing band %d is not an object" % i)
	_declarations["landing_bands"] = bands


## The section if it has the expected container type, else the empty default (already reported).
static func _section(raw: Dictionary, key: String, empty: Variant) -> Variant:
	var value: Variant = raw.get(key, empty)
	return value if typeof(value) == typeof(empty) else empty


func _parse_spans(raw: Dictionary, names: Dictionary) -> Dictionary:
	var spans := {}
	for span_id in raw:
		if raw[span_id] is not Dictionary:
			errors.append("declarations: span \"%s\" is not an object" % span_id)
			continue
		for end in str(span_id).split(">"):
			if not names.has(end):
				errors.append("declarations: span \"%s\" names unknown box \"%s\"" % [span_id, end])
		spans[span_id] = raw[span_id]
	return spans


func _parse_surfaces(raw: Dictionary, names: Dictionary) -> Dictionary:
	var surfaces := {}
	for surface_name in raw:
		if not names.has(surface_name):
			errors.append("declarations: surface \"%s\" is not a sidecar box" % surface_name)
		elif raw[surface_name] is not Dictionary:
			errors.append("declarations: surface \"%s\" is not an object" % surface_name)
		elif (raw[surface_name] as Dictionary).has("role"):
			errors.append(
				"declarations: %s declares a role — roles come only from the sidecar"
				% surface_name
			)
		else:
			surfaces[surface_name] = raw[surface_name]
	return surfaces


func _parse_floors(raw: Dictionary, names: Dictionary) -> Dictionary:
	var floors := {}
	for floor_id in raw:
		if raw[floor_id] is not Dictionary:
			errors.append("declarations: floor \"%s\" is not an object of lanes" % floor_id)
			continue
		var lanes := {}
		for lane_id in raw[floor_id] as Dictionary:
			var tiles: Variant = raw[floor_id][lane_id]
			if tiles is not Array:
				errors.append(
					"declarations: floor \"%s\" lane \"%s\" is not a list of boxes"
					% [floor_id, lane_id]
				)
				continue
			for tile in tiles as Array:
				if not names.has(str(tile)):
					errors.append(
						"declarations: floor %s lane %s names unknown box \"%s\""
						% [floor_id, lane_id, tile]
					)
			lanes[lane_id] = tiles
		if not lanes.is_empty():
			floors[floor_id] = lanes
	return floors


# --- shared ----------------------------------------------------------------------------------


static func _vector(raw: Variant) -> Variant:
	if raw is not Array or (raw as Array).size() != 3:
		return null
	for v in raw as Array:
		if not _is_number(v):
			return null
	return Vector3(raw[0], raw[1], raw[2])


## JSON numbers parse as float; GDScript literals in tests are int. Both are numbers.
static func _is_number(v: Variant) -> bool:
	return v is float or v is int


static func _read_json(file_path: String, load_errors: Array[String]) -> Variant:
	if not FileAccess.file_exists(file_path):
		load_errors.append("%s: no such file" % file_path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		load_errors.append(
			"%s:%d: %s" % [file_path, json.get_error_line(), json.get_error_message()]
		)
		return null
	return json.data
