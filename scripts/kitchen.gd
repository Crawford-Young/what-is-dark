class_name Kitchen
extends Zone
## Place 2, the kitchen at night (issue #23): a Blender-exported zone. Its constants ARE its
## course spec; the sidecar supplies the line, the boxes and their roles.

const SCENE_PATH := "res://scenes/kitchen.tscn"
const SIDECAR_PATH := "res://data/course/02-kitchen.json"
const DECL_PATH := "res://data/course/02-kitchen.declarations.json"
const ART_PATH := "res://assets/course/02-kitchen.glb"
## Same 20 m head start behind marker 0 as the slice.
const VOID_START := -20.0

## The pinned `law:subject` finding set (see `Slice.BASELINE_FINDINGS`). Changing it is a ruling;
## rulings live on issue #23.
##
## Sample counts drop at loop 5 (box 102 -> 96, ray 815 -> 495) — ACCEPTED (user ruling, #23):
## the six eroding front strips reach their 0.25 m plateau width, under their 0.4 m thickness, so
## the collector's wall-aspect test (`size.y >= min(size.x, size.z)`) stops counting them as
## floors. Six floor samples leave the box pass, and the strip spans leave both passes (80 rays
## each). Loops 0-4 audit those spans in full.
const BASELINE_FINDINGS: Array[String] = [
	# User ruling (#23): baselined as a tooling false positive (audit fix tracked in #25). Each worktop run is a fixed back slab plus an eroding front strip
	# abutting it at |x| 4.0, and the span model pairs boxes by x overlap, so the strip-to-strip
	# span reads the strip's width alone (1.15 m at loop 3). The real landing is strip + slab,
	# >= 5.6 m wide at every loop.
	"landing_width:WorktopL0_1>WorktopL1_4",
	# User ruling (#23): the back walls are OPEN from the floor to the uppers' underside behind
	# the R0->R1, R1->R2 and L1->L2 gaps (+-1.05 m: ride-ray reach + capsule radius), so no low
	# wall ride crosses a barrier. The height-blind merge still reads one run per side (+x 79.3 m,
	# -x 78.5 m), bridged by the lintels over the openings and the uppers spanning the gaps
	# (UpperR1, UpperR2, UpperL1), which are kept; the user feel-rides (probe running) whether a
	# high ride across them is reachable.
	"shell_segment:+x",
	"shell_segment:-x",
]


## Static so `just audit kitchen` can resolve the kitchen before its scene is instantiated.
static func spec() -> CourseSpec:
	return _spec_with(ZoneSpec.load_files(SIDECAR_PATH, DECL_PATH))


static func _spec_with(zone: ZoneSpec) -> CourseSpec:
	return Zone.spec_for(zone, DECL_PATH, SCENE_PATH, VOID_START, BASELINE_FINDINGS)


func _build_spec() -> CourseSpec:
	return _spec_with(_parse_zone(DECL_PATH))


func _sidecar_path() -> String:
	return SIDECAR_PATH


func _art_path() -> String:
	return ART_PATH
