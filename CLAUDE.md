# CLAUDE.md — What Is Dark (repo-specific)

**Inherits:** `~/code/games/CLAUDE.md` (Godot domain rules) → `~/code/CLAUDE.md` (universal rules). This file states only what's specific to this repo — do not restate inherited rules here.

## Stack

- Godot 4.7.1
- GDScript
- GUT 9.7.1 (headless via `just test`)
- `just` task runner (`Justfile` at repo root)

## Layout

- Pure gameplay math lives in `RefCounted` scripts under `scripts/logic/` (`move_math.gd`, `wallrun_logic.gd`, `void_logic.gd`, `posture.gd`, `course_logic.gd`) — full TDD, 100% coverage expectation.
- Node scripts (`scripts/player.gd`, `scripts/slice.gd`, `scripts/swallow_director.gd`, `scripts/void_wall.gd`) wire input/scene-tree only and delegate all math to `scripts/logic/`.
- **No coverage gate on node scripts/scenes.** Stated explicitly so this is never mistaken for an oversight — see games-domain CLAUDE.md, scene/node tests are smoke-level only.

## Test command

`just test` — run FOREGROUND, unpiped. Read the GUT summary block yourself (`Totals:` line — scripts/tests/asserts counts); never trust exit code alone.

## Gotchas

- New `class_name` scripts need one `godot --headless --editor --quit --path .` pass (same Godot exe the Justfile's `godot` variable points at) before headless GUT will see them (rebuilds Godot's global script-class cache). **No Justfile recipe currently wraps this** — `just import` runs `--headless --path . --import`, which reimports assets, not the same flag combination, and does not rebuild the class cache. Run the editor-quit pass manually (or open/quit via `just edit`) whenever a new `class_name` script is added.
- Run `just import` after any `.tscn` edit.

## Tuning-constant locations

- `scripts/player.gd` — `RUN_SPEED`, `JUMP_SPEED`, `GRAVITY`, `GROUND_ACCEL`/`AIR_ACCEL`, `GLANCE_TURN_SPEED`, `MOUSE_SENS`
- `scripts/logic/wallrun_logic.gd` — `MIN_FORWARD_SPEED`, `SINK_RATE`, `SINK_CAP`, `PUSH_AWAY_SPEED`, `PUSH_UP_SPEED`
- `scripts/logic/void_logic.gd` — `CREEP_SPEEDS` (per posture), `RESET_GAP`
- `scripts/swallow_director.gd` — `FADE_OUT`/`HOLD`/`FADE_IN` (swallow), `SETBACK_MARKERS`, `FALL_FADE_OUT`/`FALL_FADE_IN`/`FALL_VOID_GAP` (fall reset)
- `scripts/slice.gd` — `MARKER_PROGRESSES`, `FALL_Y`

## Design constraint

"Speedrunning feel" is a standing course-design constraint: fast, hard, contained. Wall-run routes are optional, never mandatory. No auto-vault unless the geometry is stair-like.
