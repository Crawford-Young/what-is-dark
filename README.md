# What Is Dark

First-person parkour about facing your own darkness. Phase 3a: Source movement integrated game-wide.

Spec: `~/code/docs/games/what-is-dark/specs/2026-07-21-what-is-dark-design.md`

## Current state

Phase 3a — Source movement integration complete (movement + systems accepted at feel gate 2026-07-25):

- **Source-engine movement is the game's movement** — CS2-style bhop (auto-hop on held jump), air-strafing past the run cap, surf-capable plane clipping; core adopted from the momentum lab into `scripts/player.gd` (`scripts/logic/source_move.gd` + `yaw_drain.gd`)
- Momentum-preserving wall ride — clip-to-plane ride with capped sink, speed-keeping kick-off
- Erosion v2 — per-loop acceleration decay (ground + air, floors at 0.52); speed carried is never bled; landing retention removed
- Snap glance back (hold to look over your shoulder)
- Posture-sensitive void chase — the dark creeps fastest when you look away, slower when glancing, nearly stalls when you face it
- Silent swallow on catch — screen fades out, holds, respawns you at a setback marker
- Quick fall reset — falling off the course fades out/in and resets you near your last passed marker
- 200 m greybox course with shell containment — **phase-2 layout, slated for full redesign in phase 3b** (built for the old movement envelope; five TempBridge planks temporarily restore flat-gap viability)

## Momentum lab (Source-movement evaluation — ADOPTED into the game)

Isolated evaluation env for CS2-style Source movement (bhop + surf), verdict **ADOPT** (2026-07-24); core adopted into the main game in phase 3a. Lab scene kept as a tuning sandbox.

- `scripts/logic/source_move.gd` — pure Source math (friction, accelerate, air cap, plane clip incl. crease `clip_multi`, jump, gravity), full TDD; all tunables top-of-file, game-wide
- `scripts/logic/yaw_drain.gd` — render-rate mouse yaw buffered across physics ticks (fixes render-rate strafe staleness)
- `scripts/momentum_player.gd` + `scenes/momentum_player.tscn` — lab player
- `scripts/momentum_lab.gd` + `scenes/momentum_lab.tscn` — greybox stations (bhop runway, strafe field, surf stage) + HUD; keys 1/2/3 teleport between stations, R resets
- Constants deliberately break CS2 parity in two user-approved places: `JUMP_SPEED` (airtime parity at game gravity) and `AIR_CAP` 1.5 (2× air-turn window)

## Controls

Derived from `project.godot` `[input]` and `scripts/player.gd`.

| Action | Input |
|---|---|
| Move | W A S D |
| Jump / wall-jump | Space |
| Glance back (hold) | Q |
| Look | Mouse |

Wall-running has no dedicated bind — running into a side wall while airborne and above minimum speed slides you along it automatically; press Jump while wall-running to kick off (wall-jump).

## How to run / test

- `just run` — play
- `just edit` — open the Godot editor
- `just test` — headless GUT unit tests
- `just import` — import assets headlessly (after adding new assets, or after any `.tscn` edit)
- `just momentum-lab` — run the momentum lab scene directly
