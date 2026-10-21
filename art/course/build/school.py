"""Place 1, Distraction: the school corridors (docs/places.md section 1). Look-dev builder for #22.

Run in background Blender against art/course/01-school.blend:
    exec(open(BUILD + "/school.py").read())
The corridor runs down -y from the spawn at y = 0. Lockers line the left (-x) wall and
classroom windows the right (+x) wall. Every classroom is the same classroom.
"""
import math
import os
import random

BUILD = globals().get("BUILD") or os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(BUILD, "wid_common.py")).read(), globals())

rng = random.Random(1)
LEN = 190.0           # corridor length (m)
W = 7.0               # corridor width: exaggerated from a real 2.5 m for bhop straights
H = 4.2               # ceiling height
XL, XR = -W / 2, W / 2
SEG = 12.0            # one classroom per 12 m on the right
ALCOVE = (-32.0, -35.6)   # memory pocket: the cloakroom, off the racing line
HALL = (-62.0, -68.0)     # double doors to the dark hall
TINT = (0.74, 0.95, 0.82)  # cold fluorescent green-grey (phase-2 tint)

reset_scene("01_School")
set_core(-150.0, 40.0)  # the near end sits behind the spawn: the void eats ahead, never underfoot
set_fog_color((0.82, 0.92, 0.86))

# ---------------------------------------------------------------- materials

def grimy(base, dirt, scale=0.35, low=0.6):
    """Paint that has been leaned on for decades: noise stains plus a darker band at shoe height."""
    def tex(N, L):
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = scale
        nz.inputs["Detail"].default_value = 10
        nz.inputs["Roughness"].default_value = 0.7
        L.new(world_tex_coord(N, L, 1.0), nz.inputs["Vector"])
        st = N.new("ShaderNodeMapRange")
        st.inputs["From Min"].default_value = 0.45
        st.inputs["From Max"].default_value = 0.75
        st.inputs["To Max"].default_value = 0.55
        L.new(nz.outputs["Fac"], st.inputs["Value"])
        geo = N.new("ShaderNodeNewGeometry")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sep.inputs[0])
        band = N.new("ShaderNodeMapRange")
        band.inputs["From Min"].default_value = low
        band.inputs["From Max"].default_value = 0.0
        band.inputs["To Max"].default_value = 0.7
        L.new(sep.outputs["Z"], band.inputs["Value"])
        fac = N.new("ShaderNodeMath")
        fac.operation = "MAXIMUM"
        L.new(st.outputs["Result"], fac.inputs[0])
        L.new(band.outputs["Result"], fac.inputs[1])
        mix = N.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L.new(fac.outputs[0], mix.inputs["Factor"])
        ins = [s for s in mix.inputs if s.type == "RGBA"]
        ins[0].default_value = (*base, 1)
        ins[1].default_value = (*dirt, 1)
        return [s for s in mix.outputs if s.type == "RGBA"][0]
    return tex


def lino_color(N, L):
    v = world_tex_coord(N, L, 1 / 0.6)  # 0.6 m tiles
    ch = N.new("ShaderNodeTexChecker")
    ch.inputs["Scale"].default_value = 1.0
    ch.inputs["Color1"].default_value = (0.25, 0.28, 0.24, 1)
    ch.inputs["Color2"].default_value = (0.21, 0.245, 0.215, 1)
    L.new(v, ch.inputs["Vector"])
    vo = N.new("ShaderNodeTexVoronoi")
    vo.inputs["Scale"].default_value = 60.0
    L.new(world_tex_coord(N, L, 1.0), vo.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.10, 0.11, 0.10, 1)
    ramp.color_ramp.elements[1].position = 0.08
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    L.new(vo.outputs["Distance"], ramp.inputs[0])
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.6
    ins = [s for s in mix.inputs if s.type == "RGBA"]
    L.new(ch.outputs["Color"], ins[0])
    L.new(ramp.outputs["Color"], ins[1])
    return [s for s in mix.outputs if s.type == "RGBA"][0]


def lino_rough(N, L):
    # wax streaks run along the corridor: noise stretched in y
    geo = N.new("ShaderNodeNewGeometry")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.0, 0.08, 1.0)
    L.new(geo.outputs["Position"], mp.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.5
    nz.inputs["Detail"].default_value = 8
    L.new(mp.outputs[0], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.05
    mr.inputs["To Max"].default_value = 0.32
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    return mr.outputs["Result"]


def block_bump(N, L):
    v = world_tex_coord(N, L, 1.0)
    br = N.new("ShaderNodeTexBrick")
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Brick Width"].default_value = 0.44
    br.inputs["Row Height"].default_value = 0.22
    sw = N.new("ShaderNodeMapping")  # bricks in the wall plane (y, z)
    sw.inputs["Rotation"].default_value = (math.radians(90), 0, math.radians(90))
    L.new(v, sw.inputs["Vector"])
    L.new(sw.outputs[0], br.inputs["Vector"])
    return br.outputs["Fac"]


def tile_grid(N, L):
    v = world_tex_coord(N, L, 1 / 0.6)
    br = N.new("ShaderNodeTexBrick")
    br.offset = 0.0
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.03
    br.inputs["Brick Width"].default_value = 1.0
    br.inputs["Row Height"].default_value = 1.0
    br.inputs["Color1"].default_value = (0.56, 0.56, 0.52, 1)
    br.inputs["Color2"].default_value = (0.47, 0.46, 0.40, 1)
    br.inputs["Mortar"].default_value = (0.30, 0.30, 0.28, 1)
    L.new(v, br.inputs["Vector"])
    return br.outputs["Color"]


def wired_glass(N, L):
    v = world_tex_coord(N, L, 1 / 0.025)
    br = N.new("ShaderNodeTexBrick")
    br.offset = 0.0
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.06
    br.inputs["Brick Width"].default_value = 1.0
    br.inputs["Row Height"].default_value = 1.0
    br.inputs["Color1"].default_value = (0.85, 0.92, 0.9, 1)
    br.inputs["Color2"].default_value = (0.85, 0.92, 0.9, 1)
    br.inputs["Mortar"].default_value = (0.05, 0.05, 0.05, 1)
    L.new(v, br.inputs["Vector"])
    return br.outputs["Color"]


M = {
    "lino": material("Lino", (0.4, 0.45, 0.41), base_tex=lino_color, rough_tex=lino_rough, coat=0.4),
    "dado": material("PaintDado", (0.09, 0.18, 0.14), rough=0.22, bump=block_bump,
                     base_tex=grimy((0.09, 0.18, 0.14), (0.04, 0.07, 0.05))),
    "wall": material("PaintUpper", (0.50, 0.53, 0.46), rough=0.6, bump=block_bump,
                     base_tex=grimy((0.50, 0.53, 0.46), (0.30, 0.31, 0.25), low=0.0)),
    "ceil": material("CeilingTiles", (0.6, 0.6, 0.57), rough=0.85, base_tex=tile_grid),
    "troffer": material("Troffer", (0.95, 1.0, 0.97), emission=12.0, emit_color=TINT),
    "radiator": material("RadiatorPaint", (0.55, 0.55, 0.50), rough=0.4, metal=0.3,
                         base_tex=grimy((0.55, 0.55, 0.50), (0.25, 0.22, 0.17), scale=1.2)),
    "plate": material("DoorPlate", (0.08, 0.10, 0.12), rough=0.3),
    "plate_ink": material("PlateInk", (0.85, 0.85, 0.8), rough=0.5),
    "troffer_rim": material("TrofferRim", (0.6, 0.62, 0.6), rough=0.4, metal=0.6),
    "locker": material("LockerPaint", (0.12, 0.21, 0.25), rough=0.35, metal=0.4,
                       base_tex=grimy((0.12, 0.21, 0.25), (0.06, 0.08, 0.08), scale=2.0, low=0.3)),
    "locker_dark": material("LockerSlot", (0.02, 0.025, 0.03), rough=0.6),
    "label": material("LabelCard", (0.86, 0.85, 0.80), rough=0.7),
    "ink": material("Ink", (0.04, 0.04, 0.05), rough=0.6),
    "steel": material("Steel", (0.62, 0.63, 0.62), rough=0.3, metal=1.0),
    "door": material("DoorVeneer", (0.42, 0.27, 0.15), rough=0.45),
    "frame": material("Frame", (0.16, 0.29, 0.24), rough=0.3),
    "glass": material("WiredGlass", (0.85, 0.92, 0.9), rough=0.04, transmission=1.0, base_tex=wired_glass),
    "pane": material("Pane", (0.9, 0.95, 0.94), rough=0.02, transmission=1.0),
    "blind": material("Blind", (0.42, 0.42, 0.38), rough=0.6),
    "cork": material("Cork", (0.48, 0.32, 0.18), rough=0.9),
    "carpet": material("Carpet", (0.18, 0.22, 0.27), rough=0.95),
    "desk": material("DeskTop", (0.66, 0.58, 0.44), rough=0.5),
    "chair": material("ChairShell", (0.16, 0.30, 0.48), rough=0.45),
    "whiteboard": material("Whiteboard", (0.9, 0.91, 0.9), rough=0.15),
    "outside": material("OutsideGlow", (0.02, 0.025, 0.03), emission=6.0, emit_color=(0.20, 0.32, 0.62),
                        practical=True),
    "exit": material("ExitRed", (1, 0.08, 0.04), emission=14.0, emit_color=(1, 0.08, 0.04)),
    "exit_box": material("ExitBox", (0.06, 0.06, 0.06), rough=0.4),
    "clock_face": material("ClockFace", (0.92, 0.92, 0.88), rough=0.4),
    "wood": material("BenchWood", (0.5, 0.36, 0.22), rough=0.5),
    "coat": material("Raincoat", (0.95, 0.70, 0.05), rough=0.35, memory=True, coat=0.6),
    "coat_lining": material("CoatLining", (0.30, 0.20, 0.03), rough=0.6, memory=True),
    "toggle": material("Toggle", (0.10, 0.06, 0.03), rough=0.4, memory=True),
    "sign": material("SignBlue", (0.05, 0.12, 0.30), rough=0.4),
    "cubby": material("CubbyShadow", (0.06, 0.05, 0.04), rough=0.8),
    "coat_tag": material("NameTag", (0.95, 0.94, 0.9), rough=0.6, memory=True),
    "dark_glass": material("DarkGlass", (0.01, 0.012, 0.012), rough=0.05),
    "alcove_lamp": material("AlcoveLamp", (1.0, 0.85, 0.6), emission=6.0, emit_color=(1.0, 0.82, 0.55), memory=True),
}
POSTER_COLORS = [(0.86, 0.32, 0.25), (0.95, 0.80, 0.25), (0.30, 0.55, 0.80), (0.92, 0.92, 0.88),
                 (0.45, 0.70, 0.35), (0.95, 0.55, 0.70), (0.98, 0.98, 0.95)]
POSTER_M = [material(f"Paper{i}", c, rough=0.75) for i, c in enumerate(POSTER_COLORS)]

# ---------------------------------------------------------------- shell (PLAY)

floor = box("Floor", (0, -LEN / 2 + 8, -0.15), (W + 30, LEN + 16, 0.3), M["lino"], "PLAY")
floor["solid"] = 1.0  # ridden: never dissolves
box("Ceiling", (0, -LEN / 2 + 8, H + 0.05), (W, LEN + 16, 0.1), M["ceil"], "DRESS")

# left wall: solid block wall with the alcove and hall doors cut out
left = []
cuts = sorted([ALCOVE, HALL], key=lambda c: -c[0])
y = 8.0
for top, bot in cuts:
    left.append((y, top))
    y = bot
left.append((y, -LEN + 8))
for i, (y0, y1) in enumerate(left):
    cy, ly = (y0 + y1) / 2, abs(y0 - y1)
    box(f"WallL_dado{i}", (XL - 0.1, cy, 0.6), (0.2, ly, 1.2), M["dado"], "PLAY")
    box(f"WallL_up{i}", (XL - 0.1, cy, (1.2 + H) / 2), (0.2, ly, H - 1.2), M["wall"], "PLAY")
for top, bot in cuts:  # lintels over the openings: the hall doors stop at 2.2 m
    z0 = 2.2 if (top, bot) == HALL else 2.5
    box(f"Lintel{top}", (XL - 0.1, (top + bot) / 2, (z0 + H) / 2), (0.2, abs(top - bot), H - z0), M["wall"], "DRESS")

# right wall: dado, window band with mullions, upper wall; one door per classroom
right = []
n_seg = int(LEN // SEG)
for s in range(n_seg):
    y0 = 8.0 - s * SEG
    right.append(((XR + 0.1, y0 - 0.3, 0.55), (0.2, 0.6, 1.1), 1))
    right.append(((XR + 0.1, y0 - 1.6 - (SEG - 1.6) / 2, 0.55), (0.2, SEG - 1.6, 1.1), 1))
    right.append(((XR + 0.1, y0 - 1.1, 2.35), (0.2, 1.0, 0.3), 0))
    right.append(((XR + 0.1, y0 - SEG / 2, 3.35), (0.2, SEG, 1.7), 0))
    # door opening y0-0.6..y0-1.6 is left open below the window line; posts between
    right.append(((XR + 0.1, y0 - 0.3, 1.8), (0.2, 0.6, 1.4), 0))
    right.append(((XR + 0.1, y0 - 2.1, 1.8), (0.2, 1.0, 1.4), 0))
    for k in range(7):  # mullions every 1.4 m over the window band
        right.append(((XR + 0.1, y0 - 2.6 - k * 1.4 - 0.05, 1.8), (0.22, 0.1, 1.4), 2))
boxes_object("WallR", right, [M["wall"], M["dado"], M["frame"]], "PLAY", bevel=0.01)

# window glass + half-dropped blinds (DRESS)
glass, blinds = [], []
for s in range(n_seg):
    y0 = 8.0 - s * SEG
    glass.append(((XR + 0.1, y0 - 2.6 - 4.7, 1.8), (0.02, 9.4, 1.4), 0))
    for k in range(6):
        h = 2.45 - k * 0.11
        drop = 0.62 + 0.25 * math.sin(s * 1.7)  # each blind a different drop
        if 2.5 - h > drop:
            continue
        blinds.append(((XR + 0.04, y0 - 7.3, h), (0.01, 9.4, 0.08), 0))
boxes_object("WindowGlass", glass, [M["pane"]], "DRESS")
boxes_object("Blinds", blinds, [M["blind"]], "DRESS")

# ---------------------------------------------------------------- the one classroom

proto = bpy.data.collections.new("ClassroomProto")  # instanced per segment, never linked to the scene
def proto_box(name, c, s, mat, bevel=0.0):
    ob = box(name, c, s, mat, "DRESS", bevel)
    coll("DRESS").objects.unlink(ob)
    proto.objects.link(ob)
    return ob

D = 9.0  # room depth in x, measured from the corridor wall
proto_box("CR_floor", (D / 2, -SEG / 2, 0.01), (D, SEG, 0.02), M["carpet"])
proto_box("CR_back", (D + 0.1, -SEG / 2, H / 2), (0.2, SEG, H), M["wall"])
proto_box("CR_side", (D / 2, -SEG + 0.1, H / 2), (D, 0.2, H), M["wall"])
proto_box("CR_ceil", (D / 2, -SEG / 2, H + 0.05), (D, SEG, 0.1), M["ceil"])
# night through the back windows, low enough that the chairs up on the desks cut across it
proto_box("CR_outside", (D - 0.02, -SEG / 2, 1.85), (0.02, 9.6, 2.0), M["outside"])
mull = [((D - 0.06, -SEG / 2 + 4.8 - k * 1.2, 1.85), (0.06, 0.08, 2.0), 0) for k in range(9)]
mull.append(((D - 0.08, -SEG / 2, 0.82), (0.16, 9.8, 0.06), 0))  # sill
mull.append(((D - 0.06, -SEG / 2, 2.88), (0.06, 9.8, 0.08), 0))  # head
o = boxes_object("CR_mullions", mull, [M["frame"]], "DRESS")
coll("DRESS").objects.unlink(o); proto.objects.link(o)
proto_box("CR_board", (D / 2, -SEG + 0.22, 1.7), (3.6, 0.04, 1.2), M["whiteboard"], 0.01)
desks, chairs = [], []
for r in range(5):
    for c in range(4):
        dx, dy = 2.0 + r * 1.35, -2.4 - c * 2.4
        desks.append(((dx, dy, 0.72), (0.6, 1.2, 0.04), 0))
        for lx in (-0.25, 0.25):
            for ly in (-0.55, 0.55):
                desks.append(((dx + lx, dy + ly, 0.36), (0.035, 0.035, 0.7), 1))
        for side in (-0.3, 0.3):  # two chairs up on each desk, legs to the ceiling
            cy = dy + side
            chairs.append(((dx, cy, 0.77), (0.4, 0.38, 0.03), 0))
            chairs.append(((dx + 0.19, cy, 0.97), (0.03, 0.38, 0.4), 0))
            for lx in (-0.17, 0.17):
                for ly in (-0.16, 0.16):
                    chairs.append(((dx + lx, cy + ly, 1.0), (0.025, 0.025, 0.45), 1))
o = boxes_object("CR_desks", desks, [M["desk"], M["steel"]], "DRESS")
coll("DRESS").objects.unlink(o); proto.objects.link(o)
o = boxes_object("CR_chairs", chairs, [M["chair"], M["steel"]], "DRESS")
coll("DRESS").objects.unlink(o); proto.objects.link(o)


def clock(name, loc, yaw_deg, into=None, coll_name="DRESS"):
    """A wall clock stopped at 2:40, the minute they were taken out of class. Local frame:
    the face looks toward -x, read by a viewer looking +x; yaw turns the whole clock."""
    import bmesh as _bm
    root = bpy.data.objects.new(name, None)
    root.location = loc
    root.rotation_euler = (0, 0, math.radians(yaw_deg))
    me = bpy.data.meshes.new(name + "_face")
    bm = _bm.new()
    _bm.ops.create_circle(bm, cap_ends=True, radius=0.2, segments=32)
    bm.to_mesh(me); bm.free()
    me.materials.append(M["clock_face"])
    face = bpy.data.objects.new(name + "_face", me)
    face.rotation_euler = (0, math.radians(90), 0)
    parts = [face]
    # viewer looking +x: right is -y. Hour hand 80 deg past twelve, minute hand 240 deg.
    for hname, ang, ln in (("hour", 80.0, 0.11), ("min", 240.0, 0.17)):
        a = math.radians(ang)
        h = box(name + "_" + hname, (-0.012, -math.sin(a) * ln / 2, math.cos(a) * ln / 2),
                (0.01, 0.012, ln), M["ink"], coll_name)
        coll(coll_name).objects.unlink(h)
        h.rotation_euler = (a, 0, 0)
        parts.append(h)
    target = into if into is not None else coll(coll_name)
    for ob in [root] + parts:
        target.objects.link(ob)
    for ob in parts:
        ob.parent = root
    return root


clock("CR_clock", (D / 2, -SEG + 0.21, 3.0), -90.0, into=proto)
for s in range(n_seg):
    inst = bpy.data.objects.new(f"Classroom{s:02d}", None)
    inst.instance_type = "COLLECTION"
    inst.instance_collection = proto
    inst.location = (XR + 0.2, 8.0 - s * SEG, 0)
    coll("DRESS").objects.link(inst)

# classroom doors: veneer leaf with a wired-glass panel, closed
door_boxes, door_glass = [], []
for s in range(n_seg):
    y0 = 8.0 - s * SEG
    yc = y0 - 1.1
    door_boxes.append(((XR + 0.06, yc, 0.5375), (0.05, 0.98, 1.075), 0))
    door_boxes.append(((XR + 0.06, yc, 1.9625), (0.05, 0.98, 0.275), 0))
    door_boxes.append(((XR + 0.06, yc - 0.24, 1.45), (0.05, 0.5, 0.75), 0))
    door_boxes.append(((XR + 0.06, yc + 0.39, 1.45), (0.05, 0.2, 0.75), 0))
    door_boxes.append(((XR + 0.1, yc, 2.15), (0.22, 1.1, 0.1), 1))
    door_glass.append(((XR + 0.06, yc + 0.15, 1.45), (0.012, 0.28, 0.75), 0))
    door_boxes.append(((XR + 0.02, yc - 0.38, 1.0), (0.04, 0.14, 0.03), 2))
rads = []
for s in range(n_seg):
    y0 = 8.0 - s * SEG
    for k in range(3):
        ry = y0 - 3.6 - k * 3.0
        for f in range(14):
            rads.append(((XR - 0.07, ry - 0.65 + f * 0.1, 0.5), (0.08, 0.05, 0.6), 0))
        rads.append(((XR - 0.05, ry, 0.12), (0.03, 0.05, 0.24), 0))
    pl = box(f"RoomPlate{s}", (XR - 0.01, y0 - 1.1, 2.3), (0.01, 0.34, 0.14), M["plate"], "DRESS")
    t = text(f"RoomNo{s}", f"{s + 1}{"ABC"[s % 3]}", (XR - 0.016, y0 - 1.1, 2.3),
             (math.radians(90), 0, math.radians(-90)), 0.09, M["plate_ink"], "DRESS")
    t["gone_at"] = 2
boxes_object("Radiators", rads, [M["radiator"]], "DRESS", bevel=0.01)
for p in range(9):  # what the crowd left behind: dropped sheets on the floor
    sheet = box(f"Dropped{p}", (rng.uniform(-2.8, 2.8), -6.0 - p * rng.uniform(9, 17), 0.002),
                (0.21, 0.297, 0.002), POSTER_M[6], "DRESS")
    sheet.rotation_euler = (0, 0, rng.uniform(0, math.pi))
    sheet["gone_at"] = 2
boxes_object("Doors", door_boxes, [M["door"], M["frame"], M["steel"]], "DRESS", bevel=0.005)
boxes_object("DoorGlass", door_glass, [M["glass"]], "DRESS")

# ---------------------------------------------------------------- lockers (left)

NAMES = ["A. Patel", "J. Okoro", "M. Hughes", "S. Byrne", "L. Chen", "R. Evans", "T. Walsh",
         "K. Mensah", "E. Doyle", "F. Ahmed", "C. Price", "N. Kowal", "H. Reid", "D. Silva"]
lk, labels = [], []
y = 6.0
idx = 0
while y > -LEN + 10:
    in_cut = any(top + 0.5 > y > bot - 0.5 for top, bot in cuts)
    bank_end = y - 0.46 * 10
    if in_cut or any(top + 0.5 > bank_end > bot - 0.5 for top, bot in cuts):
        y -= 0.46
        continue
    for k in range(10):
        ly = y - 0.23 - k * 0.46
        lk.append(((XL + 0.25, ly, 1.0), (0.5, 0.46, 1.8), 0))       # carcass
        lk.append(((XL + 0.515, ly, 1.0), (0.03, 0.43, 1.74), 0))     # door
        for v in range(4):                                             # vent slots
            lk.append(((XL + 0.532, ly, 1.72 - v * 0.05), (0.004, 0.26, 0.018), 1))
        lk.append(((XL + 0.54, ly - 0.15, 1.05), (0.03, 0.05, 0.12), 2))  # latch
        lk.append(((XL + 0.533, ly, 1.5), (0.004, 0.16, 0.05), 3))        # label card
        if rng.random() < 0.85:
            labels.append((ly, NAMES[idx % len(NAMES)]))
        idx += 1
    lk.append(((XL + 0.25, y - 2.3, 0.05), (0.52, 4.6, 0.1), 1))  # plinth
    # noticeboard over every other bank
    if int(-y / 4.6) % 2 == 0:
        board = box(f"Board{idx}", (XL + 0.03, y - 2.3, 2.75), (0.04, 3.2, 1.3), M["cork"], "DRESS", 0.01)
        for p in range(rng.randint(4, 7)):
            pw, ph = rng.uniform(0.35, 0.7), rng.uniform(0.3, 0.55)
            py = y - 2.3 + rng.uniform(-1.3, 1.3)
            pz = 2.75 + rng.uniform(-0.35, 0.35)
            po = box(f"Poster{idx}_{p}", (XL + 0.055, py, pz), (0.005, pw, ph), rng.choice(POSTER_M), "DRESS")
            po.rotation_euler = (math.radians(rng.uniform(-3, 3)), 0, 0)
            po["gone_at"] = 2
    y = bank_end - 0.3
boxes_object("Lockers", lk, [M["locker"], M["locker_dark"], M["steel"], M["label"]], "DRESS", bevel=0.004)
for i, (ly, name) in enumerate(labels):
    t = text(f"LockerName{i}", name, (XL + 0.537, ly, 1.5), (math.radians(90), 0, math.radians(90)), 0.028, M["ink"], "DRESS")
    t["gone_at"] = 2

# headline posters the player can read at speed (gone at loop 2)
SIGNS = [(-14.0, "SPRING FAIR", 0), (-49.0, "PERMISSION SLIPS DUE FRIDAY", 1), (-90.0, "BE KIND", 4),
         (-121.0, "LOST PROPERTY", 3), (-150.0, "YEAR 6 LEAVERS", 2)]
for sy, words, pc in SIGNS:
    t = text(f"Sign{sy}", words, (XL + 0.08, sy, 2.95), (math.radians(90), 0, math.radians(90)), 0.16,
             M["ink"], "DRESS")
    t["gone_at"] = 2

# ---------------------------------------------------------------- ceiling lights

rim = []
for k in range(int(LEN / 4.8) + 2):  # one centre row of 2.4 m strips: pools of light, dark between
    ly = 6.0 - k * 4.8
    panel = box(f"Strip_{k}", (0, ly, H - 0.045), (0.22, 2.4, 0.01), M["troffer"], "DRESS")
    rim.append(((0, ly, H - 0.02), (0.3, 2.5, 0.04), 0))
    # every third strip is dominant and never dies: plateau keeps one corridor of light
    area_lamp(f"Lamp_{k}", (0, ly, H - 0.055), (0.22, 2.4), 90.0, TINT, panel, rng, keep=(k % 3 == 0))
boxes_object("TrofferRims", rim, [M["troffer_rim"]], "DRESS")

# far-end EXIT sign, never reached
box("ExitBox", (0, -138.0, H - 0.35), (1.0, 0.1, 0.32), M["exit_box"], "DRESS")
t = text("ExitText", "EXIT", (0, -137.94, H - 0.35), (math.radians(90), 0, math.radians(180)), 0.2, M["exit"], "DRESS")
point_lamp("ExitGlow", (0, -137.7, H - 0.35), 4.0, (1, 0.1, 0.05), keep=True)

# corridor clock above the third classroom door
clock("CorrClock", (XR - 0.02, 8.0 - 2 * SEG - 1.1, 3.0), 0.0)

# ---------------------------------------------------------------- hall doors (dark beyond)

hy0, hy1 = HALL
hall = []
hall.append(((XL - 0.1, (hy0 + hy1) / 2, 1.1), (0.08, abs(hy0 - hy1) - 0.4, 2.2), 0))
boxes_object("HallDoors", hall, [M["frame"]], "DRESS")
for k, cy in enumerate(((hy0 + hy1) / 2 + 1.4, (hy0 + hy1) / 2 - 1.4)):
    box(f"HallPort{k}", (XL - 0.05, cy, 1.5), (0.02, 0.5, 0.5), M["dark_glass"], "DRESS")

# ---------------------------------------------------------------- memory pocket: the cloakroom

ay0, ay1 = ALCOVE
AW = abs(ay0 - ay1)
AY = (ay0 + ay1) / 2
AD = 2.0          # alcove depth
BX = XL - AD      # back wall face
box("Alcove_back", (BX - 0.1, AY, H / 2), (0.2, AW, H), M["wall"], "PLAY")
box("Alcove_dado", (BX + 0.011, AY, 0.6), (0.02, AW, 1.2), M["dado"], "DRESS")
for k, (sy, face) in enumerate(((ay0, -1), (ay1, 1))):
    box(f"Alcove_side{k}", (XL - AD / 2, sy - 0.1 * face, H / 2), (AD, 0.2, H), M["wall"], "PLAY")
    box(f"Alcove_sdado{k}", (XL - AD / 2, sy + 0.011 * face, 0.6), (AD, 0.02, 1.2), M["dado"], "DRESS")
box("Alcove_ceil", (XL - AD / 2, AY, H + 0.05), (AD, AW, 0.1), M["ceil"], "DRESS")

# the sign over the opening: the plate stays, its word goes with the other labels
box("CloakSign", (XL + 0.012, AY, 2.85), (0.02, 1.5, 0.3), M["sign"], "DRESS", 0.005)
t = text("CloakWord", "CLOAKROOM", (XL + 0.024, AY, 2.85), (math.radians(90), 0, math.radians(90)), 0.15,
         M["plate_ink"], "DRESS")
t["gone_at"] = 2

# shoe cubbies under a bench: two rows of pigeonholes, empty
CD, CH = 0.36, 0.42   # cubby depth, height (the bench top)
span = AW - 0.3
cols = int(span // 0.3)
cw = span / cols
cub = [((BX + CD / 2, AY, CH + 0.02), (CD + 0.04, span + 0.04, 0.04), 0),       # bench top
       ((BX + CD / 2, AY, 0.03), (CD, span, 0.06), 0),                           # plinth
       ((BX + CD / 2, AY, CH / 2 + 0.03), (CD, span, 0.025), 0),                 # middle shelf
       ((BX + 0.01, AY, CH / 2), (0.02, span, CH), 1)]                           # back panel
for c in range(cols + 1):
    cub.append(((BX + CD / 2, AY - span / 2 + c * cw, CH / 2), (CD, 0.02, CH), 0))
boxes_object("Cubbies", cub, [M["wood"], M["cubby"]], "DRESS", bevel=0.004)

# two staggered rows of double coat hooks on wooden rails, a name tag over each
RAILS = (1.52, 1.12)
hooks, rails = [], []
pegs = []   # (rail, index, y, z) of every hook
for r, rz in enumerate(RAILS):
    rails.append(((BX + 0.012, AY, rz), (0.024, span, 0.16), 0))
    n = 9 - r
    for k in range(n):
        py = AY - (n - 1) * 0.17 + k * 0.34
        hz = rz - 0.02
        pegs.append((r, k, py, hz))
        hooks += [((BX + 0.03, py, hz), (0.012, 0.024, 0.07), 0),             # plate
                  ((BX + 0.075, py, hz - 0.02), (0.09, 0.013, 0.013), 0),     # long prong
                  ((BX + 0.115, py, hz - 0.002), (0.013, 0.013, 0.045), 0),   # its tip
                  ((BX + 0.055, py, hz + 0.022), (0.05, 0.011, 0.011), 0),    # short prong
                  ((BX + 0.075, py, hz + 0.036), (0.011, 0.011, 0.03), 0)]
boxes_object("PegRails", rails, [M["wood"]], "DRESS", bevel=0.004)
boxes_object("Hooks", hooks, [M["steel"]], "DRESS", bevel=0.002)
COAT_PEG = (0, 2)   # upper rail, toward the far end: the stretch of back wall the line can see
for r, k, py, hz in pegs:
    mine = (r, k) == COAT_PEG
    tg = box(f"PegTag{r}_{k}", (BX + 0.026, py, hz + 0.065), (0.004, 0.11, 0.035),
             M["coat_tag"] if mine else M["label"], "MEMORY" if mine else "DRESS")
    if not mine:
        tg["gone_at"] = 3
coat_hook = next((py, hz) for r, k, py, hz in pegs if (r, k) == COAT_PEG)


def raincoat(name, tip):
    """A child's yellow raincoat hung by the loop at the back of its collar. Local frame at the
    hook's tip: +x out of the wall (the wall is at x = -0.115), y along it, z up. The shoulders
    slump from the collar, the hood hangs down behind them, the empty sleeves drop down the
    sides. Body, sleeves and hood are lofted rings; toggles, cords and pocket flaps are parented
    parts. Every part takes a memory material."""
    import bmesh as _bm
    bm = _bm.new()

    def prof(table, t):
        for (t0, v0), (t1, v1) in zip(table, table[1:]):
            if t <= t1:
                u = (t - t0) / (t1 - t0)
                u = u * u * (3 - 2 * u)
                return v0 + (v1 - v0) * u
        return table[-1][1]

    def loft(rings, cap_top=None, cap_bot=None):
        """Faces between rings; a cap is the material index of a face closing that end."""
        n = len(rings[0])
        vs = [[bm.verts.new(p) for p in ring] for ring in rings]
        for r0, r1 in zip(vs, vs[1:]):
            for j in range(n):
                bm.faces.new([r0[j], r0[(j + 1) % n], r1[(j + 1) % n], r1[j]])
        if cap_top is not None:
            bm.faces.new(list(reversed(vs[0]))).material_index = cap_top
        if cap_bot is not None:
            bm.faces.new(vs[-1]).material_index = cap_bot

    RN = 36
    COLLAR = -0.015    # the collar's top edge, just under the prong it hangs from
    LEN = 0.66

    def xc(t):         # the coat swings back toward the wall below the hook
        return 0.035 - 0.07 * t

    half_w = [(0.0, 0.055), (0.07, 0.10), (0.16, 0.158), (0.3, 0.165), (0.65, 0.185), (1.0, 0.225)]
    front = [(0.0, 0.04), (0.12, 0.065), (0.35, 0.085), (1.0, 0.10)]
    back = [(0.0, 0.035), (0.2, 0.045), (1.0, 0.05)]

    def body_point(t, a):
        wy, fx, bx = prof(half_w, t), prof(front, t), prof(back, t)
        c, s_ = math.cos(a), math.sin(a)
        dx = fx if c > 0 else bx
        fold = (0.003 + 0.026 * t * t) * math.sin(5 * a + 1.3 + 2.0 * t) * (0.4 + 0.6 * max(c, 0))
        # the front closure: a crease down to the last toggle, then the fronts part toward the hem
        ang = math.atan2(s_, c)
        split = max(t - 0.66, 0.0) / 0.34
        seam = -(0.007 + 0.05 * split) * math.exp(-(ang / (0.12 + 0.2 * split)) ** 2) * min(t * 6, 1)
        z = COLLAR - t * LEN
        if t > 0.9:   # an uneven hem, lifted into a V where the fronts part
            k = (t - 0.9) / 0.1
            z += k * (0.014 * math.sin(3 * a + 0.7) + 0.075 * math.exp(-(ang / 0.22) ** 2))
        return (xc(t) + (dx + fold + seam) * c, (wy + fold * 0.5) * s_, z)

    # the neck opening is capped in shadowed lining
    loft([[body_point(i / 23, 2 * math.pi * j / RN) for j in range(RN)] for i in range(24)], cap_top=1)

    # sleeves: empty, flattened, hanging down the sides from the slumped shoulder
    SL = 0.42
    for side in (-1, 1):
        rings = []
        for i in range(14):
            u = i / 13
            grow = min(u / 0.18, 1.0)                    # rises out of the shoulder seam
            cx = xc(0.15 + 0.4 * u) + 0.03 * grow        # a little in front of the body side
            cy = side * (0.10 + 0.055 * grow + 0.02 * u)
            cz = COLLAR - 0.11 - u * SL
            rx = (0.6 + 0.4 * grow) * (0.052 + 0.008 * math.sin(u * math.pi))  # elbow fullness
            ry = (0.6 + 0.4 * grow) * (0.034 - 0.006 * u)
            if u > 0.88:                                 # cuff band
                rx, ry = rx + 0.006, ry + 0.004
            rings.append([(cx + rx * math.cos(2 * math.pi * j / 12), cy + ry * math.sin(2 * math.pi * j / 12), cz)
                          for j in range(12)])
        loft(rings, cap_top=0, cap_bot=1)

    # hood: hanging down the back between the coat and the wall, its rim just over the collar
    hood = _bm.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=1.0)
    for v in hood["verts"]:
        x, y, z = v.co
        sag = 0.012 * (1 - z) * math.cos(3 * y)          # the cloth bags toward the bottom
        v.co = (-0.058 + 0.042 * x + sag, 0.15 * y * (1.0 - 0.2 * z), COLLAR - 0.11 + 0.10 * z)

    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(M["coat"])
    me.materials.append(M["coat_lining"])
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    ob.location = tip
    ob.rotation_euler = (math.radians(2.5), 0, 0)   # hangs a little off true
    coll("MEMORY").objects.link(ob)
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = sub.render_levels = 2
    tex = bpy.data.textures.new(name + "_crumple", "CLOUDS")
    tex.noise_scale = 0.08
    dsp = ob.modifiers.new("Crumple", "DISPLACE")
    dsp.texture = tex
    dsp.strength = 0.01
    sol = ob.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.006

    def part(pname, c, size, mat, rot=(0, 0, 0), bevel=0.0):
        p = box(f"{name}_{pname}", c, size, mat, "MEMORY", bevel)
        p.rotation_euler = rot
        p.parent = ob
        return p

    for i, tz in enumerate((0.10, 0.25, 0.40)):   # toggles down the front, each through a cord loop
        t = tz / LEN
        x = xc(t) + prof(front, t)
        z = COLLAR - tz
        part(f"toggle{i}", (x + 0.004, 0.0, z), (0.018, 0.05, 0.016), M["toggle"], bevel=0.007)
        part(f"loop{i}", (x + 0.002, -0.03, z), (0.006, 0.04, 0.006), M["toggle"])
    for side in (-1, 1):
        # the collar, folded down into two points either side of the throat
        x = xc(0.05) + prof(front, 0.05)
        part(f"collar{side}", (x + 0.008, side * 0.045, COLLAR - 0.035), (0.012, 0.075, 0.085), M["coat"],
             (math.radians(side * -28), math.radians(-12), 0), bevel=0.005)
        # the hood's drawcords, dangling from the collar front with a stopper on each end
        x = xc(0.02) + prof(front, 0.02) + 0.004
        part(f"cord{side}", (x, side * 0.035, COLLAR - 0.06), (0.004, 0.004, 0.11), M["toggle"],
             (math.radians(side * 4), 0, 0))
        part(f"stopper{side}", (x, side * 0.039, COLLAR - 0.12), (0.014, 0.014, 0.022), M["toggle"], bevel=0.006)
        # pocket flaps, turned to follow the body
        t = 0.62
        y = side * 0.115
        wy = prof(half_w, t)
        a = math.asin(max(-1.0, min(1.0, y / wy)))
        part(f"flap{side}", (xc(t) + prof(front, t) * math.cos(a) + 0.006, y, COLLAR - t * LEN),
             (0.012, 0.11, 0.045), M["coat"], (0, 0, -a * 0.8), bevel=0.005)
    return ob


coat = raincoat("Coat", (BX + 0.115, coat_hook[0], coat_hook[1]))
# the alcove's own lamp: the memory object keeps its light longest
# a laminated notice over the rails, its words gone with the other labels
box("HangNotice", (BX + 0.004, AY + 0.6, 1.98), (0.006, 0.42, 0.3), POSTER_M[6], "DRESS")
for i, line in enumerate(("PLEASE HANG UP", "YOUR COAT")):
    t = text(f"HangWord{i}", line, (BX + 0.009, AY + 0.6, 2.02 - i * 0.075), (math.radians(90), 0, math.radians(90)),
             0.05, M["ink"], "DRESS")
    t["gone_at"] = 2
abox = box("AlcoveLamp", (XL - AD / 2, AY, H - 0.02), (0.5, 0.5, 0.02), M["alcove_lamp"], "MEMORY")
point_lamp("AlcoveLight", (BX + 1.0, coat_hook[0] + 0.3, 2.7), 55.0, (1.0, 0.85, 0.62), radius=0.25, keep=True)

# ---------------------------------------------------------------- cameras

camera("CamStraight", (0.9, 4.0, 1.6), 0.0, -2.0)
camera("CamAlcove", (1.4, -27.0, 1.6), -42.0, -8.0)
camera("CamDoor", (2.2, -50.0, 1.6), -18.0, -3.0)
camera("CamCoat", (-3.7, -34.35, 1.6), -88.0, -16.0)  # lingering: stepped into the alcove mouth

apply_loop(0)
bpy.ops.wm.save_mainfile()
result = {"objects": len(bpy.data.objects), "lamps": sum(1 for o in bpy.data.objects if o.type == "LIGHT"),
          "lockers_labeled": len(labels)}
