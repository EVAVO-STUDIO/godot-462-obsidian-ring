extends SceneTree

const ReplayGuardRules = preload("res://scripts/replay_guard_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_expect(ReplayGuardRules.is_regular_season_round(1, 10), "round one should be regular season")
	_expect(ReplayGuardRules.is_regular_season_round(10, 10), "last configured round should be regular season")
	_expect(not ReplayGuardRules.is_regular_season_round(11, 10), "postseason round should not be replayable as career match")
	var table := [{"id":"a","played":1,"points":3}]
	var roster := [{"team_id":"a","players":[{"id":"p","skill":7}]}]
	var snapshot := ReplayGuardRules.snapshot_state(1250, table, roster)
	_expect(ReplayGuardRules.valid_snapshot(snapshot), "replay snapshot should contain funds, table and roster")
	table[0]["points"] = 99
	roster[0]["players"][0]["skill"] = 10
	_expect(int(snapshot["league_table"][0]["points"]) == 3, "league snapshot should be deep copied")
	_expect(int(snapshot["roster_state"][0]["players"][0]["skill"]) == 7, "roster snapshot should be deep copied")
	if failures.is_empty():
		print("Obsidian Ring replay guard self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
