godot := env_var_or_default("GODOT", "C:/Users/young/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe")

# run the game
run:
    "{{godot}}" --path .

# open the editor
edit:
    "{{godot}}" --path . -e

# run the wall-jump measurement lab
lab:
    "{{godot}}" --path . scenes/wall_lab.tscn

# headless unit tests
test:
    "{{godot}}" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json

# import assets headlessly (after adding new assets)
import:
    "{{godot}}" --headless --path . --import

# rebuild every Blender place from its builder, then export glb + sidecar JSON (issue #23)
export-course:
    sh art/course/build/export_all.sh

# audit a course against its declared intent (course-law harness); course names live in audit_cli.gd
audit course="slice":
    "{{godot}}" --headless --path . -s scripts/dev/audit_cli.gd -- {{course}}

# headless launch smoke — 600 frames, the gate CI runs
launch:
    "{{godot}}" --headless --path . --quit-after 600

# run the momentum lab (Source-movement evaluation)
momentum-lab:
    "{{godot}}" --path . scenes/momentum_lab.tscn
