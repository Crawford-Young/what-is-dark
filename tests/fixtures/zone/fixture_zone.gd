extends Zone
## The smallest ridable zone: tests/unit/test_zone_smoke.gd builds it from the fixture sidecar.

const SCENE_PATH := "res://tests/fixtures/zone/fixture_zone.tscn"
const SIDECAR_PATH := "res://tests/fixtures/zone/sidecar.json"
const DECL_PATH := "res://tests/fixtures/zone/declarations.json"
const ART_PATH := "res://tests/fixtures/zone/art.tscn"
const VOID_START := -5.0


func _build_spec() -> CourseSpec:
	var zone := _parse_zone(DECL_PATH)
	return Zone.spec_for(zone, DECL_PATH, SCENE_PATH, VOID_START, [] as Array[String])


func _sidecar_path() -> String:
	return SIDECAR_PATH


func _art_path() -> String:
	return ART_PATH
