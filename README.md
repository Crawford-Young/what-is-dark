# What Is Dark

First-person parkour about facing your own darkness. Phase 3b: full 1800 m three-zone course built for Source movement.

Spec: `~/code/docs/games/what-is-dark/specs/2026-07-21-what-is-dark-design.md`

## Current state

Phase 3b — full map redesign under Source movement (all three zone feel gates passed; erosion inverted per ruling #14). Phase 3a's movement integration is included below:

- **Source-engine movement is the game's movement** — CS2-style bhop (auto-hop on held jump), air-strafing past the run cap, surf-capable plane clipping; core adopted from the momentum lab into `scripts/player.gd` (`scripts/logic/source_move.gd` + `yaw_drain.gd`)
- Momentum-preserving wall ride — clip-to-plane ride with capped sink, speed-keeping kick-off
- Erosion v3 — **the player never degrades**; movement constants are identical on your first lap and your hundredth. Per-loop pressure is world-side instead: your first lap (loop 0) is the shipped course exactly, pressure then ramps linearly to full at loop 5 and holds there. As it ramps, the dark creeps faster (up to 1.6× base), fog closes in, margined floors shrink so their gaps drift toward the reach ceiling, and long flat floors **perforate** — holes open and widen until you have to pick a weaving line instead of holding W. Each of the five perforated floors also tears one **full-width chasm** edge to edge (1.5 m per loop → 7.5 m at plateau) that no lane can sidestep, so the weave eventually has to be jumped. Sixteen surfaces erode in total (58 tagged bodies, since a perforated floor is a grid of tiles). At max erosion every gap and every hole still sits inside the reach ceiling
- Snap glance back (hold to look over your shoulder)
- Posture-sensitive void chase — the dark creeps fastest when you look away, slower when glancing, nearly stalls when you face it
- Silent swallow on catch — screen fades out, holds, respawns you at a setback marker
- Quick fall reset — falling off the course fades out/in and resets you near your last passed marker
- **1800 m three-zone course** (phase 3b) with shell containment — **Shame** (0–600 m, school corridors: bhop gaps, wall climbs, an elevator shaft), **Grief** (600–1200 m, hospital opening up: surf ramps into flat kicker pads, chained speed gains to ~25 m/s, long ride walls), **Depression** (1200–1800 m, bedroom compressing: low ceilings, duck-or-die arches, narrow strips at the reach ceiling), ending at a lit door — the game's only warm light

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

Wall traversal has no dedicated bind. Hitting a side wall while airborne and above minimum speed rides it **automatically** — no input required. **Press** Jump during the ride to kick off it; holding Jump through the ride fires nothing, since the kick reads the press edge. Riding preserves along-wall speed with a capped sink; the kick keeps your horizontal speed and adds upward velocity.

## How to run / test

- `just run` — play
- `just edit` — open the Godot editor
- `just test` — headless GUT unit tests
- `just import` — import assets headlessly (after adding new assets, or after any `.tscn` edit)
- `just momentum-lab` — run the momentum lab scene directly
