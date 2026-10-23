"""Course exporter (#23): one place's .blend -> its glb plus its sidecar, both in the Godot frame.

Entry (run.py rebuilds the place from its builder, which saves the .blend, then calls export_main):
    blender -b art/course/0N-<place>.blend --python-exit-code 1 --python art/course/build/run.py -- <builder> export
export_all.sh does both places, after selftest.py. Writes:
    assets/course/0N-<place>.glb   PLAY, DRESS and MEMORY; modifiers applied, custom props as
                                   extras, collections as nodes, no lights or cameras
    data/course/0N-<place>.json    sidecar v1: boxes (role, centre, size, solid, erode), path,
                                   spawn, markers, door_progress, fall_y

Frame. Godot = (-bx, bz - top, by), with top = the top of the PLAY box the SPAWN stands on. That
is a turn of 180 degrees about the vertical plus a drop, not a mirror, so the glb gets the same
transform (top-level objects are moved before export; the .blend is not saved afterwards) and
the Zone root stays identity. Blender's -y travel becomes Godot's -z. On the x-flip an axis-0
erode anchor negates; erode axis 1 (Blender y) becomes Godot axis 2.

Validation fails the export loudly, and writes nothing, on: a PLAY mesh with no box records
and no role "none"; any PLAY modifier but Bevel (the glb applies them); a record that matches
no mesh island of its object, or an island with no record; an island that is not an
axis-aligned box (8 corners, 6 quads); an unknown role (course_decl.gd ROLES); an erode on any
role but course_decl.gd's EROD_ROLE, or on the vertical axis; a marker whose respawn point does
not stand on a marker_floor box (at most MARKER_FOOTING above its top). A mesh that is no box
(wid_explicit, e.g. the fridge door ajar) carries hand-laid colliders instead: each must lie
inside the mesh's world bounds and none may erode, and the mesh is exported as drawn.

A place with no racing line (the school, for now) says so with the scene prop wid_line = False:
its sidecar has an empty path and markers, and no door_progress key at all.
The glb is written before the sidecar, so a failed export never pairs a fresh sidecar with a
stale glb.
"""
import json
import os
import re

import bpy
from mathutils import Matrix, Vector

REPO = os.path.normpath(os.path.join(BUILD, "..", "..", ".."))
EPS = 1e-4            # metres: a record matches its island to a tenth of a millimetre
MARKER_SNAP = 0.5     # metres: a MARKER_n empty sits on the LINE
FALL_Y = -6.0         # Godot y, 6 m under the spawn surface: below it the rider has fallen
SPAWN_UP = 1.0        # the SPAWN empty stands this far over its surface, as respawns do
MARKER_FOOTING = 0.1  # metres: a marker's respawn point sits on its slab, never above it
EXPORTED = ("PLAY", "DRESS", "MEMORY")


class ExportError(Exception):
    pass


def read_roles(path):
    """The legal roles and the one role that may erode, read from course_decl.gd itself."""
    src = open(path, encoding="utf-8").read()
    block = re.search(r"const ROLES: Array\[String\] = \[(.*?)\]", src, re.S)
    erod = re.search(r'const EROD_ROLE := "(\w+)"', src)
    if not block or not erod:
        raise ExportError(f"{path}: cannot find ROLES / EROD_ROLE")
    return set(re.findall(r'"(\w+)"', block.group(1))), erod.group(1)


# ---------------------------------------------------------------- validation

def _islands(ob):
    """The object's own mesh (no modifiers) split by edge connectivity: per island its world-space
    vertices and the corner count of each of its faces."""
    me = ob.data
    parent = list(range(len(me.vertices)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    groups, faces = {}, {}
    for i in range(len(me.vertices)):
        groups.setdefault(find(i), []).append(i)
    for p in me.polygons:
        faces.setdefault(find(p.vertices[0]), []).append(len(p.vertices))
    mw = ob.matrix_world
    return [([tuple(mw @ me.vertices[i].co) for i in g], faces.get(k, [])) for k, g in groups.items()]


def _aabb(pts):
    return [min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)]


def _same(a, b):
    return all(abs(x - y) <= EPS for x, y in zip(a[0] + a[1], b[0] + b[1]))


def _is_box(pts, faces):
    """8 vertices on the 8 corners of their own bounds, closed by 6 quads: an axis-aligned box."""
    if len(faces) != 6 or any(n != 4 for n in faces):
        return False
    lo, hi = _aabb(pts)
    corners = {(i, j, k) for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    hit = set()
    for p in pts:
        key = []
        for ax in range(3):
            if abs(p[ax] - lo[ax]) <= EPS:
                key.append(0)
            elif abs(p[ax] - hi[ax]) <= EPS:
                key.append(1)
            else:
                return False
        hit.add(tuple(key))
    return len(pts) == 8 and hit == corners


def _record_aabb(r):
    c, s = r["center"], r["size"]
    return [c[k] - s[k] / 2 for k in range(3)], [c[k] + s[k] / 2 for k in range(3)]


def validate_play(objs, roles, erod_role):
    """Every error in the PLAY objects' box records, as a list; empty means exportable."""
    errors = []
    for ob in objs:
        if ob.get("wid_role") == "none" or ob.type == "EMPTY":
            continue
        if ob.type != "MESH":
            errors.append(f"{ob.name}: a {ob.type} object in PLAY (only boxes, or role='none')")
            continue
        if "wid_boxes" not in ob:
            errors.append(f"{ob.name}: PLAY mesh with no wid_boxes (tag its boxes with role=, or role='none')")
            continue
        for m in ob.modifiers:   # the glb applies modifiers; only a bevel leaves the boxes where they were
            if m.type != "BEVEL":
                errors.append(f"{ob.name}: modifier {m.name} ({m.type}) on a PLAY box; only Bevel is allowed")
        recs = [(f"{ob.name}_{i}", r) for i, r in enumerate(json.loads(ob["wid_boxes"]))]
        for name, r in recs:
            errors += _record_errors(name, r, roles, erod_role)
        islands = _islands(ob)
        if ob.get("wid_explicit"):
            errors += _explicit_errors(ob, recs, islands)
            continue
        bounds = [_aabb(p) for p, _ in islands]
        free = list(range(len(islands)))
        for name, r in recs:
            want = _record_aabb(r)
            k = next((k for k in free if _same(bounds[k], want)), None)
            if k is None:
                errors.append(f"{name}: record (centre {r['center']}, size {r['size']}) matches no mesh island")
                continue
            free.remove(k)
            if not _is_box(*islands[k]):
                errors.append(f"{name}: its mesh island is not an axis-aligned box")
        for k in free:
            errors.append(f"{ob.name}: mesh island {k} (bounds {bounds[k]}) has no box record")
    return errors


def _record_errors(name, r, roles, erod_role):
    errors = []
    role = r.get("role")
    if role not in roles:
        errors.append(f'{name}: unknown role "{role}" (course_decl.gd ROLES)')
    e = r.get("erode")
    if e:
        if role != erod_role:
            errors.append(f'{name}: role "{role}" erodes, and only "{erod_role}" may erode')
        if e[0] not in (0, 1):
            errors.append(f"{name}: erode axis {e[0]}, and only 0 (x) or 1 (y) may erode")
        if e[2] not in (-1, 0, 1):
            errors.append(f"{name}: erode anchor {e[2]} is not -1, 0 or +1")
    return errors


def _explicit_errors(ob, recs, islands):
    """Hand-laid colliders on a non-box mesh (wid_explicit): exempt from island matching, so each
    must lie inside the mesh's world bounds, and none may erode (nothing redraws the mesh)."""
    errors = []
    lo, hi = _aabb([p for pts, _ in islands for p in pts])
    for name, r in recs:
        if r.get("erode"):
            errors.append(f"{name}: an explicit collider erodes; explicit colliders never erode")
        a, b = _record_aabb(r)
        if any(a[k] < lo[k] - EPS or b[k] > hi[k] + EPS for k in range(3)):
            errors.append(f"{name}: explicit collider lies outside {ob.name}'s mesh bounds")
    return errors


# ---------------------------------------------------------------- frame and progress

def _r(v):
    v = round(float(v), 6)
    return 0.0 if v == 0 else v


def to_godot(p, top):
    return [_r(-p[0]), _r(p[2] - top), _r(p[1])]


def size_to_godot(s):
    return [_r(s[0]), _r(s[2]), _r(s[1])]


def erode_to_godot(e):
    axis, mn, anchor = e
    return {"axis": {0: 0, 1: 2}[axis], "min": _r(mn), "anchor": -anchor if axis == 0 else anchor}


def polyline_offset(points, p):
    """Arc length along the polyline to the point on it nearest p (Godot's get_closest_offset)."""
    p = Vector(p)
    best, run = None, 0.0
    for a, b in zip(points, points[1:]):
        a, b = Vector(a), Vector(b)
        seg = b - a
        t = 0.0 if seg.length == 0 else max(0.0, min(1.0, (p - a).dot(seg) / seg.length_squared))
        d = (a + seg * t - p).length
        if best is None or d < best[0] - 1e-12:
            best = (d, run + seg.length * t)
        run += seg.length
    return best[1]


def _point_at(points, offset):
    run = 0.0
    for a, b in zip(points, points[1:]):
        a, b = Vector(a), Vector(b)
        if run + (b - a).length >= offset:
            return a + (b - a) * ((offset - run) / max((b - a).length, 1e-12))
        run += (b - a).length
    return Vector(points[-1])


def _box_under(p, records, roles=None, max_above=None):
    """The highest record whose footprint holds p and whose top is at or below it, by no more
    than max_above metres when given (a marker stands on its slab; it never floats over it)."""
    best = None
    for name, r in records:
        if roles and r["role"] not in roles:
            continue
        c, s = r["center"], r["size"]
        top = c[2] + s[2] / 2
        if max_above is not None and p[2] - top > max_above:
            continue
        if abs(p[0] - c[0]) <= s[0] / 2 and abs(p[1] - c[1]) <= s[1] / 2 and top <= p[2] + EPS:
            if best is None or top > best[0]:
                best = (top, name, r)
    return best


# ---------------------------------------------------------------- the place

def _course(name):
    return bpy.data.objects.get(name)


def build_sidecar(place, play, records):
    sc = bpy.context.scene
    spawn = _course("SPAWN")
    if spawn is None:
        raise ExportError("no SPAWN empty in COURSE")
    sp = tuple(spawn.matrix_world.translation)
    under = _box_under(sp, records, max_above=SPAWN_UP + MARKER_FOOTING)
    if under is None:
        raise ExportError(f"SPAWN {sp} stands over no PLAY box")
    top = under[0]
    errors = []
    path, markers, door_progress = [], [], None
    if sc.get("wid_line", True):
        line = _course("LINE")
        if line is None or line.type != "CURVE" or len(line.data.splines) != 1:
            raise ExportError("no single-spline LINE curve in COURSE (or set the scene's wid_line = False)")
        pts = [tuple(line.matrix_world @ Vector(p.co[:3])) for p in line.data.splines[0].points]
        path = [to_godot(p, top) for p in pts]
        n = 0
        while _course(f"MARKER_{n}") is not None:
            m = tuple(_course(f"MARKER_{n}").matrix_world.translation)
            off = polyline_offset(pts, m)
            respawn = _point_at(pts, off)   # Course.respawn_position samples the path here (+ 1 m up)
            if (respawn - Vector(m)).length > MARKER_SNAP:
                errors.append(f"MARKER_{n} sits {(respawn - Vector(m)).length:.2f} m off the LINE")
            if _box_under(tuple(respawn), records, {"marker_floor"}, MARKER_FOOTING) is None:
                errors.append(f"MARKER_{n}: its respawn point {tuple(respawn)} stands on no marker_floor box")
            if markers and off <= markers[-1]:
                errors.append(f"MARKER_{n} at progress {off:.2f} does not come after MARKER_{n - 1}")
            markers.append(_r(off))
            n += 1
        if not markers:
            errors.append("no MARKER_0 empty in COURSE")
        door = _course("DOOR")
        if door is None:
            errors.append("no DOOR empty in COURSE")
        else:
            door_progress = _r(polyline_offset(pts, tuple(door.matrix_world.translation)))
    if errors:
        raise ExportError("\n  ".join(errors))
    boxes = []
    for name, r in records:
        rec = {"name": name, "object": name.rsplit("_", 1)[0], "role": r["role"],
               "center": to_godot(r["center"], top), "size": size_to_godot(r["size"]),
               "solid": bool(play[name.rsplit("_", 1)[0]].get("solid", 0))}
        if r.get("erode"):
            rec["erode"] = erode_to_godot(r["erode"])
        boxes.append(rec)
    sidecar = {"version": 1, "place": place, "frame": "godot", "boxes": boxes, "path": path,
               "spawn": to_godot(sp, top), "markers": markers}
    if door_progress is not None:   # absent, not null, for a place with no line
        sidecar["door_progress"] = door_progress
    sidecar["fall_y"] = FALL_Y
    return top, sidecar


def export_glb(path, top):
    """Bake the Godot frame into the scene and write the glb. Leaves the scene moved: never save after."""
    turn = Matrix(((-1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 1, -top), (0, 0, 0, 1)))
    keep = {o for c in EXPORTED for o in bpy.data.collections[c].all_objects}
    root = bpy.context.scene.collection
    for c in list(root.children):   # collections become glb nodes: only the exported ones stay linked
        if c.name not in EXPORTED:
            root.children.unlink(c)
    for o in bpy.context.scene.objects:
        o.select_set(o in keep)
        for key in ("wid_boxes", "wid_origin", "wid_explicit"):   # Blender-frame records: the sidecar has them
            if key in o:
                del o[key]
    for o in bpy.context.scene.objects:
        if o.parent is None:
            o.matrix_world = turn @ o.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_extras=True, export_hierarchy_full_collections=True,
                              export_lights=False, export_cameras=False)


def export_main():
    place = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
    try:
        bpy.context.view_layer.update()
        roles, erod_role = read_roles(os.path.join(REPO, "scripts", "logic", "course_decl.gd"))
        play = {o.name: o for o in bpy.data.collections["PLAY"].all_objects}
        errors = validate_play(play.values(), roles, erod_role)
        if errors:
            raise ExportError("\n  ".join(errors))
        records = [(f"{o.name}_{i}", r) for o in play.values() if "wid_boxes" in o
                   for i, r in enumerate(json.loads(o["wid_boxes"]))]
        top, sidecar = build_sidecar(place, play, records)
    except ExportError as exc:
        raise SystemExit(f"EXPORT FAILED {place}:\n  {exc}")
    glb = os.path.join(REPO, "assets", "course", place + ".glb")
    side = os.path.join(REPO, "data", "course", place + ".json")
    os.makedirs(os.path.dirname(glb), exist_ok=True)
    os.makedirs(os.path.dirname(side), exist_ok=True)
    export_glb(glb, top)   # the glb first: a failed glb never leaves a fresh sidecar by a stale one
    with open(side, "w", encoding="utf-8", newline="\n") as f:
        json.dump(sidecar, f, indent=1)
        f.write("\n")
    print("EXPORTED", place, "boxes", len(sidecar["boxes"]), "markers", len(sidecar["markers"]), "top", top)
