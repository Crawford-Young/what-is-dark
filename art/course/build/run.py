"""Background entry: blender -b <place>.blend --python build/run.py -- <builder> [render <outdir> <cam>:<loop> ...]"""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
ns = {"BUILD": os.path.dirname(os.path.abspath(__file__))}
exec(open(os.path.join(ns["BUILD"], args[0] + ".py")).read(), ns)
print("BUILD_RESULT", ns.get("result"))
if len(args) > 2 and args[1] == "render":
    outdir = os.path.abspath(args[2])  # Blender drops relative render paths somewhere unhelpful
    if os.environ.get("WID_PREVIEW"):  # fast composition pass: half size, few samples
        bpy.context.scene.render.resolution_percentage = 50
        bpy.context.scene.cycles.samples = 48
    for spec in args[3:]:
        cam, loop = spec.split(":")
        path = os.path.join(outdir, f"{bpy.context.scene.name}_{cam}_L{loop}.png")
        ns["render"](path, cam, int(loop))
        print("RENDERED", path)
