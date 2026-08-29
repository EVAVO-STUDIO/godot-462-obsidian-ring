extends SceneTree

const SeasonEndRules = preload("res://scripts/season_end_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var table := [
		{"id":"jaguar_house","points":12,"for":30,"against":10},
		{"id":"quetzal_runners","points":10,"for":24,"against":14},
		{"id":"obsidian_guard","points":8,"for":20,"against":18},
		{"id":"sun_serpents","points":6,"for":15,"against":21}
	]
	_expect(SeasonEndRules.user_qualified(table, 4), "Jaguar House should qualify when inside top four")
	_expect(SeasonEndRules.terminal_reason(11, 10, table, 4, [], "") == "", "qualified team should be allowed to enter semifinal")
	_expect(SeasonEndRules.terminal_reason(12, 10, table, 4, ["quetzal_runners", "obsidian_guard"], "") == "SEMIFINAL_EXIT", "semifinal loser should not enter championship")
	_expect(SeasonEndRules.terminal_reason(12, 10, table, 4, ["jaguar_house", "quetzal_runners"], "jaguar_house") == "CHAMPION", "champion should enter terminal season state")
	var short_table := [
		{"id":"quetzal_runners","points":12,"for":30,"against":10},
		{"id":"obsidian_guard","points":10,"for":24,"against":14},
		{"id":"sun_serpents","points":8,"for":20,"against":18},
		{"id":"other","points":7,"for":18,"against":17},
		{"id":"jaguar_house","points":2,"for":8,"against":29}
	]
	_expect(SeasonEndRules.terminal_reason(11, 10, short_table, 4, [], "") == "NO_PLAYOFF_BERTH", "non-qualifier should stop before semifinal")
	_test_postseason_api_boundary()
	if failures.is_empty():
		print("Obsidian Ring season-end self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_postseason_api_boundary() -> void:
	var file := FileAccess.open("res://scripts/season_end_director.gd", FileAccess.READ)
	_expect(file != null, "season_end_director.gd should be readable")
	if file == null:
		return
	var source := file.get_as_text()
	_expect(source.contains('has_method("postseason_state")') and source.contains('director.call("postseason_state")'), "season end flow should consume public postseason state API")
	_expect(not source.contains('get("_semifinal_winners")'), "season end flow must not read private semifinal state")
	_expect(not source.contains('get("_champion_id")'), "season end flow must not read private champion state")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
