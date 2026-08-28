extends Node

const FoulLedgerRules = preload("res://scripts/foul_ledger_rules.gd")
const MAX_EVENTS := 24

var events: Array = []
var last_home_actor_id := ""
var last_away_actor_id := ""
var _scene_id := 0
var _last_home_fouls := 0
var _last_away_fouls := 0
var _serial := 0

func _ready() -> void:
	process_priority = 60

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	if scene_id != _scene_id:
		_scene_id = scene_id
		_last_home_fouls = int(scene.get("home_fouls"))
		_last_away_fouls = int(scene.get("away_fouls"))
		return
	var home_fouls := int(scene.get("home_fouls"))
	var away_fouls := int(scene.get("away_fouls"))
	if home_fouls > _last_home_fouls:
		_record_home(scene, home_fouls - _last_home_fouls)
	if away_fouls > _last_away_fouls:
		_record_away(scene, away_fouls - _last_away_fouls)
	_last_home_fouls = home_fouls
	_last_away_fouls = away_fouls

func _record_home(scene: Object, count: int) -> void:
	var actor := FoulLedgerRules.controlled_actor(scene.get("home_players"), int(scene.get("controlled_home_index")))
	last_home_actor_id = str(actor.get("id", ""))
	_append_events(scene, "home", actor, count)
	_append_actor_to_status(scene, actor)

func _record_away(scene: Object, count: int) -> void:
	var actor := FoulLedgerRules.ai_tackler_actor(
		scene.get("away_players"),
		scene.get("home_players"),
		int(scene.get("possession_team")),
		int(scene.get("possession_index")),
		int(scene.get("controlled_home_index"))
	)
	last_away_actor_id = str(actor.get("id", ""))
	_append_events(scene, "away", actor, count)
	_append_actor_to_status(scene, actor)

func _append_events(scene: Object, team: String, actor: Dictionary, count: int) -> void:
	for _i in range(maxi(1, count)):
		_serial += 1
		events.append(FoulLedgerRules.make_event(team, actor, int(scene.get("match_number")), _serial))
	while events.size() > MAX_EVENTS:
		events.pop_front()

func _append_actor_to_status(scene: Object, actor: Dictionary) -> void:
	var name := str(actor.get("name", actor.get("id", ""))).to_upper()
	if name == "":
		return
	var current := str(scene.get("status_text"))
	if not current.contains(name):
		scene.set("status_text", "%s - %s" % [current, name] if current != "" else name)
		scene.set("status_timer", maxf(float(scene.get("status_timer")), 1.6))

func latest_event() -> Dictionary:
	return events.back() if not events.is_empty() else {}

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for required in ["home_fouls", "away_fouls", "home_players", "away_players", "controlled_home_index", "possession_team", "possession_index", "match_number", "status_text", "status_timer"]:
		if not names.has(required):
			return false
	return true
