# CLAUDE.md — What Is Dark (repo-specific)

**Inherits:** `~/code/games/CLAUDE.md` (Godot domain rules) → `~/code/CLAUDE.md` (universal rules). This file states only what's specific to this repo — do not restate inherited rules here.

## Stack

- Godot 4.7.1
- GDScript
- GUT 9.7.1 (headless via `just test`)
- `just` task runner (`Justfile` at repo root)

## Layout

- Pure gameplay math lives in `RefCounted` scripts under `scripts/logic/` (`source_move.gd`, `yaw_drain.gd`, `wallrun_logic.gd`, `erosion_logic.gd`, `loop_logic.gd`, `void_logic.gd`, `posture.gd`, `course_logic.gd`) — full TDD, 100% coverage expectation. `source_move.gd` + `yaw_drain.gd` are the GAME's movement core (adopted from the momentum lab, phase 3a); `move_math.gd` is deleted.
- Node scripts (`scripts/player.gd`, `scripts/slice.gd`, `scripts/swallow_director.gd`, `scripts/void_wall.gd`, lab-only `scripts/momentum_player.gd`/`momentum_lab.gd`) wire input/scene-tree only and delegate all math to `scripts/logic/`.
- **Momentum lab** (`scenes/momentum_lab.tscn`, `just momentum-lab`): Source-movement evaluation env, verdict ADOPT 2026-07-24 — core adopted into `scripts/player.gd` in phase 3a; lab scene kept as a tuning sandbox. Movement constants live ONLY in `scripts/logic/source_move.gd` (top-of-file) and are game-wide; two deliberate CS2-parity breaks are user-locked there (`JUMP_SPEED` airtime parity, `AIR_CAP` 1.5 = 2× turn window).
- **Erodable-platform contract** (erosion v3, ruling #14): a `slice.tscn` `StaticBody3D` in group `erodable` with children `Col` (CollisionShape3D/BoxShape3D) + `Mesh` (MeshInstance3D/BoxMesh) and metadata `erode_axis` (0=x, 2=z), `erode_min` (plateau size on that axis, m), `erode_anchor` (−1 pin low edge / 0 centre / +1 pin high edge). `slice.gd:apply_erosion()` reads the group, duplicates the shared sub-resources per body, and recomputes size+origin from cached shipped geometry every loop (idempotent; loop 0 = shipped course exactly). NEVER tag kickers, surf ramps, ride walls, marker/respawn floors, feed platforms, or the door — issue #12 + the E2 max-erosion audit are the standing law.
- **Perforated floors** (erosion E4): `D6Tile*` (9), `G5Tile*` (8), `D1Tile*` (6) and the finger triples `G2Pad*`/`G8PadA*`/`G8PadB*` are ONE logical floor authored as a grid of ordinary `erodable` tiles — no new logic, no new metadata. Long floors split along z into lateral lanes and shrink on `erode_axis` 2 with anchors `+1 / 0 / −1` (outer tiles pin the floor's outer edge, so the junctions to the neighbouring platforms never move); the short wide pads split along x and shrink on `erode_axis` 0. **The binding invariant is loop-0 contiguity:** at `world_scale(0) = 0` the tiles must abut exactly and reproduce the shipped solid box, so a tile's `size` and `position` may only be changed as a pair that preserves the seam. Perforation REPLACES width-shrink on a surface — never stack both (issue #23). Never perforate the surfaces on the standing no-tag list below, and never open a hole under a prop (beds, dressers, stands, gurneys) — verify per floor.
- **No coverage gate on node scripts/scenes.** Stated explicitly so this is never mistaken for an oversight — see games-domain CLAUDE.md, scene/node tests are smoke-level only.

## Test command

`just test` — run FOREGROUND, unpiped. Read the GUT summary block yourself (`Totals:` line — scripts/tests/asserts counts); never trust exit code alone.

## Gotchas

- New `class_name` scripts need one `godot --headless --editor --quit --path .` pass (same Godot exe the Justfile's `godot` variable points at) before headless GUT will see them (rebuilds Godot's global script-class cache). **No Justfile recipe currently wraps this** — `just import` runs `--headless --path . --import`, which reimports assets, not the same flag combination, and does not rebuild the class cache. Run the editor-quit pass manually (or open/quit via `just edit`) whenever a new `class_name` script is added.
- Run `just import` after any `.tscn` edit.

## Tuning-constant locations

- `scripts/player.gd` — `MOUSE_SENS`, `GLANCE_TURN_SPEED`, `FLOOR_LIMIT_DEG` (input/camera only — movement constants live in `source_move.gd`)
- `scripts/logic/source_move.gd` — ALL game-wide movement constants (`RUN_SPEED`, `GRAVITY`, `JUMP_SPEED`, `FRICTION`, `STOP_SPEED`, `GROUND_ACCEL`, `AIR_ACCEL`, `AIR_CAP`, `OVERBOUNCE`); changing one requires deliberate test-expectation updates in `tests/unit/test_source_move.gd` — never loosen tolerances
- `scripts/logic/wallrun_logic.gd` — `MIN_FORWARD_SPEED`, `SINK_CAP`, `PUSH_AWAY_SPEED`, `WALL_JUMP_VY`, `RIDE_MAX_NORMAL_Y` (ride gate: |normal.y| ≤ 0.2 — keeps surf ramps out of the wall-ride path)
- `scripts/logic/erosion_logic.gd` — `PLATEAU_LOOP`, `FOG_DENSITY_MAX` (erosion v3, ruling #14: player never degrades; `world_scale(loop)` ramps world pressure 0→1 at plateau)
- `scripts/logic/void_logic.gd` — `CREEP_SPEEDS` (per posture), `CREEP_MULT_MAX` (per-loop creep speedup cap at plateau), `RESET_GAP`
- `scripts/swallow_director.gd` — `FADE_OUT`/`HOLD`/`FADE_IN` (swallow), `SETBACK_MARKERS`, `FALL_FADE_OUT`/`FALL_FADE_IN`/`FALL_VOID_GAP` (fall reset)
- `scripts/slice.gd` — `MARKER_PROGRESSES`, `FALL_Y`

## Design constraint

"Speedrunning feel" is a standing course-design constraint: fast, hard, contained. HARD is commitment-first (user ruling 2026-07-22): gaps near the reach ceiling, precision landings, clear only at full execution — never margin-first "safely makeable" bands. Wall ride/jump is a MANDATORY core traversal verb (user ruling 2026-07-22, supersedes the earlier optional-only rule): zones contain wall-only sections (rides, climbs, wall-to-wall corridors), placed between markers (frozen respawn y=1 keeps marker floors low). Shell/boundary walls stay broken ≤25 m (rib/recess/gap) so the wall-jump chain (measured 196 m/24 m) never yields a free zone skip; designed wall sections are exempt but bounded ≤25 m. No auto-vault unless the geometry is stair-like.
