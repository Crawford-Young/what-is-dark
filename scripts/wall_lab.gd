extends Node3D
## Debug measurement lab: sprint into the wall-jump chain along the right
## wall and read distance/height/speed off the HUD. Not shipped course
## content — dumb-simple polling script, no logic classes, no tests.

const SPAWN_POS := Vector3(0, 1.1, 10)
const SPAWN_FACE := Vector3.FORWARD
const WALL_START_Z := -40.0
const FALL_RESET_Y := -5.0

var _max_dist := 0.0
var _max_h := 0.0

@onready var _player: Player = $Player
@onready var _label: Label = $HUD/Label


func _ready() -> void:
	_reset()


func _process(_delta: float) -> void:
	var dist := maxf(-_player.global_position.z + WALL_START_Z, 0.0)
	var h := _player.global_position.y
	var spd := Vector2(_player.velocity.x, _player.velocity.z).length()

	_max_dist = maxf(_max_dist, dist)
	_max_h = maxf(_max_h, h)

	_label.text = (
		"dist: %.1f\n" % dist
		+ "h:    %.1f\n" % h
		+ "spd:  %.1f (horizontal)\n" % spd
		+ "MAX dist: %.1f\n" % _max_dist
		+ "MAX h:    %.1f\n" % _max_h
		+ "[R] reset"
	)

	if h < FALL_RESET_Y:
		_reset()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset()


func _reset() -> void:
	_player.teleport(SPAWN_POS, SPAWN_FACE)
	_max_dist = 0.0
	_max_h = 0.0
