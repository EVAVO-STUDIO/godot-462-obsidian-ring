extends Node

const CourtHazardRules = preload("res://scripts/court_hazard_rules.gd")
const COURT_TOP := 62.0
const COURT_BOTTOM := 312.0

func _ready() -> void:
	process_priority = 120

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var court := _active_court(scene)
	if court.is_empty():
		return
	scene.set("wall_rebound", CourtHazardRules.effective_rebound(court, float(scene.get("wall_rebound"))))
	if int(scene.get("phase")) != 1:
		return
	_apply_low_friction(scene, court, delta)
	_apply_narrow_sidelines(scene, court)

func _supports(scene: Object) -> bool:
	var required := ["phase", "teams", "courts", "fixture_home_id", "wall_rebound", "ball_velocity", "possession_team", "home_players", "away_players"]
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in required:
		if not names.has(name):
			return false
	return true

func _active_court(scene: Object) -> Dictionary:
	var home_id := str(scene.get("fixture_home_id"))
	var court_id := ""
	for team in scene.get("teams"):
		if str(team.get("id", "")) == home_id:
			court_id = str(team.get("home_court", ""))
			break
	if court_id == "":
		return {}
	for court in scene.get("courts"):
		if str(court.get("id", "")) == court_id:
			return court
	return {}

func _apply_low_friction(scene: Object, court: Dictionary, delta: float) -> void:
	if int(scene.get("possession_team")) != 0:
		return
	var compensation := CourtHazardRules.low_friction_drag_compensation(court)
	if compensation <= 0.0:
		return
	var velocity: Vector2 = scene.get("ball_velocity")
	if velocity.length_squared() <= 0.01:
		return
	var next_speed := minf(520.0, velocity.length() + compensation * delta)
	scene.set("ball_velocity", velocity.normalized() * next_speed)

func _apply_narrow_sidelines(scene: Object, court: Dictionary) -> void:
	var margin := CourtHazardRules.vertical_margin(court)
	if margin <= 12.0:
		return
	for property_name in ["home_players", "away_players"]:
		var players: Array = scene.get(property_name)
		for i in range(players.size()):
			var player: Dictionary = players[i]
			var position: Vector2 = player.get("position", Vector2.ZERO)
			position.y = clampf(position.y, COURT_TOP + margin, COURT_BOTTOM - margin)
			player["position"] = position
			players[i] = player
		scene.set(property_name, players)
