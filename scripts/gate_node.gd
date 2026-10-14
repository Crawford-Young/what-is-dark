class_name GateNode
extends Node3D
## Node wrapper for a look-to-open gate: builds its own geometry in _ready()
## (no .tscn), ticks a GateLogic and maps openness() onto that geometry.
## Local frame: the approach runs along -Z, the gate's near edge sits at z = 0,
## the corridor floor top at y = 0. Set the exports BEFORE add_child.
##   Target  — the only block that opens the gate; a ray hit on Barrier/Bridge
##             resolves to the gate but activates nothing (user ruling, T6).
##   Barrier — "retract": a wall across the corridor that sinks into the floor.
##   Bridge  — "deploy": a walkway over a void gap that extends from the near lip.
## Collision is binary (flips as openness crosses 0.5); the mesh is continuous.
## Hidden (start_hidden, until reveal()): both blocks are invisible and the
## Target is unclickable, but a shut Barrier stays solid (user ruling, T7).

const OPEN_THRESHOLD := 0.5
const SINK_MARGIN := 0.02  ## fully-open wall sinks this far below the floor top (no z-fight)

@export var timed_window := GateLogic.NO_RECLOSE  ## seconds open before re-close; < 0 = stays open
@export var kind := "retract"  ## "retract" | "deploy"
@export var corridor_width := 8.0  ## x extent of the barrier / bridge
@export var barrier_height := 6.0  ## retract wall height above the floor top
@export var gap_length := 10.0  ## deploy bridge span along -Z (the void gap)
@export var thickness := 1.0  ## wall depth (retract) / walkway depth (deploy)
@export var target_size := Vector3(2.0, 2.0, 0.5)
@export var target_offset := Vector3(0.0, 8.0, 0.0)  ## target centre, gate-local
@export var start_hidden := false  ## hidden until reveal(); reset() returns here

var logic: GateLogic
var _target: StaticBody3D
var _target_col: CollisionShape3D
var _gate_body: StaticBody3D  ## the Barrier or Bridge
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _blocking := true
var _revealed := true


func _ready() -> void:
	logic = GateLogic.new(timed_window)
	_add_block(&"Target", target_offset, target_size, Color(1.0, 0.85, 0.2))
	match kind:
		"retract":
			_add_block(&"Barrier", Vector3(0.0, barrier_height / 2.0, -thickness / 2.0),
				Vector3(corridor_width, barrier_height, thickness), Color(0.6, 0.15, 0.15))
		"deploy":
			_add_block(&"Bridge", Vector3(0.0, -thickness / 2.0, -gap_length / 2.0),
				Vector3(corridor_width, thickness, gap_length), Color(0.2, 0.5, 0.6))
		_:
			push_error("GateNode: unknown kind '%s'" % kind)
			return
	_apply_openness(0.0)
	_set_revealed(not start_hidden)


## Rejected while hidden: an unseen gate cannot be opened.
func try_activate() -> bool:
	if not _revealed:
		return false
	return logic.try_activate()


func reveal() -> void:
	_set_revealed(true)


func is_revealed() -> bool:
	return _revealed


## Back to a fresh SHUT gate (openness 0 applied), hidden again if start_hidden.
func reset() -> void:
	logic = GateLogic.new(timed_window)
	_apply_openness(0.0)
	_set_revealed(not start_hidden)


## Activates only when the ray hit IS this gate's Target body (identity, not name).
func try_activate_from(collider: Object) -> bool:
	if collider == null or collider != _target:
		return false
	return try_activate()


## Walks parents from a ray-hit collider to its owning gate; null when none.
## collider.owner is the scene-save owner (null for procedural children), so
## the tree walk is the only reliable link.
static func resolve_gate(from: Node) -> GateNode:
	var n := from
	while n != null and not (n is GateNode):
		n = n.get_parent()
	return n as GateNode


func _physics_process(delta: float) -> void:
	if _mesh == null:
		return
	logic.tick(delta)
	_apply_openness(logic.openness())


func _apply_openness(openness: float) -> void:
	if kind == "retract":
		# Slides straight down: openness 1 puts the wall's top just under the floor.
		_mesh.position.y = -openness * (barrier_height + SINK_MARGIN)
		_set_blocking(openness < OPEN_THRESHOLD)
	else:
		# Extends from the near lip (z = 0); zero scale would make a singular
		# basis, so a closed bridge is hidden instead.
		var reach := clampf(openness, 0.0, 1.0)
		_mesh.visible = reach > 0.0
		_mesh.scale.z = maxf(reach, 0.001)
		_mesh.position.z = gap_length * (1.0 - reach) / 2.0
		_set_blocking(openness >= OPEN_THRESHOLD)


## Retract blocks while shut; deploy "blocks" (is walkable) while open. Deferred
## because the flip happens inside the physics step.
func _set_blocking(solid: bool) -> void:
	if solid == _blocking:
		return
	_blocking = solid
	_col.set_deferred(&"disabled", not solid)


## Visibility only on the blocks; the Target's collision follows it so a
## hidden Target can't be hit, while the gate body's collision stays owned by
## _set_blocking (a hidden shut Barrier still slams).
func _set_revealed(revealed: bool) -> void:
	_revealed = revealed
	_target.visible = revealed
	_gate_body.visible = revealed
	_target_col.set_deferred(&"disabled", not revealed)


func _add_block(block_name: StringName, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = block_name
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
	add_child(body)
	if block_name == &"Target":
		_target = body
		_target_col = col
	else:
		_gate_body = body
		_mesh = mesh
		_col = col
