class_name StandingsSummaryRules
extends RefCounted

static func sorted_rows(table: Array) -> Array:
	var rows := table.duplicate(true)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("points", 0))
		var pb := int(b.get("points", 0))
		if pa != pb:
			return pa > pb
		var da := int(a.get("for", 0)) - int(a.get("against", 0))
		var db := int(b.get("for", 0)) - int(b.get("against", 0))
		if da != db:
			return da > db
		return int(a.get("for", 0)) > int(b.get("for", 0))
	)
	return rows

static func row_line(row: Dictionary, rank: int, user_team_id: String = "jaguar_house") -> String:
	var marker := ">" if str(row.get("id", "")) == user_team_id else " "
	var name := str(row.get("name", row.get("id", "TEAM"))).to_upper()
	var played := int(row.get("played", 0))
	var diff := int(row.get("for", 0)) - int(row.get("against", 0))
	var points := int(row.get("points", 0))
	return "%s%d %-15s P%02d D%+03d %02dPTS" % [marker, rank, name.left(15), played, diff, points]

static func playoff_cutoff_line(playoff_teams: int, total_teams: int) -> String:
	var count := clampi(playoff_teams, 0, maxi(0, total_teams))
	return "PLAYOFF CUT: TOP %d" % count
