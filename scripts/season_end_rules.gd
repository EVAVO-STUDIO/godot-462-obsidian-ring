class_name SeasonEndRules
extends RefCounted

const USER_TEAM_ID := "jaguar_house"

static func user_qualified(sorted_table: Array, playoff_teams: int) -> bool:
	for row in PlayoffRules.qualifiers(sorted_table, playoff_teams):
		if str(row.get("id", "")) == USER_TEAM_ID:
			return true
	return false

static func terminal_reason(round_no: int, season_rounds: int, sorted_table: Array, playoff_teams: int, semifinal_winners: Array, champion_id: String) -> String:
	var semifinal_round := maxi(1, season_rounds) + 1
	var final_round := maxi(1, season_rounds) + 2
	if champion_id != "":
		return "CHAMPION" if champion_id == USER_TEAM_ID else "CHAMPIONSHIP_COMPLETE"
	if round_no == semifinal_round and not user_qualified(sorted_table, playoff_teams):
		return "NO_PLAYOFF_BERTH"
	if round_no >= final_round and USER_TEAM_ID not in semifinal_winners:
		return "SEMIFINAL_EXIT"
	return ""

static func terminal_message(reason: String) -> String:
	match reason:
		"CHAMPION": return "SEASON COMPLETE - CHAMPIONS"
		"CHAMPIONSHIP_COMPLETE": return "SEASON COMPLETE - CHAMPIONSHIP FINISHED"
		"NO_PLAYOFF_BERTH": return "SEASON COMPLETE - NO PLAYOFF BERTH"
		"SEMIFINAL_EXIT": return "SEASON COMPLETE - SEMIFINAL EXIT"
		_: return ""
