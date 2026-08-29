class_name StandingsSummaryRules
extends RefCounted

static func sorted_rows(table: Array) -> Array:
	var rows := table.duplicate(true)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("points", 0))
		var pb := int(b.get("points", 0))
		if pa != pb: return pa > pb
		var da := int(a.get("for", 0)) - int(a.get("against", 0))
		var db := int(b.get("for", 0)) - int(b.get("against", 0))
		if da != db: return da > db
		return int(a.get("for", 0)) > int(b.get("for", 0))
	)
	return rows

static func availability(roster: Dictionary) -> Dictionary:
	var players: Array = roster.get("players", [])
	var available := 0
	var injured := 0
	var suspended := 0
	for player in players:
		if typeof(player) != TYPE_DICTIONARY: continue
		var injury := maxi(0, int(player.get("injury_matches", 0)))
		var suspension := maxi(0, int(player.get("suspension_matches", 0)))
		if injury > 0: injured += 1
		if suspension > 0: suspended += 1
		if injury <= 0 and suspension <= 0: available += 1
	return {"available":available,"total":players.size(),"injured":injured,"suspended":suspended}

static func availability_code(roster: Dictionary) -> String:
	if roster.is_empty(): return " A?/?"
	var state := availability(roster)
	return " A%d/%d" % [int(state.get("available", 0)), int(state.get("total", 0))]

static func row_line(row: Dictionary, rank: int, user_team_id: String = "jaguar_house", roster: Dictionary = {}) -> String:
	var marker := ">" if str(row.get("id", "")) == user_team_id else " "
	var name := str(row.get("name", row.get("id", "TEAM"))).to_upper()
	var played := int(row.get("played", 0))
	var diff := int(row.get("for", 0)) - int(row.get("against", 0))
	var points := int(row.get("points", 0))
	return "%s%d %-12s P%02d D%+03d %02d%s" % [marker, rank, name.left(12), played, diff, points, availability_code(roster)]

static func playoff_cutoff_line(playoff_teams: int, total_teams: int) -> String:
	var count := clampi(playoff_teams, 0, maxi(0, total_teams))
	return "PLAYOFF CUT: TOP %d" % count
