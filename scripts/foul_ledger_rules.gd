class_name FoulLedgerRules
extends RefCounted

static func controlled_actor(players: Array, controlled_index: int) -> Dictionary:
	if players.is_empty():
		return {}
	var index := clampi(controlled_index, 0, players.size() - 1)
	var player = players[index]
	return player if typeof(player) == TYPE_DICTIONARY else {}

static func ai_tackler_actor(away_players: Array, home_players: Array, possession_team: int, possession_index: int, controlled_home_index: int) -> Dictionary:
	if away_players.is_empty():
		return {}
	var target := Vector2.ZERO
	if possession_team == 1 and possession_index >= 0 and possession_index < home_players.size():
		target = home_players[possession_index].get("position", Vector2.ZERO)
	elif not home_players.is_empty():
		var controlled := clampi(controlled_home_index, 0, home_players.size() - 1)
		target = home_players[controlled].get("position", Vector2.ZERO)
	var best: Dictionary = away_players[0]
	var best_distance := INF
	for player in away_players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var position: Vector2 = player.get("position", Vector2.ZERO)
		var distance := position.distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best

static func make_event(team: String, actor: Dictionary, round_no: int, serial: int) -> Dictionary:
	return {
		"serial": maxi(1, serial),
		"round": maxi(1, round_no),
		"team": team,
		"actor_id": str(actor.get("id", "")),
		"actor_name": str(actor.get("name", actor.get("id", "PLAYER"))).to_upper()
	}
