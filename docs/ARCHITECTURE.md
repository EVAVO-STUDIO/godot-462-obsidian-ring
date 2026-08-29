# Obsidian Ring Runtime Architecture

## Current layers

- `main.gd` owns high-level game flow, temporary rendering, match orchestration and the live court geometry used by athletes, AI, ball physics, scoring and drawing.
- `content_catalog.gd` owns JSON loading and content access helpers.
- `match_rules.gd`, `league_rules.gd`, `roster_rules.gd`, `playoff_rules.gd` and the other `*_rules.gd` files own pure deterministic calculations.
- Runtime directors handle narrowly scoped orchestration such as substitutions, condition/fatigue, court hazards, AI fixture simulation, replay protection, foul attribution and presentation rails.
- `SeasonDirector` owns live discipline consequences and postseason progression, and exposes postseason state through the public `postseason_state()` / `restore_postseason_state()` API.
- `SeasonSave` is the single canonical career persistence boundary.
- `data/` owns fictional teams, rulesets, courts, rosters, fixtures and league/career definitions.

## Game flow

`TITLE -> PLAYING -> RESULT -> TITLE`

The title phase presents the matchup, court, selected-player management state and full standings. Playing owns the timed possession/scoring simulation. Result determines winner, purse, career effects and replay/next-match behavior.

## Canonical career state

`SeasonSave` schema v3 stores funds/round, the league table, canonical roster mutations, semifinal winners, champion identity and championship-purse-paid state.

Roster restore starts from authored canonical rosters and merges only approved mutable fields by player ID. Missing saved players cannot delete authored bench players or rewrite identity/role data.

`SeasonSave` and presentation consumers access postseason state only through `SeasonDirector.postseason_state()` / `restore_postseason_state()`.

## Legacy postseason migration

`user://obsidian_ring_postseason.json` is read-only migration compatibility. If canonical `obsidian_ring_season.json` exists, the legacy file is ignored. Current runtime never writes the legacy file and there is no active legacy `_save_state()` path.

## Save recovery

The canonical season save maintains a validated backup. Restore prefers valid primary state and falls back to backup if the primary is corrupt or unsupported. Recovered content still passes through roster, table and postseason sanitisation.

## Match condition, participation and injury persistence

`ConditionDirector` owns match-long participant condition bookkeeping at process priority `150`.

- Stamina is captured by player ID throughout PLAYING, so a substituted-out participant retains the last real stamina observed before leaving the court.
- Players who never appeared receive bench recovery; players who appeared receive fatigue carry from their actual final observed stamina.
- Injury severity is also captured continuously by player ID.
- The injury ledger stores the **maximum injury timer observed during the match**, not the timer remaining at the final whistle. An early injury therefore cannot disappear merely because its temporary on-court stun counted back to zero before RESULT.
- Both home and away participants feed the injury ledger, so AI clubs do not receive hidden immunity from season attrition.
- At RESULT, the maximum observed injury is converted to the canonical 1–3 match injury scale and merged with `max(existing, new)` so persistence never shortens an existing injury.

`MatchSubstitutionDirector` also persists an outgoing user player's current injury **before** replacing that runtime dictionary. This closes the separate case where an injured player leaves the live `home_players` array before RESULT.

The existing `main.gd::_persist_match_injuries()` remains as a compatible final-active-player fallback; the match-long ledger is the completeness layer that covers recovered and substituted participants.

`FatigueDirector` runs after condition capture at priority `170`, so carried starting stamina is established before live performance multipliers are derived.

## Discipline

`FoulLedgerDirector` records the attributed foul actor before `SeasonDirector` applies booking/suspension consequences.

Discipline policy is owned at the booking source. `SeasonDirector` reads `booking_threshold` and `suspension_matches` from league config and passes them explicitly into `DisciplineRules.apply_booking()`. The earlier mutable policy director/state has been removed.

## Court geometry ownership

The reference `COURT` rectangle is only a scaling baseline. Each fixture resolves authored court data into one live `court_rect` through `CourtGeometryRules.movement_rect()`.

That rectangle drives formations, player clamps, AI lanes, ball wall collisions, ring positions, wall-scoring apertures, ball reset position and rendering. `CourtHazardDirector` may refine that live geometry for low friction, fast walls and narrow sidelines but must not introduce fixed replacement bounds.

## League integrity

Regular-season AI fixtures are deterministic and recorded through the same league-result rules as the user fixture. The ten-round schedule remains balanced at five home and five away matches per club. Replay matches are exhibition-only and cannot mutate committed career state.

Non-user fixture simulation occurs on first RESULT entry while `match_number` still identifies the completed round; round advancement occurs only after the player continues.

## Refactor direction

Keep one authoritative owner for each persistent or simulation concept, with public contracts where another subsystem genuinely needs access. Presentation-only directors can remain separate. Runtime layers that merely repair a decision already made elsewhere remain candidates for source integration.

## Invariants

- A scoring event resolves exactly once before rebound processing.
- One live `court_rect` drives athletes, AI, ball bounds, scoring geometry, resets and rendering.
- Court hazards refine live geometry and never hard-code replacement bounds.
- Match participation is tracked by player ID across substitutions.
- Match-long injury persistence uses maximum observed severity and applies symmetrically to both teams.
- Live substitution persists outgoing injury state before replacement.
- Stamina is clamped and contact actions respect cooldown/cost rules.
- Discipline thresholds/suspension length come directly from authored league config.
- Saved rosters cannot delete authored players or replace canonical identity/role data.
- Postseason state uses the public SeasonDirector API.
- Legacy postseason persistence is migration-read-only.
- Career state remains usable offline with no paid CI/cloud dependency.
- Canonical save state is versioned, sanitized and recoverable from backup.
