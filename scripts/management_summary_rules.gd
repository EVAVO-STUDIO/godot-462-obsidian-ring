class_name ManagementSummaryRules
extends RefCounted

static func player_line(player: Dictionary) -> String:
	if player.is_empty():
		return "PLAYER STATE UNAVAILABLE"
	return "%s  INJ %d  SUSP %d  BOOK %d  FAT %d" % [
		str(player.get("name", "PLAYER")).to_upper(),
		maxi(0, int(player.get("injury_matches", 0))),
		maxi(0, int(player.get("suspension_matches", 0))),
		maxi(0, int(player.get("booking_points", 0))),
		clampi(int(player.get("fatigue_carry", 0)), 0, 40)
	]

static func opponent_line(roster: Dictionary, team_name: String = "OPPONENT") -> String:
	var players: Array = roster.get("players", [])
	if players.is_empty():
		return "%s  CONDITION UNAVAILABLE" % team_name.to_upper()
	var available := 0
	var injured := 0
	var suspended := 0
	var fatigue_total := 0
	var fatigue_count := 0
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var injury := maxi(0, int(player.get("injury_matches", 0)))
		var suspension := maxi(0, int(player.get("suspension_matches", 0)))
		if injury > 0:
			injured += 1
		if suspension > 0:
			suspended += 1
		if injury <= 0 and suspension <= 0:
			available += 1
		fatigue_total += clampi(int(player.get("fatigue_carry", 0)), 0, 40)
		fatigue_count += 1
	var average_fatigue := 0 if fatigue_count <= 0 else int(round(float(fatigue_total) / float(fatigue_count)))
	return "VS %s  AVAIL %d/%d  INJ %d  SUSP %d  FAT %d" % [
		team_name.to_upper(), available, players.size(), injured, suspended, average_fatigue
	]

static func foul_line(event: Dictionary) -> String:
	if event.is_empty():
		return "FOUL LOG  NONE"
	return "FOUL LOG  R%02d  %s  %s" % [
		maxi(1, int(event.get("round", 1))),
		str(event.get("team", "")).to_upper(),
		str(event.get("actor_name", event.get("actor_id", "PLAYER"))).to_upper()
	]

static func postseason_line(semifinal_winners: Array, champion_id: String) -> String:
	if champion_id != "":
		return "CHAMPION  %s" % champion_id.replace("_", " ").to_upper()
	if not semifinal_winners.is_empty():
		var names: Array[String] = []
		for winner in semifinal_winners:
			names.append(str(winner).replace("_", " ").to_upper())
		return "PLAYOFF WINNERS  %s" % " / ".join(names)
	return "REGULAR SEASON"
