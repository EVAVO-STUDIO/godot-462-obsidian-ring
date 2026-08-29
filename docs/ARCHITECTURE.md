# Obsidian Ring Runtime Architecture

## Current layers

- `main.gd` owns high-level game flow, temporary rendering, match orchestration and the live court geometry used by athletes, AI, ball physics, scoring and drawing.
- `content_catalog.gd` owns JSON loading and content access helpers.
- `match_rules.gd`, `league_rules.gd`, `roster_rules.gd`, `playoff_rules.gd` and other `*_rules.gd` files own pure deterministic calculations.
- Runtime directors handle narrowly scoped orchestration such as substitutions, condition/fatigue, court hazards, AI fixture simulation, replay protection, foul attribution and presentation rails.
- `SeasonDirector` owns live discipline consequences and postseason progression through the public `postseason_state()` / `restore_postseason_state()` API.
- `SeasonSave` is the single canonical career persistence boundary.

## Game flow

`TITLE -> PLAYING -> RESULT -> TITLE`

The title phase presents matchup, court, player management, opponent condition and standings. Playing owns the live possession/scoring simulation. Result commits the fixture and career consequences before round advancement.

## Canonical career state

`SeasonSave` schema v3 stores:

- funds and round;
- league table;
- canonical roster mutations;
- semifinal winners;
- champion identity;
- championship-purse-paid state.

Roster restore starts from authored canonical rosters and merges only approved mutable fields by player ID. Missing save players cannot delete authored bench players or rewrite identity/role data.

Legacy `user://obsidian_ring_postseason.json` is migration-read-only. Current runtime never writes it.

The canonical season save keeps a validated backup and can recover from corrupt/unsupported primary state before normal sanitisation.

## Match-long condition and injury ownership

`ConditionDirector` runs at process priority `150` and owns participant condition bookkeeping.

- Stamina is captured by player ID throughout PLAYING.
- Substituted-out participants retain their last real stamina observation.
- Players who never appeared receive bench recovery.
- Players who appeared receive carry from actual final observed stamina.
- Injury severity is captured continuously for both teams.
- The injury ledger stores the maximum injury timer observed during the match, not only the timer remaining at RESULT.
- Maximum observed injury converts to the canonical 1–3 match injury scale.
- Persistent injury uses `max(existing, new)` so a later event cannot shorten an existing injury.

`MatchSubstitutionDirector` also persists an outgoing Jaguar House player's current injury before replacing the runtime dictionary, covering the separate live-substitution removal case.

`FatigueDirector` runs after condition capture at priority `170`, so starting condition is established before live performance multipliers are derived.

## Discipline

`FoulLedgerDirector` records the attributed foul actor before `SeasonDirector` applies booking/suspension consequences.

Booking policy is owned at the booking source. `SeasonDirector` reads authored `booking_threshold` and `suspension_matches` values and passes them directly into `DisciplineRules.apply_booking()`.

Suspension serving operates across canonical rosters as the round advances.

## Court geometry

The reference `COURT` rectangle is only a scaling baseline. Every fixture resolves authored court data into one live `court_rect` through `CourtGeometryRules.movement_rect()`.

That same rect drives:

- player formations;
- player clamps;
- AI lanes;
- ball wall collisions;
- ring positions;
- wall-scoring apertures;
- ball reset position;
- rendering.

`CourtHazardDirector` may refine live geometry for low friction, fast walls and narrow sidelines but must never introduce fixed replacement bounds.

## League integrity and AI club condition

The ten-round regular season remains balanced at five home and five away fixtures per club. Replay matches are exhibition-only and cannot mutate committed career state.

### Roster-aware AI fixture strength

AI-vs-AI simulation consumes canonical roster state:

- injured players are unavailable;
- suspended players are unavailable;
- available-player skill influences strength;
- persistent fatigue reduces strength;
- fully unavailable rosters use a bounded `-12` modifier floor;
- the modifier remains smaller than authored team attack/defence/speed identity.

So attrition matters without erasing club character.

### Deterministic off-screen fixture wear

AI-vs-AI matches now create bounded post-match condition wear too.

`FixtureSimulationRules.simulate_roster_wear()`:

- runs only for players who were eligible for that simulated fixture;
- adds deterministic fatigue based on team/opponent/round/player identity;
- clamps fatigue to the same 0–40 canonical range;
- never adds hidden fatigue to already injured/suspended players;
- has a low deterministic injury chance, approximately one in eleven team-fixtures;
- never creates that injury when only the minimum three eligible players remain;
- preserves existing unavailable injury/suspension state.

Wear is applied **after** the AI result is calculated and recorded, mirroring live-match order rather than weakening a team before the match it just played.

### AI recovery boundary

When `match_number` advances, `FixtureSimulationDirector` recovers every non-user roster exactly once:

- `RosterRules.recover_between_matches()` reduces injury duration;
- `ConditionRules.recover_bench_carry()` reduces stale fatigue carry.

Jaguar House is skipped because the user-team management flow remains the recovery owner there.

## Management visibility

The title management rail exposes both the selected Jaguar House player's state and the next opponent's canonical condition summary.

Opponent summary includes:

- available players / total roster;
- injuries;
- suspensions;
- average fatigue.

The summary comes from the same roster state that live selection and AI fixture simulation use, so management information is actionable rather than decorative.

## Postseason ownership

`SeasonDirector` owns live postseason state. `SeasonSave`, season-end guards and presentation layers use the public API rather than private fields.

The legacy postseason JSON remains migration-only and is ignored when canonical season state exists.

## Refactor direction

Keep one authoritative owner for each simulation/persistence concept. Presentation-only directors can remain separate. Avoid runtime layers that merely reinterpret or repair a decision after another subsystem already made it.

## Invariants

- A scoring event resolves exactly once before rebound processing.
- One live `court_rect` drives athletes, AI, ball bounds, scoring geometry, resets and rendering.
- Court hazards refine live geometry and never replace it with fixed bounds.
- Match participation is tracked by player ID across substitutions.
- Match-long injury persistence uses maximum observed severity for both teams.
- Live substitution persists outgoing user injury before replacement.
- Injured/suspended players are excluded from active selection and substitution candidacy.
- AI fixtures consume canonical roster availability/skill/fatigue.
- AI-vs-AI fixtures generate deterministic bounded post-match wear.
- AI wear applies after result calculation and cannot injure a roster already reduced to the minimum three eligible players.
- AI recovery runs exactly once on round advance and skips Jaguar House.
- Discipline policy comes from authored league config at booking time.
- Saved rosters cannot delete authored players or rewrite canonical identity/role.
- Postseason state uses the public SeasonDirector API.
- Legacy postseason persistence is migration-read-only.
- Career state remains offline-capable with no paid CI/cloud dependency.
- Canonical save state is versioned, sanitized and backup-recoverable.
