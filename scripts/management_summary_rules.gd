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
