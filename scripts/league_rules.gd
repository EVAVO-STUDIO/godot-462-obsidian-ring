class_name LeagueRules
extends RefCounted

static func make_table(teams: Array) -> Array:
	var table: Array = []
	for team in teams:
		table.append({"id":str(team.get("id", "team")),"name":str(team.get("name", "Team")),"played":0,"wins":0,"draws":0,"losses":0,"for":0,"against":0,"points":0})
	return table

static func record_result(table: Array, home_id: String, away_id: String, home_score: int, away_score: int, win_points: int, draw_points: int) -> void:
	var home := _find(table, home_id)
	var away := _find(table, away_id)
	if home < 0 or away < 0:
		return
	for index in [home, away]:
		table[index]["played"] = int(table[index]["played"]) + 1
	table[home]["for"] = int(table[home]["for"]) + home_score
	table[home]["against"] = int(table[home]["against"]) + away_score
	table[away]["for"] = int(table[away]["for"]) + away_score
	table[away]["against"] = int(table[away]["against"]) + home_score
	if home_score > away_score:
		table[home]["wins"] = int(table[home]["wins"]) + 1
		table[away]["losses"] = int(table[away]["losses"]) + 1
		table[home]["points"] = int(table[home]["points"]) + win_points
	elif home_score < away_score:
		table[away]["wins"] = int(table[away]["wins"]) + 1
		table[home]["losses"] = int(table[home]["losses"]) + 1
		table[away]["points"] = int(table[away]["points"]) + win_points
	else:
		table[home]["draws"] = int(table[home]["draws"]) + 1
		table[away]["draws"] = int(table[away]["draws"]) + 1
		table[home]["points"] = int(table[home]["points"]) + draw_points
		table[away]["points"] = int(table[away]["points"]) + draw_points

static func sorted_table(table: Array) -> Array:
	var copy := table.duplicate(true)
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) != int(b["points"]): return int(a["points"]) > int(b["points"])
		var gd_a := int(a["for"]) - int(a["against"])
		var gd_b := int(b["for"]) - int(b["against"])
		if gd_a != gd_b: return gd_a > gd_b
		return int(a["for"]) > int(b["for"])
	)
	return copy

static func injury_seconds_from_hit(force: float, toughness: float) -> float:
	if force < 20.0: return 0.0
	return clampf((force - toughness * 2.0) * 0.35, 0.0, 24.0)

static func foul_for_tackle(relative_speed: float, discipline: float) -> bool:
	var threshold := 165.0 + discipline * 7.0
	return relative_speed > threshold

static func _find(table: Array, id: String) -> int:
	for i in range(table.size()):
		if str(table[i].get("id", "")) == id: return i
	return -1
