extends Node

const ConditionRules = preload("res://scripts/condition_rules.gd")

var _scene_id := 0
var _last_phase := -1

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	var phase := int(scene.get("phase"))
	if scene_id != _scene_id:
		_scene_id = scene_id
		_last_phase = phase
		return

	if phase == 1 and _last_phase != 1:
		_apply_starting_condition(scene)
	elif phase == 2 and _last_phase == 1:
		_capture_end_condition(scene)
	_last_phase = phase

func _supports(scene: Object) -> bool:
	var required := ["phase", "home_players", "away_players", "roster_state", "home_team_id", "away_team_id"]
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in required:
		if not names.has(name):
			return false
	return true

func _apply_starting_condition(scene: Object) -> void:
	_apply_team_start(scene, "home_players")
	_apply_team_start(scene, "away_players")

func _apply_team_start(scene: Object, property_name: String) -> void:
	var players: Array = scene.get(property_name)
	var carry_by_id := _carry_map(scene.get("roster_state"))
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var id := str(player.get("id", ""))
		player["stamina"] = ConditionRules.starting_stamina(int(carry_by_id.get(id, 0)))
		players[i] = player
	scene.set(property_name, players)

func _capture_end_condition(scene: Object) -> void:
	var played: Dictionary = {}
	_capture_live_team(scene.get("home_players"), played)
	_capture_live_team(scene.get("away_players"), played)
	var rosters: Array = scene.get("roster_state")
	for ri in range(rosters.size()):
		var roster: Dictionary = rosters[ri]
		var players: Array = roster.get("players", [])
		for pi in range(players.size()):
			var spec: Dictionary = players[pi]
			var id := str(spec.get("id", ""))
			if played.has(id):
				spec["fatigue_carry"] = ConditionRules.carry_from_end_stamina(float(played[id]))
			else:
				spec["fatigue_carry"] = ConditionRules.recover_bench_carry(int(spec.get("fatigue_carry", 0)))
			players[pi] = spec
		roster["players"] = players
		rosters[ri] = roster
	scene.set("roster_state", rosters)

func _capture_live_team(players, output: Dictionary) -> void:
	if typeof(players) != TYPE_ARRAY:
		return
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var id := str(player.get("id", ""))
		if id != "":
			output[id] = float(player.get("stamina", 100.0))

func _carry_map(rosters) -> Dictionary:
	var result: Dictionary = {}
	if typeof(rosters) != TYPE_ARRAY:
		return result
	for roster in rosters:
		if typeof(roster) != TYPE_DICTIONARY:
			continue
		for player in roster.get("players", []):
			if typeof(player) != TYPE_DICTIONARY:
				continue
			var id := str(player.get("id", ""))
			if id != "":
				result[id] = int(player.get("fatigue_carry", 0))
	return result
