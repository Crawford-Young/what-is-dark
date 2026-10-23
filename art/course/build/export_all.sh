#!/bin/sh
# Rebuild and export every place (#23): the pipeline self-test, then per place its builder (which
# saves the .blend) and export.py (glb + sidecar). Stops at the first failure with its rc.
# BLENDER overrides the Blender executable.
set -eu
BLENDER="${BLENDER:-C:/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
cd "$(dirname "$0")/../../.."
"$BLENDER" -b --factory-startup --python-exit-code 1 --python art/course/build/selftest.py
for place in 01-school:school 02-kitchen:kitchen; do
    blend="art/course/${place%%:*}.blend"
    builder="${place##*:}"
    echo "export-course: $builder -> $blend"
    "$BLENDER" -b "$blend" --python-exit-code 1 --python art/course/build/run.py -- "$builder" export
done
echo "export-course: ok"
