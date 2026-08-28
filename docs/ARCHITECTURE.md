# Obsidian Ring Runtime Architecture

## Current layers

- `main.gd` owns high-level game flow, temporary rendering and match orchestration.
- `content_catalog.gd` owns JSON loading and content access helpers.
- `match_rules.gd` owns pure match arithmetic such as stamina and result/purse calculations.
- `data/` owns fictional teams, rulesets, courts and league/career definitions.

## Game flow

`TITLE -> PLAYING -> RESULT -> TITLE`

The title phase presents the matchup and court. Playing owns the timed possession/scoring simulation. Result determines winner, purse and replay/next-match behavior.

## Refactor direction

As the game grows, move responsibilities out of `main.gd` in this order:

1. ball simulation and scoring detector
2. athlete/player controller
3. AI team controller
4. tackle/contact resolver
5. match controller
6. league/career state and save persistence
7. presentation/HUD

Local multiplayer should share the same athlete/controller contract used by AI rather than introducing a separate physics path.

## Invariants

- A scoring event resolves exactly once before rebound processing.
- Stamina is clamped and contact actions respect cooldown/cost rules.
- Fictional arcade rules remain clearly separate from historical claims.
- Team, court and ruleset IDs remain stable and unique.
- Production art can replace prototype drawing without altering scoring or possession logic.
- Career state must remain usable offline with no paid CI or cloud runtime dependency.
