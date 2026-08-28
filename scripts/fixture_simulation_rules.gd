class_name FixtureSimulationRules
extends RefCounted

static func _id_value(id: String) -> int:
	var total := 0
	for i in range(id.length()):
		total += id.unicode_at(i) * (i + 3)
	return total

static func team_strength(team: Dictionary) -> int:
	return maxi(1, int(team.get("attack", 5)) * 3 + int(team.get("defence", 5)) * 2 + int(team.get("speed", 5)) * 2 + int(team.get("discipline", 5)))

static func deterministic_score(team: Dictionary, opponent: Dictionary, round_no: int, home: bool) -> int:
	var attack_pressure := int(team.get("attack", 5)) * 2 + int(team.get("speed", 5))
	var resistance := int(opponent.get("defence", 5)) * 2
	var strength_delta := team_strength(team) - team_strength(opponent)
	var seed_value := _id_value(str(team.get("id", "team"))) + maxi(1, round_no) * 97 + (31 if home else 0)
	var variation := posmod(seed_value, 5) - 2
	var raw := 2 + int(round(float(attack_pressure - resistance) / 4.0)) + int(round(float(strength_delta) / 18.0)) + variation
	return clampi(raw, 0, 12)

static func simulate_fixture(home: Dictionary, away: Dictionary, round_no: int) -> Dictionary:
	return {
		"home_score": deterministic_score(home, away, round_no, true),
		"away_score": deterministic_score(away, home, round_no, false)
	}

static func team_played(table: Array, team_id: String) -> int:
	for row in table:
		if str(row.get("id", "")) == team_id:
			return maxi(0, int(row.get("played", 0)))
	return 0

static func fixture_needs_simulation(table: Array, home_id: String, away_id: String, round_no: int) -> bool:
	return team_played(table, home_id) < round_no and team_played(table, away_id) < round_no
