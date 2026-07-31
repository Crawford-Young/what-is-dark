extends SceneTree
## just audit — walks the course against its declared intent at every loop 0..plateau,
## both survey methods. Prints a sample count per pass, then findings, then a verdict.
## Exit 0 when the finding set equals CourseAudit.BASELINE_FINDINGS, 1 otherwise.


func _initialize() -> void:
	root.call_deferred("add_child", (load("res://scenes/slice.tscn") as PackedScene).instantiate())
	_run.call_deferred()


func _run() -> void:
	await process_frame  # _ready has now run on the slice and its children
	var slice := root.get_child(root.get_child_count() - 1) as Slice
	var audit := CourseAudit.new(slice)
	var setup_errors := audit.assert_setup()
	if not setup_errors.is_empty():
		for e in setup_errors:
			print("SETUP FAILURE: %s" % e)
		quit(2)
		return
	var declarations := audit.declarations()
	var findings: Array[Dictionary] = []
	for loop in ErosionLogic.PLATEAU_LOOP + 1:
		var box := audit.survey_boxes(loop)
		var ray: Dictionary = await audit.survey_rays(loop)
		for survey in [box, ray]:
			print(
				"pass method=%s loop=%d samples=%d"
				% [survey["method"], loop, int(survey["sample_count"])]
			)
			findings.append_array(CourseSweep.sweep(survey, declarations))
		findings.append_array(audit.disagreements(box, ray))
	# Key-set construction duplicated VERBATIM in test_course_audit.gd's baseline gate on
	# purpose — the GUT copy is CI's independent pin of this CLI; do not DRY them together.
	var keys: Array[String] = []
	for f in findings:
		print("%s %s %s — %s" % [f["severity"], f["law"], f["subject"], f["detail"]])
		var key := "%s:%s" % [f["law"], f["subject"]]
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	var baseline: Array[String] = CourseAudit.BASELINE_FINDINGS.duplicate()
	baseline.sort()
	print("findings=%d unique=%d baseline=%d" % [findings.size(), keys.size(), baseline.size()])
	quit(0 if keys == baseline else 1)
