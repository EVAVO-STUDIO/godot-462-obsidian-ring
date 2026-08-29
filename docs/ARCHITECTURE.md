# Obsidian Ring Runtime Architecture

## Current layers

- `main.gd` owns high-level game flow, temporary rendering and match orchestration.
- `content_catalog.gd` owns JSON loading and content access helpers.
- `match_rules.gd`, `league_rules.gd`, `roster_rules.gd`, `playoff_rules.gd` and the other `*_rules.gd` files own pure deterministic calculations.
- Runtime directors handle narrowly scoped orchestration such as substitutions, fatigue, court effects, AI fixture simulation, replay protection, foul attribution and presentation rails.
- `SeasonDirector` owns live discipline consequences and postseason progression, and exposes postseason state through the public `postseason_state()` / `restore_postseason_state()` API.
- `SeasonSave` is the single canonical career persistence boundary.
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

`SeasonSave` reads and restores postseason state only through `SeasonDirector.postseason_state()` and `SeasonDirector.restore_postseason_state()`. Other directors and UI layers use the same public API rather than reaching into `_semifinal_winners`, `_champion_id` or `_championship_purse_paid` directly.

## Legacy postseason migration

`user://obsidian_ring_postseason.json` is read-only migration compatibility for careers created before the canonical v3 save absorbed postseason state.

`SeasonDirector` checks for the canonical `user://obsidian_ring_season.json` first. If the canonical file exists, the legacy file is ignored. Only when no canonical save exists may `_load_legacy_state_if_needed()` import a supported legacy postseason file.

Current runtime code never writes the legacy file. There is no active legacy `_save_state()` path. Once imported state causes a canonical career change, normal `SeasonSave` autosave captures it into the v3 canonical save and future launches ignore the legacy source.

The legacy file must never become a second authoritative career state again.

## Save recovery

The canonical season save has a validated backup. A supported valid primary is copied to the backup before replacement. Restore prefers primary state and falls back to backup if the primary is corrupt or unsupported. Recovered content still passes through table, roster and postseason sanitisation.

## Match condition and discipline

`ConditionDirector` accumulates stamina by player ID throughout the whole match, so substituted-out participants retain their last observed stamina. Only players who never appeared receive bench recovery.

`FoulLedgerDirector` records the exact attributed foul actor before `SeasonDirector` applies booking/suspension consequences.

Discipline policy is owned at the booking source rather than by mutable shared state:

- `SeasonDirector` reads `booking_threshold` and `suspension_matches` from the active league configuration when a booking is applied.
- Those values are passed explicitly into `DisciplineRules.apply_booking()`.
- `DisciplineRules` keeps only immutable fallback constants (`3` booking points and `1` suspension match).
- The earlier `DisciplinePolicyDirector` and mutable static policy variables have been removed.

This means process priority cannot change which discipline policy a foul uses.

## League integrity

Regular-season AI fixtures use deterministic simulation and are recorded through the same league result rules as the user fixture. The ten-round schedule is balanced at five home and five away matches per club. Replay matches are exhibition-only and cannot mutate committed career state.

## Refactor direction

Continue reducing private cross-director coupling and duplicate state. Keep one authoritative owner for each persistent concept, with public read/restore contracts where another subsystem genuinely needs access.

Longer-term candidates include moving more ball/scoring court geometry to authored data and consolidating presentation-only directors where that reduces complexity without mixing UI and simulation.

## Invariants

- A scoring event resolves exactly once before rebound processing.
- Stamina is clamped and contact actions respect cooldown/cost rules.
- Discipline thresholds/suspension length are passed explicitly from authored league config at booking time.
- Fictional arcade rules remain clearly separate from historical claims.
- Team, court, player and ruleset IDs remain stable and unique.
- Saved rosters cannot delete authored players or replace canonical identity/role data.
- Persistent postseason state is accessed through the public SeasonDirector API.
- Legacy postseason persistence is migration-read-only and never written by current runtime.
- Production art can replace prototype drawing without altering scoring or possession logic.
- Career state remains usable offline with no paid CI or cloud runtime dependency.
- Canonical save state is versioned, sanitized and recoverable from backup.
