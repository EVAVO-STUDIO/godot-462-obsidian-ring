class_name PlayoffRules
extends RefCounted

static func qualifiers(sorted_table: Array, playoff_teams: int) -> Array:
	var count := clampi(playoff_teams, 0, sorted_table.size())
	return sorted_table.slice(0, count)

static func semifinal_pairings(sorted_table: Array, playoff_teams: int) -> Array:
	var qualified := qualifiers(sorted_table, playoff_teams)
	if qualified.size() < 4:
		return []
	return [
		{"home": qualified[0].duplicate(true), "away": qualified[3].duplicate(true)},
		{"home": qualified[1].duplicate(true), "away": qualified[2].duplicate(true)}
	]

static func winner_id(home: Dictionary, away: Dictionary, home_score: int, away_score: int) -> String:
	if home_score > away_score:
		return str(home.get("id", ""))
	if away_score > home_score:
		return str(away.get("id", ""))
	var home_diff := int(home.get("for", 0)) - int(home.get("against", 0))
	var away_diff := int(away.get("for", 0)) - int(away.get("against", 0))
	if home_diff != away_diff:
		return str(home.get("id", "")) if home_diff > away_diff else str(away.get("id", ""))
	if int(home.get("for", 0)) != int(away.get("for", 0)):
		return str(home.get("id", "")) if int(home.get("for", 0)) > int(away.get("for", 0)) else str(away.get("id", ""))
	return str(home.get("id", ""))

static func final_pairing(semifinal_winner_ids: Array, table: Array) -> Dictionary:
	if semifinal_winner_ids.size() < 2:
		return {}
	var first := _find_team(table, str(semifinal_winner_ids[0]))
	var second := _find_team(table, str(semifinal_winner_ids[1]))
	if first.is_empty() or second.is_empty():
		return {}
	return {"home": first, "away": second}

static func _find_team(table: Array, id: String) -> Dictionary:
	for row in table:
		if str(row.get("id", "")) == id:
			return row.duplicate(true)
	return {}
