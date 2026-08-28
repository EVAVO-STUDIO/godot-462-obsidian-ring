extends Node

const DisciplineRules = preload("res://scripts/discipline_rules.gd")
const LeagueRules = preload("res://scripts/league_rules.gd")
const PlayoffRules = preload("res://scripts/playoff_rules.gd")
const SAVE_PATH := "user://obsidian_ring_postseason.json"
const SAVE_VERSION := 2
const USER_TEAM_ID := "jaguar_house"

var _last_home_fouls := 0
var _last_away_fouls := 0
var _last_match_number := 1
var _last_phase := -1
var _loaded_scene_id := 0
var _semifinal_winners: Array = []
var _champion_id := ""
var _championship_purse_paid := false

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	if _loaded_scene_id != scene_id:
		_load_state()
		_last_home_fouls = int(scene.get("home_fouls"))
		_last_away_fouls = int(scene.get("away_fouls"))
		_last_match_number = int(scene.get("match_number"))
		_last_phase = int(scene.get("phase"))
		_loaded_scene_id = scene_id

	_apply_new_bookings(scene)
	_service_old_suspensions(scene)
	_capture_postseason_result(scene)
	_apply_postseason_identity(scene)

	_last_home_fouls = int(scene.get("home_fouls"))
	_last_away_fouls = int(scene.get("away_fouls"))
	_last_match_number = int(scene.get("match_number"))
	_last_phase = int(scene.get("phase"))

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for required in ["home_fouls", "away_fouls", "match_number", "league_table", "roster_state", "home_players", "away_players", "phase", "funds"]:
		if not names.has(required):
			return false
	return true

func _league_config(scene: Object) -> Dictionary:
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return {}
	return league_data.get("league", {})

func _playoff_config(scene: Object) -> Dictionary:
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return {}
	return league_data.get("playoffs", {})

func _apply_new_bookings(scene: Object) -> void:
	var home_fouls := int(scene.get("home_fouls"))
	var away_fouls := int(scene.get("away_fouls"))
	if home_fouls > _last_home_fouls:
		var players: Array = scene.get("home_players")
		var controlled := clampi(int(scene.get("controlled_home_index")), 0, maxi(0, players.size() - 1))
		if not players.is_empty():
			_apply_booking_to_roster(scene, str(players[controlled].get("id", "")), 1)
	if away_fouls > _last_away_fouls:
		var players: Array = scene.get("away_players")
		if not players.is_empty():
			var index := _nearest_away_tackler_index(scene, players)
			_apply_booking_to_roster(scene, str(players[index].get("id", "")), 1)

func _nearest_away_tackler_index(scene: Object, players: Array) -> int:
	if players.is_empty():
		return 0
	var target := Vector2.ZERO
	var home_players: Array = scene.get("home_players")
	var possession_team := int(scene.get("possession_team")) if _has_property(scene, "possession_team") else 0
	var possession_index := int(scene.get("possession_index")) if _has_property(scene, "possession_index") else -1
	if possession_team == 1 and possession_index >= 0 and possession_index < home_players.size():
		target = home_players[possession_index].get("position", Vector2.ZERO)
	elif not home_players.is_empty():
		var controlled := clampi(int(scene.get("controlled_home_index")), 0, home_players.size() - 1)
		target = home_players[controlled].get("position", Vector2.ZERO)
	var best_index := 0
	var best_distance := INF
	for i in range(players.size()):
		var position: Vector2 = players[i].get("position", Vector2.ZERO)
		var distance := position.distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _apply_booking_to_roster(scene: Object, player_id: String, points: int) -> void:
	if player_id == "":
		return
	var rosters: Array = scene.get("roster_state")
	for ri in range(rosters.size()):
		var roster: Dictionary = rosters[ri]
		var players: Array = roster.get("players", [])
		for pi in range(players.size()):
			var player: Dictionary = players[pi]
			if str(player.get("id", "")) != player_id:
				continue
			var before_suspension := int(player.get("suspension_matches", 0))
			player = DisciplineRules.apply_booking(player, points)
			if int(player.get("suspension_matches", 0)) > before_suspension:
				player["suspension_until_round"] = int(scene.get("match_number")) + 1
			players[pi] = player
			roster["players"] = players
			rosters[ri] = roster
			scene.set("roster_state", rosters)
			var status := "%s BOOKED" % str(player.get("name", "PLAYER")).to_upper()
			if int(player.get("suspension_matches", 0)) > before_suspension:
				status = "%s SUSPENDED" % str(player.get("name", "PLAYER")).to_upper()
			scene.set("status_text", status)
			scene.set("status_timer", 1.6)
			return

func _service_old_suspensions(scene: Object) -> void:
	var round_no := int(scene.get("match_number"))
	if round_no == _last_match_number:
		return
	var rosters: Array = scene.get("roster_state")
	var changed := false
	for ri in range(rosters.size()):
		var roster: Dictionary = rosters[ri]
		var players: Array = roster.get("players", [])
		for pi in range(players.size()):
			var player: Dictionary = players[pi]
			var suspension := int(player.get("suspension_matches", 0))
			var until_round := int(player.get("suspension_until_round", -1))
			if suspension > 0 and until_round >= 0 and round_no > until_round:
				player = DisciplineRules.serve_round(player)
				if int(player.get("suspension_matches", 0)) <= 0:
					player.erase("suspension_until_round")
				players[pi] = player
				changed = true
		roster["players"] = players
		rosters[ri] = roster
	if changed:
		scene.set("roster_state", rosters)

func _capture_postseason_result(scene: Object) -> void:
	var phase := int(scene.get("phase"))
	if _last_phase == phase or phase != 2:
		return
	var league_cfg := _league_config(scene)
	var season_rounds := maxi(1, int(league_cfg.get("season_rounds", 10)))
	var semifinal_round := season_rounds + 1
	var final_round := season_rounds + 2
	var round_no := int(scene.get("match_number"))
	if round_no < semifinal_round or round_no > final_round:
		return
	var home_id := str(scene.get("home_team_id"))
	var away_id := str(scene.get("away_team_id"))
	var table := LeagueRules.sorted_table(scene.get("league_table"))
	var home_row := _table_row(table, home_id)
	var away_row := _table_row(table, away_id)
	var winner := PlayoffRules.winner_id(home_row, away_row, int(scene.get("home_score")), int(scene.get("away_score")))
	if round_no == semifinal_round:
		if winner not in _semifinal_winners:
			_semifinal_winners.append(winner)
		var other := _other_semifinal_winner(table, winner)
		if other != "" and other not in _semifinal_winners:
			_semifinal_winners.append(other)
	elif round_no == final_round:
		_champion_id = winner
		_award_championship_purse(scene)
	_save_state()

func _award_championship_purse(scene: Object) -> void:
	if _championship_purse_paid or _champion_id != USER_TEAM_ID:
		return
	var cfg := _playoff_config(scene)
	var purse := maxi(0, int(cfg.get("championship_purse", 0)))
	if purse > 0:
		scene.set("funds", int(scene.get("funds")) + purse)
		scene.set("status_text", "CHAMPIONS +%d" % purse)
		scene.set("status_timer", 999.0)
	_championship_purse_paid = true

func _apply_postseason_identity(scene: Object) -> void:
	var league_cfg := _league_config(scene)
	var playoff_cfg := _playoff_config(scene)
	if not bool(playoff_cfg.get("enabled", true)):
		return
	var round_no := int(scene.get("match_number"))
	var season_rounds := maxi(1, int(league_cfg.get("season_rounds", 10)))
	if round_no <= season_rounds:
		return
	var table := LeagueRules.sorted_table(scene.get("league_table"))
	var semifinal_round := season_rounds + 1
	var final_round := season_rounds + 2
	if round_no == semifinal_round:
		var pair := _user_semifinal(table, int(league_cfg.get("playoff_teams", 4)))
		if pair.is_empty():
			scene.set("status_text", "SEASON COMPLETE - NO PLAYOFF BERTH")
			scene.set("status_timer", 999.0)
			return
		_apply_pair(scene, pair, "SEMIFINAL")
	elif round_no == final_round:
		if USER_TEAM_ID not in _semifinal_winners:
			scene.set("status_text", "SEASON COMPLETE - SEMIFINAL EXIT")
			scene.set("status_timer", 999.0)
			return
		var final_pair := PlayoffRules.final_pairing(_semifinal_winners, table)
		if not final_pair.is_empty():
			_apply_pair(scene, final_pair, "CHAMPIONSHIP")
	elif _champion_id != "":
		var champion := _table_row(table, _champion_id)
		scene.set("status_text", "CHAMPION: %s" % str(champion.get("name", _champion_id)).to_upper())
		scene.set("status_timer", 999.0)

func _user_semifinal(table: Array, playoff_teams: int) -> Dictionary:
	for pair in PlayoffRules.semifinal_pairings(table, playoff_teams):
		if str(pair["home"].get("id", "")) == USER_TEAM_ID or str(pair["away"].get("id", "")) == USER_TEAM_ID:
			return pair
	return {}

func _other_semifinal_winner(table: Array, known_winner: String) -> String:
	for pair in PlayoffRules.semifinal_pairings(table, 4):
		var home_id := str(pair["home"].get("id", ""))
		var away_id := str(pair["away"].get("id", ""))
		if known_winner == home_id or known_winner == away_id or home_id == USER_TEAM_ID or away_id == USER_TEAM_ID:
			continue
		return PlayoffRules.winner_id(pair["home"], pair["away"], 0, 0)
	return ""

func _apply_pair(scene: Object, pair: Dictionary, label: String) -> void:
	var home_id := str(pair["home"].get("id", ""))
	var away_id := str(pair["away"].get("id", ""))
	var opponent_id := away_id if home_id == USER_TEAM_ID else home_id
	var teams: Array = scene.get("teams")
	var opponent_name := opponent_id
	for team in teams:
		if str(team.get("id", "")) == opponent_id:
			opponent_name = str(team.get("name", opponent_id)).to_upper()
			break
	scene.set("fixture_home_id", home_id)
	scene.set("fixture_away_id", away_id)
	scene.set("home_team_id", USER_TEAM_ID)
	scene.set("away_team_id", opponent_id)
	scene.set("away_team_name", opponent_name)
	scene.set("status_text", "%s - %s" % [label, opponent_name])
	scene.set("status_timer", 999.0)

func _table_row(table: Array, id: String) -> Dictionary:
	for row in table:
		if str(row.get("id", "")) == id:
			return row
	return {"id": id, "name": id, "for": 0, "against": 0}

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"semifinal_winners": _semifinal_winners,
		"champion_id": _champion_id,
		"championship_purse_paid": _championship_purse_paid
	}, "  "))

func _load_state() -> void:
	_semifinal_winners.clear()
	_champion_id = ""
	_championship_purse_paid = false
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var version := int(parsed.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		return
	var winners = parsed.get("semifinal_winners", [])
	if typeof(winners) == TYPE_ARRAY:
		for winner in winners:
			var id := str(winner)
			if id != "" and id not in _semifinal_winners:
				_semifinal_winners.append(id)
	_champion_id = str(parsed.get("champion_id", ""))
	_championship_purse_paid = bool(parsed.get("championship_purse_paid", false))

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
