class_name RosterSaveRules
extends RefCounted

const MAX_FATIGUE_CARRY := 40
const MUTABLE_FIELDS := [
	"skill",
	"injury_matches",
	"suspension_matches",
	"booking_points",
	"suspensions_served",
	"fatigue_carry",
	"suspension_until_round"
]

static func merge_rosters(canonical, saved) -> Array:
	if typeof(canonical) != TYPE_ARRAY:
		return []
	var saved_players := _saved_player_map(saved)
	var result: Array = []
	for canonical_roster in canonical:
		if typeof(canonical_roster) != TYPE_DICTIONARY:
			continue
		var next_roster: Dictionary = canonical_roster.duplicate(true)
		var next_players: Array = []
		for canonical_player in canonical_roster.get("players", []):
			if typeof(canonical_player) != TYPE_DICTIONARY:
				continue
			var next_player: Dictionary = canonical_player.duplicate(true)
			var id := str(next_player.get("id", ""))
			if id != "" and saved_players.has(id):
				next_player = _merge_mutable_state(next_player, saved_players[id])
			next_players.append(next_player)
		next_roster["players"] = next_players
		result.append(next_roster)
	return result

static func _saved_player_map(saved) -> Dictionary:
	var result: Dictionary = {}
	if typeof(saved) != TYPE_ARRAY:
		return result
	for roster in saved:
		if typeof(roster) != TYPE_DICTIONARY:
			continue
		for player in roster.get("players", []):
			if typeof(player) != TYPE_DICTIONARY:
				continue
			var id := str(player.get("id", ""))
			if id != "" and not result.has(id):
				result[id] = player
	return result

static func _merge_mutable_state(canonical: Dictionary, saved: Dictionary) -> Dictionary:
	var next := canonical.duplicate(true)
	for field in MUTABLE_FIELDS:
		if saved.has(field):
			next[field] = saved[field]
	next["skill"] = clampi(int(next.get("skill", canonical.get("skill", 1))), 1, 10)
	next["injury_matches"] = maxi(0, int(next.get("injury_matches", 0)))
	next["suspension_matches"] = maxi(0, int(next.get("suspension_matches", 0)))
	next["booking_points"] = maxi(0, int(next.get("booking_points", 0)))
	next["suspensions_served"] = maxi(0, int(next.get("suspensions_served", 0)))
	next["fatigue_carry"] = clampi(int(next.get("fatigue_carry", 0)), 0, MAX_FATIGUE_CARRY)
	if next.has("suspension_until_round"):
		var until_round := int(next.get("suspension_until_round", -1))
		if until_round < 0:
			next.erase("suspension_until_round")
		else:
			next["suspension_until_round"] = until_round
	return next
