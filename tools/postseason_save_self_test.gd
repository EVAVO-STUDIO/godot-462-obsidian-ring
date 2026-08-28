extends SceneTree

const SeasonSaveScript = preload("res://scripts/season_save.gd")

class FakeSeason:
	extends Node
	var teams: Array = [
		{"id":"jaguar_house"},
		{"id":"quetzal_runners"},
		{"id":"obsidian_guard"},
		{"id":"sun_serpents"}
	]
	var funds := 1000
	var match_number := 11
	var league_table: Array = []
	var roster_state: Array = []
	var league: Dictionary = {"league":{"season_rounds":10}}

var failures: Array[String] = []

func _initialize() -> void:
	var saver = SeasonSaveScript.new()
	var fake = FakeSeason.new()
	var clean := saver._sanitize_postseason(fake, {
		"semifinal_winners":["jaguar_house","obsidian_guard","jaguar_house","bogus"],
		"champion_id":"jaguar_house",
		"championship_purse_paid":true
	})
	_expect(clean.get("semifinal_winners", []).size() == 2, "postseason save should keep at most two unique valid semifinal winners")
	_expect(str(clean.get("champion_id", "")) == "jaguar_house", "valid champion should be preserved")
	_expect(bool(clean.get("championship_purse_paid", false)), "valid paid champion state should be preserved")
	var invalid := saver._sanitize_postseason(fake, {
		"semifinal_winners":["bogus","bogus"],
		"champion_id":"bogus",
		"championship_purse_paid":true
	})
	_expect(invalid.get("semifinal_winners", []).is_empty(), "unknown semifinal winners should be rejected")
	_expect(str(invalid.get("champion_id", "")) == "", "unknown champion should be rejected")
	_expect(not bool(invalid.get("championship_purse_paid", true)), "purse-paid flag should be false when champion is invalid")
	fake.free()
	saver.free()
	if failures.is_empty():
		print("Obsidian Ring postseason save self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
