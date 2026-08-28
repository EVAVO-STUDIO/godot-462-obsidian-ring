extends Node

const ReplayGuardRules = preload("res://scripts/replay_guard_rules.gd")

var _scene_id := 0
var _last_phase := -1
var _last_match_number := -1
var _replay_active := false
var _snapshot: Dictionary = {}

func _ready() -> void:
	process_priority = 500

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	var phase := int(scene.get("phase"))
	var match_number := int(scene.get("match_number"))
	if scene_id != _scene_id:
		_scene_id = scene_id
		_last_phase = phase
		_last_match_number = match_number
		_replay_active = false
		_snapshot.clear()
		return
	if _last_phase == 2 and phase == 1 and match_number == _last_match_number:
		_begin_replay(scene)
	elif _replay_active and _last_phase == 1 and phase == 2 and match_number == _last_match_number:
		_restore_committed_state(scene)
	elif match_number != _last_match_number:
		_replay_active = false
		_snapshot.clear()
	_last_phase = int(scene.get("phase"))
	_last_match_number = int(scene.get("match_number"))

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in ["phase", "match_number", "funds", "league_table", "roster_state", "league", "status_text", "status_timer"]:
		if not names.has(name):
			return false
	return true

func _season_rounds(scene: Object) -> int:
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return 10
	return maxi(1, int(league_data.get("league", {}).get("season_rounds", 10)))

func _begin_replay(scene: Object) -> void:
	var round_no := int(scene.get("match_number"))
	if not ReplayGuardRules.is_regular_season_round(round_no, _season_rounds(scene)):
		scene.set("phase", 2)
		scene.set("status_text", "POSTSEASON REPLAY UNAVAILABLE")
		scene.set("status_timer", 2.0)
		return
	_snapshot = ReplayGuardRules.snapshot_state(int(scene.get("funds")), scene.get("league_table"), scene.get("roster_state"))
	_replay_active = true
	scene.set("status_text", "REPLAY - EXHIBITION ONLY")
	scene.set("status_timer", 2.0)

func _restore_committed_state(scene: Object) -> void:
	if not ReplayGuardRules.valid_snapshot(_snapshot):
		_replay_active = false
		return
	var table: Array = _snapshot.get("league_table", [])
	var rosters: Array = _snapshot.get("roster_state", [])
	scene.set("funds", int(_snapshot.get("funds", scene.get("funds"))))
	scene.set("league_table", table.duplicate(true))
	scene.set("roster_state", rosters.duplicate(true))
	scene.set("status_text", "REPLAY COMPLETE - CAREER STATE UNCHANGED")
	scene.set("status_timer", 2.2)
	_replay_active = false

func is_replay_active() -> bool:
	return _replay_active
