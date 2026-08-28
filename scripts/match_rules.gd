class_name MatchRules
extends RefCounted

static func clamp_stamina(value: float) -> float:
	return clampf(value, 0.0, 100.0)

static func recover_stamina(value: float, moving: bool, delta: float) -> float:
	var rate := -3.0 if moving else 16.0
	return clamp_stamina(value + rate * delta)

static func can_tackle(stamina: float, cooldown: float, cost: float = 14.0) -> bool:
	return cooldown <= 0.0 and stamina >= cost

static func winner_text(home_name: String, away_name: String, home_score: int, away_score: int) -> String:
	if home_score > away_score:
		return "%s WINS" % home_name
	if away_score > home_score:
		return "%s WINS" % away_name
	return "DRAW MATCH"

static func prize_for_result(home_score: int, away_score: int, win_prize: int, draw_prize: int, loss_prize: int) -> int:
	if home_score > away_score:
		return maxi(0, win_prize)
	if home_score == away_score:
		return maxi(0, draw_prize)
	return maxi(0, loss_prize)
