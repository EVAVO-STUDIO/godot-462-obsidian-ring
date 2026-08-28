extends SceneTree

const ContentCatalog = preload("res://scripts/content_catalog.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var data = ContentCatalog.load_json("res://data/fixtures.json")
	_expect(typeof(data) == TYPE_DICTIONARY, "fixtures catalogue should load")
	var rounds: Array = data.get("rounds", []) if typeof(data) == TYPE_DICTIONARY else []
	var homes: Dictionary = {}
	var games: Dictionary = {}
	var pair_counts: Dictionary = {}
	for round_data in rounds:
		var seen: Dictionary = {}
		for fixture in round_data.get("fixtures", []):
			var home := str(fixture.get("home", ""))
			var away := str(fixture.get("away", ""))
			_expect(home != "" and away != "" and home != away, "fixture must contain two distinct teams")
			_expect(not seen.has(home) and not seen.has(away), "team must appear only once per round")
			seen[home] = true
			seen[away] = true
			homes[home] = int(homes.get(home, 0)) + 1
			games[home] = int(games.get(home, 0)) + 1
			games[away] = int(games.get(away, 0)) + 1
			var pair := [home, away]
			pair.sort()
			var key := "%s|%s" % [pair[0], pair[1]]
			pair_counts[key] = int(pair_counts.get(key, 0)) + 1
	_expect(rounds.size() == 10, "schedule should retain ten regular-season rounds")
	for team in games.keys():
		_expect(int(games[team]) == 10, "%s should play every round" % team)
		_expect(int(homes.get(team, 0)) == 5, "%s should have exactly five home fixtures" % team)
	var pair_values: Array[int] = []
	for count in pair_counts.values():
		pair_values.append(int(count))
	pair_values.sort()
	_expect(pair_values == [3,3,3,3,4,4], "pair frequencies should be mathematically optimal for ten rounds")
	if failures.is_empty():
		print("Obsidian Ring fixture balance self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
