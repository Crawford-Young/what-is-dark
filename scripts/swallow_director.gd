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


func begin_swallow(course: Course, player: Player) -> void:
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FADE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_callback(_respawn.bind(course, player))
	tween.tween_property(_black, "color:a", 0.0, FADE_IN)
	tween.tween_callback(_release.bind(course, player))


func begin_fall_reset(course: Course, player: Player) -> void:
	if player.frozen:
		return
	player.frozen = true
	var tween := create_tween()
	tween.tween_property(_black, "color:a", 1.0, FALL_FADE_OUT)
	tween.tween_callback(_fall_respawn.bind(course, player))
	tween.tween_property(_black, "color:a", 0.0, FALL_FADE_IN)
	tween.tween_callback(_release_fall.bind(player))


func _fall_respawn(course: Course, player: Player) -> void:
	var idx := maxi(course.marker_logic.nearest_passed_marker(course.player_progress()), 0)
	var offset: float = course.marker_progresses[idx]
	player.teleport(course.respawn_position(idx), course.course_direction_at(offset))
	course.void_logic.limit_behind(offset, FALL_VOID_GAP)
	course.sync_void_wall()


func _release_fall(player: Player) -> void:
	player.frozen = false


func _respawn(course: Course, player: Player) -> void:
	var idx := course.marker_logic.setback_index(course.player_progress(), SETBACK_MARKERS)
	var offset: float = course.marker_progresses[idx]
	player.teleport(course.respawn_position(idx), course.course_direction_at(offset))
	course.void_logic.reset_behind(offset)
	course.sync_void_wall()


func _release(course: Course, player: Player) -> void:
	player.frozen = false
	course.catch_armed = true


func begin_loop(course: Course, player: Player) -> void:
	if _loop_active or player.frozen:
		return
	_loop_active = true
	var tween := create_tween()
	tween.tween_property(_white, "color:a", 1.0, LOOP_FLASH_OUT)
	tween.tween_callback(_loop_respawn.bind(course, player))
	tween.tween_property(_white, "color:a", 0.0, LOOP_FLASH_IN)
	tween.tween_callback(_end_loop)


func _loop_respawn(course: Course, player: Player) -> void:
	if player.frozen:
		return
	player.shift_to(course.respawn_position(0))
	course.loop_logic.advance_loop()
	course.apply_erosion()
	course.void_logic.progress = course.void_start
	course.sync_void_wall()


func _end_loop() -> void:
	_loop_active = false
