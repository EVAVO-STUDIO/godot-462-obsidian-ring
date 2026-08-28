# Obsidian Ring

Original brutal 90s arcade Mesoamerican-inspired ball sport built in Godot 4.6.2.

## Current status

Playable 3-on-3 league foundation on `main`.

Implemented now:

- 640×360 nearest-neighbour game canvas
- title / match-up → match → result flow
- 3-on-3 teams with player switching
- runner, striker and guard roles with distinct multipliers
- team ratings affecting speed, attack, defence and discipline
- stamina, tackling, knock-loose possession and injuries
- foul detection and possession turnovers
- teammate passing, directional strikes and interception checks
- team AI for loose-ball pursuit, support shape, defensive pressure and ring attacks
- data-driven ring/wall scoring, match duration and court rebound behavior
- persistent funds and league table
- wins, draws, losses, points, scoring differential and standings sorting
- named five-player roster catalogue for every team
- deterministic 10-round fixture catalogue
- reusable roster rules for substitutions, training, medical treatment and between-match recovery
- versioned local season autosave in `user://obsidian_ring_season.json`
- fictional teams/courts kept separate from historical claims
- local PowerShell validation with optional Godot headless smoke test

The game is deliberately Mesoamerican-inspired rather than presented as a universal historical reconstruction. Fictional teams, league rules and exaggerated arcade mechanics are clearly separated from historical reference work.

## Controls

- Move: `WASD` or arrow keys
- Pass: `Space`
- Power strike: `X`
- Tackle: `Z`
- Switch controlled home player: `C`
- Aim passes/strikes: mouse cursor during the current prototype
- Begin / next match: `Enter`
- Rematch: `R`
- Leave active match: `Esc`

## Project layout

- `project.godot` — Godot project configuration and `SeasonSave` autoload
- `scenes/` — game scenes
- `scripts/main.gd` — current playable match/league orchestration
- `scripts/content_catalog.gd` — JSON loading helper
- `scripts/match_rules.gd` — stamina/results/purse rules
- `scripts/team_play_rules.gd` — control selection and support positioning
- `scripts/league_rules.gd` — standings, foul and injury rules
- `scripts/roster_rules.gd` — substitutions, training and medical management
- `scripts/season_save.gd` — versioned local season autosave/restore
- `data/teams.json` — fictional team identities and ratings
- `data/player_roles.json` — runner/striker/guard role profiles
- `data/rosters.json` — named five-player team rosters
- `data/fixtures.json` — deterministic 10-round season schedule
- `data/rules.json` — scoring/match configuration
- `data/courts.json` — court identities and rebound parameters
- `data/league.json` — league/career economy configuration
- `docs/GAME_DESIGN.md` — game pillars, cultural guardrails and roadmap
- `docs/ARCHITECTURE.md` — runtime/system boundaries
- `docs/QA.md` — match-integrity and regression checklist
- `tools/validate.ps1` — zero-cost local validation

## Validate locally

```powershell
Set-Location C:\GitRepos\godot-462-obsidian-ring
.\tools\validate.ps1
```

If Godot is not on `PATH`, set `GODOT_BIN` or pass `-GodotBin`. Structural, JSON, fixture, roster, league, cross-reference and save-configuration checks still run without the engine executable.

## Direction

The target is a fast small-sided 1990s arcade sports game with brutal possession battles, rebounds, difficult high-value ring shots, injuries, fouls, substitutions, training/medical choices, team identities, local multiplayer and complete league/playoff progression.

Classic future-sports games may inform pacing/readability only. Do not copy proprietary teams, arenas, UI, sprites, sounds, names, exact rules or progression structures.

## Infrastructure

- Godot 4.6.2
- GDScript-first gameplay foundation
- desktop-first
- later controller/web/mobile support where appropriate
- no dependency on paid GitHub Actions or Vercel services
- local validation and automation are first-class

Copyright (c) EVAVO Studio.
