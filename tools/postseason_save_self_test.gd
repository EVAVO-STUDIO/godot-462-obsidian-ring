extends SceneTree

const SeasonSaveScript = preload("res://scripts/season_save.gd")
const SeasonDirectorScript = preload("res://scripts/season_director.gd")

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

	var director = SeasonDirectorScript.new()
	director.restore_postseason_state(clean)
	var state := director.postseason_state()
	_expect(state.get("semifinal_winners", []).size() == 2, "season director should restore semifinal winners through public API")
	_expect(str(state.get("champion_id", "")) == "jaguar_house", "season director public API should expose champion")
	_expect(bool(state.get("championship_purse_paid", false)), "season director public API should expose purse state")
	var winners: Array = state.get("semifinal_winners", [])
	winners.clear()
	_expect(director.postseason_state().get("semifinal_winners", []).size() == 2, "postseason_state should return a defensive copy")

	var save_file := FileAccess.open("res://scripts/season_save.gd", FileAccess.READ)
	_expect(save_file != null, "season_save.gd should be readable for canonical API check")
	if save_file != null:
		var source := save_file.get_as_text()
		_expect(source.contains('has_method("postseason_state")') and source.contains('has_method("restore_postseason_state")'), "canonical save should use SeasonDirector public postseason API")
		_expect(not source.contains('director.get("_semifinal_winners")'), "canonical save must not read private semifinal state")
		_expect(not source.contains('director.get("_champion_id")'), "canonical save must not read private champion state")
		_expect(not source.contains('director.set("_semifinal_winners"'), "canonical save must not write private semifinal state")
		_expect(not source.contains('director.set("_champion_id"'), "canonical save must not write private champion state")

	var director_file := FileAccess.open("res://scripts/season_director.gd", FileAccess.READ)
	_expect(director_file != null, "season_director.gd should be readable for legacy migration check")
	if director_file != null:
		var source := director_file.get_as_text()
		_expect(source.contains('LEGACY_SAVE_PATH := "user://obsidian_ring_postseason.json"'), "legacy postseason path should remain identifiable for migration")
		_expect(source.contains('CANONICAL_SAVE_PATH := "user://obsidian_ring_season.json"'), "legacy migration should know the canonical save path")
		_expect(source.contains("func _load_legacy_state_if_needed()"), "legacy postseason state should only be loaded through migration helper")
		_expect(source.contains("if FileAccess.file_exists(CANONICAL_SAVE_PATH):"), "canonical season save must suppress legacy migration")
		_expect(not source.contains("func _save_state()"), "legacy postseason file must no longer have an active save writer")
		_expect(not source.contains("FileAccess.open(LEGACY_SAVE_PATH, FileAccess.WRITE)"), "legacy postseason file must never be written by current runtime")

	director.free()
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
