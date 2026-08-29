# Obsidian Ring Runtime Architecture

## Current layers

- `main.gd` owns high-level game flow, temporary rendering and match orchestration.
- `content_catalog.gd` owns JSON loading and content access helpers.
- `match_rules.gd`, `league_rules.gd`, `roster_rules.gd`, `playoff_rules.gd` and the other `*_rules.gd` files own pure deterministic calculations.
- Runtime directors handle narrowly scoped orchestration such as discipline policy, substitutions, fatigue, court effects, AI fixture simulation, replay protection and presentation rails.
- `SeasonDirector` owns live postseason progression and exposes that state through the public `postseason_state()` / `restore_postseason_state()` API.
- `SeasonSave` is the canonical career persistence boundary.
- `data/` owns fictional teams, rulesets, courts, rosters, fixtures and league/career definitions.

## Game flow

`TITLE -> PLAYING -> RESULT -> TITLE`

The title phase presents the matchup, court, selected-player management state and full standings. Playing owns the timed possession/scoring simulation. Result determines winner, purse, career effects and replay/next-match behavior.

## Canonical career state

`SeasonSave` schema v3 stores:

- funds and round
- full league table
- canonical roster career mutations
- semifinal winners
- champion identity
- championship-purse-paid state

Roster restore starts from authored canonical rosters and merges only approved mutable fields by player ID. Missing players in a save therefore cannot delete authored bench players or rewrite identity/role data.

`SeasonSave` reads and restores postseason state only through `SeasonDirector.postseason_state()` and `SeasonDirector.restore_postseason_state()`. Other directors and UI layers must use the same public API rather than reaching into `_semifinal_winners`, `_champion_id` or `_championship_purse_paid` directly.

The older `obsidian_ring_postseason.json` path remains migration compatibility only. It must not become a second authoritative career state.

## Save recovery

The canonical season save has a validated backup. A supported valid primary is copied to the backup before replacement. Restore prefers primary state and falls back to backup if the primary is corrupt or unsupported. Recovered content still passes through table, roster and postseason sanitisation.

## Match condition and discipline

`ConditionDirector` accumulates stamina by player ID throughout the whole match, so substituted-out participants retain their last observed stamina. Only players who never appeared receive bench recovery.

`FoulLedgerDirector` records the exact attributed foul actor before `SeasonDirector` applies booking/suspension consequences. Discipline thresholds and suspension lengths come from league configuration through `DisciplinePolicyDirector`.

## League integrity

Regular-season AI fixtures use deterministic simulation and are recorded through the same league result rules as the user fixture. The ten-round schedule is balanced at five home and five away matches per club. Replay matches are exhibition-only and cannot mutate committed career state.

## Refactor direction

Continue reducing private cross-director coupling and duplicate state. Keep one authoritative owner for each persistent concept, with public read/restore contracts where another subsystem genuinely needs access.

Longer-term candidates include moving more ball/scoring court geometry to authored data and consolidating presentation-only directors where that reduces complexity without mixing UI and simulation.

## Invariants

- A scoring event resolves exactly once before rebound processing.
- Stamina is clamped and contact actions respect cooldown/cost rules.
- Fictional arcade rules remain clearly separate from historical claims.
- Team, court, player and ruleset IDs remain stable and unique.
- Saved rosters cannot delete authored players or replace canonical identity/role data.
- Persistent postseason state is accessed through the public SeasonDirector API.
- Production art can replace prototype drawing without altering scoring or possession logic.
- Career state remains usable offline with no paid CI or cloud runtime dependency.
- Canonical save state is versioned, sanitized and recoverable from backup.
