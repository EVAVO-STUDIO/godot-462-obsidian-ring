# Obsidian Ring — Game Design Foundation

## North star

Create an original brutal 1990s arcade sports game that borrows the speed, readability, league tension and physicality associated with classic future-sports games while grounding its own identity in a stylised Mesoamerican-inspired ball court, ring scoring, heavy rubber ball, protective equipment and ceremonial atmosphere.

This is not a historical simulation and must not present invented arcade mechanics as archaeological fact.

## Core match loop

1. Select a team and ruleset.
2. Enter a compact stone court with strong left/right attacking direction.
3. Gain possession through positioning, rebounds and tackles.
4. Pass or strike the ball through traffic.
5. Score one point through the lower-value end-wall lane or five through the difficult ring target.
6. Manage stamina, injuries, fouls and substitutions.
7. Win the match, earn league resources and improve the squad.

## Gameplay pillars

- **Immediate control:** movement and contact must feel fast and legible.
- **High-value skill shot:** ring goals should be rare enough to feel dramatic but achievable through practice.
- **Physical possession:** tackles change momentum without turning every collision into random loss of control.
- **Rebound play:** walls and court geometry are tactical surfaces.
- **Team identity:** squads differ in speed, defence, attack and discipline.
- **Short matches:** default arcade matches fit a three-minute session.
- **League pressure:** injuries, roster depth and upgrades matter between matches.

## Scoring

- Ring shot: 5 points in the baseline arcade rules.
- End-wall scoring lane: 1 point.
- Future variants may add court-specific targets, streak bonuses or tournament modifiers, but the core score must remain readable at a glance.

## Contact and stamina

- Tackles consume stamina and have recovery windows.
- Power strikes consume stamina.
- Contact should use predictable geometry and cooldowns rather than uncontrolled physics explosions.
- Later injury/foul systems must distinguish legal shoulder/body contact from dangerous actions.

## Historical and cultural guardrails

- Describe the game as **Mesoamerican-inspired**, not a recreation of one universal ancient rule set.
- Do not imply that all Mesoamerican cultures, periods or ballgames shared identical rules or ritual practices.
- Avoid defaulting to sacrifice as spectacle or treating cultures as a generic fantasy aesthetic.
- Architecture, dress, protective gear, iconography and terminology should be researched per specific cultural reference before production art is locked.
- Fictional teams and league structures should remain clearly fictional.

## 1990s presentation target

- Internal canvas: 640×360 with nearest-neighbour filtering.
- Strong pixel silhouettes and chunky animation frames.
- Stone, painted plaster, woven cloth, rubber, wood, feathers and obsidian-inspired accents rather than futuristic steel arenas.
- Dense but readable scoreboard and roster screens.
- Production visuals should feel like an ambitious 1993–1996 arcade/computer sports title, not modern pixel-art nostalgia with excessive post-processing.

## Data architecture

- `data/teams.json`: team identities and high-level ratings.
- `data/rules.json`: match and scoring profiles.
- Future: players, courts, league tables, injuries, upgrades, schedules and AI profiles.

## Near-term implementation order

1. Split player, ball, opponent and match director into dedicated scripts/nodes.
2. Load teams and rules from JSON.
3. Expand to full small-sided teams with player switching.
4. Add directional passing and assisted teammate targeting.
5. Add legal tackle windows, knockdowns and possession recovery.
6. Add goalkeeper/defensive specialist logic if playtests require it.
7. Add fouls, injuries and substitutions.
8. Add match intro/result screens and tournament ladder.
9. Add roster progression and team economy.
10. Add local two-player/controller support and deterministic match test scenarios.

## IP guardrails

- Do not copy Speedball names, arenas, teams, UI, sprites, sound, exact rules or progression content.
- The useful reference is pacing and readability, not proprietary expression.
- All art, audio, branding, teams, courts, rules and code must remain original.

## Infrastructure

- No paid GitHub Actions dependency.
- Local validation and test scripts are first-class project tooling.
- Build/export artefacts and caches stay outside Git.
