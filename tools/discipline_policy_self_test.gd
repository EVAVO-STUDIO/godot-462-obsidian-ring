extends SceneTree

const DisciplineRules = preload("res://scripts/discipline_rules.gd")
const FoulLedgerRules = preload("res://scripts/foul_ledger_rules.gd")
const ManagementSummaryRules = preload("res://scripts/management_summary_rules.gd")
const StandingsSummaryRules = preload("res://scripts/standings_summary_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_default_policy()
	_test_custom_policy()
	_test_policy_ownership()
	_test_foul_attribution()
	_test_management_summary()
	_test_standings_summary()
	if failures.is_empty():
		print("Obsidian Ring discipline policy self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_default_policy() -> void:
	_expect(DisciplineRules.DEFAULT_BOOKING_THRESHOLD == 3, "default booking threshold should remain three")
	_expect(DisciplineRules.DEFAULT_SUSPENSION_LENGTH == 1, "default suspension should remain one match")
	var booked := DisciplineRules.apply_booking({"booking_points":2,"suspension_matches":0,"suspensions_served":0}, 1)
	_expect(int(booked.get("suspension_matches", 0)) == 1, "three booking points should trigger one-match default suspension")
	_expect(int(booked.get("booking_points", 0)) == 0, "exact threshold should reset booking points to zero")

func _test_custom_policy() -> void:
	var booked := DisciplineRules.apply_booking({"booking_points":3,"suspension_matches":0,"suspensions_served":0}, 2, 4, 2)
	_expect(int(booked.get("suspension_matches", 0)) == 2, "explicit authored policy should apply two-match suspension")
	_expect(int(booked.get("booking_points", 0)) == 1, "booking points above threshold should carry forward instead of disappearing")
	_expect(int(booked.get("suspensions_served", 0)) == 1, "triggered suspension should increment suspension history")
	_expect(DisciplineRules.suspension_matches(3, 4, 2) == 0, "custom threshold should not suspend below threshold")
	_expect(DisciplineRules.suspension_matches(4, 4, 2) == 2, "custom threshold should return authored suspension length")
	var served := DisciplineRules.serve_round(booked)
	_expect(int(served.get("suspension_matches", 0)) == 1, "serving one round should decrement multi-match suspension by one")

func _test_policy_ownership() -> void:
	var project := FileAccess.open("res://project.godot", FileAccess.READ)
	_expect(project != null, "project.godot should be readable for discipline ownership check")
	if project != null:
		var text := project.get_as_text()
		_expect(not text.contains("DisciplinePolicyDirector"), "obsolete discipline policy autoload must remain removed")
	_expect(not FileAccess.file_exists("res://scripts/discipline_policy_director.gd"), "obsolete discipline policy director file must remain deleted")
	var season_file := FileAccess.open("res://scripts/season_director.gd", FileAccess.READ)
	_expect(season_file != null, "season_director.gd should be readable for direct policy check")
	if season_file != null:
		var source := season_file.get_as_text()
		_expect(source.contains('league_cfg.get("booking_threshold", 3)'), "SeasonDirector should read booking threshold at booking source")
		_expect(source.contains('league_cfg.get("suspension_matches", 1)'), "SeasonDirector should read suspension length at booking source")
		_expect(source.contains("DisciplineRules.apply_booking(player, points, booking_threshold, suspension_length)"), "SeasonDirector should pass explicit policy into booking rule")

func _test_foul_attribution() -> void:
	var home_players := [
		{"id":"h0","name":"HOME ZERO","position":Vector2(100,100)},
		{"id":"h1","name":"HOME ONE","position":Vector2(200,100)}
	]
	var away_players := [
		{"id":"a0","name":"AWAY ZERO","position":Vector2(210,100)},
		{"id":"a1","name":"AWAY ONE","position":Vector2(420,100)}
	]
	var home_actor := FoulLedgerRules.controlled_actor(home_players, 1)
	_expect(str(home_actor.get("id", "")) == "h1", "home foul should resolve to controlled tackler")
	var away_actor := FoulLedgerRules.ai_tackler_actor(away_players, home_players, 1, 1, 0)
	_expect(str(away_actor.get("id", "")) == "a0", "away foul should resolve to exact nearest AI tackler used by live tackle branch")
	var event := FoulLedgerRules.make_event("away", away_actor, 5, 3)
	_expect(str(event.get("actor_id", "")) == "a0" and int(event.get("round", 0)) == 5 and int(event.get("serial", 0)) == 3, "foul event should preserve actor round and serial")

func _test_management_summary() -> void:
	var player := {"name":"IKA","injury_matches":1,"suspension_matches":2,"booking_points":3,"fatigue_carry":14}
	var line := ManagementSummaryRules.player_line(player)
	_expect(line.contains("IKA") and line.contains("INJ 1") and line.contains("SUSP 2") and line.contains("BOOK 3") and line.contains("FAT 14"), "management summary should expose selected player condition")
	var foul := ManagementSummaryRules.foul_line({"round":7,"team":"away","actor_name":"TALA"})
	_expect(foul.contains("R07") and foul.contains("AWAY") and foul.contains("TALA"), "management summary should expose latest foul actor")
	_expect(ManagementSummaryRules.postseason_line([], "jaguar_house").contains("JAGUAR HOUSE"), "management summary should expose champion identity")
	var project := FileAccess.open("res://project.godot", FileAccess.READ)
	_expect(project != null, "project.godot should be readable for management summary autoload check")
	if project != null:
		var text := project.get_as_text()
		_expect(text.contains("ManagementSummaryDirector=\"*res://scripts/management_summary_director.gd\""), "management summary director must remain autoloaded")
		_expect(text.contains("StandingsSummaryDirector=\"*res://scripts/standings_summary_director.gd\""), "standings summary director must remain autoloaded")
	var manager_file := FileAccess.open("res://scripts/management_summary_director.gd", FileAccess.READ)
	_expect(manager_file != null, "management_summary_director.gd should be readable")
	if manager_file != null:
		var source := manager_file.get_as_text()
		_expect(source.contains('has_method("postseason_state")') and source.contains('director.call("postseason_state")'), "management summary should consume public postseason state API")
		_expect(not source.contains('get("_semifinal_winners")'), "management summary must not read private semifinal state")
		_expect(not source.contains('get("_champion_id")'), "management summary must not read private champion state")

func _test_standings_summary() -> void:
	var table := [
		{"id":"sun_serpents","name":"Sun Serpents","played":5,"for":20,"against":20,"points":7},
		{"id":"jaguar_house","name":"Jaguar House","played":5,"for":24,"against":18,"points":10},
		{"id":"obsidian_guard","name":"Obsidian Guard","played":5,"for":22,"against":17,"points":10},
		{"id":"quetzal_runners","name":"Quetzal Runners","played":5,"for":17,"against":25,"points":4}
	]
	var rows := StandingsSummaryRules.sorted_rows(table)
	_expect(str(rows[0].get("id", "")) == "jaguar_house", "standings should break equal points by score differential")
	var line := StandingsSummaryRules.row_line(rows[0], 1)
	_expect(line.begins_with(">1") and line.contains("P05") and line.contains("D+06") and line.contains("10PTS"), "standings line should expose user marker played differential and points")
	_expect(StandingsSummaryRules.playoff_cutoff_line(4, 4) == "PLAYOFF CUT: TOP 4", "standings should expose authored playoff cutoff")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
