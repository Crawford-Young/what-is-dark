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

# audit the course against its declared intent (course-law harness)
audit:
    "{{godot}}" --headless --path . -s scripts/dev/audit_cli.gd

# headless launch smoke — 600 frames, the gate CI runs
launch:
    "{{godot}}" --headless --path . --quit-after 600

# run the momentum lab (Source-movement evaluation)
momentum-lab:
    "{{godot}}" --path . scenes/momentum_lab.tscn

# run the surf lab (T3 hop-chain array)
surf-lab:
    "{{godot}}" --path . scenes/surf_lab.tscn

# run the gate lab (T7 sightline lanes)
gate-lab:
    "{{godot}}" --path . scenes/gate_lab.tscn

# run the obstacle lab (T11 speed-cost + hard-stop rows)
obstacle-lab:
    "{{godot}}" --path . scenes/obstacle_lab.tscn
