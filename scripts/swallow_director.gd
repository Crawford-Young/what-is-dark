class_name SwallowDirector
extends CanvasLayer
## The silent swallow (spec §2, §5): the dark holds you, says nothing —
## this phase ships the FIRST swallow only, which is always silent.

const FADE_OUT := 0.6
const HOLD := 2.5
const FADE_IN := 0.8
const SETBACK_MARKERS := 1

@onready var _black: ColorRect = $Black


func begin_swallow(slice: Slice, player: Player) -> void:
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FADE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_callback(_respawn.bind(slice, player))
	tween.tween_property(_black, "color:a", 0.0, FADE_IN)
	tween.tween_callback(_release.bind(slice, player))


func _respawn(slice: Slice, player: Player) -> void:
	var idx := slice.course.setback_index(slice.player_progress(), SETBACK_MARKERS)
	var offset: float = slice.course.marker_progresses[idx]
	player.teleport(slice.respawn_position(idx), slice.course_direction_at(offset))
	slice.void_logic.reset_behind(offset)
	slice.sync_void_wall()


func _release(slice: Slice, player: Player) -> void:
	player.frozen = false
	slice.catch_armed = true
