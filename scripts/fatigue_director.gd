extends Node

const LOW_STAMINA_THRESHOLD := 24.0
const CRITICAL_STAMINA_THRESHOLD := 8.0
const MIN_PERFORMANCE_MULT := 0.72

var _scene_id := 0
var _last_match_number := -1

func _ready() -> void:
	# ConditionDirector runs at 150 and must apply carried starting stamina first.
	process_priority = 170

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	if scene_id != _scene_id:
		_scene_id = scene_id
		_last_match_number = int(scene.get("match_number"))
	if int(scene.get("phase")) != 1:
		return
	_apply_team_fatigue(scene, "home_players")
	_apply_team_fatigue(scene, "away_players")
	_try_emergency_home_sub(scene)
	_last_match_number = int(scene.get("match_number"))

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for required in ["phase", "home_players", "away_players", "controlled_home_index", "roster_state", "home_team_id", "match_number"]:
		if not names.has(required):
			return false
	return true

func _apply_team_fatigue(scene: Object, property_name: String) -> void:
	var players: Array = scene.get(property_name)
	for i in range(players.size()):
		var player: Dictionary = players[i]
		_capture_base_stats(player)
		var stamina := clampf(float(player.get("stamina", 100.0)), 0.0, 100.0)
		var factor := _performance_factor(stamina)
		player["fatigue_factor"] = factor
		for stat in ["speed_mult", "tackle_mult", "passing_mult", "shooting_mult"]:
			var base_key := "base_%s" % stat
			player[stat] = float(player.get(base_key, player.get(stat, 1.0))) * factor
		players[i] = player
	scene.set(property_name, players)

func _capture_base_stats(player: Dictionary) -> void:
	for stat in ["speed_mult", "tackle_mult", "passing_mult", "shooting_mult"]:
		var base_key := "base_%s" % stat
		if not player.has(base_key):
			player[base_key] = float(player.get(stat, 1.0))

func _performance_factor(stamina: float) -> float:
	if stamina >= LOW_STAMINA_THRESHOLD:
		return 1.0
	var t := clampf(stamina / LOW_STAMINA_THRESHOLD, 0.0, 1.0)
	return lerpf(MIN_PERFORMANCE_MULT, 1.0, t)

func _try_emergency_home_sub(scene: Object) -> void:
	var players: Array = scene.get("home_players")
	if players.is_empty():
		return
	var index := clampi(int(scene.get("controlled_home_index")), 0, players.size() - 1)
	var current: Dictionary = players[index]
	if float(current.get("stamina", 100.0)) > CRITICAL_STAMINA_THRESHOLD and float(current.get("injured", 0.0)) <= 0.0:
		return
	var substitution_director := get_node_or_null("/root/MatchSubstitutionDirector")
	if substitution_director == null or not substitution_director.has_method("request_emergency_substitution"):
		return
	substitution_director.call("request_emergency_substitution", scene, index)

func performance_factor_for_stamina(stamina: float) -> float:
	return _performance_factor(stamina)
