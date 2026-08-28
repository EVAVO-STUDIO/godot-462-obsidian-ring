class_name RosterRules
extends RefCounted

static func roster_for_team(rosters: Array, team_id: String) -> Dictionary:
	for roster in rosters:
		if str(roster.get("team_id", "")) == team_id:
			return roster
	return {}

static func ordered_players(roster: Dictionary) -> Array:
	var healthy: Array = []
	var injured: Array = []
	for player in roster.get("players", []):
		if int(player.get("injury_matches", 0)) > 0:
			injured.append(player)
		else:
			healthy.append(player)
	return healthy + injured

static func active_three(roster: Dictionary) -> Array:
	var players := ordered_players(roster)
	return players.slice(0, mini(3, players.size()))

static func bench(roster: Dictionary) -> Array:
	var players := ordered_players(roster)
	if players.size() <= 3:
		return []
	return players.slice(3, players.size())

static func substitute(active: Array, bench_players: Array, active_index: int, bench_index: int) -> Dictionary:
	if active_index < 0 or active_index >= active.size() or bench_index < 0 or bench_index >= bench_players.size():
		return {"changed":false,"active":active,"bench":bench_players}
	var next_active := active.duplicate(true)
	var next_bench := bench_players.duplicate(true)
	var outgoing = next_active[active_index]
	next_active[active_index] = next_bench[bench_index]
	next_bench[bench_index] = outgoing
	return {"changed":true,"active":next_active,"bench":next_bench}

static func training_cost(base_cost: int, skill: int) -> int:
	return maxi(0, base_cost + maxi(0, skill - 5) * 55)

static func train_player(player: Dictionary, funds: int, base_cost: int) -> Dictionary:
	var skill := int(player.get("skill", 1))
	if skill >= 10:
		return {"changed":false,"player":player,"funds":funds,"reason":"MAX_SKILL"}
	var cost := training_cost(base_cost, skill)
	if funds < cost:
		return {"changed":false,"player":player,"funds":funds,"reason":"INSUFFICIENT_FUNDS"}
	var next := player.duplicate(true)
	next["skill"] = skill + 1
	return {"changed":true,"player":next,"funds":funds - cost,"reason":"TRAINED"}

static func medical_cost(base_cost: int, injury_matches: int) -> int:
	return maxi(0, base_cost + maxi(0, injury_matches - 1) * 80)

static func treat_player(player: Dictionary, funds: int, base_cost: int) -> Dictionary:
	var injury_matches := int(player.get("injury_matches", 0))
	if injury_matches <= 0:
		return {"changed":false,"player":player,"funds":funds,"reason":"HEALTHY"}
	var cost := medical_cost(base_cost, injury_matches)
	if funds < cost:
		return {"changed":false,"player":player,"funds":funds,"reason":"INSUFFICIENT_FUNDS"}
	var next := player.duplicate(true)
	next["injury_matches"] = maxi(0, injury_matches - 1)
	return {"changed":true,"player":next,"funds":funds - cost,"reason":"TREATED"}

static func recover_between_matches(player: Dictionary) -> Dictionary:
	var next := player.duplicate(true)
	next["injury_matches"] = maxi(0, int(next.get("injury_matches", 0)) - 1)
	return next
