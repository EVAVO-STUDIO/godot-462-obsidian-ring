# Obsidian Ring

Original brutal 90s arcade Mesoamerican-inspired ball sport built in Godot 4.6.2.

## Current status

Playable foundation on `main`.

Implemented now:

- 640×360 nearest-neighbour game canvas
- player movement and stamina
- opponent AI pursuit/attack behavior
- ball possession and loose-ball recovery
- directional passing
- power strikes
- wall rebounds and ball slowdown
- stamina-cost tackles and possession knock-loose behavior
- five-point ring scoring
- one-point end-wall scoring lane
- match clock and scoreboard
- score event banner
- initial fictional team catalogue
- configurable arcade/tournament rules seed data
- local PowerShell validation with optional Godot headless smoke test

The game is deliberately Mesoamerican-inspired rather than presented as a universal historical reconstruction. Fictional teams, league rules and exaggerated arcade mechanics are clearly separated from historical reference work.

## Controls

- Move: `WASD` or arrow keys
- Pass: `Space`
- Power strike: `X`
- Tackle: `Z`
- Aim passes/strikes: mouse cursor during the current prototype

## Project layout

- `project.godot` — Godot project configuration
- `scenes/` — game scenes
- `scripts/` — runtime gameplay code
- `data/teams.json` — fictional team identities and ratings
- `data/rules.json` — ruleset/scoring configuration seed data
- `docs/GAME_DESIGN.md` — game pillars, cultural guardrails and roadmap
- `tools/validate.ps1` — zero-cost local validation

## Validate locally

```powershell
Set-Location C:\GitRepos\godot-462-obsidian-ring
.\tools\validate.ps1
```

If Godot is not on `PATH`, set `GODOT_BIN` or pass `-GodotBin`. Structural and JSON checks still run without the engine executable.

## Direction

The target is a fast small-sided 1990s arcade sports game with physical possession battles, rebound play, difficult high-value ring shots, injuries, fouls, substitutions, team identities, local multiplayer and a league/career structure.

Classic future-sports games may inform pacing/readability only. Do not copy proprietary teams, arenas, UI, sprites, sounds, names, exact rules or progression structures.

## Infrastructure

- Godot 4.6.2
- GDScript-first gameplay foundation
- desktop-first
- later controller/web/mobile support where appropriate
- no dependency on paid GitHub Actions or Vercel services
- local validation and automation are first-class

Copyright (c) EVAVO Studio.
