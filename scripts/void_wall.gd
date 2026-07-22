class_name VoidWall
extends Node3D
## Visual only: a featureless black sheet standing at the void's progress
## point on the course path. Never a creature (spec §2).


func place_on_path(path: Path3D, void_progress: float) -> void:
	var curve := path.curve
	var offset := clampf(void_progress, 0.0, curve.get_baked_length())
	var pos := path.to_global(curve.sample_baked(offset))
	var ahead := path.to_global(curve.sample_baked(minf(offset + 1.0, curve.get_baked_length())))
	var dir := (ahead - pos).normalized() if not pos.is_equal_approx(ahead) else Vector3.FORWARD
	if void_progress < 0.0:
		pos += dir * void_progress
	global_position = pos
	if not pos.is_equal_approx(ahead):
		look_at(pos + dir, Vector3.UP)
