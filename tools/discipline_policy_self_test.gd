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
	_expect(int(booked.get("booking_points", 0)) == 1, "booking points above threshold should carry forward")
	_expect(int(booked.get("suspensions_served", 0)) == 1, "triggered suspension should increment history")
	_expect(DisciplineRules.suspension_matches(3, 4, 2) == 0, "custom threshold should not suspend below threshold")
	_expect(DisciplineRules.suspension_matches(4, 4, 2) == 2, "custom threshold should return authored suspension length")
	var served := DisciplineRules.serve_round(booked)
	_expect(int(served.get("suspension_matches", 0)) == 1, "serving one round should decrement multi-match suspension")

func _test_policy_ownership() -> void:
	var project := FileAccess.open("res://project.godot", FileAccess.READ)
	_expect(project != null, "project.godot should be readable")
	if project != null:
		_expect(not project.get_as_text().contains("DisciplinePolicyDirector"), "obsolete policy autoload must remain removed")
	_expect(not FileAccess.file_exists("res://scripts/discipline_policy_director.gd"), "obsolete discipline policy file must remain deleted")
	var season_file := FileAccess.open("res://scripts/season_director.gd", FileAccess.READ)
	_expect(season_file != null, "season director should be readable")
	if season_file != null:
		var source := season_file.get_as_text()
		_expect(source.contains('league_cfg.get("booking_threshold", 3)'), "SeasonDirector should read threshold at booking source")
		_expect(source.contains('league_cfg.get("suspension_matches", 1)'), "SeasonDirector should read suspension length at booking source")
		_expect(source.contains("DisciplineRules.apply_booking(player, points, booking_threshold, suspension_length)"), "SeasonDirector should pass explicit policy")

func _test_foul_attribution() -> void:
	var home_players := [{"id":"h0","name":"HOME ZERO","position":Vector2(100,100)},{"id":"h1","name":"HOME ONE","position":Vector2(200,100)}]
	var away_players := [{"id":"a0","name":"AWAY ZERO","position":Vector2(210,100)},{"id":"a1","name":"AWAY ONE","position":Vector2(420,100)}]
	var home_actor := FoulLedgerRules.controlled_actor(home_players, 1)
	_expect(str(home_actor.get("id", "")) == "h1", "home foul should resolve to controlled tackler")
	var away_actor := FoulLedgerRules.ai_tackler_actor(away_players, home_players, 1, 1, 0)
	_expect(str(away_actor.get("id", "")) == "a0", "away foul should resolve to nearest AI tackler")
	var event := FoulLedgerRules.make_event("away", away_actor, 5, 3)
	_expect(str(event.get("actor_id", "")) == "a0" and int(event.get("round", 0)) == 5 and int(event.get("serial", 0)) == 3, "foul event should preserve actor round and serial")

func _test_management_summary() -> void:
	var player := {"name":"IKA","injury_matches":1,"suspension_matches":2,"booking_points":3,"fatigue_carry":14}
	var line := ManagementSummaryRules.player_line(player)
	_expect(line.contains("IKA") and line.contains("INJ 1") and line.contains("SUSP 2") and line.contains("BOOK 3") and line.contains("FAT 14"), "management summary should expose selected player condition")
	var opponent := {"team_id":"quetzal_runners","players":[
		{"id":"a","name":"TALA","role":"runner","skill":8,"injury_matches":0,"suspension_matches":0,"fatigue_carry":8},
		{"id":"b","name":"IXA","role":"guard","skill":10,"injury_matches":2,"suspension_matches":0,"fatigue_carry":12},
		{"id":"c","name":"KIRI","role":"striker","skill":9,"injury_matches":0,"suspension_matches":1,"fatigue_carry":20},
		{"id":"d","name":"NOMA","role":"guard","skill":7,"injury_matches":0,"suspension_matches":0,"fatigue_carry":0},
		{"id":"e","name":"SOLA","role":"runner","skill":6,"injury_matches":0,"suspension_matches":0,"fatigue_carry":10}
	]}
	var opponent_line := ManagementSummaryRules.opponent_line(opponent, "Quetzal Runners")
	_expect(opponent_line.contains("VS QUETZAL RUNNERS"), "management summary should identify next opponent")
	_expect(opponent_line.contains("AVAIL 3/5") and opponent_line.contains("INJ 1") and opponent_line.contains("SUSP 1"), "management summary should expose opponent availability losses")
	_expect(opponent_line.contains("FAT 10"), "management summary should expose opponent average fatigue")
	var threat := ManagementSummaryRules.best_available_threat(opponent)
	_expect(str(threat.get("id", "")) == "a", "scouting must ignore injured/suspended higher-skill players and select best available threat")
	var scout := ManagementSummaryRules.scout_line(opponent)
	_expect(scout.contains("TALA") and scout.contains("RUNNER") and scout.contains("SK8") and scout.contains("FAT8"), "scouting line should expose available threat identity, role, skill and fatigue")
	_expect(scout.contains("FORM"), "scouting line should expose the same roster-strength modifier used by fixture simulation")
	var unavailable := {"players":[{"id":"x","skill":10,"injury_matches":1},{"id":"y","skill":9,"suspension_matches":1}]}
	_expect(ManagementSummaryRules.scout_line(unavailable).contains("NO AVAILABLE THREAT"), "scouting should fail safely when no player can participate")
	var foul := ManagementSummaryRules.foul_line({"round":7,"team":"away","actor_name":"TALA"})
	_expect(foul.contains("R07") and foul.contains("AWAY") and foul.contains("TALA"), "management summary should expose latest foul actor")
	_expect(ManagementSummaryRules.postseason_line([], "jaguar_house").contains("JAGUAR HOUSE"), "management summary should expose champion identity")
	var project := FileAccess.open("res://project.godot", FileAccess.READ)
	_expect(project != null, "project.godot should be readable")
	if project != null:
		var text := project.get_as_text()
		_expect(text.contains("ManagementSummaryDirector=\"*res://scripts/management_summary_director.gd\""), "management summary director must remain autoloaded")
		_expect(text.contains("StandingsSummaryDirector=\"*res://scripts/standings_summary_director.gd\""), "standings summary director must remain autoloaded")
	var manager_file := FileAccess.open("res://scripts/management_summary_director.gd", FileAccess.READ)
	_expect(manager_file != null, "management summary director should be readable")
	if manager_file != null:
		var source := manager_file.get_as_text()
		_expect(source.contains('has_method("postseason_state")') and source.contains('director.call("postseason_state")'), "management summary should consume public postseason state API")
		_expect(source.contains("_opponent_roster(scene)"), "management summary should read canonical opponent roster")
		_expect(source.contains("ManagementSummaryRules.opponent_line") and source.contains("ManagementSummaryRules.scout_line"), "management summary should render condition and scouting lines")
		_expect(source.contains('"%s\\n%s\\n%s\\n%s\\n%s"'), "management rail should reserve five compact lines")
		_expect(not source.contains('get("_semifinal_winners")') and not source.contains('get("_champion_id")'), "management summary must not read private postseason state")

func _test_standings_summary() -> void:
	var table := [
		{"id":"sun_serpents","name":"Sun Serpents","played":5,"for":20,"against":20,"points":7},
		{"id":"jaguar_house","name":"Jaguar House","played":5,"for":24,"against":18,"points":10},
		{"id":"obsidian_guard","name":"Obsidian Guard","played":5,"for":22,"against":17,"points":10},
		{"id":"quetzal_runners","name":"Quetzal Runners","played":5,"for":17,"against":25,"points":4}
	]
	var rows := StandingsSummaryRules.sorted_rows(table)
	_expect(str(rows[0].get("id", "")) == "jaguar_house", "standings should break equal points by score differential")
	var roster := {"team_id":"jaguar_house","players":[
		{"id":"a","injury_matches":0,"suspension_matches":0},
		{"id":"b","injury_matches":1,"suspension_matches":0},
		{"id":"c","injury_matches":0,"suspension_matches":1},
		{"id":"d","injury_matches":0,"suspension_matches":0},
		{"id":"e","injury_matches":0,"suspension_matches":0}
	]}
	var availability := StandingsSummaryRules.availability(roster)
	_expect(int(availability.get("available", -1)) == 3 and int(availability.get("injured", -1)) == 1 and int(availability.get("suspended", -1)) == 1, "standings availability should use canonical injury/suspension state")
	_expect(StandingsSummaryRules.availability_code(roster) == " A3/5", "standings should expose compact availability marker")
	var row_line := StandingsSummaryRules.row_line(rows[0], 1, "jaguar_house", roster)
	_expect(row_line.begins_with(">1") and row_line.contains("P05") and row_line.contains("D+06") and row_line.contains("10") and row_line.contains("A3/5"), "standings row should expose rank, performance and availability")
	_expect(StandingsSummaryRules.playoff_cutoff_line(4, 4) == "PLAYOFF CUT: TOP 4", "standings should expose authored playoff cutoff")
	var director_file := FileAccess.open("res://scripts/standings_summary_director.gd", FileAccess.READ)
	_expect(director_file != null, "standings director should be readable")
	if director_file != null:
		var source := director_file.get_as_text()
		_expect(source.contains('scene.get("roster_state")'), "standings panel should consume canonical roster state")
		_expect(source.contains("_roster_for_team"), "standings panel should resolve each club roster by team id")
		_expect(source.contains("StandingsSummaryRules.row_line(row, i + 1, \"jaguar_house\", _roster_for_team"), "standings rows should render availability from canonical roster")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
