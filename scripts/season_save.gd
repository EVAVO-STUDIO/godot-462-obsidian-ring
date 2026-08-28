extends Node

const SAVE_PATH := "user://obsidian_ring_season.json"
const SAVE_VERSION := 2
const SAVE_INTERVAL := 1.0
const MAX_FUNDS := 99999999

var _restored_scene_id := 0
var _timer := 0.0
var _last_signature := ""

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports_season_state(scene):
		return
	var scene_id := scene.get_instance_id()
	if _restored_scene_id != scene_id:
		_restore(scene)
		_restored_scene_id = scene_id
		_last_signature = _signature(scene)
		_timer = 0.0
		return
	_timer += delta
	if _timer < SAVE_INTERVAL:
		return
	_timer = 0.0
	var signature := _signature(scene)
	if signature != _last_signature:
		_save(scene)
		_last_signature = signature

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var scene := get_tree().current_scene
		if scene != null and _supports_season_state(scene):
			_save(scene)

func _supports_season_state(scene: Object) -> bool:
	var required := ["funds", "match_number", "league_table", "roster_state"]
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in required:
		if not names.has(name):
			return false
	return true

func _season_rounds(scene: Object) -> int:
	var league_data = scene.get("league")
	if typeof(league_data) == TYPE_DICTIONARY:
		return maxi(1, int(league_data.get("league", {}).get("season_rounds", 10)))
	return 10

func _valid_team_ids(scene: Object) -> Dictionary:
	var result: Dictionary = {}
	var teams = scene.get("teams")
	if typeof(teams) == TYPE_ARRAY:
		for team in teams:
			if typeof(team) == TYPE_DICTIONARY:
				var id := str(team.get("id", ""))
				if id != "":
					result[id] = true
	return result

func _valid_player_ids(scene: Object) -> Dictionary:
	var result: Dictionary = {}
	var rosters = scene.get("roster_state")
	if typeof(rosters) != TYPE_ARRAY:
		return result
	for roster in rosters:
		if typeof(roster) != TYPE_DICTIONARY:
			continue
		for player in roster.get("players", []):
			if typeof(player) == TYPE_DICTIONARY:
				var id := str(player.get("id", ""))
				if id != "":
					result[id] = true
	return result

func _sanitize_table(scene: Object, saved) -> Array:
	if typeof(saved) != TYPE_ARRAY:
		return scene.get("league_table")
	var valid_ids := _valid_team_ids(scene)
	var result: Array = []
	var seen: Dictionary = {}
	for row in saved:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var id := str(row.get("id", ""))
		if not valid_ids.has(id) or seen.has(id):
			continue
		seen[id] = true
		var next := row.duplicate(true)
		for key in ["played", "wins", "draws", "losses", "for", "against", "points"]:
			next[key] = maxi(0, int(next.get(key, 0)))
		result.append(next)
	return result if result.size() == valid_ids.size() else scene.get("league_table")

func _sanitize_rosters(scene: Object, saved) -> Array:
	if typeof(saved) != TYPE_ARRAY:
		return scene.get("roster_state")
	var valid_team_ids := _valid_team_ids(scene)
	var current_players := _valid_player_ids(scene)
	var result: Array = []
	var seen_teams: Dictionary = {}
	var seen_players: Dictionary = {}
	for roster in saved:
		if typeof(roster) != TYPE_DICTIONARY:
			continue
		var team_id := str(roster.get("team_id", ""))
		if not valid_team_ids.has(team_id) or seen_teams.has(team_id):
			continue
		var next_players: Array = []
		for player in roster.get("players", []):
			if typeof(player) != TYPE_DICTIONARY:
				continue
			var id := str(player.get("id", ""))
			if not current_players.has(id) or seen_players.has(id):
				continue
			seen_players[id] = true
			var next := player.duplicate(true)
			next["skill"] = clampi(int(next.get("skill", 1)), 1, 10)
			next["injury_matches"] = maxi(0, int(next.get("injury_matches", 0)))
			next["suspension_matches"] = maxi(0, int(next.get("suspension_matches", 0)))
			next["booking_points"] = maxi(0, int(next.get("booking_points", 0)))
			next["suspensions_served"] = maxi(0, int(next.get("suspensions_served", 0)))
			next_players.append(next)
		if next_players.size() < 3:
			continue
		seen_teams[team_id] = true
		result.append({"team_id": team_id, "players": next_players})
	return result if result.size() == valid_team_ids.size() else scene.get("roster_state")

func _snapshot(scene: Object) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"funds": clampi(int(scene.get("funds")), 0, MAX_FUNDS),
		"match_number": maxi(1, int(scene.get("match_number"))),
		"league_table": scene.get("league_table"),
		"roster_state": scene.get("roster_state")
	}

func _signature(scene: Object) -> String:
	return JSON.stringify(_snapshot(scene))

func _save(scene: Object) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Obsidian Ring season save could not be opened for writing.")
		return
	file.store_string(JSON.stringify(_snapshot(scene), "  "))

func _restore(scene: Object) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("Obsidian Ring save ignored because it is invalid or from an unsupported version.")
		return
	scene.set("funds", clampi(int(parsed.get("funds", scene.get("funds"))), 0, MAX_FUNDS))
	var max_reasonable_round := _season_rounds(scene) + 3
	scene.set("match_number", clampi(int(parsed.get("match_number", scene.get("match_number"))), 1, max_reasonable_round))
	scene.set("league_table", _sanitize_table(scene, parsed.get("league_table", [])))
	scene.set("roster_state", _sanitize_rosters(scene, parsed.get("roster_state", [])))
	if scene.has_method("_apply_match_identity"):
		scene.call("_apply_match_identity")
	if scene.has_method("_prepare_match"):
		scene.call("_prepare_match")
