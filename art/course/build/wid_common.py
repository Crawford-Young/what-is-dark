"""Shared look-dev kit for the seven places (#22): scene setup, the per-loop fade, mesh helpers.

Run inside Blender (bpy). A place's builder execs this file, builds its geometry through the
helpers, then calls apply_loop(n) before each render. Notes: docs/places.md.

The fade is visual only (places.md, "The fade, every loop"):
  - every material runs through the WID_Fade group: it desaturates by the scene's
    wid_desat (memory materials use wid_mem_desat) and dissolves geometry beyond the
    place's core along y, by wid_edge metres, into the void;
  - objects with a custom prop `gone_at` are hidden from that loop on (detail loss);
  - lamps with a `light_r` roll die when light_r < the loop's dead fraction (light failure);
    a place's dominant lights roll 1.0 and never die, so plateau keeps one line of light;
  - from loop 2, walls and dressing open ragged holes onto the void (wid_holes);
  - objects with `solid` = 1 (the surfaces you ride: floors, ride walls, ramps) never
    dissolve, open holes or darken with the desat. A surface you can stand on is never
    invisible;
  - dominant lamps (and their panels) brighten per loop by DOMINANT_GAIN while the scene's
    exposure lifts by EXPOSURE_LIFT: the void stays black, the ridden line stays lit.

Erosion is not visual: it is the geometry Godot plays. Every PLAY box carries a record in its
object's `wid_boxes` custom prop (a JSON list, one entry per box, in mesh order): its role
(course_decl.gd ROLES), its loop-0 world centre and size, and an optional erode
(axis, min, anchor) in the Blender frame. apply_loop(n) re-sizes the eroding boxes with
erosion_logic.gd's formula, so a render at loop n shows the course Godot builds at loop n.
export.py turns the records into the Godot sidecar. They are the collider source: the mesh is
only read to check the records against it.
"""
import json
import math
import random

import bpy
import bmesh

# Per-loop fade table, loop 0..5 (places.md).
DESAT = [0.0, 0.20, 0.45, 0.65, 0.80, 0.90]
MEM_DESAT = [0.0, 0.0, 0.0, 0.15, 0.30, 0.35]
EDGE = [0.0, 1.0, 3.0, 6.0, 10.0, 15.0]
DEAD = [0.0, 1 / 6, 1 / 3, 0.5, 0.8, 0.9]
# haze: absorption pulls distance into black, a little scatter haloes the lamps; both thicken per loop
ABSORB = [0.018, 0.020, 0.022, 0.025, 0.028, 0.032]
# late loops punch ragged holes in walls and dressing (noise threshold; 0 = none)
HOLES = [0.0, 0.0, 0.30, 0.37, 0.42, 0.46]
SCATTER = [0.004, 0.0045, 0.005, 0.006, 0.007, 0.008]
# as the practical lights die, the dominant ones flare and the eye adapts to the dark,
# so the surfaces you ride stay readable at plateau (stops of exposure lift per loop)
DOMINANT_GAIN = [1.0, 1.1, 1.3, 1.7, 2.2, 2.8]
EXPOSURE_LIFT = [0.0, 0.05, 0.15, 0.3, 0.45, 0.6]

# erosion_logic.gd: world_scale(loop) = clamp(loop / PLATEAU_LOOP, 0, 1)
PLATEAU_LOOP = 5

# COURSE holds what the exporter reads besides boxes: the SPAWN, MARKER_n and DOOR empties and
# the LINE curve. It is never exported to the glb.
COLLECTIONS = ("PLAY", "DRESS", "MEMORY", "LIGHT", "CAM", "COURSE")


# ---------------------------------------------------------------- scene

def reset_scene(name):
    """Empty the file and set up one scene: metric, black void, Cycles on the GPU."""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.lights,
                 bpy.data.cameras, bpy.data.node_groups, bpy.data.collections, bpy.data.worlds):
        for block in list(coll):
            coll.remove(block)
    sc = bpy.context.scene
    sc.name = name
    sc.unit_settings.system = "METRIC"
    sc.render.engine = "CYCLES"
    sc.cycles.device = "GPU"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.refresh_devices()
    for d in prefs.devices:
        d.use = d.type == "OPTIX"
    sc.cycles.samples = 192
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.use_denoising = True
    sc.cycles.denoiser = "OPTIX"
    sc.cycles.max_bounces = 8
    sc.cycles.transparent_max_bounces = 16
    sc.cycles.volume_step_rate = 2.0
    sc.render.resolution_x = 1920
    sc.render.resolution_y = 1080
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.new("Void")
    sc.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Color"].default_value = (0, 0, 0, 1)
    bg.inputs["Strength"].default_value = 0.0
    ab = nt.nodes.new("ShaderNodeVolumeAbsorption")
    ab.name = "Absorb"
    ab.inputs["Color"].default_value = (0.0, 0.0, 0.0, 1)
    ab.inputs["Density"].default_value = ABSORB[0]
    sca = nt.nodes.new("ShaderNodeVolumeScatter")
    sca.name = "Fog"
    sca.inputs["Density"].default_value = SCATTER[0]
    sca.inputs["Anisotropy"].default_value = 0.6
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(ab.outputs[0], add.inputs[0])
    nt.links.new(sca.outputs[0], add.inputs[1])
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    nt.links.new(add.outputs[0], out.inputs["Volume"])
    sc.view_settings.exposure = -0.6
    sc["wid_exposure0"] = -0.6
    _bloom(sc)
    for c in COLLECTIONS:
        col = bpy.data.collections.new(c)
        sc.collection.children.link(col)
    return sc


def _bloom(sc):
    """Soft glare round the lamps, the way a tired eye sees fluorescents. Best effort: the
    compositor API moved in Blender 5, so a failure here leaves the render unbloomed."""
    try:
        ng = bpy.data.node_groups.new("WID_Comp", "CompositorNodeTree")
        ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = ng.nodes.new("CompositorNodeRLayers")
        gl = ng.nodes.new("CompositorNodeGlare")
        for key, val in (("Type", "Bloom"), ("Quality", "High")):
            if key in gl.inputs:
                gl.inputs[key].default_value = val
        for key, val in (("Threshold", 1.0), ("Strength", 0.35), ("Size", 0.6)):
            if key in gl.inputs:
                gl.inputs[key].default_value = val
        out = ng.nodes.new("NodeGroupOutput")
        ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
        ng.links.new(gl.outputs["Image"], out.inputs[0])
        sc.compositing_node_group = ng
        sc.render.use_compositing = True
        sc["wid_bloom"] = "ok"
    except Exception as exc:  # noqa: BLE001 - look-dev nicety, never fatal
        sc["wid_bloom"] = repr(exc)


def set_fog_color(rgb):
    bpy.context.scene.world.node_tree.nodes["Fog"].inputs["Color"].default_value = (*rgb, 1)


def set_haze(scale):
    """Scale this place's haze. ABSORB and SCATTER are per metre, tuned in the school's 4 m
    corridor; a place built at ten times scale thins them, or the far end drowns in fog."""
    bpy.context.scene["wid_haze"] = float(scale)


def set_core(y_min, y_max):
    """The place's core along y; the void eats inward from both ends by wid_edge."""
    sc = bpy.context.scene
    sc["wid_core_min"] = float(y_min)
    sc["wid_core_max"] = float(y_max)


def coll(name):
    return bpy.data.collections[name]


# ---------------------------------------------------------------- fade group

def _fade_group():
    ng = bpy.data.node_groups.get("WID_Fade")
    if ng:
        return ng
    ng = bpy.data.node_groups.new("WID_Fade", "ShaderNodeTree")
    io = ng.interface
    io.new_socket("Color", in_out="INPUT", socket_type="NodeSocketColor")
    io.new_socket("Emission", in_out="INPUT", socket_type="NodeSocketFloat")
    io.new_socket("Memory", in_out="INPUT", socket_type="NodeSocketFloat")
    io.new_socket("Color", in_out="OUTPUT", socket_type="NodeSocketColor")
    io.new_socket("Alpha", in_out="OUTPUT", socket_type="NodeSocketFloat")
    io.new_socket("Emission", in_out="OUTPUT", socket_type="NodeSocketFloat")
    N, L = ng.nodes, ng.links
    gi = N.new("NodeGroupInput")
    go = N.new("NodeGroupOutput")

    def attr(name, kind="VIEW_LAYER"):
        a = N.new("ShaderNodeAttribute")
        a.attribute_type = kind
        a.attribute_name = name
        return a.outputs["Fac"]

    def math(op, a, b=None, clamp=False):
        m = N.new("ShaderNodeMath")
        m.operation = op
        m.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                L.new(v, m.inputs[i])
        return m.outputs[0]

    # desaturation: memory materials follow their own, later curve
    desat = N.new("ShaderNodeMix")
    desat.data_type = "FLOAT"
    L.new(gi.outputs["Memory"], desat.inputs["Factor"])
    L.new(attr("wid_desat"), desat.inputs[2])
    L.new(attr("wid_mem_desat"), desat.inputs[3])
    d = desat.outputs[0]
    hs = N.new("ShaderNodeHueSaturation")
    L.new(gi.outputs["Color"], hs.inputs["Color"])
    L.new(math("SUBTRACT", 1.0, d), hs.inputs["Saturation"])
    solid = attr("solid", "OBJECT")
    dim = math("MULTIPLY", math("MULTIPLY", d, 0.35), math("SUBTRACT", 1.0, solid))
    L.new(math("SUBTRACT", 1.0, dim), hs.inputs["Value"])

    # void bite: distance past the shrunken core along y, roughened by noise
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    y = sep.outputs["Y"]
    e = attr("wid_edge")
    lo = math("ADD", attr("wid_core_min"), e)
    hi = math("SUBTRACT", attr("wid_core_max"), e)
    past = math("MAXIMUM", math("MAXIMUM", math("SUBTRACT", lo, y), math("SUBTRACT", y, hi)), 0.0)
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.45
    noise.inputs["Detail"].default_value = 6.0
    noise.inputs["Roughness"].default_value = 0.65
    L.new(geo.outputs["Position"], noise.inputs["Vector"])
    v = math("SUBTRACT", past, math("MULTIPLY", noise.outputs["Fac"], 4.0))
    edge_alpha = math("SUBTRACT", 1.0, math("MULTIPLY", v, 3.0, clamp=True))
    # holes: a second, finer noise under a per-loop threshold; memory objects keep whole
    hn = N.new("ShaderNodeTexNoise")
    hn.inputs["Scale"].default_value = 0.55
    hn.inputs["Detail"].default_value = 8.0
    hn.inputs["Roughness"].default_value = 0.6
    L.new(geo.outputs["Position"], hn.inputs["Vector"])
    above = math("SUBTRACT", hn.outputs["Fac"], attr("wid_holes"))
    hole_alpha = math("MAXIMUM", math("MULTIPLY", above, 25.0, clamp=True), gi.outputs["Memory"])
    rim = math("ADD", 0.25, math("MULTIPLY", math("MULTIPLY", above, 6.0, clamp=True), 0.75))
    rim = math("MAXIMUM", math("MAXIMUM", rim, gi.outputs["Memory"]), solid)  # no scorch on what you ride
    alpha = math("MAXIMUM", math("MULTIPLY", edge_alpha, hole_alpha), solid)
    darken = math("SUBTRACT", 1.0, math("MULTIPLY", math("DIVIDE", past, 4.0, clamp=True), 0.85))
    darken = math("MULTIPLY", darken, rim)
    col = N.new("ShaderNodeMix")
    col.data_type = "RGBA"
    col.blend_type = "MULTIPLY"
    col.inputs["Factor"].default_value = 1.0
    rgba_in = [s for s in col.inputs if s.type == "RGBA"]
    L.new(hs.outputs["Color"], rgba_in[0])
    cv = N.new("ShaderNodeCombineColor")
    for i in range(3):
        L.new(darken, cv.inputs[i])
    L.new(cv.outputs[0], rgba_in[1])
    rgba_out = [s for s in col.outputs if s.type == "RGBA"][0]
    L.new(rgba_out, go.inputs["Color"])
    L.new(alpha, go.inputs["Alpha"])

    # emission: a dead lamp's panel goes dark; the rest dim with the desat, and a dominant
    # panel's gain (object prop, 0 when absent) brightens it as the others die
    alive = math("SUBTRACT", 1.0, attr("dead", "OBJECT"))
    em = math("MULTIPLY", math("MULTIPLY", gi.outputs["Emission"], alive),
              math("SUBTRACT", 1.0, math("MULTIPLY", d, 0.4)))
    em = math("MULTIPLY", em, math("ADD", 1.0, attr("gain", "OBJECT")))
    L.new(math("MULTIPLY", em, darken), go.inputs["Emission"])
    return ng


def material(name, color, rough=0.5, metal=0.0, emission=0.0, emit_color=None,
             memory=False, transmission=0.0, coat=0.0, base_tex=None, rough_tex=None, bump=None,
             practical=False):
    """Principled material routed through WID_Fade. base_tex/rough_tex/bump are callbacks
    (nodes, links) -> output socket, for procedural detail. A practical glow (a lit window,
    a screen) is a light with no lamp: its emission fails with the loop's dead fraction."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    p = N["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Transmission Weight"].default_value = transmission
    p.inputs["Coat Weight"].default_value = coat
    g = N.new("ShaderNodeGroup")
    g.node_tree = _fade_group()
    if base_tex:
        L.new(base_tex(N, L), g.inputs["Color"])
    else:
        g.inputs["Color"].default_value = (*color, 1)
    g.inputs["Emission"].default_value = emission
    g.inputs["Memory"].default_value = 1.0 if memory else 0.0
    L.new(g.outputs["Color"], p.inputs["Base Color"])
    L.new(g.outputs["Alpha"], p.inputs["Alpha"])
    if emission:
        ec = emit_color or color
        p.inputs["Emission Color"].default_value = (*ec, 1)
        L.new(g.outputs["Emission"], p.inputs["Emission Strength"])
    if rough_tex:
        L.new(rough_tex(N, L), p.inputs["Roughness"])
    if bump:
        b = N.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = 0.25
        L.new(bump(N, L), b.inputs["Height"])
        L.new(b.outputs["Normal"], p.inputs["Normal"])
    m["wid_memory"] = memory
    if practical:
        m["wid_emission0"] = emission
    return m


def world_tex_coord(N, L, scale=1.0):
    """World-space position, scaled — procedural patterns line up across separate objects."""
    geo = N.new("ShaderNodeNewGeometry")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    L.new(geo.outputs["Position"], mp.inputs["Vector"])
    return mp.outputs[0]


# ---------------------------------------------------------------- geometry

# a box's 8 corners in mesh order (x slowest), and its 6 faces by the side they look at
_CORNERS = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
_FACES = {"-x": (0, 1, 3, 2), "+x": (4, 6, 7, 5), "-y": (0, 4, 5, 1), "+y": (2, 3, 7, 6),
          "-z": (0, 2, 6, 4), "+z": (1, 5, 7, 3)}


def _corners(center, size, origin):
    """A box's corners relative to its object's origin. apply_loop rebuilds them the same way,
    so loop 0 lands on the shipped vertices bit for bit."""
    return [(center[0] - origin[0] + sx * (size[0] / 2), center[1] - origin[1] + sy * (size[1] / 2),
             center[2] - origin[2] + sz * (size[2] / 2)) for sx, sy, sz in _CORNERS]


def boxes_object(name, boxes, mats, collection, bevel=0.0, role=None, erode=None, origin=(0, 0, 0)):
    """One mesh object from many axis-aligned boxes in world coords, boxes =
    [(center, size, mat_index[, opts])], with the object's origin at `origin`.

    role tags every box for the exporter (a course_decl.gd role), or "none" marks the whole
    object visual-only. Untagged boxes in PLAY fail the export. erode = (axis, min, anchor) in
    the Blender frame: axis 0 = x or 1 = y, min the plateau size, anchor -1 / 0 / +1 pins the
    low edge / centre / high edge. opts overrides "role" and "erode" per box. Its "flush" names
    the faces (e.g. ("+x",)) that abut a neighbour box: their edges stay unbevelled, so a
    floor split into two boxes still reads as one surface."""
    bm = bmesh.new()
    bw = bm.edges.layers.float.new("bevel_weight_edge")
    flush_edges = set()
    records = []
    for b in boxes:
        c, s, mi = b[:3]
        opts = b[3] if len(b) > 3 else {}
        vs = [bm.verts.new(p) for p in _corners(c, s, origin)]
        for side, f in _FACES.items():
            face = bm.faces.new([vs[i] for i in f])
            face.material_index = mi
            if side in opts.get("flush", ()):
                flush_edges.update(face.edges)
        rec = {"role": opts.get("role", role), "center": list(c), "size": list(s)}
        e = opts.get("erode", erode)
        if e is not None:
            rec["erode"] = list(e)
        records.append(rec)
    for e in bm.edges:
        e[bw] = 0.0 if e in flush_edges else 1.0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    ob.location = origin
    coll(collection).objects.link(ob)
    if role == "none":
        ob["wid_role"] = "none"
    elif any(r["role"] for r in records):
        ob["wid_boxes"] = json.dumps(records)
        ob["wid_origin"] = list(origin)
    if bevel:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        # every edge weighs 1 but the flush ones, so a weight limit bevels boxes as an angle one does
        mod.limit_method = "WEIGHT" if flush_edges else "ANGLE"
        mod.harden_normals = True
    return ob


def explicit_colliders(ob, boxes, role):
    """Give a PLAY mesh that is no axis-aligned box (a door ajar at 45 degrees) hand-laid
    collider boxes, boxes = [(center, size)] in world coords. The mesh stays visual; the
    exporter checks each box lies inside the mesh's world bounds instead of matching an
    island, and such boxes may never erode."""
    ob["wid_boxes"] = json.dumps([{"role": role, "center": list(c), "size": list(s)} for c, s in boxes])
    ob["wid_explicit"] = 1
    return ob


def box(name, center, size, mat, collection, bevel=0.0, role=None, erode=None):
    """One box with its origin at its centre, so rotations turn it in place."""
    return boxes_object(name, [(center, size, 0)], [mat], collection, bevel, role, erode, origin=center)


def text(name, body, loc, rot, size, mat, collection, align="CENTER", extrude=0.0):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.extrude = extrude
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu)
    ob.location = loc
    ob.rotation_euler = rot
    coll(collection).objects.link(ob)
    return ob


def area_lamp(name, loc, size, energy, color=(1, 1, 1), panel=None, rng=None, keep=False):
    """A ceiling lamp: area light plus an optional emissive panel that dies with it."""
    li = bpy.data.lights.new(name, "AREA")
    li.shape = "RECTANGLE"
    li.size, li.size_y = size
    li.energy = energy
    li.color = color
    ob = bpy.data.objects.new(name, li)
    ob.location = loc
    coll("LIGHT").objects.link(ob)
    roll = 1.0 if keep else (rng.random() if rng else 1.0)
    ob["light_r"] = roll
    ob["energy0"] = energy
    ob["dominant"] = keep  # kept area lamps are the place's dominant light
    if panel is not None:
        panel["light_r"] = roll
        panel["dominant"] = keep
    return ob


def point_lamp(name, loc, energy, color, radius=0.1, keep=True, rng=None):
    li = bpy.data.lights.new(name, "POINT")
    li.energy = energy
    li.color = color
    li.shadow_soft_size = radius
    ob = bpy.data.objects.new(name, li)
    ob.location = loc
    coll("LIGHT").objects.link(ob)
    ob["light_r"] = 1.0 if keep else rng.random()
    ob["energy0"] = energy
    return ob


def camera(name, loc, yaw_deg, pitch_deg=0.0):
    """Rider's-eye camera: Godot's vertical 90 degree FOV (player.tscn), eye at 1.6 m."""
    cam = bpy.data.cameras.new(name)
    cam.sensor_fit = "VERTICAL"
    cam.sensor_height = 24.0
    cam.lens = 12.0  # (24/2) / tan(45 deg): 90 degrees vertical
    cam.clip_start = 0.05
    cam.clip_end = 500
    ob = bpy.data.objects.new(name, cam)
    ob.location = loc
    # yaw 0 looks down -y (the course direction); positive yaw turns toward +x
    ob.rotation_euler = (math.radians(90 + pitch_deg), 0, math.radians(180 + yaw_deg))
    coll("CAM").objects.link(ob)
    return ob


# ---------------------------------------------------------------- loops

def eroded_box(center, size, erode, scale):
    """erosion_logic.gd, mirrored: eroded_size lerps one axis toward min by the world scale (a
    min at or above the size means no erosion), and anchored_origin holds the pinned edge."""
    if not erode:
        return list(center), list(size)
    axis, mn, anchor = erode
    base = size[axis]
    new = base if mn >= base else base + (mn - base) * min(max(scale, 0.0), 1.0)
    c, s = list(center), list(size)
    s[axis] = new
    c[axis] = center[axis] + anchor * (base - new) * 0.5
    return c, s


def _erode(ob, scale):
    recs = json.loads(ob["wid_boxes"])
    if not any(r.get("erode") for r in recs):
        return
    origin = ob["wid_origin"]
    verts = ob.data.vertices
    for i, r in enumerate(recs):
        if r.get("erode"):
            c, s = eroded_box(r["center"], r["size"], r["erode"], scale)
            for k, p in enumerate(_corners(c, s, origin)):
                verts[8 * i + k].co = p
    ob.data.update()


def apply_loop(n):
    """Put the place in its loop-n state (0..5): the fade, and the erosion Godot plays."""
    sc = bpy.context.scene
    world_scale = min(max(n / PLATEAU_LOOP, 0.0), 1.0)
    for ob in bpy.data.objects:
        if "wid_boxes" in ob and not ob.get("wid_explicit"):
            _erode(ob, world_scale)
    sc["wid_loop"] = n
    sc["wid_desat"] = DESAT[n]
    sc["wid_mem_desat"] = MEM_DESAT[n]
    sc["wid_edge"] = EDGE[n]
    sc["wid_holes"] = HOLES[n]
    haze = sc.get("wid_haze", 1.0)  # places that never call set_haze keep the tables as tuned
    sc.world.node_tree.nodes["Fog"].inputs["Density"].default_value = SCATTER[n] * haze
    sc.world.node_tree.nodes["Absorb"].inputs["Density"].default_value = ABSORB[n] * haze
    sc.view_settings.exposure = sc.get("wid_exposure0", -0.6) + EXPOSURE_LIFT[n]
    for ob in bpy.data.objects:
        if "gone_at" in ob:
            ob.hide_render = n >= ob["gone_at"]
        if "light_r" in ob:
            dead = ob["light_r"] < DEAD[n]
            gain = DOMINANT_GAIN[n] if ob.get("dominant") else 1.0
            if ob.type == "LIGHT":
                ob.hide_render = dead
                ob.data.energy = ob["energy0"] * (1 - 0.3 * DESAT[n]) * gain
            else:
                ob["dead"] = 1.0 if dead else 0.0
                ob["gain"] = gain - 1.0
    for m in bpy.data.materials:
        if "wid_emission0" in m:
            g = next(nd for nd in m.node_tree.nodes if nd.type == "GROUP")
            g.inputs["Emission"].default_value = m["wid_emission0"] * (1 - DEAD[n])
    # custom props feed shaders through Attribute nodes; tag for a fresh depsgraph
    for ob in bpy.data.objects:
        ob.update_tag()


def render(path, cam_name, n):
    apply_loop(n)
    sc = bpy.context.scene
    sc.camera = bpy.data.objects[cam_name]
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
