class_name ReplayGuardRules
extends RefCounted

static func is_regular_season_round(match_number: int, season_rounds: int) -> bool:
	return match_number >= 1 and match_number <= maxi(1, season_rounds)

static func snapshot_state(funds: int, league_table: Array, roster_state: Array) -> Dictionary:
	return {
		"funds": maxi(0, funds),
		"league_table": league_table.duplicate(true),
		"roster_state": roster_state.duplicate(true)
	}

static func valid_snapshot(snapshot: Dictionary) -> bool:
	return snapshot.has("funds") and typeof(snapshot.get("league_table", null)) == TYPE_ARRAY and typeof(snapshot.get("roster_state", null)) == TYPE_ARRAY
