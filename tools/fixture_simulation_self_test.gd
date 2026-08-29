extends SceneTree

const ContentCatalog = preload("res://scripts/content_catalog.gd")
const FixtureSimulationRules = preload("res://scripts/fixture_simulation_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_simulation()
	_test_schedule_balance()
	_test_result_round_lifecycle()
	if failures.is_empty():
		print("Obsidian Ring fixture simulation self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_simulation() -> void:
	var home := {"id":"obsidian_guard","attack":7,"defence":9,"speed":5,"discipline":8}
	var away := {"id":"sun_serpents","attack":8,"defence":6,"speed":8,"discipline":5}
	var first := FixtureSimulationRules.simulate_fixture(home, away, 1)
	var repeat := FixtureSimulationRules.simulate_fixture(home, away, 1)
	_expect(first == repeat, "AI fixture simulation must be deterministic for the same round and teams")
	_expect(int(first.get("home_score", -1)) >= 0 and int(first.get("home_score", 99)) <= 12, "home AI score should remain in bounds")
	_expect(int(first.get("away_score", -1)) >= 0 and int(first.get("away_score", 99)) <= 12, "away AI score should remain in bounds")
	var table := [
		{"id":"obsidian_guard","played":0},
		{"id":"sun_serpents","played":0}
	]
	_expect(FixtureSimulationRules.fixture_needs_simulation(table, "obsidian_guard", "sun_serpents", 1), "unplayed round should require simulation")
	table[0]["played"] = 1
	table[1]["played"] = 1
	_expect(not FixtureSimulationRules.fixture_needs_simulation(table, "obsidian_guard", "sun_serpents", 1), "already-recorded AI fixture must not simulate twice")

func _test_schedule_balance() -> void:
	var data = ContentCatalog.load_json("res://data/fixtures.json")
	_expect(typeof(data) == TYPE_DICTIONARY, "fixtures catalogue should load")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var rounds: Array = data.get("rounds", [])
	_expect(rounds.size() == 10, "regular season should retain ten rounds")
	var homes: Dictionary = {}
	var games: Dictionary = {}
	var pair_counts: Dictionary = {}
	for round_data in rounds:
		var seen: Dictionary = {}
		for fixture in round_data.get("fixtures", []):
			var home := str(fixture.get("home", ""))
			var away := str(fixture.get("away", ""))
			_expect(home != "" and away != "" and home != away, "fixture must contain two distinct teams")
			_expect(not seen.has(home) and not seen.has(away), "team must appear only once in each round")
			seen[home] = true
			seen[away] = true
			homes[home] = int(homes.get(home, 0)) + 1
			games[home] = int(games.get(home, 0)) + 1
			games[away] = int(games.get(away, 0)) + 1
			var pair := [home, away]
			pair.sort()
			var key := "%s|%s" % [pair[0], pair[1]]
			pair_counts[key] = int(pair_counts.get(key, 0)) + 1
	for team in games.keys():
		_expect(int(games[team]) == 10, "%s should play every round" % team)
		_expect(int(homes.get(team, 0)) == 5, "%s should have exactly five home fixtures" % team)
	var pair_values: Array[int] = []
	for count in pair_counts.values():
		pair_values.append(int(count))
	pair_values.sort()
	_expect(pair_values == [3,3,3,3,4,4], "ten-round opponent frequencies should be optimally balanced")

func _test_result_round_lifecycle() -> void:
	var main_file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	_expect(main_file != null, "main.gd should be readable for result round lifecycle checks")
	if main_file != null:
		var source := main_file.get_as_text()
		var result_branch := source.find("GamePhase.RESULT:")
		var advance_call := source.find("_advance_between_matches()", result_branch)
		var increment := source.find("match_number += 1", result_branch)
		_expect(result_branch >= 0 and advance_call > result_branch and increment > advance_call, "match_number must advance only after completed result handling")
	var fixture_file := FileAccess.open("res://scripts/fixture_simulation_director.gd", FileAccess.READ)
	_expect(fixture_file != null, "fixture simulation director should be readable for completed-round checks")
	if fixture_file != null:
		var source := fixture_file.get_as_text()
		_expect(source.contains('var round_no := maxi(1, int(scene.get("match_number")))'), "AI fixture simulation should use the still-current completed round")
		_expect(source.contains("if phase == 2 and _last_phase != 2:"), "AI fixture simulation should run only on result entry")
		_expect(source.contains("FixtureSimulationRules.fixture_needs_simulation"), "AI fixture should retain played-count duplicate protection")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
