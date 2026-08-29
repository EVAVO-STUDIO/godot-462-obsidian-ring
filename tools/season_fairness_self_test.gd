extends SceneTree

const FixtureSimulationRules = preload("res://scripts/fixture_simulation_rules.gd")
const RosterRules = preload("res://scripts/roster_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_live_availability()
	_test_roster_strength()
	_test_injury_persistence_sources()
	_test_round_recovery_source()
	if failures.is_empty():
		print("Obsidian Ring season fairness self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_live_availability() -> void:
	var roster := {"team_id":"test","players":[
		{"id":"guard","role":"guard","skill":8,"injury_matches":0,"suspension_matches":0},
		{"id":"striker","role":"striker","skill":8,"injury_matches":1,"suspension_matches":0},
		{"id":"runner","role":"runner","skill":7,"injury_matches":0,"suspension_matches":0},
		{"id":"bench","role":"striker","skill":6,"injury_matches":0,"suspension_matches":0},
		{"id":"suspended","role":"guard","skill":10,"injury_matches":0,"suspension_matches":1}
	]}
	var active := RosterRules.active_three(roster)
	var ids: Array[String] = []
	for player in active:
		ids.append(str(player.get("id", "")))
	_expect(active.size() == 3, "available squad depth should still field three players")
	_expect("striker" not in ids, "injured player must not enter the active three")
	_expect("suspended" not in ids, "suspended player must not enter the active three")
	_expect("bench" in ids, "eligible bench player should replace unavailable preferred-role player")

func _test_roster_strength() -> void:
	var healthy := {"players":[
		{"id":"a","skill":8,"injury_matches":0,"suspension_matches":0,"fatigue_carry":0},
		{"id":"b","skill":7,"injury_matches":0,"suspension_matches":0,"fatigue_carry":0},
		{"id":"c","skill":7,"injury_matches":0,"suspension_matches":0,"fatigue_carry":4},
		{"id":"d","skill":6,"injury_matches":0,"suspension_matches":0,"fatigue_carry":0}
	]}
	var depleted := {"players":[
		{"id":"a","skill":8,"injury_matches":2,"suspension_matches":0,"fatigue_carry":0},
		{"id":"b","skill":7,"injury_matches":0,"suspension_matches":1,"fatigue_carry":0},
		{"id":"c","skill":7,"injury_matches":0,"suspension_matches":0,"fatigue_carry":36},
		{"id":"d","skill":6,"injury_matches":0,"suspension_matches":0,"fatigue_carry":32}
	]}
	_expect(FixtureSimulationRules.roster_strength_modifier(healthy) > FixtureSimulationRules.roster_strength_modifier(depleted), "injury suspension and fatigue should reduce AI fixture strength")
	_expect(FixtureSimulationRules.roster_strength_modifier({"players":[{"id":"x","injury_matches":1}]}) == -12, "fully unavailable roster should retain bounded minimum strength modifier")

func _test_injury_persistence_sources() -> void:
	var condition_file := FileAccess.open("res://scripts/condition_director.gd", FileAccess.READ)
	var substitution_file := FileAccess.open("res://scripts/match_substitution_director.gd", FileAccess.READ)
	_expect(condition_file != null and substitution_file != null, "condition and substitution sources should be readable")
	if condition_file != null:
		var source := condition_file.get_as_text()
		_expect(source.contains("_capture_injuries(home_players)") and source.contains("_capture_injuries(away_players)"), "match-long injury ledger must cover both teams")
		_expect(source.contains("_injury_seconds_by_id"), "match-long injury severity should be keyed by player ID")
		_expect(source.contains('maxi(int(spec.get("injury_matches", 0)), injury_matches)'), "career injury persistence must never shorten an existing injury")
	if substitution_file != null:
		_expect(substitution_file.get_as_text().contains("_persist_outgoing_injury(scene, outgoing)"), "injured outgoing user player must persist before substitution replacement")

func _test_round_recovery_source() -> void:
	var fixture_file := FileAccess.open("res://scripts/fixture_simulation_director.gd", FileAccess.READ)
	var season_file := FileAccess.open("res://scripts/season_director.gd", FileAccess.READ)
	_expect(fixture_file != null and season_file != null, "fixture and season directors should be readable")
	if fixture_file != null:
		var source := fixture_file.get_as_text()
		_expect(source.contains("_recover_non_user_rosters(scene)"), "AI clubs should recover at round advancement")
		_expect(source.contains("RosterRules.recover_between_matches(players[pi])"), "AI injury recovery should use canonical roster rule")
		_expect(source.contains("FixtureSimulationRules.with_roster_context"), "AI fixture results should consume current roster condition")
	if season_file != null:
		var source := season_file.get_as_text()
		_expect(source.contains("func _service_old_suspensions"), "season director should serve suspensions across round changes")
		_expect(source.contains("DisciplineRules.serve_round(player)"), "suspensions should use canonical discipline serving rule")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
