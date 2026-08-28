extends Node

const CourtGeometryRules = preload("res://scripts/court_geometry_rules.gd")
const BASE_COURT := Rect2(70.0, 62.0, 500.0, 250.0)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene) or int(scene.get("phase")) != 1:
		return
	var court := _active_court(scene)
	if court.is_empty():
		return
	var rect := CourtGeometryRules.movement_rect(BASE_COURT, court)
	_clamp_team(scene, "home_players", rect)
	_clamp_team(scene, "away_players", rect)

func _active_court(scene: Object) -> Dictionary:
	var court_name := str(scene.get("court_name"))
	var courts: Array = scene.get("courts")
	for court in courts:
		if str(court.get("name", "")).to_upper() == court_name.to_upper():
			return court
	return {}

func _clamp_team(scene: Object, property_name: String, rect: Rect2) -> void:
	var players: Array = scene.get(property_name)
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var position: Vector2 = player.get("position", rect.get_center())
		player["position"] = CourtGeometryRules.clamp_player(position, rect)
		players[i] = player
	scene.set(property_name, players)

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for required in ["phase", "courts", "court_name", "home_players", "away_players"]:
		if not names.has(required):
			return false
	return true
