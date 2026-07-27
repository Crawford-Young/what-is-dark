extends CanvasLayer
## PROBE (phase 3b, E3/T8 gates): live run telemetry — HUD + per-tick CSV.
##
## Temporary instrumentation for the speed/pacing gates. Revert once the gate
## data is collected; nothing in the game reads it.
##
## Speed is recorded TWO independent ways every tick, per the momentum-lab
## stride-aliasing law (issue class: a single-method rate measurement can be
## systematically wrong): `v_engine` is the engine's own velocity vector,
## `v_pos` is derived from POSITION deltas across a multi-tick window. They
## should agree within a few percent on clean running; a divergence means one
## of them is lying and the CSV shows which.
##
## Lap time is likewise recorded two ways: physics-tick count × tick delta, and
## OS wall clock. Divergence means the run dropped physics frames.

const ZONE_BOUNDS: Array[float] = [600.0, 1200.0, 1795.0]
const ZONE_NAMES: Array[String] = ["Shame", "Grief", "Depression"]
const SPEED_WINDOW := 6  ## ticks spanned by the position-delta speed measurement
const CSV_HEADER := "tick,t_s,progress_m,v_engine,v_pos,y,on_floor,frozen,loop,void_m,void_gap_m"

@onready var _label: Label = $Label

var _slice: Slice
var _player: Player

var _tick := 0
var _lap_tick_start := 0
var _lap_msec_start := 0
var _next_zone := 0
var _splits: PackedStringArray = []
var _max_speed := 0.0
var _max_speed_at := 0.0
var _min_void_gap := INF
var _min_void_gap_at := 0.0
var _resets := 0
var _was_frozen := false
var _last_loop := 0
var _run_index := 0
var _rows: PackedStringArray = []
var _recent: Array[Vector3] = []


func _ready() -> void:
	_slice = get_parent() as Slice
	_player = _slice.get_node("Player") as Player
	_lap_msec_start = Time.get_ticks_msec()
	_rows.append(CSV_HEADER)
	print("[telemetry] logging to ", ProjectSettings.globalize_path("user://"))


func _physics_process(delta: float) -> void:
	_tick += 1
	var pos := _player.global_position
	_recent.append(pos)
	if _recent.size() > SPEED_WINDOW + 1:
		_recent.remove_at(0)

	var v_engine := Vector2(_player.velocity.x, _player.velocity.z).length()
	var v_pos := _windowed_speed(delta)
	var progress := _slice.player_progress()
	var loop := _slice.loop_logic.loop_count

	if _player.frozen and not _was_frozen:
		_resets += 1
	_was_frozen = _player.frozen

	var void_progress := _slice.void_logic.progress
	var void_gap := progress - void_progress

	if not _player.frozen and v_engine > _max_speed:
		_max_speed = v_engine
		_max_speed_at = progress
	if not _player.frozen and void_gap < _min_void_gap:
		_min_void_gap = void_gap
		_min_void_gap_at = progress

	while _next_zone < ZONE_BOUNDS.size() and progress >= ZONE_BOUNDS[_next_zone]:
		_splits.append("%s %.1fs" % [ZONE_NAMES[_next_zone], _lap_seconds()])
		_next_zone += 1

	if loop != _last_loop:
		_finish_lap()
		_last_loop = loop

	_rows.append("%d,%.4f,%.3f,%.4f,%.4f,%.3f,%d,%d,%d,%.3f,%.3f" % [
		_tick, _tick * delta, progress, v_engine, v_pos, pos.y,
		1 if _player.is_on_floor() else 0, 1 if _player.frozen else 0, loop,
		void_progress, void_gap,
	])
	_update_label(progress, v_engine, v_pos, loop, void_gap)


## Horizontal speed from position deltas across the whole window — immune to the
## per-tick sampling artefacts that corrupt stride-sampled derivatives.
func _windowed_speed(delta: float) -> float:
	if _recent.size() < 2:
		return 0.0
	var span := _recent[-1] - _recent[0]
	var ticks := _recent.size() - 1
	return Vector2(span.x, span.z).length() / (ticks * delta)


func _lap_seconds() -> float:
	return (_tick - _lap_tick_start) * (1.0 / Engine.physics_ticks_per_second)


func _finish_lap() -> void:
	var tick_seconds := _lap_seconds()
	var wall_seconds := (Time.get_ticks_msec() - _lap_msec_start) / 1000.0
	print("[telemetry] LAP %d — tick-clock %.2fs · wall-clock %.2fs · splits %s · max %.2f m/s at %.0f m · closest void %.0f m at %.0f m · resets %d" % [
		_run_index, tick_seconds, wall_seconds, ", ".join(_splits), _max_speed, _max_speed_at,
		_min_void_gap, _min_void_gap_at, _resets,
	])
	_write_csv()
	_run_index += 1
	_lap_tick_start = _tick
	_lap_msec_start = Time.get_ticks_msec()
	_next_zone = 0
	_splits = PackedStringArray()
	_max_speed = 0.0
	_max_speed_at = 0.0
	_min_void_gap = INF
	_min_void_gap_at = 0.0
	_resets = 0
	_rows = PackedStringArray([CSV_HEADER])


func _write_csv() -> void:
	var path := "user://telemetry_lap_%d.csv" % _run_index
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[telemetry] could not open %s" % path)
		return
	file.store_string("\n".join(_rows))
	file.close()
	print("[telemetry] wrote ", ProjectSettings.globalize_path(path), " (", _rows.size() - 1, " ticks)")


func _update_label(progress: float, v_engine: float, v_pos: float, loop: int, void_gap: float) -> void:
	_label.text = "%.1f m  |  loop %d\n%.1f m/s  (pos %.1f)\nmax %.1f m/s @ %.0f m\nvoid %.0f m back  (closest %.0f m)\nlap %.1fs   resets %d\n%s" % [
		progress, loop, v_engine, v_pos, _max_speed, _max_speed_at,
		void_gap, _min_void_gap, _lap_seconds(), _resets, ", ".join(_splits),
	]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _rows.size() > 1:
		_finish_lap()
