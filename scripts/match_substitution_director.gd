extends Node

const RosterRules = preload("res://scripts/roster_rules.gd")
const USER_TEAM_ID := "jaguar_house"
const SUBSTITUTIONS_PER_MATCH := 2

var _scene_id := 0
var _match_number := -1
var _was_playing := false
var _remaining := SUBSTITUTIONS_PER_MATCH
var _used_player_ids: Dictionary = {}
var _last_emergency_attempt_key := ""

func _ready() -> void:
	if not InputMap.has_action("substitute_live"):
		InputMap.add_action("substitute_live")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_V
	if not InputMap.action_has_event("substitute_live", event):
		InputMap.action_add_event("substitute_live", event)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	var match_number := int(scene.get("match_number"))
	var playing := int(scene.get("phase")) == 1
	if scene_id != _scene_id or match_number != _match_number or (playing and not _was_playing):
		_scene_id = scene_id
		_match_number = match_number
		_remaining = SUBSTITUTIONS_PER_MATCH
		_used_player_ids.clear()
		_last_emergency_attempt_key = ""
	_was_playing = playing
	if not playing or _remaining <= 0:
		return
	if Input.is_action_just_pressed("substitute_live"):
		var active: Array = scene.get("home_players")
		if not active.is_empty():
			_substitute_player(scene, clampi(int(scene.get("controlled_home_index")), 0, active.size() - 1), false)

func _supports(scene: Object) -> bool:
	var required := ["phase", "match_number", "home_players", "roster_state", "controlled_home_index", "home_team_id"]
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in required:
		if not names.has(name):
			return false
	return scene.has_method("_make_player") and scene.has_method("_team_for_id")

func request_emergency_substitution(scene: Object, active_index: int) -> bool:
	if scene == null or not _supports(scene) or int(scene.get("phase")) != 1 or _remaining <= 0:
		return false
	var active: Array = scene.get("home_players")
	if active_index < 0 or active_index >= active.size():
		return false
	var outgoing_id := str(active[active_index].get("id", ""))
	var attempt_key := "%d:%s" % [int(scene.get("match_number")), outgoing_id]
	if attempt_key == _last_emergency_attempt_key:
		return false
	_last_emergency_attempt_key = attempt_key
	return _substitute_player(scene, active_index, true)

func _substitute_player(scene: Object, active_index: int, emergency: bool) -> bool:
	var active: Array = scene.get("home_players")
	if active.is_empty() or active_index < 0 or active_index >= active.size() or _remaining <= 0:
		return false
	var outgoing: Dictionary = active[active_index]
	var roster := RosterRules.roster_for_team(scene.get("roster_state"), USER_TEAM_ID)
	var bench := RosterRules.bench(roster)
	var active_ids: Dictionary = {}
	for player in active:
		active_ids[str(player.get("id", ""))] = true
	var candidate := RosterRules.best_substitute_candidate(
		bench,
		active_ids,
		_used_player_ids,
		str(outgoing.get("role", ""))
	)
	if candidate.is_empty():
		if not emergency:
			_set_status(scene, "NO ELIGIBLE SUBSTITUTE")
		return false

	_persist_outgoing_injury(scene, outgoing)
	var position: Vector2 = outgoing.get("position", Vector2(205, 190))
	var team: Dictionary = scene.call("_team_for_id", str(scene.get("home_team_id")))
	var replacement: Dictionary = scene.call("_make_player", position, candidate, team)
	active[active_index] = replacement
	scene.set("home_players", active)
	_used_player_ids[str(candidate.get("id", ""))] = true
	_used_player_ids[str(outgoing.get("id", ""))] = true
	_remaining -= 1
	var prefix := "AUTO SUB" if emergency else "SUB"
	_set_status(scene, "%s %s FOR %s  %d LEFT" % [prefix, str(candidate.get("name", "PLAYER")).to_upper(), str(outgoing.get("name", "PLAYER")).to_upper(), _remaining])
	return true

func _persist_outgoing_injury(scene: Object, outgoing: Dictionary) -> void:
	var injury_seconds := float(outgoing.get("injured", 0.0))
	if injury_seconds <= 0.0:
		return
	var player_id := str(outgoing.get("id", ""))
	if player_id == "":
		return
	var injury_matches := clampi(int(ceil(injury_seconds / 6.0)), 1, 3)
	var rosters: Array = scene.get("roster_state")
	for ri in range(rosters.size()):
		var roster = rosters[ri]
		if typeof(roster) != TYPE_DICTIONARY or str(roster.get("team_id", "")) != USER_TEAM_ID:
			continue
		var players: Array = roster.get("players", [])
		for pi in range(players.size()):
			var spec = players[pi]
			if typeof(spec) != TYPE_DICTIONARY or str(spec.get("id", "")) != player_id:
				continue
			spec["injury_matches"] = maxi(int(spec.get("injury_matches", 0)), injury_matches)
			players[pi] = spec
			roster["players"] = players
			rosters[ri] = roster
			scene.set("roster_state", rosters)
			return

func remaining_substitutions() -> int:
	return _remaining

func _set_status(scene: Object, message: String) -> void:
	if _has_property(scene, "status_text"):
		scene.set("status_text", message)
	if _has_property(scene, "status_timer"):
		scene.set("status_timer", 2.0)

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
