class_name FixtureSimulationRules
extends RefCounted

static func _id_value(id: String) -> int:
	var total := 0
	for i in range(id.length()):
		total += id.unicode_at(i) * (i + 3)
	return total

static func roster_strength_modifier(roster: Dictionary) -> int:
	var players: Array = roster.get("players", [])
	if players.is_empty():
		return 0
	var eligible := 0
	var skill_total := 0.0
	var fatigue_total := 0.0
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		if int(player.get("injury_matches", 0)) > 0 or int(player.get("suspension_matches", 0)) > 0:
			continue
		eligible += 1
		skill_total += clampf(float(player.get("skill", 5)), 1.0, 10.0)
		fatigue_total += clampf(float(player.get("fatigue_carry", 0)), 0.0, 40.0)
	if eligible <= 0:
		return -12
	var average_skill := skill_total / float(eligible)
	var average_fatigue := fatigue_total / float(eligible)
	var availability_bonus := clampi(eligible - 3, -3, 2) * 2
	var skill_bonus := int(round((average_skill - 5.0) * 1.4))
	var fatigue_penalty := int(round(average_fatigue / 8.0))
	return clampi(availability_bonus + skill_bonus - fatigue_penalty, -12, 8)

static func with_roster_context(team: Dictionary, roster: Dictionary) -> Dictionary:
	var result := team.duplicate(true)
	result["roster_strength_modifier"] = roster_strength_modifier(roster)
	return result

static func team_strength(team: Dictionary) -> int:
	var base := int(team.get("attack", 5)) * 3 + int(team.get("defence", 5)) * 2 + int(team.get("speed", 5)) * 2 + int(team.get("discipline", 5))
	return maxi(1, base + int(team.get("roster_strength_modifier", 0)))

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
