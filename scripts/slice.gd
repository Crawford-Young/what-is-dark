class_name Slice
extends Course
## The 1800 m vertical slice. Its constants ARE its course spec; all gameplay wiring lives in
## `Course`.

const SCENE_PATH := "res://scenes/slice.tscn"
const DECL_PATH := "res://data/course_declarations.json"
const MARKER_PROGRESSES: Array[float] = [
	0.0, 70.0, 150.0, 190.0, 280.0, 330.0, 420.0, 460.0, 520.0, 600.0,
	650.0, 780.0, 830.0, 900.0, 940.0, 1080.0, 1140.0, 1200.0,
	1260.0, 1360.0, 1420.0, 1480.0, 1560.0, 1650.0,
]
## Light-door threshold: 1795.0 = the 1800 m lap's door (phase 3b).
const DOOR_PROGRESS := 1795.0
const FALL_Y := -6.0
const VOID_START := -20.0

## The pinned finding set — deduped `law:subject` keys the audit is ALLOWED to report. `just audit`
## and the GUT gate case both exit green only when the live set EQUALS this list, so a new defect
## fails loudly and a silently fixed one fails loudly too (stale baseline). Authored at T9 from
## run8 against commit e0592e0's manifest. Every key is a documented read of the RETIRING course;
## issue numbers cite `docs/games/what-is-dark/issues/2026-07-29-phase4-w0-issues.md`, where every
## FAIL's ACCEPT verdict lives in the "T9 ruling round" entry (2026-07-31) plus the cited issue.
## Number namespaces: bare #18-#21 are that wave log's own entries; #23/#27/#28/#33/#34 (and any
## number tagged "course") are phase-3b course issues from `issues/done/2026-07-25-phase3b-issues.md`
## — the wave log tags its own 23rd entry "#23 (wave)" to keep the two apart.
const BASELINE_FINDINGS: Array[String] = [
	"bare_run_reach:G2PadRight>G2Ramp1",  # #20 companion — ray reads the bank face 12 m down its diagonal
	"compound_landing:D1TileM2>D2StripA",  # #23 — near-ceiling gap onto a strip eroding 2.5 -> 1.6 m
	"compound_landing:D2StripA>D2StripB",  # #23
	"compound_landing:D2StripB>D2StripC",  # #23
	"compound_landing:D6TileL3>D7PadA",  # loop-5 narrow landing (D7PadA 4.00 -> 2.80 m) — T8-close, ruling round
	"compound_landing:D6TileL3>D7PadB",  # #21(b) companion — probe misses the shrunken pad at loop 5
	"compound_landing:D6TileM3>D7PadA",  # loop-5 narrow landing — T8-close, ruling round
	"compound_landing:D6TileR3>D7PadA",  # loop-5 narrow landing — T8-close, ruling round
	"compound_landing:D6TileR3>D7PadB",  # #21(b) companion
	"compound_landing:D7PadA>D7PadB",  # measured-law read, no issue number — T8-close, ruling round
	"compound_landing:G7Exit>G8PadARight",  # #34 — 8.20 m gap, G8PadA reaches 5 m at plateau
	"compound_landing:G8PadALeft>G8PadBLeft",  # #34
	"compound_landing:G8PadAMid>G8PadBMid",  # #34
	"compound_landing:G8PadARight>G8PadBRight",  # #34
	"compound_landing:Sh4Mid>Sh5FloorA",  # #33 — 7.50/7.85 m gaps onto a pad eroding 12 -> 4 m
	"compound_landing:Sh6Ledge>Sh6ExitTileL2",  # #18 pair — phantom 40 m key on the walk-off drop
	"declaration:D1TileL3>D2Exit",  # #21(a) — straight-z model cannot merge lanes; RULED baseline
	"declaration:D1TileR2>D2Exit",  # #21(a)
	"declaration:D6TileL3>D7PadB",  # #21(b)
	"declaration:D6TileR3>D7PadB",  # #21(b)
	"declaration:G2PadLeft>G2Kick1",  # #20 — lateral bank entry unrepresentable; RULED baseline
	"declaration:G2PadRight>G2Kick1",  # #20
	"declaration:Sh6Ledge>Sh6ExitTileL2",  # #18 — no drop verb; RULED option (c)
	"method_disagreement:G2PadRight>G2Ramp1",  # #20 companion — ray falls through a slit onto the face
	"method_disagreement:Sh8Ramp>Sh8FloorTileL3",  # #19 — 0.673 m on the compound-rotated bank; RULED ACCEPT
	"precision_chain_at_cap:D1TileM2>D2StripA",  # course #27's adjudicated 3-chain — wave #23 entry
	"precision_chain_at_cap:D4LandA>D5FloorA",  # #28-class standing constraint — wave #23 entry
	"precision_chain_at_cap:D6TileL3>D7PadA",  # #28-class, per lane — wave #23 entry
	"precision_chain_at_cap:D6TileM3>D7PadA",  # #28-class, per lane — wave #23 entry
	"precision_chain_at_cap:D6TileR3>D7PadA",  # #28-class, per lane — wave #23 entry
	"precision_chain_at_cap:G7Exit>G8PadARight",  # course #34's triple at ruling #7's cap — wave #23 entry
	"precision_chain_at_cap:Sh3FloorB>Sh4Step1",  # #28-class standing constraint — wave #23 entry
	"precision_chain_at_cap:Sh8FloorTileL2>Sh8FloorTileL3",  # course #28's adjudicated 3-chain incl. chasm
	"shrink_target_carries:D1TileL1",  # props on shrinking tiles — RULED ACCEPT, T9 ruling round
	"shrink_target_carries:D1TileR2",  # ruling round
	"shrink_target_carries:D6TileL1",  # ruling round
	"shrink_target_carries:D6TileL2",  # ruling round
	"shrink_target_carries:D6TileL3",  # ruling round
	"shrink_target_carries:D6TileR2",  # ruling round
	"shrink_target_carries:G5TileA1",  # ruling round
	"shrink_target_carries:G5TileA2",  # ruling round
	"shrink_target_carries:G5TileD1",  # ruling round
	"shrink_target_carries:G5TileD2",  # ruling round
	"shrink_target_carries:G5TileD3",  # ruling round
	"surf_exit_unmeasured:Sh8Ramp>Sh8FloorTileL3",  # #19 companion — non-kicker exit, unmeasured exit_h_speed
	"wall_chain_gap:Sh9Lip>Sh9Exit",  # Sh9 ride handoff — measured-law read, T8-close mapping, ruling round
]


## Static so `just audit` can resolve the slice by name before its scene is instantiated.
static func spec() -> CourseSpec:
	var s := CourseSpec.new()
	s.scene_path = SCENE_PATH
	s.declarations_path = DECL_PATH
	s.markers = MARKER_PROGRESSES
	s.door_progress = DOOR_PROGRESS
	s.fall_y = FALL_Y
	s.void_start = VOID_START
	s.baseline = BASELINE_FINDINGS
	return s


func _build_spec() -> CourseSpec:
	return spec()
