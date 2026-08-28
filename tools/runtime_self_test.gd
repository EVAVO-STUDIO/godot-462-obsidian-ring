extends SceneTree

const ContentCatalog = preload("res://scripts/content_catalog.gd")
const MatchRules = preload("res://scripts/match_rules.gd")
const TeamPlayRules = preload("res://scripts/team_play_rules.gd")
const LeagueRules = preload("res://scripts/league_rules.gd")
const RosterRules = preload("res://scripts/roster_rules.gd")
const DisciplineRules = preload("res://scripts/discipline_rules.gd")
const PlayoffRules = preload("res://scripts/playoff_rules.gd")
const FatigueDirector = preload("res://scripts/fatigue_director.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_catalog()
	_test_match_rules()
	_test_team_play()
	_test_league()
	_test_roster()
	_test_discipline()
	_test_playoffs()
	_test_fatigue()
	if failures.is_empty():
		print("Obsidian Ring runtime self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _test_catalog() -> void:
	for path in ["res://data/teams.json","res://data/rules.json","res://data/courts.json","res://data/league.json","res://data/player_roles.json","res://data/rosters.json","res://data/fixtures.json"]:
		var parsed = ContentCatalog.load_json(path)
		_expect(typeof(parsed) == TYPE_DICTIONARY, "runtime content loader should parse %s" % path)

func _test_match_rules() -> void:
	_expect(MatchRules.clamp_stamina(120.0) == 100.0, "stamina should clamp to one hundred")
	_expect(MatchRules.recover_stamina(50.0, false, 1.0) > 50.0, "idle player should recover stamina")
	_expect(MatchRules.recover_stamina(50.0, true, 1.0) < 50.0, "moving player should spend stamina")
	_expect(MatchRules.can_tackle(20.0, 0.0), "player with stamina and no cooldown should tackle")
	_expect(MatchRules.winner_text("HOME", "AWAY", 5, 2) == "HOME WINS", "winner text should identify home winner")

func _test_team_play() -> void:
	var players := [
		{"position":Vector2(0, 0)},
		{"position":Vector2(100, 0)},
		{"position":Vector2(200, 0)}
	]
	_expect(TeamPlayRules.nearest_player_index(players, Vector2(90, 0)) == 1, "nearest-player selection should choose closest teammate")
	_expect(TeamPlayRules.nearest_teammate_index(players, 0, Vector2(190, 0)) == 2, "teammate targeting should exclude source player")

func _test_league() -> void:
	var teams := [{"id":"a","name":"A"},{"id":"b","name":"B"},{"id":"c","name":"C"},{"id":"d","name":"D"}]
	var table := LeagueRules.make_table(teams)
	LeagueRules.record_result(table, "a", "b", 5, 1, 3, 1)
	_expect(int(table[0]["played"]) == 1 and int(table[0]["points"]) == 3, "winning result should update played and points")
	_expect(int(table[1]["losses"]) == 1, "losing result should increment losses")
	var sorted := LeagueRules.sorted_table(table)
	_expect(str(sorted[0]["id"]) == "a", "standings should rank winner first")

func _test_roster() -> void:
	var roster := {"players":[
		{"id":"g","role":"guard","skill":7,"injury_matches":0,"suspension_matches":0},
		{"id":"s","role":"striker","skill":8,"injury_matches":0,"suspension_matches":0},
		{"id":"r","role":"runner","skill":9,"injury_matches":0,"suspension_matches":0},
		{"id":"b1","role":"runner","skill":6,"injury_matches":0,"suspension_matches":0},
		{"id":"b2","role":"guard","skill":6,"injury_matches":1,"suspension_matches":0}
	]}
	var active := RosterRules.active_three(roster)
	_expect(active.size() == 3, "active lineup should contain three players")
	var roles: Dictionary = {}
	for player in active:
		roles[str(player.get("role", ""))] = true
	_expect(roles.has("guard") and roles.has("striker") and roles.has("runner"), "active lineup should preserve role balance when possible")
	var trained := RosterRules.train_player({"skill":5,"injury_matches":0,"suspension_matches":0}, 500, 220)
	_expect(bool(trained["changed"]) and int(trained["player"]["skill"]) == 6, "training should increase skill when affordable")
	var suspended_roster := {"players":[
		{"id":"sg","role":"guard","skill":10,"injury_matches":0,"suspension_matches":1},
		{"id":"g","role":"guard","skill":7,"injury_matches":0,"suspension_matches":0},
		{"id":"s","role":"striker","skill":8,"injury_matches":0,"suspension_matches":0},
		{"id":"r","role":"runner","skill":9,"injury_matches":0,"suspension_matches":0},
		{"id":"b","role":"runner","skill":5,"injury_matches":0,"suspension_matches":0}
	]}
	var suspension_active := RosterRules.active_three(suspended_roster)
	for player in suspension_active:
		_expect(str(player.get("id", "")) != "sg", "suspended player must not enter active lineup")

	var bench := [
		{"id":"fast_runner","role":"runner","skill":9,"injury_matches":0,"suspension_matches":0},
		{"id":"steady_guard","role":"guard","skill":7,"injury_matches":0,"suspension_matches":0},
		{"id":"hurt_guard","role":"guard","skill":10,"injury_matches":1,"suspension_matches":0}
	]
	var role_pick := RosterRules.best_substitute_candidate(bench, {}, {}, "guard")
	_expect(str(role_pick.get("id", "")) == "steady_guard", "substitution should prefer an eligible same-role player over a higher-skill different role")
	var fallback_pick := RosterRules.best_substitute_candidate(bench, {}, {"steady_guard":true}, "guard")
	_expect(str(fallback_pick.get("id", "")) == "fast_runner", "substitution should fall back to the best eligible player when no same-role option remains")

func _test_discipline() -> void:
	var booked := DisciplineRules.apply_booking({"booking_points":2,"suspensions_served":0,"suspension_matches":0}, 1)
	_expect(int(booked.get("suspension_matches", 0)) >= 1, "booking threshold should trigger suspension")
	_expect(not DisciplineRules.available({"injury_matches":0,"suspension_matches":1}), "suspended player should be unavailable")
	_expect(DisciplineRules.available({"injury_matches":0,"suspension_matches":0}), "healthy unsuspended player should be available")

func _test_playoffs() -> void:
	var table := [
		{"id":"a","name":"A","points":12,"for":30,"against":10},
		{"id":"b","name":"B","points":10,"for":24,"against":14},
		{"id":"c","name":"C","points":8,"for":20,"against":18},
		{"id":"d","name":"D","points":6,"for":15,"against":21}
	]
	var semis := PlayoffRules.semifinal_pairings(table, 4)
	_expect(semis.size() == 2, "four-team playoffs should create two semifinals")
	_expect(str(semis[0]["home"]["id"]) == "a" and str(semis[0]["away"]["id"]) == "d", "first semifinal should pair seed one versus seed four")
	_expect(str(semis[1]["home"]["id"]) == "b" and str(semis[1]["away"]["id"]) == "c", "second semifinal should pair seed two versus seed three")
	var final_pair := PlayoffRules.final_pairing(["a", "b"], table)
	_expect(str(final_pair["home"]["id"]) == "a" and str(final_pair["away"]["id"]) == "b", "final should contain semifinal winners")

func _test_fatigue() -> void:
	var fatigue := FatigueDirector.new()
	var fresh := float(fatigue.performance_factor_for_stamina(100.0))
	var tired := float(fatigue.performance_factor_for_stamina(12.0))
	var exhausted := float(fatigue.performance_factor_for_stamina(0.0))
	_expect(fresh == 1.0, "fresh players should retain full performance")
	_expect(tired < fresh and tired > exhausted, "performance should degrade progressively with low stamina")
	_expect(exhausted >= 0.70, "fatigue floor should remain playable")
	fatigue.free()
