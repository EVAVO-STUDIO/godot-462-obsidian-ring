class_name RosterRules
extends RefCounted

static func roster_for_team(rosters: Array, team_id: String) -> Dictionary:
	for roster in rosters:
		if str(roster.get("team_id", "")) == team_id:
			return roster
	return {}

static func _available(player: Dictionary) -> bool:
	return int(player.get("injury_matches", 0)) <= 0 and int(player.get("suspension_matches", 0)) <= 0

static func ordered_players(roster: Dictionary) -> Array:
	var available: Array = []
	var unavailable: Array = []
	for player in roster.get("players", []):
		if _available(player):
			available.append(player)
		else:
			unavailable.append(player)
	available.sort_custom(func(a, b): return int(a.get("skill", 1)) > int(b.get("skill", 1)))
	unavailable.sort_custom(func(a, b):
		var a_wait := int(a.get("injury_matches", 0)) + int(a.get("suspension_matches", 0))
		var b_wait := int(b.get("injury_matches", 0)) + int(b.get("suspension_matches", 0))
		return a_wait < b_wait
	)
	return available + unavailable

static func active_three(roster: Dictionary) -> Array:
	var ordered := ordered_players(roster)
	var active: Array = []
	var used_ids: Dictionary = {}
	for preferred_role in ["guard", "striker", "runner"]:
		for player in ordered:
			if active.size() >= 3:
				break
			var player_id := str(player.get("id", ""))
			if used_ids.has(player_id) or not _available(player):
				continue
			if str(player.get("role", "")) == preferred_role:
				active.append(player)
				used_ids[player_id] = true
				break
	for player in ordered:
		if active.size() >= 3:
			break
		var player_id := str(player.get("id", ""))
		if not used_ids.has(player_id) and _available(player):
			active.append(player)
			used_ids[player_id] = true
	return active

static func bench(roster: Dictionary) -> Array:
	var active := active_three(roster)
	var active_ids: Dictionary = {}
	for player in active:
		active_ids[str(player.get("id", ""))] = true
	var result: Array = []
	for player in ordered_players(roster):
		if not active_ids.has(str(player.get("id", ""))):
			result.append(player)
	return result

static func best_substitute_candidate(bench_players: Array, active_ids: Dictionary, used_ids: Dictionary, preferred_role: String) -> Dictionary:
	var role_match: Dictionary = {}
	var fallback: Dictionary = {}
	for spec in bench_players:
		var id := str(spec.get("id", ""))
		if id == "" or active_ids.has(id) or used_ids.has(id) or not _available(spec):
			continue
		if fallback.is_empty() or int(spec.get("skill", 1)) > int(fallback.get("skill", 1)):
			fallback = spec
		if str(spec.get("role", "")) == preferred_role:
			if role_match.is_empty() or int(spec.get("skill", 1)) > int(role_match.get("skill", 1)):
				role_match = spec
	return role_match if not role_match.is_empty() else fallback

static func substitute(active: Array, bench_players: Array, active_index: int, bench_index: int) -> Dictionary:
	if active_index < 0 or active_index >= active.size() or bench_index < 0 or bench_index >= bench_players.size():
		return {"changed":false,"active":active,"bench":bench_players,"reason":"INVALID_SELECTION"}
	var incoming: Dictionary = bench_players[bench_index]
	if int(incoming.get("injury_matches", 0)) > 0:
		return {"changed":false,"active":active,"bench":bench_players,"reason":"PLAYER_INJURED"}
	if int(incoming.get("suspension_matches", 0)) > 0:
		return {"changed":false,"active":active,"bench":bench_players,"reason":"PLAYER_SUSPENDED"}
	var next_active := active.duplicate(true)
	var next_bench := bench_players.duplicate(true)
	var outgoing = next_active[active_index]
	next_active[active_index] = incoming
	next_bench[bench_index] = outgoing
	return {"changed":true,"active":next_active,"bench":next_bench,"reason":"SUBSTITUTED"}

static func training_cost(base_cost: int, skill: int) -> int:
	return maxi(0, base_cost + maxi(0, skill - 5) * 55)

static func train_player(player: Dictionary, funds: int, base_cost: int) -> Dictionary:
	if int(player.get("injury_matches", 0)) > 0:
		return {"changed":false,"player":player,"funds":funds,"reason":"PLAYER_INJURED"}
	if int(player.get("suspension_matches", 0)) > 0:
		return {"changed":false,"player":player,"funds":funds,"reason":"PLAYER_SUSPENDED"}
	var skill := int(player.get("skill", 1))
	if skill >= 10:
		return {"changed":false,"player":player,"funds":funds,"reason":"MAX_SKILL"}
	var cost := training_cost(base_cost, skill)
	if funds < cost:
		return {"changed":false,"player":player,"funds":funds,"reason":"INSUFFICIENT_FUNDS"}
	var next := player.duplicate(true)
	next["skill"] = skill + 1
	return {"changed":true,"player":next,"funds":funds - cost,"reason":"TRAINED","cost":cost}

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
	return {"changed":true,"player":next,"funds":funds - cost,"reason":"TREATED","cost":cost}

static func recover_between_matches(player: Dictionary) -> Dictionary:
	var next := player.duplicate(true)
	next["injury_matches"] = maxi(0, int(next.get("injury_matches", 0)) - 1)
	return next

static func squad_strength(roster: Dictionary) -> float:
	var players := active_three(roster)
	if players.is_empty():
		return 0.0
	var total := 0.0
	for player in players:
		total += float(player.get("skill", 1))
	return total / float(players.size())
