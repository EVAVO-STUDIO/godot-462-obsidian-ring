extends Node

const LeagueRules = preload("res://scripts/league_rules.gd")
const SeasonEndRules = preload("res://scripts/season_end_rules.gd")

var _confirm_events: Array = []
var _confirm_blocked := false

func _ready() -> void:
	process_priority = -100

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		_restore_confirm()
		return
	var reason := _terminal_reason(scene)
	if reason == "":
		_restore_confirm()
		return
	_block_confirm()
	scene.set("status_text", SeasonEndRules.terminal_message(reason))
	scene.set("status_timer", 999.0)

func _supports(scene: Object) -> bool:
	var required := ["match_number", "league_table", "league", "status_text", "status_timer"]
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in required:
		if not names.has(name):
			return false
	return true

func _terminal_reason(scene: Object) -> String:
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return ""
	var league_cfg: Dictionary = league_data.get("league", {})
	var season_rounds := maxi(1, int(league_cfg.get("season_rounds", 10)))
	var playoff_teams := maxi(0, int(league_cfg.get("playoff_teams", 4)))
	var table := LeagueRules.sorted_table(scene.get("league_table"))
	var semifinal_winners: Array = []
	var champion_id := ""
	var season_director := get_node_or_null("/root/SeasonDirector")
	if season_director != null:
		var winners = season_director.get("_semifinal_winners")
		if typeof(winners) == TYPE_ARRAY:
			semifinal_winners = winners
		champion_id = str(season_director.get("_champion_id"))
	return SeasonEndRules.terminal_reason(int(scene.get("match_number")), season_rounds, table, playoff_teams, semifinal_winners, champion_id)

func _block_confirm() -> void:
	if _confirm_blocked or not InputMap.has_action("confirm"):
		return
	_confirm_events = InputMap.action_get_events("confirm").duplicate()
	InputMap.action_erase_events("confirm")
	_confirm_blocked = true

func _restore_confirm() -> void:
	if not _confirm_blocked:
		return
	if not InputMap.has_action("confirm"):
		InputMap.add_action("confirm")
	for event in _confirm_events:
		InputMap.action_add_event("confirm", event)
	_confirm_events.clear()
	_confirm_blocked = false
