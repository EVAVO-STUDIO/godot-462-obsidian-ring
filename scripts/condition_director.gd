extends Node

const ConditionRules = preload("res://scripts/condition_rules.gd")

var _scene_id := 0
var _last_phase := -1
var _played_stamina_by_id: Dictionary = {}
var _injury_seconds_by_id: Dictionary = {}

func _ready() -> void:
	process_priority = 150

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	var phase := int(scene.get("phase"))
	if scene_id != _scene_id:
		_scene_id = scene_id
		_last_phase = phase
		_played_stamina_by_id.clear()
		_injury_seconds_by_id.clear()
		return

	if phase == 1 and _last_phase != 1:
		_played_stamina_by_id.clear()
		_injury_seconds_by_id.clear()
		_apply_starting_condition(scene)
		_capture_participants(scene)
	elif phase == 1:
		_capture_participants(scene)
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

func _capture_participants(scene: Object) -> void:
	var home_players: Array = scene.get("home_players")
	var away_players: Array = scene.get("away_players")
	_played_stamina_by_id = ConditionRules.capture_stamina(_played_stamina_by_id, home_players)
	_played_stamina_by_id = ConditionRules.capture_stamina(_played_stamina_by_id, away_players)
	_capture_injuries(home_players)
	_capture_injuries(away_players)

func _capture_injuries(players: Array) -> void:
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var id := str(player.get("id", ""))
		if id == "":
			continue
		var injury_seconds := maxf(0.0, float(player.get("injured", 0.0)))
		if injury_seconds > float(_injury_seconds_by_id.get(id, 0.0)):
			_injury_seconds_by_id[id] = injury_seconds

func _capture_end_condition(scene: Object) -> void:
	_capture_participants(scene)
	var rosters: Array = scene.get("roster_state")
	for ri in range(rosters.size()):
		var roster: Dictionary = rosters[ri]
		var players: Array = roster.get("players", [])
		for pi in range(players.size()):
			var spec: Dictionary = players[pi]
			var id := str(spec.get("id", ""))
			if _played_stamina_by_id.has(id):
				spec["fatigue_carry"] = ConditionRules.carry_from_end_stamina(float(_played_stamina_by_id[id]))
			else:
				spec["fatigue_carry"] = ConditionRules.recover_bench_carry(int(spec.get("fatigue_carry", 0)))
			if _injury_seconds_by_id.has(id):
				var injury_seconds := float(_injury_seconds_by_id[id])
				if injury_seconds > 0.0:
					var injury_matches := clampi(int(ceil(injury_seconds / 6.0)), 1, 3)
					spec["injury_matches"] = maxi(int(spec.get("injury_matches", 0)), injury_matches)
			players[pi] = spec
		roster["players"] = players
		rosters[ri] = roster
	scene.set("roster_state", rosters)

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
