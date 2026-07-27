class_name SwallowDirector
extends CanvasLayer
## The silent swallow (spec §2, §5): the dark holds you, says nothing —
## this phase ships the FIRST swallow only, which is always silent.

const FADE_OUT := 0.6
const HOLD := 2.5
const FADE_IN := 0.8
const SETBACK_MARKERS := 1
const FALL_FADE_OUT := 0.12
const FALL_FADE_IN := 0.18
const FALL_VOID_GAP := 6.0
const LOOP_FLASH_OUT := 0.15
const LOOP_FLASH_IN := 0.3

@onready var _black: ColorRect = $Black
@onready var _white: ColorRect = $White

var _loop_active := false


func begin_swallow(slice: Slice, player: Player) -> void:
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FADE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_callback(_respawn.bind(slice, player))
	tween.tween_property(_black, "color:a", 0.0, FADE_IN)
	tween.tween_callback(_release.bind(slice, player))


func begin_fall_reset(slice: Slice, player: Player) -> void:
	if player.frozen:
		return
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FALL_FADE_OUT)
	tween.tween_callback(_fall_respawn.bind(slice, player))
	tween.tween_property(_black, "color:a", 0.0, FALL_FADE_IN)
	tween.tween_callback(_release_fall.bind(player))


func _fall_respawn(slice: Slice, player: Player) -> void:
	var idx := maxi(slice.course.nearest_passed_marker(slice.player_progress()), 0)
	var offset: float = slice.course.marker_progresses[idx]
	player.teleport(slice.respawn_position(idx), slice.course_direction_at(offset))
	slice.void_logic.limit_behind(offset, FALL_VOID_GAP)
	slice.sync_void_wall()


func _release_fall(player: Player) -> void:
	player.frozen = false


func _respawn(slice: Slice, player: Player) -> void:
	var idx := slice.course.setback_index(slice.player_progress(), SETBACK_MARKERS)
	var offset: float = slice.course.marker_progresses[idx]
	player.teleport(slice.respawn_position(idx), slice.course_direction_at(offset))
	slice.void_logic.reset_behind(offset)
	slice.sync_void_wall()


func _release(slice: Slice, player: Player) -> void:
	player.frozen = false
	slice.catch_armed = true


func begin_loop(slice: Slice, player: Player) -> void:
	if _loop_active or player.frozen:
		return
	_loop_active = true
	var tween := create_tween()
	tween.tween_property(_white, "color:a", 1.0, LOOP_FLASH_OUT)
	tween.tween_callback(_loop_respawn.bind(slice, player))
	tween.tween_property(_white, "color:a", 0.0, LOOP_FLASH_IN)
	tween.tween_callback(_end_loop)


func _loop_respawn(slice: Slice, player: Player) -> void:
	if player.frozen:
		return
	player.shift_to(slice.respawn_position(0))
	slice.loop_logic.advance_loop()
	slice.apply_erosion()
	slice.void_logic.progress = Slice.VOID_START
	slice.sync_void_wall()


func _end_loop() -> void:
	_loop_active = false
