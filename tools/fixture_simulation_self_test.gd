extends SceneTree

const FixtureSimulationRules = preload("res://scripts/fixture_simulation_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
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
	if failures.is_empty():
		print("Obsidian Ring fixture simulation self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
