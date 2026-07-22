# What Is Dark

First-person parkour about facing your own darkness. Phase 1: vertical slice complete.

Spec: `~/code/docs/games/what-is-dark/specs/2026-07-21-what-is-dark-design.md`

## Current state

Phase 1 vertical slice complete:

- First-person speedrun movement — run, jump, wall-run with emergent wall-climb
- Snap glance back (hold to look over your shoulder)
- Posture-sensitive void chase — the dark creeps fastest when you look away, slower when glancing, nearly stalls when you face it
- Silent swallow on catch — screen fades out, holds, respawns you at a setback marker
- Quick fall reset — falling off the course fades out/in and resets you near your last passed marker
- 200 m greybox course with shell containment

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
