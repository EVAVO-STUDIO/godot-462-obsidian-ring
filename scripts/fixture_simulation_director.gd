extends Node

const LeagueRules = preload("res://scripts/league_rules.gd")
const FixtureSimulationRules = preload("res://scripts/fixture_simulation_rules.gd")
const RosterRules = preload("res://scripts/roster_rules.gd")
const USER_TEAM_ID := "jaguar_house"

var _scene_id := 0
var _last_phase := -1
var _last_match_number := -1

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var scene_id := scene.get_instance_id()
	var match_number := int(scene.get("match_number"))
	if scene_id != _scene_id:
		_scene_id = scene_id
		_last_phase = int(scene.get("phase"))
		_last_match_number = match_number
		return
	if _last_match_number >= 0 and match_number != _last_match_number:
		_recover_non_user_rosters(scene)
		_last_match_number = match_number
	var phase := int(scene.get("phase"))
	if phase == 2 and _last_phase != 2:
		_simulate_other_fixture(scene)
	_last_phase = phase

func _supports(scene: Object) -> bool:
	var required := ["phase", "match_number", "fixture_rounds", "league_table", "league", "teams", "roster_state"]
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	for name in required:
		if not names.has(name):
			return false
	return true

func _recover_non_user_rosters(scene: Object) -> void:
	var rosters: Array = scene.get("roster_state")
	var changed := false
	for ri in range(rosters.size()):
		var roster = rosters[ri]
		if typeof(roster) != TYPE_DICTIONARY or str(roster.get("team_id", "")) == USER_TEAM_ID:
			continue
		var players: Array = roster.get("players", [])
		for pi in range(players.size()):
			players[pi] = RosterRules.recover_between_matches(players[pi])
		roster["players"] = players
		rosters[ri] = roster
		changed = true
	if changed:
		scene.set("roster_state", rosters)

func _simulate_other_fixture(scene: Object) -> void:
	var round_no := maxi(1, int(scene.get("match_number")))
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return
	var league_cfg: Dictionary = league_data.get("league", {})
	var season_rounds := maxi(1, int(league_cfg.get("season_rounds", 10)))
	if round_no > season_rounds:
		return
	var rounds: Array = scene.get("fixture_rounds")
	if round_no > rounds.size():
		return
	var round_data: Dictionary = rounds[round_no - 1]
	var other_fixture: Dictionary = {}
	for fixture in round_data.get("fixtures", []):
		var home_id := str(fixture.get("home", ""))
		var away_id := str(fixture.get("away", ""))
		if home_id == USER_TEAM_ID or away_id == USER_TEAM_ID:
			continue
		other_fixture = fixture
		break
	if other_fixture.is_empty():
		return
	var home_id := str(other_fixture.get("home", ""))
	var away_id := str(other_fixture.get("away", ""))
	var table: Array = scene.get("league_table")
	if not FixtureSimulationRules.fixture_needs_simulation(table, home_id, away_id, round_no):
		return
	var home := _team_for_id(scene.get("teams"), home_id)
	var away := _team_for_id(scene.get("teams"), away_id)
	if home.is_empty() or away.is_empty():
		return
	var roster_state: Array = scene.get("roster_state")
	var home_roster := RosterRules.roster_for_team(roster_state, home_id)
	var away_roster := RosterRules.roster_for_team(roster_state, away_id)
	home = FixtureSimulationRules.with_roster_context(home, home_roster)
	away = FixtureSimulationRules.with_roster_context(away, away_roster)
	var result := FixtureSimulationRules.simulate_fixture(home, away, round_no)
	LeagueRules.record_result(
		table,
		home_id,
		away_id,
		int(result.get("home_score", 0)),
		int(result.get("away_score", 0)),
		int(league_cfg.get("win_points", 3)),
		int(league_cfg.get("draw_points", 1))
	)
	scene.set("league_table", table)
	if _has_property(scene, "status_text"):
		scene.set("status_text", "%s %d-%d %s" % [str(home.get("name", home_id)).to_upper(), int(result["home_score"]), int(result["away_score"]), str(away.get("name", away_id)).to_upper()])
	if _has_property(scene, "status_timer"):
		scene.set("status_timer", 2.5)

func _team_for_id(teams: Array, id: String) -> Dictionary:
	for team in teams:
		if str(team.get("id", "")) == id:
			return team
	return {}

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false
