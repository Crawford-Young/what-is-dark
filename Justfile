godot := env_var_or_default("GODOT", "C:/Users/young/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe")

# run the game
run:
    "{{godot}}" --path .

# open the editor
edit:
    "{{godot}}" --path . -e

# headless unit tests
test:
    "{{godot}}" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json

# import assets headlessly (after adding new assets)
import:
    "{{godot}}" --headless --path . --import
