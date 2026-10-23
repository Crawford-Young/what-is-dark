extends SceneTree
## just audit [course] — walks a course against its declared intent at every loop 0..plateau,
## both survey methods. Prints a sample count per pass, then findings, then a verdict.
## Exit 0 when the finding set equals the course's `CourseSpec.baseline`, 1 when it does not,
## 2 when the audit cannot run (unknown course, invalid spec, failed setup).

const DEFAULT_COURSE := "slice"


## Course name -> its spec, resolved lazily so one course's missing data never blocks another's
## audit. Wave 2 of #23 registers the kitchen zone here.
static func courses() -> Dictionary:
	return {
		"slice": func() -> CourseSpec: return Slice.spec(),
	}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var registry := courses()
	var known := ", ".join(PackedStringArray(registry.keys()))
	if args.size() > 1:
		printerr("usage: just audit [course] — one course name, got %d args (known: %s)" % [
			args.size(), known
		])
		quit(2)
		return
	var course_name: String = args[0] if args.size() == 1 else DEFAULT_COURSE
	if not registry.has(course_name):
		printerr("unknown course \"%s\" — known: %s" % [course_name, known])
		quit(2)
		return
	var spec: CourseSpec = (registry[course_name] as Callable).call()
	var spec_errors := spec.validate()
	if not spec_errors.is_empty():
		for e in spec_errors:
			printerr("SPEC FAILURE (%s): %s" % [course_name, e])
		quit(2)
		return
	root.call_deferred("add_child", (load(spec.scene_path) as PackedScene).instantiate())
	_run.call_deferred(spec)


## `spec` is the registry spec validated above — the ONE source for the scene and the gate.
func _run(spec: CourseSpec) -> void:
	await process_frame  # _ready has now run on the course and its children
	var course := root.get_child(root.get_child_count() - 1) as Course
	var audit := CourseAudit.new(course)
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
	var baseline: Array[String] = spec.baseline.duplicate()
	baseline.sort()
	print("findings=%d unique=%d baseline=%d" % [findings.size(), keys.size(), baseline.size()])
	quit(0 if keys == baseline else 1)
