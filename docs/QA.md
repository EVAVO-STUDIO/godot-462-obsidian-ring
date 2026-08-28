# Obsidian Ring QA

## Required smoke tests

1. Project opens in Godot 4.6.2 without import or parse errors.
2. Main scene boots at 640x360 internal resolution.
3. Player remains inside court bounds.
4. Loose ball slows and rebounds without escaping the court.
5. Possession can transfer to player or AI only when the loose ball is recoverable.
6. Pass and strike release possession exactly once.
7. Tackles consume stamina and cannot trigger continuously through cooldown.
8. Ring shots award the configured high-value score once only.
9. Wall scores award the configured lower-value score once only.
10. Match timer stops gameplay state cleanly at zero.
11. Team, rules, court and league JSON parse and retain unique ids.

## Match integrity gates

- Scoring is checked before a boundary rebound can reverse the shot direction.
- A scoring event resets the ball once and cannot cascade into a second score.
- Knock-loose actions must not teleport possession directly to the tackler.
- Stamina must remain clamped between 0 and 100.
- AI movement and collisions must remain bounded by the active court.

## Product guardrails

- Fictional teams and competition systems must stay clearly separate from historical claims.
- Historical research may inform architecture, materials, equipment and broad ballgame context, but gameplay rules are explicitly an original arcade design.
- No copied proprietary future-sports names, arenas, UI, audio, sprites or exact mechanics.
- No GitHub Actions dependency is required for validation.

## Future automated checks

- seeded match simulation
- duplicate team/court id detection
- scoring edge-case tests
- stamina arithmetic tests
- league table calculation tests
- AI possession deadlock detection
