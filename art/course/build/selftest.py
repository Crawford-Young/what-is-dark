"""Self-test for the course pipeline: box records, Blender-side erosion, export validation, frame.

Run headless (export_all.sh runs it first, and fails on it):
    blender -b --factory-startup --python-exit-code 1 --python art/course/build/selftest.py
Builds a throwaway scene in memory; never saves a file.
"""
import json
import os

import bmesh
import bpy

BUILD = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(BUILD, "wid_common.py")).read(), globals())
exec(open(os.path.join(BUILD, "export.py")).read(), globals())

FAILS = []


def check(cond, what):
    if not cond:
        FAILS.append(what)


def near(a, b, eps=1e-6):
    return all(abs(x - y) <= eps for x, y in zip(a, b)) and len(a) == len(b)


def errors_of(objs):
    return validate_play(objs, ROLES_TEST, "floor")


ROLES_TEST = {"floor", "ride_wall", "prop", "marker_floor"}
reset_scene("SelfTest")
mat = material("T", (0.5, 0.5, 0.5))

# ---- records: world-frame loop-0 centre/size, one per box, role and erode carried
slab = boxes_object("Slab", [((3.0, -5.0, 8.8), (6.0, 10.0, 0.4), 0),
                             ((-3.0, -5.0, 8.8), (6.0, 10.0, 0.4), 0, {"role": "marker_floor", "erode": None})],
                    [mat], "PLAY", role="floor", erode=(0, 2.0, 1))
recs = json.loads(slab["wid_boxes"])
check(len(recs) == 2, "two records for two boxes")
check(recs[0]["role"] == "floor" and recs[0]["erode"] == [0, 2.0, 1], "object-level role/erode on box 0")
check(recs[1]["role"] == "marker_floor" and recs[1].get("erode") is None, "per-box override on box 1")
check(near(recs[0]["center"], (3.0, -5.0, 8.8)) and near(recs[0]["size"], (6.0, 10.0, 0.4)), "box 0 record")
single = box("Single", (0.0, -20.0, 5.0), (1.0, 2.0, 3.0), mat, "PLAY", role="prop")
check(near(json.loads(single["wid_boxes"])[0]["center"], (0.0, -20.0, 5.0)), "box() records the world centre")
check(tuple(single.location) == (0.0, -20.0, 5.0), "box() keeps its origin at its centre")

# ---- apply_loop: loop 0 is the shipped geometry exactly; plateau = min, high edge pinned
v0 = [tuple(v.co) for v in slab.data.vertices]
apply_loop(5)
xs = [slab.data.vertices[i].co.x for i in range(8)]
check(abs(min(xs) - 4.0) < 1e-5 and abs(max(xs) - 6.0) < 1e-5, f"plateau box 0 spans x 4..6, got {min(xs)}..{max(xs)}")
xs1 = [slab.data.vertices[i].co.x for i in range(8, 16)]
check(abs(min(xs1) + 6.0) < 1e-6 and abs(max(xs1)) < 1e-6, "un-eroded box 1 untouched at plateau")
apply_loop(2)
xs = [slab.data.vertices[i].co.x for i in range(8)]
check(abs(min(xs) - 1.6) < 1e-5, f"loop 2 shrinks 6 -> 4.4 (low edge 1.6), got {min(xs)}")
apply_loop(0)
check([tuple(v.co) for v in slab.data.vertices] == v0, "loop 0 restores the shipped vertices bit for bit")

# ---- validation
bpy.context.view_layer.update()
check(errors_of([slab, single]) == [], f"valid objects pass: {errors_of([slab, single])}")
untagged = boxes_object("Untagged", [((0, 0, 0), (1, 1, 1), 0)], [mat], "PLAY")
check(any("Untagged" in e and "no wid_boxes" in e for e in errors_of([untagged])), "untagged PLAY mesh fails")
ghost = boxes_object("Ghost", [((0, 0, 0), (1, 1, 1), 0)], [mat], "PLAY", role="none")
check(errors_of([ghost]) == [], "role none is visual-only and passes")
moved = box("Moved", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="prop")
moved.location = (0.5, 0, 0)
bpy.context.view_layer.update()
check(any("Moved_0" in e and "mesh island" in e for e in errors_of([moved])), "record off its island fails")
odd = box("Odd", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="bench")
check(any("unknown role" in e for e in errors_of([odd])), "unknown role fails")
wall = box("Wall", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="ride_wall", erode=(0, 0.5, 0))
check(any("may erode" in e for e in errors_of([wall])), "erode on a ride wall fails")
up = box("Up", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="floor", erode=(2, 0.5, 0))
check(any("axis" in e for e in errors_of([up])), "erode on the vertical axis fails")
rot = box("Rot", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="prop")
rot.rotation_euler = (0, 0, 0.5)
bpy.context.view_layer.update()
check(any("Rot" in e for e in errors_of([rot])), "a rotated box is not an axis-aligned box and fails")
extra = box("Extra", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="prop")
extra["wid_boxes"] = "[]"
check(any("Extra" in e and "island" in e for e in errors_of([extra])), "an island with no record fails")

arr = box("Arr", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="prop")
arr.modifiers.new("Array", "ARRAY")
check(any("Arr" in e and "modifier" in e for e in errors_of([arr])), "a non-Bevel modifier on a PLAY box fails")
bev = box("Bev", (0, 0, 0), (1, 1, 1), mat, "PLAY", 0.05, role="prop")
check(errors_of([bev]) == [], "a Bevel modifier is allowed")
open_ = box("Open", (0, 0, 0), (1, 1, 1), mat, "PLAY", role="prop")
bm_ = bmesh.new()
bm_.from_mesh(open_.data)
bm_.faces.ensure_lookup_table()
bmesh.ops.delete(bm_, geom=[bm_.faces[0]], context="FACES_ONLY")
bm_.to_mesh(open_.data)
bm_.free()
check(any("Open_0" in e and "not an axis-aligned box" in e for e in errors_of([open_])), "a box missing a face fails")

# explicit colliders: records that approximate a non-box mesh, checked against its bounds instead
leaf = boxes_object("Leaf", [((0, 0, 0), (2.0, 0.2, 2.0), 0)], [mat], "PLAY")
leaf.rotation_euler = (0, 0, 0.6)
bpy.context.view_layer.update()
explicit_colliders(leaf, [((-0.4, -0.25, 0.0), (0.8, 0.7, 2.0)), ((0.4, 0.25, 0.0), (0.8, 0.7, 2.0))], "prop")
check(errors_of([leaf]) == [], f"explicit colliders inside their mesh pass: {errors_of([leaf])}")
stray = boxes_object("Stray", [((0, 0, 0), (2.0, 0.2, 2.0), 0)], [mat], "PLAY")
explicit_colliders(stray, [((3.0, 0.0, 0.0), (0.5, 0.5, 0.5))], "prop")
check(any("Stray_0" in e and "outside" in e for e in errors_of([stray])), "an explicit collider off its mesh fails")
melt = boxes_object("Melt", [((0, 0, 0), (2.0, 0.2, 2.0), 0)], [mat], "PLAY")
explicit_colliders(melt, [((0.0, 0.0, 0.0), (0.5, 0.2, 0.5))], "floor")
recs_ = json.loads(melt["wid_boxes"])
recs_[0]["erode"] = [0, 0.1, 0]
melt["wid_boxes"] = json.dumps(recs_)
check(any("Melt_0" in e and "explicit" in e for e in errors_of([melt])), "an explicit collider may not erode")

# a marker stands on its slab: a point floating more than 0.1 m above it is not on it
slab_recs = [("S_0", {"role": "marker_floor", "center": [0, 0, -0.2], "size": [4, 4, 0.4]})]
check(_box_under((0, 0, 0.05), slab_recs, {"marker_floor"}, 0.1) is not None, "a point on the slab finds it")
check(_box_under((0, 0, 0.5), slab_recs, {"marker_floor"}, 0.1) is None, "a point 0.5 m up does not")

# ---- frame and progress
check(to_godot((1.0, 2.0, 9.5), 9.0) == [-1.0, 0.5, 2.0], "Godot frame = (-bx, bz - top, by)")
check(size_to_godot((1.0, 2.0, 3.0)) == [1.0, 3.0, 2.0], "size swaps y and z")
check(erode_to_godot([0, 5.85, 1]) == {"axis": 0, "min": 5.85, "anchor": -1}, "x erode anchor negates")
check(erode_to_godot([1, 2.0, -1]) == {"axis": 2, "min": 2.0, "anchor": -1}, "y erode maps to z, anchor kept")
line = [(0, 0, 0), (0, -10, 0), (5, -10, 0)]
check(abs(polyline_offset(line, (5, -10, 0)) - 15.0) < 1e-9, "progress at the end = arc length")
check(abs(polyline_offset(line, (1, -4, 0)) - 4.0) < 1e-9, "progress projects onto the nearest segment")

if FAILS:
    raise SystemExit("SELFTEST FAILED (%d):\n  " % len(FAILS) + "\n  ".join(FAILS))
print("SELFTEST OK")
