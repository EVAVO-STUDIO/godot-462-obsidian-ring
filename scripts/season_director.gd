extends Node

const DisciplineRules = preload("res://scripts/discipline_rules.gd")
const LeagueRules = preload("res://scripts/league_rules.gd")
const PlayoffRules = preload("res://scripts/playoff_rules.gd")
const SAVE_PATH := "user://obsidian_ring_postseason.json"
const USER_TEAM_ID := "jaguar_house"

var _last_home_fouls := 0
var _last_away_fouls := 0
var _last_match_number := 1
var _last_phase := -1
var _loaded := false
var _semifinal_winners: Array = []
var _champion_id := ""

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	if not _loaded:
		_load_state()
		_last_home_fouls = int(scene.get("home_fouls"))
		_last_away_fouls = int(scene.get("away_fouls"))
		_last_match_number = int(scene.get("match_number"))
		_last_phase = int(scene.get("phase"))
		_loaded = true

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
	for required in ["home_fouls", "away_fouls", "match_number", "league_table", "roster_state", "home_players", "away_players", "phase"]:
		if not names.has(required):
			return false
	return true

func _league_config(scene: Object) -> Dictionary:
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return {}
	return league_data.get("league", {})

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
			var index := clampi(int(scene.get("possession_index")), 0, players.size() - 1)
			_apply_booking_to_roster(scene, str(players[index].get("id", "")), 1)

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
			if scene.has_method("set"):
				scene.set("status_text", "%s BOOKED" % str(player.get("name", "PLAYER")).to_upper())
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
	var round_no := int(scene.get("match_number"))
	if _last_phase == phase or phase != 2 or round_no < 11:
		return
	var home_id := str(scene.get("home_team_id"))
	var away_id := str(scene.get("away_team_id"))
	var table := LeagueRules.sorted_table(scene.get("league_table"))
	var home_row := _table_row(table, home_id)
	var away_row := _table_row(table, away_id)
	var winner := PlayoffRules.winner_id(home_row, away_row, int(scene.get("home_score")), int(scene.get("away_score")))
	if round_no == 11:
		if winner not in _semifinal_winners:
			_semifinal_winners.append(winner)
		var other := _other_semifinal_winner(table, winner)
		if other != "" and other not in _semifinal_winners:
			_semifinal_winners.append(other)
	elif round_no == 12:
		_champion_id = winner
	_save_state()

func _apply_postseason_identity(scene: Object) -> void:
	var cfg := _league_config(scene)
	if not bool(cfg.get("playoffs_enabled", true)):
		return
	var round_no := int(scene.get("match_number"))
	if round_no < 11:
		return
	var table := LeagueRules.sorted_table(scene.get("league_table"))
	if round_no == 11:
		var pair := _user_semifinal(table, int(cfg.get("playoff_teams", 4)))
		if pair.is_empty():
			scene.set("status_text", "SEASON COMPLETE - NO PLAYOFF BERTH")
			scene.set("status_timer", 999.0)
			return
		_apply_pair(scene, pair, "SEMIFINAL")
	elif round_no == 12:
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
	file.store_string(JSON.stringify({"version":1,"semifinal_winners":_semifinal_winners,"champion_id":_champion_id}, "  "))

func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != 1:
		return
	var winners = parsed.get("semifinal_winners", [])
	if typeof(winners) == TYPE_ARRAY:
		_semifinal_winners = winners
	_champion_id = str(parsed.get("champion_id", ""))
