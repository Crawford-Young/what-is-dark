# CLAUDE.md — What Is Dark (repo-specific)

**Inherits:** `~/code/games/CLAUDE.md` (Godot domain rules) → `~/code/CLAUDE.md` (universal rules). This file states only what's specific to this repo — do not restate inherited rules here.

## Stack

- Godot 4.7.1
- GDScript
- GUT 9.7.1 (headless via `just test`)
- `just` task runner (`Justfile` at repo root)

## Layout

- Pure gameplay math lives in `RefCounted` scripts under `scripts/logic/` (`move_math.gd`, `wallrun_logic.gd`, `void_logic.gd`, `posture.gd`, `course_logic.gd`, plus lab-only `source_move.gd`, `yaw_drain.gd`) — full TDD, 100% coverage expectation.
- Node scripts (`scripts/player.gd`, `scripts/slice.gd`, `scripts/swallow_director.gd`, `scripts/void_wall.gd`, lab-only `scripts/momentum_player.gd`/`momentum_lab.gd`) wire input/scene-tree only and delegate all math to `scripts/logic/`.
- **Momentum lab** (`scenes/momentum_lab.tscn`, `just momentum-lab`): Source-movement evaluation env, verdict ADOPT 2026-07-24. Lab constants live ONLY in `scripts/logic/source_move.gd` (top-of-file); two deliberate CS2-parity breaks are user-locked there (`JUMP_SPEED` airtime parity, `AIR_CAP` 1.5 = 2× turn window). Main-game movement (`scripts/player.gd`) stays byte-untouched by lab work.
- **No coverage gate on node scripts/scenes.** Stated explicitly so this is never mistaken for an oversight — see games-domain CLAUDE.md, scene/node tests are smoke-level only.

## Test command

`just test` — run FOREGROUND, unpiped. Read the GUT summary block yourself (`Totals:` line — scripts/tests/asserts counts); never trust exit code alone.

## Gotchas

- New `class_name` scripts need one `godot --headless --editor --quit --path .` pass (same Godot exe the Justfile's `godot` variable points at) before headless GUT will see them (rebuilds Godot's global script-class cache). **No Justfile recipe currently wraps this** — `just import` runs `--headless --path . --import`, which reimports assets, not the same flag combination, and does not rebuild the class cache. Run the editor-quit pass manually (or open/quit via `just edit`) whenever a new `class_name` script is added.
- Run `just import` after any `.tscn` edit.

## Tuning-constant locations

- `scripts/player.gd` — `RUN_SPEED`, `JUMP_SPEED`, `GRAVITY`, `GROUND_ACCEL`/`AIR_ACCEL`, `GLANCE_TURN_SPEED`, `MOUSE_SENS`
- `scripts/logic/source_move.gd` — ALL momentum-lab constants (`RUN_SPEED`, `GRAVITY`, `JUMP_SPEED`, `FRICTION`, `STOP_SPEED`, `GROUND_ACCEL`, `AIR_ACCEL`, `AIR_CAP`, `OVERBOUNCE`); changing one requires deliberate test-expectation updates in `tests/unit/test_source_move.gd` — never loosen tolerances
- `scripts/logic/wallrun_logic.gd` — `MIN_FORWARD_SPEED`, `SINK_RATE`, `SINK_CAP`, `PUSH_AWAY_SPEED`, `PUSH_UP_SPEED`
- `scripts/logic/void_logic.gd` — `CREEP_SPEEDS` (per posture), `RESET_GAP`
- `scripts/swallow_director.gd` — `FADE_OUT`/`HOLD`/`FADE_IN` (swallow), `SETBACK_MARKERS`, `FALL_FADE_OUT`/`FALL_FADE_IN`/`FALL_VOID_GAP` (fall reset)
- `scripts/slice.gd` — `MARKER_PROGRESSES`, `FALL_Y`

## Design constraint

"Speedrunning feel" is a standing course-design constraint: fast, hard, contained. Wall-run routes are optional, never mandatory. No auto-vault unless the geometry is stair-like.
