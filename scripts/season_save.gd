extends Node

const RosterSaveRules = preload("res://scripts/roster_save_rules.gd")
const SaveRecoveryRules = preload("res://scripts/save_recovery_rules.gd")
const SAVE_PATH := "user://obsidian_ring_season.json"
const BACKUP_PATH := "user://obsidian_ring_season.bak.json"
const SAVE_VERSION := 3
const MIN_SAVE_VERSION := 2
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
	var canonical = scene.get("roster_state")
	return RosterSaveRules.merge_rosters(canonical, saved)

func _postseason_snapshot() -> Dictionary:
	var director := get_node_or_null("/root/SeasonDirector")
	if director == null:
		return {"semifinal_winners": [], "champion_id": "", "championship_purse_paid": false}
	var winners = director.get("_semifinal_winners")
	return {
		"semifinal_winners": winners.duplicate(true) if typeof(winners) == TYPE_ARRAY else [],
		"champion_id": str(director.get("_champion_id")),
		"championship_purse_paid": bool(director.get("_championship_purse_paid"))
	}

func _sanitize_postseason(scene: Object, saved) -> Dictionary:
	var valid_ids := _valid_team_ids(scene)
	var winners: Array = []
	if typeof(saved) == TYPE_DICTIONARY:
		var raw_winners = saved.get("semifinal_winners", [])
		if typeof(raw_winners) == TYPE_ARRAY:
			for raw_id in raw_winners:
				var id := str(raw_id)
				if valid_ids.has(id) and id not in winners and winners.size() < 2:
					winners.append(id)
		var champion := str(saved.get("champion_id", ""))
		if champion != "" and not valid_ids.has(champion):
			champion = ""
		return {
			"semifinal_winners": winners,
			"champion_id": champion,
			"championship_purse_paid": bool(saved.get("championship_purse_paid", false)) and champion != ""
		}
	return {"semifinal_winners": [], "champion_id": "", "championship_purse_paid": false}

func _snapshot(scene: Object) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"funds": clampi(int(scene.get("funds")), 0, MAX_FUNDS),
		"match_number": maxi(1, int(scene.get("match_number"))),
		"league_table": scene.get("league_table"),
		"roster_state": scene.get("roster_state"),
		"postseason": _postseason_snapshot()
	}

func _signature(scene: Object) -> String:
	return JSON.stringify(_snapshot(scene))

func _save(scene: Object) -> void:
	var snapshot_text := JSON.stringify(_snapshot(scene), "  ")
	_backup_valid_primary()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Obsidian Ring season save could not be opened for writing.")
		return
	file.store_string(snapshot_text)

func _backup_valid_primary() -> void:
	var primary_text := _read_text(SAVE_PATH)
	if SaveRecoveryRules.parse_supported_json(primary_text, MIN_SAVE_VERSION, SAVE_VERSION).is_empty():
		return
	var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if backup != null:
		backup.store_string(primary_text)

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _restore(scene: Object) -> void:
	var chosen := SaveRecoveryRules.choose_primary_or_backup(
		_read_text(SAVE_PATH),
		_read_text(BACKUP_PATH),
		MIN_SAVE_VERSION,
		SAVE_VERSION
	)
	var parsed = chosen.get("data", {})
	if typeof(parsed) != TYPE_DICTIONARY or parsed.is_empty():
		return
	if str(chosen.get("source", "primary")) == "backup":
		push_warning("Obsidian Ring recovered season state from backup save.")
	var version := int(parsed.get("version", -1))
	scene.set("funds", clampi(int(parsed.get("funds", scene.get("funds"))), 0, MAX_FUNDS))
	var max_reasonable_round := _season_rounds(scene) + 3
	scene.set("match_number", clampi(int(parsed.get("match_number", scene.get("match_number"))), 1, max_reasonable_round))
	scene.set("league_table", _sanitize_table(scene, parsed.get("league_table", [])))
	scene.set("roster_state", _sanitize_rosters(scene, parsed.get("roster_state", [])))
	if version >= 3:
		var postseason := _sanitize_postseason(scene, parsed.get("postseason", {}))
		call_deferred("_restore_postseason_deferred", postseason)
	if scene.has_method("_apply_match_identity"):
		scene.call("_apply_match_identity")
	if scene.has_method("_prepare_match"):
		scene.call("_prepare_match")

func _restore_postseason_deferred(postseason: Dictionary) -> void:
	var director := get_node_or_null("/root/SeasonDirector")
	if director == null:
		return
	director.set("_semifinal_winners", postseason.get("semifinal_winners", []).duplicate(true))
	director.set("_champion_id", str(postseason.get("champion_id", "")))
	director.set("_championship_purse_paid", bool(postseason.get("championship_purse_paid", false)))
