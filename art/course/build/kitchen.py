"""Place 2, Busyness: the kitchen at night (docs/places.md section 2). Look-dev builder for #22.

Run in background Blender against art/course/02-kitchen.blend:
    exec(open(BUILD + "/kitchen.py").read())
A galley kitchen at ten times scale: the rider is a child on a giant's counters. Two worktop
runs face each other down -y from the spawn at y = 0: the sink run at -x (on the rider's
right, looking down the galley) and the hob run at +x, with a chasm between them and the floor
9 m below. The chasm grows: 3.0 m at loop 0, 7.5 m at plateau, as each worktop's front strip
erodes back toward the wall (#23). The fridge stands across the far end, door ajar, a wedge of
cold light pouring out of it down the galley; the cooker-hood bulb burns amber over the hob, so
the racing line (LINE, laid out with the run tables below) rides out of the amber into the blue.
"""
import math
import os

import bmesh
import mathutils

BUILD = globals().get("BUILD") or os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(BUILD, "wid_common.py")).read(), globals())

WT = 9.0                   # worktop top (a real 0.9 m counter)
WT_TH = 0.4                # worktop thickness
XF, XB = 1.5, 9.6          # worktop front edge at loop 0 and back wall, |x|: the chasm is 2 * XF = 3.0 m
XP = XF + 2.25             # the front edge at plateau: the chasm is 2 * XP = 7.5 m, the hard ceiling
XS = 4.0                   # seam between a worktop's eroding front strip and its fixed back slab
XD = 4.3                   # base unit door faces: everything under the worktop sits behind XP
XU = 6.1                   # upper cupboard carcass front, |x| (3.5 m deep)
UP_Z0, UP_Z1 = 13.5, 20.5  # upper cupboards: 4.5 m clear over the worktop, 7 m tall
CEIL = 24.0
Y0, Y1 = 8.0, -70.5        # near wall behind the spawn, far wall behind the fridge
# The line: spawn on the hob run, past the hob under the hood; cross the chasm to the sink run
# where the two runs overlap (the hob run has an 8.5 m gap you cannot clear along it); cross back
# before the sink; bread bin, microwave, up onto the cupboard faces (a 23.5 m bank) and a wall
# ride over the second gap (12.5 m); land in the fridge light by the rack, through the door.
# Both crossings are straight across, so neither is longer than the chasm: 7.5 m at plateau.
# The sink run breaks opposite the wall-ride gap (8.5 m, past the 8.31 m reach), so the climb and
# the wall ride are the only way to the fridge.
SINK_RUNS = [(8.0, -16.0), (-23.3, -47.0), (-55.5, -70.5)]   # the hall doorway, then the uncrossable gap
HOB_RUNS = [(8.0, -24.5), (-33.0, -45.0), (-57.5, -70.5)]    # a crossing gap, then the wall-ride gap
DOORWAY = (-16.5, -22.8)   # the sink run restarts 1.2 m before the hob run ends: the first crossing
WINDOW = (-30.0, -43.0)    # over the sink
SINK = (-33.5, -39.5)
SINK_X = (-8.8, -4.6)
HOB = (-13.0, -19.0)
HOOD = (-10.5, -21.5)
SINK_UPPERS = [(8.0, -14.0), (-45.0, -57.5), (-58.0, -70.5)]
HOB_UPPERS = [(8.0, -10.5), (-21.5, -35.0), (-35.5, -59.0), (-59.5, -70.5)]  # third bank = the ride wall
FR_Y, FR_W = -64.0, 6.0     # fridge front and width; it stands 18.6 m, to the top of its box
DOOR_OPEN = 45.0           # degrees the fridge door stands ajar, hinged on its -x edge: the slit
                           # and its light face the hob run, the line and the rack; the card on
                           # the door face looks back up the galley
AMBER = (1.0, 0.50, 0.15)
COLD = (0.56, 0.77, 1.0)
INK_FONT = bpy.data.fonts.load("C:/Windows/Fonts/Inkfree.ttf", check_existing=True)

reset_scene("02_Kitchen")
set_core(-95.0, 30.0)  # the galley is short: the void bites nothing you ride, the fridge stays
set_fog_color((0.86, 0.9, 0.96))
set_haze(0.3)  # 10x scale: the far end would drown at the corridor density

# ---------------------------------------------------------------- materials


def _pos(N, L, a, b):
    """World position projected onto two axes, for 2D patterns on axis-aligned faces."""
    geo = N.new("ShaderNodeNewGeometry")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    cmb = N.new("ShaderNodeCombineXYZ")
    L.new(sep.outputs[a], cmb.inputs[0])
    L.new(sep.outputs[b], cmb.inputs[1])
    return cmb.outputs[0]


def tiles(axes, size, c1, c2, grout, mortar=0.04):
    """Square tiles at `size` metres on the plane of `axes` (e.g. "YZ" for a wall facing x)."""
    def brick(N, L):
        br = N.new("ShaderNodeTexBrick")
        br.offset = 0.0
        br.inputs["Scale"].default_value = 1.0 / size
        br.inputs["Mortar Size"].default_value = mortar
        br.inputs["Brick Width"].default_value = 1.0
        br.inputs["Row Height"].default_value = 1.0
        br.inputs["Color1"].default_value = (*c1, 1)
        br.inputs["Color2"].default_value = (*c2, 1)
        br.inputs["Mortar"].default_value = (*grout, 1)
        L.new(_pos(N, L, axes[0], axes[1]), br.inputs["Vector"])
        return br

    def color(N, L):
        return brick(N, L).outputs["Color"]

    def height(N, L):
        inv = N.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        L.new(brick(N, L).outputs["Fac"], inv.inputs[1])
        return inv.outputs[0]
    return color, height


def speckle(base, fleck, scale=9.0):
    """Granite-effect laminate: a fine fleck over a slow cloud."""
    def tex(N, L):
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = scale
        nz.inputs["Detail"].default_value = 4
        L.new(world_tex_coord(N, L, 1.0), nz.inputs["Vector"])
        ramp = N.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        ramp.color_ramp.elements[0].position = 0.0
        ramp.color_ramp.elements[0].color = (*fleck, 1)
        ramp.color_ramp.elements[1].position = 0.36
        ramp.color_ramp.elements[1].color = (*base, 1)
        L.new(nz.outputs["Fac"], ramp.inputs[0])
        return ramp.outputs["Color"]
    return tex


def wiped(N, L):
    """Every counter wiped down at 2 a.m.: broad cloth arcs left in the gloss."""
    geo = N.new("ShaderNodeNewGeometry")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.35, 0.12, 1.0)
    L.new(geo.outputs["Position"], mp.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 2.0
    nz.inputs["Detail"].default_value = 3
    nz.inputs["Distortion"].default_value = 2.5
    L.new(mp.outputs[0], nz.inputs["Vector"])
    mr = N.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.35
    mr.inputs["From Max"].default_value = 0.7
    mr.inputs["To Min"].default_value = 0.03
    mr.inputs["To Max"].default_value = 0.22
    L.new(nz.outputs["Fac"], mr.inputs["Value"])
    return mr.outputs["Result"]


def mottled(base, dark, scale=0.25):
    """Emulsion that has had a family against it: slow patches of a darker tone."""
    def tex(N, L):
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = scale
        nz.inputs["Detail"].default_value = 8
        nz.inputs["Roughness"].default_value = 0.65
        L.new(world_tex_coord(N, L, 1.0), nz.inputs["Vector"])
        mix = N.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L.new(nz.outputs["Fac"], mix.inputs["Factor"])
        ins = [s for s in mix.inputs if s.type == "RGBA"]
        ins[0].default_value = (*base, 1)
        ins[1].default_value = (*dark, 1)
        return [s for s in mix.outputs if s.type == "RGBA"][0]
    return tex


def checker(size, c1, c2):
    def tex(N, L):
        ch = N.new("ShaderNodeTexChecker")
        ch.inputs["Scale"].default_value = 1.0
        ch.inputs["Color1"].default_value = (*c1, 1)
        ch.inputs["Color2"].default_value = (*c2, 1)
        L.new(world_tex_coord(N, L, 1.0 / size), ch.inputs["Vector"])
        return ch.outputs["Color"]
    return tex


def stripes(base, stripe, axis="Z", period=1.2, width=0.18):
    """Tea-towel stripes across one world axis."""
    def tex(N, L):
        geo = N.new("ShaderNodeNewGeometry")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Position"], sep.inputs[0])
        m = N.new("ShaderNodeMath")
        m.operation = "PINGPONG"
        m.inputs[1].default_value = period / 2
        L.new(sep.outputs[axis], m.inputs[0])
        st = N.new("ShaderNodeMath")
        st.operation = "LESS_THAN"
        st.inputs[1].default_value = width
        L.new(m.outputs[0], st.inputs[0])
        mix = N.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L.new(st.outputs[0], mix.inputs["Factor"])
        ins = [s for s in mix.inputs if s.type == "RGBA"]
        ins[0].default_value = (*base, 1)
        ins[1].default_value = (*stripe, 1)
        return [s for s in mix.outputs if s.type == "RGBA"][0]
    return tex


def pan_base(N, L):
    """The pan's bare steel base, scrubbed: machining rings and the ghost of a scorch."""
    tc = N.new("ShaderNodeTexCoord")
    wv = N.new("ShaderNodeTexWave")
    wv.wave_type = "RINGS"
    wv.inputs["Scale"].default_value = 4.0
    wv.inputs["Distortion"].default_value = 0.4
    L.new(tc.outputs["Object"], wv.inputs["Vector"])
    ln = N.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    L.new(tc.outputs["Object"], ln.inputs[0])
    ring = N.new("ShaderNodeMapRange")       # the heat ring sat where the flame did
    ring.inputs["From Min"].default_value = 0.35
    ring.inputs["From Max"].default_value = 0.95
    ring.inputs["To Min"].default_value = 0.0
    ring.inputs["To Max"].default_value = 1.0
    L.new(ln.outputs["Value"], ring.inputs["Value"])
    bell = N.new("ShaderNodeMath")
    bell.operation = "PINGPONG"
    bell.inputs[1].default_value = 0.5
    L.new(ring.outputs["Result"], bell.inputs[0])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.0
    L.new(tc.outputs["Object"], nz.inputs["Vector"])
    st = N.new("ShaderNodeMath")
    st.operation = "MULTIPLY"
    L.new(bell.outputs[0], st.inputs[0])
    L.new(nz.outputs["Fac"], st.inputs[1])
    steel = N.new("ShaderNodeMix")
    steel.data_type = "RGBA"
    L.new(wv.outputs["Fac"], steel.inputs["Factor"])
    s_in = [s for s in steel.inputs if s.type == "RGBA"]
    s_in[0].default_value = (0.66, 0.66, 0.64, 1)
    s_in[1].default_value = (0.52, 0.52, 0.50, 1)
    tint = N.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    L.new(st.outputs[0], tint.inputs["Factor"])
    t_in = [s for s in tint.inputs if s.type == "RGBA"]
    L.new([s for s in steel.outputs if s.type == "RGBA"][0], t_in[0])
    t_in[1].default_value = (0.40, 0.25, 0.12, 1)
    return [s for s in tint.outputs if s.type == "RGBA"][0]


wall_tile_c, wall_tile_h = tiles("YZ", 1.0, (0.80, 0.80, 0.77), (0.78, 0.79, 0.76), (0.42, 0.41, 0.38))
end_tile_c, end_tile_h = tiles("XZ", 1.0, (0.80, 0.80, 0.77), (0.78, 0.79, 0.76), (0.42, 0.41, 0.38))
M = {
    "worktop": material("Worktop", (0.6, 0.58, 0.54), base_tex=speckle((0.60, 0.58, 0.54), (0.36, 0.35, 0.33)),
                        rough_tex=wiped, coat=0.5),
    "unit": material("UnitDoor", (0.66, 0.61, 0.50), rough=0.3, coat=0.3),
    "carcass": material("Carcass", (0.55, 0.51, 0.42), rough=0.6),
    "plinth": material("Plinth", (0.07, 0.07, 0.07), rough=0.5),
    "handle": material("Handle", (0.75, 0.75, 0.73), rough=0.28, metal=1.0),
    "steel": material("Stainless", (0.72, 0.72, 0.70), rough=0.22, metal=1.0),
    "brushed": material("Brushed", (0.6, 0.6, 0.58), rough=0.4, metal=1.0),
    "tile": material("WallTile", (0.8, 0.8, 0.77), rough=0.12, base_tex=wall_tile_c, bump=wall_tile_h),
    "tile_end": material("WallTileEnd", (0.8, 0.8, 0.77), rough=0.12, base_tex=end_tile_c, bump=end_tile_h),
    "paint": material("WallPaint", (0.44, 0.38, 0.28), rough=0.8,
                      base_tex=mottled((0.50, 0.43, 0.31), (0.30, 0.25, 0.18))),
    "cal_photo": material("CalendarPhoto", (0.2, 0.35, 0.5), rough=0.5,
                          base_tex=stripes((0.22, 0.42, 0.62), (0.25, 0.42, 0.16), "Z", period=6.0, width=1.4)),
    "red_pen": material("RedPen", (0.7, 0.05, 0.05), rough=0.5),
    "ceil": material("Ceiling", (0.6, 0.6, 0.58), rough=0.9),
    "floor": material("FloorVinyl", (0.2, 0.19, 0.17), rough=0.35,
                      base_tex=checker(3.0, (0.20, 0.19, 0.17), (0.11, 0.105, 0.10))),
    "skirting": material("Skirting", (0.62, 0.6, 0.55), rough=0.4),
    "fridge": material("FridgeEnamel", (0.80, 0.82, 0.83), rough=0.18, coat=0.6),
    "liner": material("FridgeLiner", (0.88, 0.9, 0.92), rough=0.35),
    "fridge_glow": material("FridgeGlow", (0.9, 0.95, 1.0), emission=3.0, emit_color=(0.80, 0.90, 1.0)),
    "gasket": material("Gasket", (0.25, 0.26, 0.27), rough=0.7),
    "shelf": material("ShelfGlass", (0.85, 0.93, 0.95), rough=0.03, transmission=1.0),
    "crisper": material("Crisper", (0.8, 0.88, 0.9), rough=0.25, transmission=0.8),
    "grille": material("Grille", (0.04, 0.04, 0.04), rough=0.6),
    "dark_glass": material("DarkGlass", (0.015, 0.015, 0.017), rough=0.06),
    "fascia": material("Fascia", (0.03, 0.03, 0.035), rough=0.15),
    "iron": material("CastIron", (0.04, 0.04, 0.04), rough=0.55),
    "brass": material("BurnerBrass", (0.55, 0.42, 0.2), rough=0.35, metal=1.0),
    "bulb": material("HoodBulb", (1.0, 0.8, 0.5), emission=40.0, emit_color=AMBER, practical=True),
    "filter": material("GreaseFilter", (0.2, 0.2, 0.2), rough=0.45, metal=0.8),
    "led": material("OvenClockLED", (0.1, 1.0, 0.55), emission=30.0, emit_color=(0.15, 1.0, 0.5), practical=True),
    "led_amber": material("HoodLED", (1.0, 0.5, 0.1), emission=20.0, emit_color=(1.0, 0.45, 0.08), practical=True),
    "night": material("NightOutside", (0.01, 0.012, 0.02), emission=0.1, emit_color=(0.10, 0.14, 0.30),
                      practical=True),
    "pane": material("WindowPane", (0.9, 0.95, 0.94), rough=0.02, transmission=1.0),
    "upvc": material("WindowFrame", (0.78, 0.78, 0.76), rough=0.35),
    "water": material("Water", (0.9, 0.95, 1.0), rough=0.0, transmission=1.0),
    "wood": material("BoardWood", (0.46, 0.31, 0.17), rough=0.55),
    "door_paint": material("HallDoor", (0.70, 0.68, 0.62), rough=0.4),
    "hall": material("HallDark", (0.12, 0.11, 0.1), rough=0.8),
    "toaster": material("ToasterRed", (0.48, 0.05, 0.04), rough=0.25, coat=0.6),
    "breadbin": material("BreadBinEnamel", (0.10, 0.22, 0.28), rough=0.3, coat=0.5),
    "black": material("BlackPlastic", (0.03, 0.03, 0.03), rough=0.4),
    "white": material("WhitePlastic", (0.82, 0.82, 0.80), rough=0.35),
    "towel_flat": material("TeaTowelFlat", (0.85, 0.84, 0.8), rough=0.9, memory=True,
                           base_tex=stripes((0.85, 0.84, 0.80), (0.10, 0.20, 0.45), "X")),
    "towel": material("TeaTowel", (0.85, 0.84, 0.8), rough=0.9,
                      base_tex=stripes((0.85, 0.84, 0.80), (0.10, 0.20, 0.45), "Z")),
    "cloth": material("Dishcloth", (0.18, 0.42, 0.55), rough=0.95),
    "soap": material("WashingUp", (0.25, 0.55, 0.12), rough=0.15, transmission=0.4),
    "book": [material(f"Book{i}", c, rough=0.6) for i, c in
             enumerate(((0.45, 0.12, 0.08), (0.12, 0.25, 0.40), (0.80, 0.70, 0.40), (0.20, 0.35, 0.20)))],
    "book_ink": material("SpineInk", (0.9, 0.88, 0.8), rough=0.5),
    "milk": material("MilkBottle", (0.9, 0.9, 0.88), rough=0.3),
    "foil": material("Foil", (0.8, 0.8, 0.8), rough=0.35, metal=1.0),
    "jar": material("JarRed", (0.45, 0.06, 0.08), rough=0.1, transmission=0.3),
    "juice": material("JuiceCarton", (0.9, 0.55, 0.1), rough=0.5),
    "shade": material("LightShade", (0.75, 0.75, 0.72), rough=0.5),
    # memory: the rack, the pan, the card. Kept whole, desaturated last.
    "pan_base": material("PanBase", (0.62, 0.62, 0.6), rough=0.3, metal=1.0, memory=True, base_tex=pan_base),
    "pan_out": material("PanOutside", (0.05, 0.05, 0.055), rough=0.35, memory=True),
    "pan_in": material("PanNonstick", (0.04, 0.04, 0.045), rough=0.5, memory=True),
    "pan_handle": material("PanHandle", (0.03, 0.03, 0.03), rough=0.45, memory=True),
    "rack": material("RackWire", (0.8, 0.8, 0.78), rough=0.18, metal=1.0, memory=True),
    "tray": material("RackTray", (0.82, 0.83, 0.82), rough=0.3, memory=True),
    "card": material("Card", (0.80, 0.26, 0.42), rough=0.7, memory=True),   # pink: it reads on white enamel
    "card_cake": material("CardCake", (0.36, 0.18, 0.09), rough=0.7, memory=True),
    "card_cream": material("CardIcing", (0.96, 0.92, 0.85), rough=0.7, memory=True),
    "card_flame": material("CardFlame", (0.95, 0.70, 0.10), rough=0.7, memory=True),
    "card_ink": material("CardInk", (0.97, 0.94, 0.86), rough=0.6, memory=True),   # silver-white pen
    "list": material("ListPaper", (0.92, 0.92, 0.88), rough=0.75),
    "pencil": material("Pencil", (0.15, 0.15, 0.2), rough=0.6),
}
MAGNET_M = [material(f"Magnet{i}", c, rough=0.3) for i, c in enumerate(
    ((0.85, 0.12, 0.10), (0.95, 0.78, 0.10), (0.15, 0.55, 0.25), (0.12, 0.30, 0.75), (0.95, 0.45, 0.10)))]


# ---------------------------------------------------------------- local geometry helpers

def _finish(bm, name, mats, collection, smooth_angle=None):
    me = bpy.data.meshes.new(name)
    if smooth_angle is not None:
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(smooth_angle):
                e.smooth = False
        for f in bm.faces:
            f.smooth = True
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    coll(collection).objects.link(ob)
    return ob


def cyl(name, loc, r, h, mat, collection, rot=(0, 0, 0), r2=None, segs=32):
    """A cylinder (or frustum, top radius r2) along local z, centred on loc."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                          radius2=r if r2 is None else r2, depth=h)
    ob = _finish(bm, name, [mat], collection, smooth_angle=40)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def lathe(name, prof, mats, mat_of, collection, segs=48):
    """Revolve a closed (r, z) profile about local z. mat_of(i) is the material index of the
    band between profile points i and i + 1; an r of 0 closes that end to a point."""
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r == 0:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * j / segs),
                                        r * math.sin(2 * math.pi * j / segs), z)) for j in range(segs)])
    for i, (a, b) in enumerate(zip(rings, rings[1:])):
        for j in range(segs):
            k = (j + 1) % segs
            if len(a) == 1:
                f = bm.faces.new([a[0], b[k], b[j]])
            elif len(b) == 1:
                f = bm.faces.new([a[j], a[k], b[0]])
            else:
                f = bm.faces.new([a[j], a[k], b[k], b[j]])
            f.material_index = mat_of(i)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, mats, collection, smooth_angle=35)


def hull(name, pts, mat, collection):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    bmesh.ops.convex_hull(bm, input=vs)
    return _finish(bm, name, [mat], collection)


def tube(name, pts, r, mat, collection):
    """A smooth round tube through pts: cables, the tap's swan neck."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1)
    sp.order_u = 3
    sp.use_endpoint_u = True
    sp.resolution_u = 16
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu)
    coll(collection).objects.link(ob)
    return ob


def pivot(name, loc, yaw_deg, collection):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    e.rotation_euler = (0, 0, math.radians(yaw_deg))
    coll(collection).objects.link(e)
    return e


def child(ob, parent):
    ob.parent = parent
    return ob


def seg7(name, digits, x, y0, z0, h, mat, collection):
    """A seven-segment readout on a face looking -x (read from the chasm: right is -y)."""
    on = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
          "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}
    w, t = h * 0.55, h * 0.12
    spots = {"a": (w / 2, h, w, t), "b": (w, 0.75 * h, t, h / 2), "c": (w, 0.25 * h, t, h / 2),
             "d": (w / 2, 0, w, t), "e": (0, 0.25 * h, t, h / 2), "f": (0, 0.75 * h, t, h / 2),
             "g": (w / 2, h / 2, w, t)}
    bxs = []
    u = 0.0
    for ch in digits:
        if ch == ":":
            for v in (0.3 * h, 0.7 * h):
                bxs.append(((x, y0 - u - t, z0 + v), (0.02, t, t), 0))
            u += 3 * t
            continue
        for s in on[ch]:
            cu, cv, su, sv = spots[s]
            bxs.append(((x, y0 - u - cu, z0 + cv), (0.02, su * 0.92, sv * 0.92), 0))
        u += w + 0.4 * h
    return boxes_object(name, bxs, [mat], collection)


def ink_text(name, body, loc, rot, size, mat, collection, gone_at=None, parent=None):
    t = text(name, body, loc, rot, size, mat, collection)
    t.data.font = INK_FONT
    if gone_at is not None:
        t["gone_at"] = gone_at
    if parent is not None:
        t.parent = parent
    return t


# ---------------------------------------------------------------- shell

FACE_X = (math.radians(90), 0, math.radians(-90))   # text read from the chasm, on a +x wall
FACE_Y = (math.radians(90), 0, math.radians(180))   # facing +y, back up the galley

box("Floor", (0, (Y0 + Y1) / 2, -0.1), (2 * XB + 0.8, Y0 - Y1, 0.2), M["floor"], "DRESS")
box("Ceiling", (0, (Y0 + Y1) / 2, CEIL + 0.15), (2 * XB + 0.8, Y0 - Y1, 0.3), M["ceil"], "DRESS")
box("WallNear", (0, Y0 + 0.2, CEIL / 2), (2 * XB + 0.8, 0.4, CEIL), M["paint"], "PLAY", role="ride_wall")
box("WallEnd", (0, Y1 - 0.2, CEIL / 2), (2 * XB + 0.8, 0.4, CEIL), M["paint"], "PLAY", role="ride_wall")
box("WallR", (XB + 0.2, (Y0 + Y1) / 2, CEIL / 2), (0.4, Y0 - Y1, CEIL), M["paint"], "PLAY", role="ride_wall")
# sink-side wall: cut for the hall doorway and the window over the sink
lw = []
spans = [(Y0, DOORWAY[0], 0.0, CEIL), (DOORWAY[0], DOORWAY[1], 20.5, CEIL), (DOORWAY[1], WINDOW[0], 0.0, CEIL),
         (WINDOW[0], WINDOW[1], 0.0, 11.0), (WINDOW[0], WINDOW[1], 20.5, CEIL), (WINDOW[1], Y1, 0.0, CEIL)]
for ya, yb, za, zb in spans:
    lw.append(((-XB - 0.2, (ya + yb) / 2, (za + zb) / 2), (0.4, ya - yb, zb - za), 0))
boxes_object("WallL", lw, [M["paint"]], "PLAY", role="ride_wall")

# splashback tiles between the worktops and the wall cupboards
tl = []
for ya, yb, za, zb in ((Y0, DOORWAY[0], WT, UP_Z0), (DOORWAY[1], WINDOW[0], WT, UP_Z0), (WINDOW[0], WINDOW[1], WT, 11.0),
                       (WINDOW[1], Y1, WT, UP_Z0)):
    tl.append(((-XB + 0.03, (ya + yb) / 2, (za + zb) / 2), (0.06, ya - yb, zb - za), 0))
for ya, yb, za, zb in ([(Y0, HOOD[0], WT, UP_Z0), (HOOD[0], HOOD[1], WT, 15.5), (HOOD[1], HOB_RUNS[0][1], WT, UP_Z0)]
                       + [(a, b, WT, UP_Z0) for a, b in HOB_RUNS[1:]]
                       + [(HOB_RUNS[1][1], HOB_RUNS[2][0], WT, UP_Z0)]):   # still there over the wall-ride gap
    tl.append(((XB - 0.03, (ya + yb) / 2, (za + zb) / 2), (0.06, ya - yb, zb - za), 0))
boxes_object("Splashback", tl, [M["tile"]], "DRESS")
te = []
for sx in (-1, 1):
    # from the fridge's side, where the worktop meets the end wall at every loop
    te.append(((sx * (FR_W / 2 + XB) / 2, Y1 + 0.03, (WT + UP_Z0) / 2), (XB - FR_W / 2, 0.06, UP_Z0 - WT), 0))
boxes_object("SplashbackEnd", te, [M["tile_end"]], "DRESS")
sk = [((sx * (XB - 0.1), (a[1] + b[0]) / 2, 0.6), (0.2, a[1] - b[0], 1.2), 0)   # bare wall in a run's gap
      for sx, runs in ((1, HOB_RUNS), (-1, SINK_RUNS[1:])) for a, b in zip(runs, runs[1:])]
boxes_object("Skirting", sk, [M["skirting"]], "DRESS")

# ---------------------------------------------------------------- worktops and base units


def worktop(name, sx, ya, yb, cut=None, marker=False):
    """One worktop run, ridden, from y = ya down to yb on the side sx (+1 hob, -1 sink).

    A back slab (|x| XS..XB) that never erodes, so it can hold a marker's respawn, and a
    front strip along the chasm (|x| XF..XS) that erodes on x toward the slab: its front edge
    runs from XF at loop 0 to XP at plateau. Past the fridge's front the strip only reaches the
    fridge's side, and does not erode. cut = the sink's (y, x) ranges: the slab opens round it,
    the strip runs on."""
    z = WT - WT_TH / 2
    to_wall, to_chasm = ("+x", "-x") if sx > 0 else ("-x", "+x")
    slab = {"role": "marker_floor" if marker else "floor", "flush": (to_chasm,)}

    def piece(ax0, ax1, y0, y1, opts):   # |x| from ax0 to ax1, y from y0 down to y1
        return ((sx * (ax0 + ax1) / 2, (y0 + y1) / 2, z), (ax1 - ax0, y0 - y1, WT_TH), 0, opts)

    def strip(*flush):   # pinned at the seam (anchor sx = its wall-side edge), front at XP at plateau
        return {"role": "floor", "erode": (0, XS - XP, sx), "flush": (to_wall, *flush)}

    # beside the fridge the strip never erodes: it fills fridge side to slab, so no slot opens there
    fill = {"role": "floor", "flush": (to_wall, "+y")}

    if cut is None:
        bx = [piece(XS, XB, ya, yb, slab)]
    else:
        (cy0, cy1), (cx0, cx1) = cut
        bx = [piece(XS, XB, ya, cy0, slab), piece(XS, XB, cy1, yb, slab),
              piece(-cx0, XB, cy0, cy1, dict(slab, flush=())),   # behind the sink
              piece(XS, -cx1, cy0, cy1, slab)]                   # in front of it
    if yb < FR_Y:
        bx += [piece(XF, XS, ya, FR_Y, strip("-y")), piece(FR_W / 2, XS, FR_Y, yb, fill)]
    else:
        bx.append(piece(XF, XS, ya, yb, strip()))
    ob = boxes_object(name, bx, [M["worktop"]], "PLAY", bevel=0.06)
    ob["solid"] = 1.0
    return ob


def base_units(name, sx, ya, yb, skip=()):
    """Carcass, plinth, doors and drawers facing the chasm, a bar handle on each front. Every
    door's handle sits on the same side, so no pair of them reads as eyes."""
    L_ = ya - yb
    bx = [((sx * (XD + 0.2 + XB) / 2, (ya + yb) / 2, (1.5 + WT - WT_TH) / 2), (XB - XD - 0.2, L_, WT - WT_TH - 1.5), 1),
          ((sx * (XD + 0.6 + XB) / 2, (ya + yb) / 2, 0.75), (XB - XD - 0.6, L_, 1.5), 2)]
    for y in (ya, yb):  # end panels where the run stops over the void
        bx.append(((sx * (XD + XB) / 2, y - 0.1 if y == ya else y + 0.1, (WT - WT_TH) / 2),
                   (XB - XD, 0.2, WT - WT_TH), 0))
    n = max(1, round(L_ / 5.0))
    w = L_ / n
    for k in range(n):
        y0 = ya - k * w
        cy = y0 - w / 2
        if any(s0 >= cy >= s1 for s0, s1 in skip):
            continue
        bx.append(((sx * (XD + 0.1), cy, 7.95), (0.2, w - 0.08, 1.1), 0))
        bx.append(((sx * (XD + 0.1), cy, 4.5), (0.2, w - 0.08, 5.9), 0))
        bx.append(((sx * (XD - 0.12), cy, 8.0), (0.12, 1.6, 0.12), 3))
        bx.append(((sx * (XD - 0.05), cy - 0.75, 8.0), (0.1, 0.08, 0.08), 3))
        bx.append(((sx * (XD - 0.05), cy + 0.75, 8.0), (0.1, 0.08, 0.08), 3))
        bx.append(((sx * (XD - 0.12), y0 - 0.55, 6.4), (0.12, 0.12, 1.6), 3))
        bx.append(((sx * (XD - 0.05), y0 - 0.55, 5.65), (0.1, 0.08, 0.08), 3))
        bx.append(((sx * (XD - 0.05), y0 - 0.55, 7.15), (0.1, 0.08, 0.08), 3))
    return boxes_object(name, bx, [M["unit"], M["carcass"], M["plinth"], M["handle"]], "DRESS", bevel=0.03)


for i, (ya, yb) in enumerate(SINK_RUNS):   # MARKER_1 stands on L1, MARKER_0 and MARKER_2 on R0 and R1
    worktop(f"WorktopL{i}", -1, ya, yb, cut=(SINK, SINK_X) if i == 1 else None, marker=i == 1)
    base_units(f"BaseL{i}", -1, ya, yb)
for i, (ya, yb) in enumerate(HOB_RUNS):
    worktop(f"WorktopR{i}", 1, ya, yb, marker=i < 2)
    base_units(f"BaseR{i}", 1, ya, yb, skip=(HOB,) if i == 0 else ())

# ---------------------------------------------------------------- wall cupboards (ride walls)


def uppers(name, sx, ya, yb):
    """A bank of wall cupboards. Their faces are ride walls (solid); one knob per door at its
    lower near corner, all on the same side."""
    L_ = ya - yb
    bx = [((sx * (XU + XB) / 2, (ya + yb) / 2, (UP_Z0 + UP_Z1) / 2), (XB - XU, L_, UP_Z1 - UP_Z0), 1)]
    n = max(1, round(L_ / 5.0))
    w = L_ / n
    knobs = []
    for k in range(n):
        y0 = ya - k * w
        bx.append(((sx * (XU - 0.12), y0 - w / 2, (UP_Z0 + UP_Z1) / 2), (0.24, w - 0.08, UP_Z1 - UP_Z0 - 0.08), 0))
        knobs.append(((sx * (XU - 0.38), y0 - 0.6, UP_Z0 + 0.7), (0.3, 0.32, 0.32), 0))
    ob = boxes_object(name, bx, [M["unit"], M["carcass"]], "PLAY", bevel=0.03, role="ride_wall")
    ob["solid"] = 1.0
    kn = boxes_object(name + "_knobs", knobs, [M["handle"]], "DRESS", bevel=0.14)
    return ob, kn


for i, (ya, yb) in enumerate(SINK_UPPERS):
    uppers(f"UpperL{i}", -1, ya, yb)
for i, (ya, yb) in enumerate(HOB_UPPERS):
    uppers(f"UpperR{i}", 1, ya, yb)

# ---------------------------------------------------------------- the hob, the oven, the hood

hy0, hy1 = HOB
hc = (hy0 + hy1) / 2
box("HobPlate", (6.7, hc, WT + 0.04), (4.4, hy0 - hy1 - 0.4, 0.08), M["steel"], "DRESS", 0.02)
grate = []
for gy in (hc + 1.4, hc - 1.4):
    for bx_, by_ in ((5.7, gy), (7.7, gy)):
        cyl(f"Burner{bx_}_{gy}", (bx_, by_, WT + 0.15), 0.62, 0.14, M["brass"], "DRESS")
        cyl(f"BurnerCap{bx_}_{gy}", (bx_, by_, WT + 0.3), 0.42, 0.18, M["iron"], "DRESS")
        for a in range(4):  # cast-iron fingers over each burner
            ang = math.radians(45 + 90 * a)
            grate.append(((bx_ + math.cos(ang) * 0.85, by_ + math.sin(ang) * 0.85, WT + 0.5),
                          (0.16 + abs(math.cos(ang)) * 0.6, 0.16 + abs(math.sin(ang)) * 0.6, 0.12), 0))
    grate.append(((6.7, gy + 1.3, WT + 0.35), (4.2, 0.16, 0.5), 0))
    grate.append(((6.7, gy - 1.3, WT + 0.35), (4.2, 0.16, 0.5), 0))
    for gx in (4.7, 6.7, 8.7):
        grate.append(((gx, gy, WT + 0.35), (0.16, 2.76, 0.5), 0))
boxes_object("HobGrates", grate, [M["iron"]], "DRESS", bevel=0.03)

# the oven under the hob: a row of knobs either side of the clock, a wide dark window
ov = [((XD + 0.1, hc, 7.95), (0.2, hy0 - hy1 - 0.08, 1.1), 1),          # fascia
      ((XD + 0.1, hc, 4.5), (0.2, hy0 - hy1 - 0.08, 5.9), 0),           # door
      ((XD - 0.02, hc, 4.4), (0.06, hy0 - hy1 - 1.6, 2.6), 2),          # window
      ((XD - 0.35, hc, 6.85), (0.14, hy0 - hy1 - 1.2, 0.16), 0),        # handle bar
      ((XD - 0.15, hc + 2.2, 6.85), (0.3, 0.12, 0.12), 0),
      ((XD - 0.15, hc - 2.2, 6.85), (0.3, 0.12, 0.12), 0),
      ((XD + 0.1, hc, 0.75), (0.2, hy0 - hy1 - 0.08, 1.5), 3)]          # plinth drawer
for k, dy in enumerate((2.3, 1.6, 0.95, -0.95, -1.6, -2.3)):
    ov.append(((XD - 0.12, hc + dy, 7.95), (0.25, 0.42, 0.42), 0))
boxes_object("Oven", ov, [M["brushed"], M["fascia"], M["dark_glass"], M["plinth"]], "DRESS", bevel=0.02)
seg7("OvenClock", "23:47", XD - 0.02, hc + 0.55, 7.78, 0.36, M["led"], "DRESS")

# the tea towel folded over the oven handle, hanging into the chasm
tw = [((XD - 0.45, hc + 0.9, 5.5), (0.06, 2.4, 2.8), 0),
      ((XD - 0.28, hc + 0.9, 6.0), (0.06, 2.4, 1.8), 0),
      ((XD - 0.36, hc + 0.9, 6.95), (0.22, 2.4, 0.14), 0)]
towel = boxes_object("TeaTowel", tw, [M["towel"]], "DRESS", bevel=0.05)
towel["gone_at"] = 4

# chimney hood: visor, canopy, chimney; one amber bulb near the front edge
box("HoodVisor", (7.3, (HOOD[0] + HOOD[1]) / 2, 15.85), (4.6, 9.0, 0.7), M["steel"], "DRESS", 0.03)
hull("HoodCanopy", [(x, y, z) for x, y, z in
                    [(5.0, -11.5, 16.2), (9.6, -11.5, 16.2), (5.0, -20.5, 16.2), (9.6, -20.5, 16.2),
                     (7.4, -14.6, 18.2), (9.6, -14.6, 18.2), (7.4, -17.4, 18.2), (9.6, -17.4, 18.2)]],
     M["steel"], "DRESS")
box("HoodChimney", (8.5, -16.0, (18.2 + CEIL) / 2), (2.2, 2.8, CEIL - 18.2), M["steel"], "DRESS")
filt = [((7.4, y, 15.49), (3.8, 2.6, 0.02), 0) for y in (-12.6, -16.0, -19.4)]
boxes_object("HoodFilters", filt, [M["filter"]], "DRESS")
bulb = cyl("HoodBulb", (5.75, -16.0, 15.46), 0.32, 0.06, M["bulb"], "DRESS")
bulb["light_r"] = 0.4   # dies at loop 3, after the magnets and the card's writing
btn = [((4.98, -17.6 - k * 0.55, 15.85), (0.06, 0.32, 0.18), 0) for k in range(5)]
boxes_object("HoodButtons", btn, [M["brushed"]], "DRESS")
box("HoodLED", (4.94, -16.95, 15.85), (0.04, 0.1, 0.1), M["led_amber"], "DRESS")

# ---------------------------------------------------------------- the sink, the window, the tap

sy0, sy1 = SINK
sxa, sxb = SINK_X
sc_y, sc_x = (sy0 + sy1) / 2, (sxa + sxb) / 2
basin = [((sc_x, sc_y, WT - 2.0), (sxb - sxa, sy0 - sy1, 0.1), 0),
         ((sxa + 0.05, sc_y, WT - 1.0), (0.1, sy0 - sy1, 2.0), 0),
         ((sxb - 0.05, sc_y, WT - 1.0), (0.1, sy0 - sy1, 2.0), 0),
         ((sc_x, sy0 - 0.05, WT - 1.0), (sxb - sxa, 0.1, 2.0), 0),
         ((sc_x, sy1 + 0.05, WT - 1.0), (sxb - sxa, 0.1, 2.0), 0)]
for (ya, yb, xa, xb) in ((sy0 + 0.3, sy0, sxa - 0.3, sxb + 0.3), (sy1, sy1 - 0.3, sxa - 0.3, sxb + 0.3),
                         (sy0, sy1, sxa - 0.3, sxa), (sy0, sy1, sxb, sxb + 0.3)):
    basin.append((((xa + xb) / 2, (ya + yb) / 2, WT + 0.03), (xb - xa, ya - yb, 0.06), 0))
boxes_object("Sink", basin, [M["steel"]], "DRESS", bevel=0.02)
cyl("Plughole", (sc_x - 0.2, sc_y, WT - 1.94), 0.5, 0.04, M["iron"], "DRESS")
cyl("PlugRing", (sc_x - 0.2, sc_y, WT - 1.93), 0.62, 0.03, M["steel"], "DRESS")
# the swan-neck tap at the back, running into a sink that never fills
cyl("TapBase", (-9.2, sc_y, WT + 0.2), 0.38, 0.4, M["steel"], "DRESS")
tube("TapNeck", [(-9.2, sc_y, WT), (-9.2, sc_y, 12.6), (-9.0, sc_y, 13.4), (-8.1, sc_y, 13.5),
                 (-7.1, sc_y, 13.0), (-6.85, sc_y, 12.2)], 0.2, M["steel"], "DRESS")
box("TapLever", (-9.2, sc_y + 0.55, 11.6), (0.18, 0.9, 0.14), M["steel"], "DRESS", 0.05)
tube("TapStream", [(-6.85, sc_y, 12.05), (-6.85, sc_y, 10.0), (-6.86, sc_y, WT - 1.95)], 0.09, M["water"], "DRESS")
cyl("TapSplash", (-6.85, sc_y, WT - 1.93), 0.35, 0.05, M["water"], "DRESS", r2=0.12)
# window: one pane under a fanlight (never two dark panes over a sink)
wy0, wy1 = WINDOW
wf = [((-XB + 0.05, wy0 - 0.3, 15.75), (0.5, 0.6, 9.5), 0), ((-XB + 0.05, wy1 + 0.3, 15.75), (0.5, 0.6, 9.5), 0),
      ((-XB + 0.05, (wy0 + wy1) / 2, 20.2), (0.5, wy0 - wy1, 0.6), 0),
      ((-XB + 0.05, (wy0 + wy1) / 2, 18.0), (0.5, wy0 - wy1, 0.4), 0),
      ((-XB + 0.05, (wy0 + wy1) / 2, 11.3), (0.5, wy0 - wy1, 0.6), 0),
      ((-XB + 0.35, (wy0 + wy1) / 2, 10.95), (0.9, wy0 - wy1 + 0.6, 0.2), 0)]   # sill
boxes_object("WindowFrame", wf, [M["upvc"]], "DRESS", bevel=0.04)
box("WindowGlass", (-XB - 0.1, (wy0 + wy1) / 2, 15.75), (0.03, wy0 - wy1, 9.5), M["pane"], "DRESS")
box("NightOutside", (-XB - 6.0, (wy0 + wy1) / 2, 15.0), (0.2, 30.0, 20.0), M["night"], "DRESS")
# washing-up liquid, a folded dishcloth on the rim
cyl("WashingUp", (-9.05, sc_y - 2.2, WT + 1.15), 0.32, 2.3, M["soap"], "DRESS")
cyl("WashingUpCap", (-9.05, sc_y - 2.2, WT + 2.45), 0.16, 0.3, M["white"], "DRESS")
cloth = box("Dishcloth", (-4.15, sc_y + 1.5, WT + 0.12), (0.8, 2.2, 0.24), M["cloth"], "DRESS", 0.08)
cloth["gone_at"] = 3

# ---------------------------------------------------------------- the near run: kettle, sockets, toaster


def socket(name, y, z, plugs):
    """A UK double socket with a plug in each half, so no bare three-pin face shows."""
    bxs = [((-XB + 0.08, y, z), (0.1, 1.46, 0.86), 0)]
    for k, dy in enumerate((0.36, -0.36)):
        bxs.append(((-XB + 0.14, y + dy + 0.12, z + 0.26), (0.04, 0.18, 0.24), 0))   # switch
        if k < plugs:
            bxs.append(((-XB + 0.35, y + dy - 0.05, z - 0.08), (0.45, 0.5, 0.55), 0))
    return boxes_object(name, bxs, [M["white"]], "DRESS", bevel=0.03)


socket("SocketKettle", -0.6, 10.75, 2)
kx, ky = -7.9, -2.8
cyl("KettleBase", (kx, ky, WT + 0.08), 1.1, 0.16, M["black"], "DRESS")
lathe("Kettle", [(0, 0), (1.0, 0), (1.03, 0.2), (0.98, 1.6), (0.82, 2.05), (0.5, 2.2), (0, 2.22)],
      [M["steel"]], lambda i: 0, "DRESS").location = (kx, ky, WT + 0.16)
cyl("KettleKnob", (kx, ky, WT + 2.5), 0.22, 0.25, M["black"], "DRESS")
cyl("KettleSpout", (kx + 1.15, ky, WT + 1.5), 0.32, 1.1, M["steel"], "DRESS", rot=(0, math.radians(50), 0), r2=0.16)
hb = [((kx - 1.25, ky, WT + 1.2), (0.25, 0.4, 1.6), 0), ((kx - 1.0, ky, WT + 2.0), (0.6, 0.4, 0.25), 0),
      ((kx - 1.0, ky, WT + 0.45), (0.6, 0.4, 0.25), 0)]
boxes_object("KettleHandle", hb, [M["black"]], "DRESS", bevel=0.1)
tube("KettleCord", [(kx - 0.6, ky, WT + 0.08), (-9.2, ky + 0.5, WT + 0.1), (-9.4, -0.4, WT + 0.25),
                    (-9.35, -0.45, 10.4)], 0.07, M["white"], "DRESS")
tb = box("Toaster", (-8.0, -13.0, WT + 1.05), (1.9, 3.2, 2.1), M["toaster"], "DRESS", 0.35)
tb["gone_at"] = 4
box("ToasterLever", (-8.0, -14.7, WT + 1.5), (0.4, 0.3, 0.25), M["black"], "DRESS", 0.08)
tube("ToasterCord", [(-8.6, -11.5, WT + 0.1), (-9.4, -6.0, WT + 0.12), (-9.4, -1.2, WT + 0.25),
                     (-9.35, -0.95, 10.4)], 0.07, M["white"], "DRESS")
board = box("ChoppingBoard", (-5.0, -7.5, WT + 0.18), (2.9, 4.1, 0.35), M["wood"], "DRESS", 0.12)
board.rotation_euler = (0, 0, math.radians(7))
board["gone_at"] = 4

# ---------------------------------------------------------------- the hob run: books, bread bin, microwave

titles = ["Delia", "Easy Suppers", "Jamie", "Baking"]
bk = []
for k, (th, tw_) in enumerate(((2.5, 0.45), (2.2, 0.55), (2.7, 0.38), (2.35, 0.5))):
    by = -2.0 - k * 0.6
    ob = box(f"Book{k}", (9.0, by, WT + th / 2), (1.6, tw_, th), M["book"][k], "DRESS", 0.03)
    ob["gone_at"] = 4
    t = text(f"BookTitle{k}", titles[k], (8.18, by, WT + th / 2), (math.radians(90), math.radians(90), math.radians(-90)),
             0.22, M["book_ink"], "DRESS")
    t["gone_at"] = 2
# the climb: bread bin (1.8 m), microwave (3 m, pulled forward of the cupboards), cupboard faces
bin_ = box("BreadBin", (7.9, -36.3, WT + 0.9), (3.0, 4.0, 1.8), M["breadbin"], "PLAY", 0.45, role="prop")
bin_["solid"] = 1.0
box("BreadBinLid", (6.42, -36.3, WT + 1.25), (0.08, 2.6, 0.12), M["brushed"], "DRESS", 0.03)
# its front stays out of the line's sight of the rack; the door and panel are dressing on the body
mw = box("Microwave", (7.1, -41.6, WT + 1.5), (4.2, 5.5, 3.0), M["black"], "PLAY", 0.08, role="prop")
mw["solid"] = 1.0
mf = [((4.98, -40.95, WT + 1.5), (0.04, 3.6, 2.2), 0), ((4.98, -43.75, WT + 1.5), (0.04, 0.9, 2.5), 1)]
boxes_object("MicrowaveFront", mf, [M["dark_glass"], M["brushed"]], "DRESS", bevel=0.08)

# ---------------------------------------------------------------- the hall doorway (sink side)

dy0, dy1 = DOORWAY
arch = [((-XB + 0.1, dy0 + 0.35, 10.6), (0.25, 0.7, 21.2), 0), ((-XB + 0.1, dy1 - 0.35, 10.6), (0.25, 0.7, 21.2), 0),
        ((-XB + 0.1, (dy0 + dy1) / 2, 20.85), (0.25, dy0 - dy1 + 1.4, 0.7), 0)]
boxes_object("Architrave", arch, [M["skirting"]], "DRESS", bevel=0.04)
hall = [((-20.0, (dy0 + dy1) / 2, -0.1), (20.0, 16.0, 0.2), 0), ((-30.2, (dy0 + dy1) / 2, CEIL / 2), (0.4, 16.0, CEIL), 0),
        ((-20.0, dy0 + 4.2, CEIL / 2), (20.0, 0.4, CEIL), 0), ((-20.0, dy1 - 4.2, CEIL / 2), (20.0, 0.4, CEIL), 0),
        ((-20.0, (dy0 + dy1) / 2, CEIL + 0.15), (20.0, 16.0, 0.3), 0)]
boxes_object("Hall", hall, [M["hall"]], "DRESS")
hd = pivot("HallDoorPivot", (-XB - 0.4, dy0, 0), -72.0, "DRESS")
leaf = [((-0.22, -3.5, 10.2), (0.45, 7.0, 20.4), 0)]
for pz in (5.0, 14.8):
    for py in (-1.8, -5.2):
        leaf.append(((0.03, py, pz), (0.1, 2.6, 8.0), 0))
leaf.append(((0.15, -6.3, 10.0), (0.3, 0.9, 0.18), 1))
child(boxes_object("HallDoor", leaf, [M["door_paint"], M["brushed"]], "DRESS", bevel=0.04), hd)
box("LightSwitch", (-XB + 0.06, dy0 + 1.6, 12.0), (0.1, 0.86, 0.86), M["white"], "DRESS", 0.03)
box("LightRocker", (-XB + 0.14, dy0 + 1.6, 12.0), (0.06, 0.24, 0.36), M["white"], "DRESS", 0.02)
box("GapSocket", (XB - 0.06, -51.0, 3.0), (0.1, 1.46, 0.86), M["white"], "DRESS", 0.03)
# the calendar on the bare wall by the first crossing: October, her birthday ringed in red
cy_ = (HOB_RUNS[0][1] + HOB_RUNS[1][0]) / 2
box("CalendarGrid", (XB - 0.04, cy_, 8.9), (0.05, 3.0, 3.0), M["list"], "DRESS")
box("CalendarPhoto", (XB - 0.04, cy_, 11.9), (0.05, 3.0, 3.0), M["cal_photo"], "DRESS")
box("CalendarNail", (XB - 0.1, cy_, 13.5), (0.15, 0.12, 0.12), M["brushed"], "DRESS")
grid = [((XB - 0.07, cy_, 7.6 + r * 0.42), (0.01, 2.6, 0.03), 0) for r in range(6)]
grid += [((XB - 0.07, cy_ - 1.3 + c * 2.6 / 7, 8.65), (0.01, 0.03, 2.1), 0) for c in range(8)]
g = boxes_object("CalendarLines", grid, [M["pencil"]], "DRESS")
g["gone_at"] = 2
t = text("CalendarMonth", "OCTOBER", (XB - 0.07, cy_, 10.0), FACE_X, 0.3, M["pencil"], "DRESS")
t["gone_at"] = 2
for k, (r, m, dx) in enumerate(((0.21, M["red_pen"], 0.075), (0.15, M["list"], 0.08))):  # a red pen ring
    ring = cyl(f"CalendarRing{k}", (XB - dx, cy_ - 0.3, 8.42), r, 0.01, m, "DRESS", rot=(0, math.radians(90), 0))
    ring["gone_at"] = 2

# ---------------------------------------------------------------- the fridge (landmark, dominant light)

fb = [((0, -70.15, 9.7), (FR_W, 0.5, 17.8), 0),
      ((-2.75, -67.25, 9.7), (0.5, 5.3, 17.8), 0), ((2.75, -67.25, 9.7), (0.5, 5.3, 17.8), 0),
      ((0, -67.25, 18.3), (5.0, 5.3, 0.6), 0), ((0, -67.25, 7.0), (5.0, 5.3, 0.8), 0),
      ((0, -67.25, 1.1), (5.0, 5.3, 0.6), 0),
      ((0, FR_Y - 0.3, 4.0), (FR_W, 0.6, 6.1), 0),                       # freezer door, shut
      ((-2.55, FR_Y + 0.12, 6.3), (0.5, 0.25, 0.9), 0),                  # its handle lip
      ((0, FR_Y - 0.65, 0.45), (5.6, 0.2, 0.7), 1)]                      # kick grille
fridge = boxes_object("Fridge", fb, [M["fridge"], M["grille"]], "PLAY", bevel=0.12, role="prop")
fridge["solid"] = 1.0
inner = []
for z in (10.3, 12.9, 15.5):
    inner.append(((0, -67.3, z), (5.0, 4.8, 0.1), 0))
boxes_object("FridgeShelves", inner, [M["shelf"]], "DRESS")
trims = [((0, -64.95, z), (5.0, 0.12, 0.25), 0) for z in (10.3, 12.9, 15.5)]
trims += [((-1.25, -67.0, 8.7), (2.3, 4.6, 2.2), 1), ((1.25, -67.0, 8.7), (2.3, 4.6, 2.2), 1)]
boxes_object("FridgeTrims", trims, [M["liner"], M["crisper"]], "DRESS", bevel=0.05)
glow = box("FridgeGlow", (0, -69.85, 12.9), (4.8, 0.06, 10.4), M["fridge_glow"], "DRESS")
glow["solid"] = 1.0
# what was put away: the milk, a foil-covered plate (dinner), a jar, a carton
cyl("Milk", (1.5, -66.0, 11.35), 0.48, 2.0, M["milk"], "DRESS")
cyl("MilkCap", (1.5, -66.0, 12.45), 0.25, 0.2, MAGNET_M[3], "DRESS")
cyl("Plate", (-0.9, -66.8, 13.05), 1.4, 0.12, M["white"], "DRESS")
lathe("PlateFoil", [(0, 0), (1.35, 0), (1.2, 0.35), (0.6, 0.6), (0, 0.65)], [M["foil"]], lambda i: 0,
      "DRESS").location = (-0.9, -66.8, 13.1)
cyl("Jar", (-1.6, -66.0, 10.85), 0.45, 1.0, M["jar"], "DRESS")
cyl("JarLid", (-1.6, -66.0, 11.4), 0.47, 0.15, M["brushed"], "DRESS")
box("Butter", (0.6, -67.5, 15.9), (1.6, 1.0, 0.7), MAGNET_M[1], "DRESS", 0.08)

# the door, ajar: pivot on its hinge, everything on it parented so it swings as one
# door-local frame: x runs from the hinge (0) to the free edge (FR_W), the outer face is y = 0
door = pivot("FridgeDoor", (-FR_W / 2, FR_Y, 0), DOOR_OPEN, "PLAY")
dl = [((FR_W / 2, -0.3, 12.9), (FR_W, 0.6, 11.4), 0),                  # leaf
      ((FR_W / 2, -0.66, 12.9), (FR_W - 0.3, 0.12, 11.0), 1),          # gasket
      ((FR_W - 0.45, 0.12, 9.6), (0.5, 0.25, 0.9), 0)]                  # handle lip at the free edge
for z in (9.4, 11.9, 14.4):                                             # door bins
    dl.append(((FR_W / 2, -1.2, z), (FR_W - 0.9, 0.9, 0.12), 2))
    dl.append(((FR_W / 2, -1.62, z + 0.35), (FR_W - 0.9, 0.06, 0.7), 2))
leaf = child(boxes_object("FridgeDoorLeaf", dl, [M["fridge"], M["gasket"], M["liner"]], "PLAY", bevel=0.1), door)
# ajar, the leaf is no axis-aligned box, so its colliders are a staircase of boxes along it: each
# step bounds one eighth of the leaf's width (its 0.6 m thickness, its full height); the mesh is
# exported as drawn
DOOR_STEPS = 8
ca, sa = math.cos(math.radians(DOOR_OPEN)), math.sin(math.radians(DOOR_OPEN))
steps = []
for k in range(DOOR_STEPS):
    corners = [(-FR_W / 2 + u * ca - v * sa, FR_Y + u * sa + v * ca)
               for u in (k * FR_W / DOOR_STEPS, (k + 1) * FR_W / DOOR_STEPS) for v in (-0.6, 0.0)]
    xs, ys = [p[0] for p in corners], [p[1] for p in corners]
    steps.append((((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 12.9), (max(xs) - min(xs), max(ys) - min(ys), 11.4)))
explicit_colliders(leaf, steps, "prop")
leaf["solid"] = 1.0
child(cyl("DoorBottle", (4.2, -1.2, 10.4), 0.4, 1.9, M["juice"], "DRESS"), door)
child(cyl("DoorBottle2", (2.0, -1.2, 12.9), 0.35, 1.8, M["soap"], "DRESS"), door)

# the birthday card, on the door toward its free edge, over the rack
CARD = (4.2, 12.9)     # door-local x, z: toward the free edge, over the rack
cx_, cz_ = CARD
child(box("Card", (cx_, 0.03, cz_), (1.5, 0.05, 2.1), M["card"], "MEMORY", 0.01), door)
cake = [((cx_, 0.065, cz_ - 0.52), (0.9, 0.02, 0.42), 0), ((cx_, 0.068, cz_ - 0.28), (0.95, 0.02, 0.1), 1)]
for k in range(3):
    cake.append(((cx_ - 0.25 + k * 0.25, 0.068, cz_ - 0.1), (0.05, 0.02, 0.26), 1))
    cake.append(((cx_ - 0.25 + k * 0.25, 0.07, cz_ + 0.08), (0.07, 0.02, 0.1), 2))
child(boxes_object("CardCake", cake, [M["card_cake"], M["card_cream"], M["card_flame"]], "MEMORY"), door)
for k, (line, sz) in enumerate((("Happy", 0.3), ("Birthday", 0.3), ("Mum  x", 0.26))):
    ink_text(f"CardWord{k}", line, (cx_, 0.075, cz_ + 0.72 - k * 0.3), FACE_Y, sz, M["card_ink"], "MEMORY",
             gone_at=2, parent=door)
# magnets and a shopping list: the first things to go. Placed so no two sit side by side over
# the card (a pair of dots over a rectangle reads as a face)
mags = [(cx_, cz_ + 1.12, 0), (1.4, 15.95, 4), (0.9, 13.0, 3), (1.7, 10.4, 2), (5.2, 9.6, 1)]
for k, (mx, mz, mi) in enumerate(mags):
    mg = child(cyl(f"Magnet{k}", (mx, 0.12, mz), 0.24, 0.16, MAGNET_M[mi], "DRESS",
                   rot=(math.radians(90), 0, 0)), door)
    mg["gone_at"] = 1
lst = child(box("ShoppingList", (1.4, 0.03, 15.0), (1.1, 0.04, 1.7), M["list"], "DRESS"), door)
lst["gone_at"] = 1
for k, item in enumerate(("milk", "eggs", "candles", "cream")):
    ink_text(f"ListWord{k}", item, (1.4, 0.06, 15.55 - k * 0.32), FACE_Y, 0.2, M["pencil"], "DRESS",
             gone_at=1, parent=door)

# ---------------------------------------------------------------- memory: the rack and the burnt pan

RX, RY, RW, RL = 5.8, -60.6, 3.0, 5.2     # rack centre, depth (x), length (y): beside the fridge, in its
                                          # light; its towel ends just behind XP, never over the void
box("TowelUnderRack", (RX, RY + 0.4, WT + 0.03), (RW + 1.0, RL + 1.6, 0.06), M["towel_flat"], "MEMORY", 0.02)
box("RackTray", (RX, RY, WT + 0.21), (RW + 0.4, RL + 0.4, 0.3), M["tray"], "MEMORY", 0.1)
wires = []
z0 = WT + 0.6
for k in range(6):                                   # floor wires along y
    wires.append(((RX - RW / 2 + k * RW / 5, RY, z0), (0.07, RL, 0.07), 0))
for k in range(9):                                   # and across
    wires.append(((RX, RY - RL / 2 + k * RL / 8, z0), (RW, 0.07, 0.07), 0))
for sx_ in (-1, 1):
    for sy_ in (-1, 1):                              # corner posts
        wires.append(((RX + sx_ * RW / 2, RY + sy_ * RL / 2, z0 + 0.9), (0.08, 0.08, 1.8), 0))
    wires.append(((RX + sx_ * RW / 2, RY, z0 + 1.8), (0.08, RL, 0.08), 0))   # top rails
for sy_ in (-1, 1):
    wires.append(((RX, RY + sy_ * RL / 2, z0 + 1.8), (RW, 0.08, 0.08), 0))
for k in range(10):                                  # plate tines: a back row, taller
    ty = RY - RL / 2 + 0.3 + k * (RL - 0.6) / 9
    wires.append(((RX + 0.7, ty, z0 + 1.1), (0.06, 0.06, 2.2), 0))
    wires.append(((RX - 0.5, ty, z0 + 0.45), (0.06, 0.06, 0.9), 0))
boxes_object("Rack", wires, [M["rack"]], "MEMORY", bevel=0.02)
# the pan: scrubbed, upside down, propped in the tines with its base to the room
pan = lathe("Pan", [(0, 0), (1.10, 0), (1.18, 0.02), (1.22, 0.07), (1.40, 0.50), (1.44, 0.55), (1.40, 0.57),
                    (1.34, 0.55), (1.17, 0.12), (1.08, 0.08), (0, 0.08)],
            [M["pan_base"], M["pan_out"], M["pan_in"]], lambda i: 0 if i == 0 else (1 if i <= 5 else 2), "MEMORY")
# it stands in a slot like a plate, base up the galley (turned a little to the chasm), leaning
# back; the handle out over the chasm. Columns: local x, y (handle), z (-z is the base).
LEAN = math.radians(20)
pan.matrix_world = mathutils.Matrix.Rotation(math.radians(15), 4, "Z") @ mathutils.Matrix((
    (0, -1, 0, 0),
    (-math.sin(LEAN), 0, -math.cos(LEAN), 0),
    (math.cos(LEAN), 0, -math.sin(LEAN), 0),
    (0, 0, 0, 1)))
pan.location = (RX, RY + 1.4, z0 + 1.42)
hdl = [((0, 1.4 + 1.05, 0.45), (0.28, 2.1, 0.18), 0), ((0, 1.38, 0.32), (0.22, 0.4, 0.22), 1)]
child(boxes_object("PanHandle", hdl, [M["pan_handle"], M["pan_base"]], "MEMORY", bevel=0.07), pan)
for k, (dx, dy, r) in enumerate(((0.9, 2.1, 0.16), (-0.6, 2.4, 0.11), (1.3, 1.2, 0.09), (-1.1, 3.0, 0.13))):
    lathe(f"Drip{k}", [(0, 0), (r, 0), (0.9 * r, 0.35 * r), (0.55 * r, 0.62 * r), (0, 0.7 * r)], [M["water"]],
          lambda i: 0, "MEMORY", segs=16).location = (RX + dx, RY + dy, WT + 0.36)

# ---------------------------------------------------------------- ceiling: the light that's off, the smoke

lathe("CeilingShade", [(0, 0), (2.2, 0), (2.0, -0.6), (1.2, -0.9), (0, -0.95)], [M["shade"]], lambda i: 0,
      "DRESS").location = (0, -30.0, CEIL)


def smoke_material():
    m = bpy.data.materials.new("Smoke")
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    for n in list(N):
        if n.type != "OUTPUT_MATERIAL":
            N.remove(n)
    out = next(n for n in N if n.type == "OUTPUT_MATERIAL")
    vol = N.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.62, 0.62, 0.64, 1)
    vol.inputs["Anisotropy"].default_value = 0.35
    geo = N.new("ShaderNodeNewGeometry")
    mp = N.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.3, 0.07, 0.55)
    L.new(geo.outputs["Position"], mp.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.6
    nz.inputs["Detail"].default_value = 6
    nz.inputs["Distortion"].default_value = 1.2
    L.new(mp.outputs[0], nz.inputs["Vector"])
    wisp = N.new("ShaderNodeMapRange")
    wisp.inputs["From Min"].default_value = 0.60
    wisp.inputs["From Max"].default_value = 0.70
    L.new(nz.outputs["Fac"], wisp.inputs["Value"])
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(geo.outputs["Position"], sep.inputs[0])
    band = N.new("ShaderNodeMapRange")       # it hangs just under the ceiling
    band.inputs["From Min"].default_value = 20.8
    band.inputs["From Max"].default_value = 23.2
    L.new(sep.outputs["Z"], band.inputs["Value"])
    drift = N.new("ShaderNodeMapRange")      # thick by the hood, thinning as it drifts to the fridge
    drift.inputs["From Min"].default_value = -80.0
    drift.inputs["From Max"].default_value = -14.0
    L.new(sep.outputs["Y"], drift.inputs["Value"])
    d = N.new("ShaderNodeMath")
    d.operation = "MULTIPLY"
    L.new(wisp.outputs["Result"], d.inputs[0])
    L.new(band.outputs["Result"], d.inputs[1])
    d2 = N.new("ShaderNodeMath")
    d2.operation = "MULTIPLY"
    L.new(d.outputs[0], d2.inputs[0])
    L.new(drift.outputs["Result"], d2.inputs[1])
    d3 = N.new("ShaderNodeMath")
    d3.operation = "MULTIPLY"
    d3.inputs[1].default_value = 0.18
    L.new(d2.outputs[0], d3.inputs[0])
    L.new(d3.outputs[0], vol.inputs["Density"])
    L.new(vol.outputs[0], out.inputs["Volume"])
    return m


box("Smoke", (2.5, -38.0, 22.35), (13.5, 60.0, 3.2), smoke_material(), "DRESS")

# ---------------------------------------------------------------- light

# the fridge: a lamp at the back of the cavity facing out; the ajar door lets it out toward the hob run
fl = area_lamp("FridgeLight", (0, -69.6, 12.9), (4.6, 10.0), 200000.0, COLD, panel=glow, keep=True)
fl.rotation_euler = (math.radians(90), 0, 0)
# the hood bulb: amber, dies at loop 3
hl = point_lamp("HoodLight", (5.75, -16.0, 15.2), 4500.0, AMBER, radius=0.35, keep=True)
hl["light_r"] = 0.4

# ---------------------------------------------------------------- the course (exporter: spawn, line, markers, door)


def course_point(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    coll("COURSE").objects.link(e)
    return e


# The racing line, on the surface ridden: markers stand on the worktops' fixed back slabs
# (|x| >= XS), so a respawn never lands on a strip that erodes.
LINE = [(5.0, 4.0, WT),            # spawn, MARKER_0
        (4.25, -2.0, WT), (4.25, -24.0, WT),         # past the hob, under the hood, to the overlap
        (-4.5, -24.0, WT), (-4.5, -27.5, WT),        # first crossing, straight across; MARKER_1
        (-4.5, -33.5, WT), (4.5, -33.5, WT),         # second crossing, before the sink; MARKER_2
        (6.8, -36.5, WT + 1.8), (5.4, -41.0, WT + 3.0),   # bread bin, microwave
        (5.3, -45.0, 15.5), (5.3, -57.5, 15.5),      # the cupboard faces over the wall-ride gap
        (4.25, -60.0, WT), (4.25, -63.0, WT)]        # land by the rack: the DOOR, then the fridge
cu = bpy.data.curves.new("LINE", "CURVE")
cu.dimensions = "3D"
sp = cu.splines.new("POLY")
sp.points.add(len(LINE) - 1)
for p, c in zip(sp.points, LINE):
    p.co = (*c, 1)
coll("COURSE").objects.link(bpy.data.objects.new("LINE", cu))
course_point("SPAWN", (5.0, 4.0, WT + 1.0))   # the player stands 1 m up, as respawns do
for k, i in enumerate((0, 4, 6)):
    course_point(f"MARKER_{k}", LINE[i])
course_point("DOOR", LINE[11])

# ---------------------------------------------------------------- cameras

EYE = WT + 1.6
camera("CamLine", (4.0, -20.0, EYE), -9.0, -1.0)    # past the hob, under the hood, before the first crossing
camera("CamFridge", (4.0, -44.9, EYE), -14.0, 22.0)  # end of the hob run, looking up into the light
camera("CamPan", (-4.2, -52.5, EYE), 20.0, 18.0)    # lingering: stepped off to the sink run's end, the pan under the card
camera("CamOven", (-5.0, -12.0, EYE), 75.0, -14.0)  # look-dev check of the clock across the chasm

apply_loop(0)
bpy.ops.wm.save_mainfile()
result = {"objects": len(bpy.data.objects), "lamps": sum(1 for o in bpy.data.objects if o.type == "LIGHT")}
