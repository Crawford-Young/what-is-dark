## DEBUG PROBE — remove before gates
class_name StrafeRecorder
extends RefCounted
## Per-tick + raw-mouse-event telemetry ring buffer for the R13 playtest complaint ("air-strafe
## speed still dies in real rides" while every synthetic-yaw-input sim shows 92-96% retention).
## Captures the REAL input pipeline (actual mouse cadence pre-YawDrain, plus the resulting
## per-tick applied yaw and speed) so a real ride can be compared against the sync-window math
## (omega = 90/v rad/s ceiling; a tick brakes when wish_dir is >90 degrees off horizontal
## velocity). Does not affect movement math in any way -- read-only recorder, dump-to-CSV only.
## Temporary: every block touching this file (and its momentum_player.gd hook) is tagged for
## removal once the R13 investigation is done.

const WINDOW_TICKS := 7200  ## ~60s at 120Hz -- rows older than this (by tick distance) are pruned
const DUMP_PATH := "user://strafe_dump.csv"
const CSV_HEADER := "row_type,tick,timestamp_usec,yaw_deg,dyaw_deg,raw_yaw_delta_deg,speed_h,vel_y,on_floor,input_x,input_y,angle_deg"

var _rows: Array[Dictionary] = []
var _current_tick := 0


## Called once per physics tick from momentum_player.gd's hook.
func record_tick(yaw_deg: float, dyaw_deg: float, speed_h: float, vel_y: float, on_floor: bool,
		input_x: float, input_y: float, angle_deg: float) -> void:
	_current_tick += 1
	_rows.append({
		"type": "tick",
		"tick": _current_tick,
		"yaw_deg": yaw_deg,
		"dyaw_deg": dyaw_deg,
		"speed_h": speed_h,
		"vel_y": vel_y,
		"on_floor": on_floor,
		"input_x": input_x,
		"input_y": input_y,
		"angle_deg": angle_deg,
	})
	_prune()


## Called from momentum_player.gd's _unhandled_input for every raw mouse-motion event, BEFORE
## it reaches YawDrain -- lets the dump separate the hand's raw spike profile from the drained
## (smoothed) output the physics tick actually applies.
func record_mouse_event(timestamp_usec: int, raw_yaw_delta_deg: float) -> void:
	_rows.append({
		"type": "mouse",
		"tick": _current_tick,
		"timestamp_usec": timestamp_usec,
		"raw_yaw_delta_deg": raw_yaw_delta_deg,
	})
	_prune()


func _prune() -> void:
	while _rows.size() > 0 and (_current_tick - int(_rows[0]["tick"])) > WINDOW_TICKS:
		_rows.pop_front()


## Writes the whole ring buffer to user://strafe_dump.csv (overwriting any prior dump), prints
## the absolute path + row count to console, returns the row count.
func dump() -> int:
	var f := FileAccess.open(DUMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("StrafeRecorder: could not open %s for writing (err %d)" % [DUMP_PATH, FileAccess.get_open_error()])
		return 0
	f.store_line(CSV_HEADER)
	for row in _rows:
		if row["type"] == "tick":
			f.store_line("tick,%d,,%.6f,%.6f,,%.6f,%.6f,%s,%.6f,%.6f,%.6f" % [
				row["tick"], row["yaw_deg"], row["dyaw_deg"], row["speed_h"], row["vel_y"],
				row["on_floor"], row["input_x"], row["input_y"], row["angle_deg"]])
		else:
			f.store_line("mouse,%d,%d,,,%.6f,,,,,," % [
				row["tick"], row["timestamp_usec"], row["raw_yaw_delta_deg"]])
	f.close()
	var count := _rows.size()
	print("StrafeRecorder: dumped %d rows to %s" % [count, ProjectSettings.globalize_path(DUMP_PATH)])
	return count
