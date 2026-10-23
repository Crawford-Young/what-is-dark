"""Background entry: blender -b <place>.blend --python build/run.py -- <builder> [render <outdir> <cam>:<loop> ...]
or                  blender -b <place>.blend --python-exit-code 1 --python build/run.py -- <builder> export

<builder> is a builder name in this folder (kitchen, school) or a path to a .py builder. The
builder wipes the file, rebuilds the place and saves it; export (export.py) then writes the
place's glb and sidecar, and fails the run on any validation error."""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
ns = {"BUILD": os.path.dirname(os.path.abspath(__file__))}
src = args[0] if args[0].endswith(".py") else os.path.join(ns["BUILD"], args[0] + ".py")
exec(open(src).read(), ns)
print("BUILD_RESULT", ns.get("result"))
if len(args) > 1 and args[1] == "export":
    exec(open(os.path.join(ns["BUILD"], "export.py")).read(), ns)
    ns["export_main"]()
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
