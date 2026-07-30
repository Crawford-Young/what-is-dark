class_name CourseDecl
extends RefCounted
## What a span or a surface must SAY about itself before any law can be applied to it.
##
## The sweep checks geometry against an intent. Absent an intent there is nothing to check,
## so an undeclared span is itself a finding — that is the whole defence against the
## bookkeeping drift of issue #32, where a span's real length outgrew the number recorded
## for it in a checklist and no gate existed to notice.

const DECLARATIONS: Array[String] = [
	"bare_run",  ## clears on run speed alone
	"carried_speed",  ## needs speed delivered from somewhere upstream
	"wall_ride",  ## crossed along a wall, not over the gap
	"chasm",  ## grows per loop; audited against the plateau ceiling
	"surf_transfer",  ## ramp exit carries into the next gap
	"gate_deploy",  ## reserved for 4.1 — gate laws are not built in this wave
]

const ROLES: Array[String] = [
	"floor",
	"kicker",
	"surf_ramp",
	"ride_wall",
	"marker_floor",
	"feed_platform",
	"prop",
	"door",
	"gate_path",
]

## `carried_speed` requires a `source` ("ground" or an upstream span id) because a bare
## entry_speed is a self-certified number: spec 4.0.2 asks the harness to verify the upstream
## geometry can DELIVER the speed, which is unanswerable without knowing where it comes from.
const REQUIRED_KEYS := {
	"bare_run": [],
	"carried_speed": ["entry_speed", "source"],
	"wall_ride": ["wall", "entry_height", "along_speed"],
	"chasm": ["per_loop"],
	"surf_transfer": ["entry_speed", "drop", "kicker", "factor"],
	"gate_deploy": ["sightline_m"],
}

## Only a plain floor may erode. `marker_floor` is excluded DELIBERATELY: a shrinking respawn
## floor is the softlock class (issue #12, confirmed by 3b probe P3) — the player returns to a
## surface that no longer holds them and the loop cannot continue.
const EROD_ROLE := "floor"


static func validate_span(id: String, decl: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not decl.has("decl"):
		errors.append("%s: undeclared span — every span names its intended verb" % id)
		return errors

	var decl_name := str(decl["decl"])
	if not DECLARATIONS.has(decl_name):
		errors.append('%s: unknown declaration "%s"' % [id, decl_name])
		return errors

	for key in REQUIRED_KEYS[decl_name]:
		if not decl.has(key):
			errors.append('%s: %s declaration is missing "%s"' % [id, decl_name, key])

	# A kicker restores the flat arc (issue #12), so there the exit speed IS horizontal. Any
	# other ramp exit leaves the ground at an angle, and its horizontal component has to be
	# measured rather than assumed.
	if decl_name == "surf_transfer" and not bool(decl.get("kicker", true)):
		if not decl.has("exit_h_speed"):
			errors.append(
				(
					'%s: surf_transfer with "kicker": false must declare a measured '
					+ '"exit_h_speed" — only a kicker makes the exit all horizontal'
				)
				% id
			)

	return errors


static func validate_surface(surface_name: String, surface: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	if not surface.has("role"):
		errors.append(
			"%s: no role — every audited surface declares what it is for" % surface_name
		)
	else:
		var role := str(surface["role"])
		if not ROLES.has(role):
			errors.append('%s: unknown role "%s"' % [surface_name, role])
		elif bool(surface.get("erodable", false)) and not erodable_legal_for_role(role):
			errors.append(
				'%s: role "%s" is marked erodable — only "%s" may erode' % [
					surface_name, role, EROD_ROLE
				]
			)

	# The two erosion modes are mutually exclusive: a floor that both loses width and gains
	# holes has no analysable landing surface left, and the two laws would each read the other's
	# geometry as its own.
	if bool(surface.get("perforated", false)) and bool(surface.get("width_shrink", false)):
		errors.append(
			"%s: perforated and width_shrink stacked — a floor erodes one way or the other"
			% surface_name
		)

	return errors


static func erodable_legal_for_role(role: String) -> bool:
	return role == EROD_ROLE
