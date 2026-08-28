extends Node2D

const ContentCatalog = preload("res://scripts/content_catalog.gd")
const MatchRules = preload("res://scripts/match_rules.gd")
const TeamPlayRules = preload("res://scripts/team_play_rules.gd")
const LeagueRules = preload("res://scripts/league_rules.gd")
const RosterRules = preload("res://scripts/roster_rules.gd")
const PLAYER_SPEED := 185.0
const AI_SPEED := 132.0
const COURT := Rect2(70.0, 62.0, 500.0, 250.0)
const BALL_RADIUS := 7.0
const USER_TEAM_ID := "jaguar_house"

enum GamePhase { TITLE, PLAYING, RESULT }

var phase := GamePhase.TITLE
var ball_position := Vector2(320.0, 180.0)
var ball_velocity := Vector2.ZERO
var home_score := 0
var away_score := 0
var match_time := 180.0
var match_length := 180.0
var ring_points := 5
var wall_points := 1
var wall_rebound := 0.82
var possession_team := 0
var possession_index := -1
var controlled_home_index := 0
var tackle_timer := 0.0
var last_score_text := "FIRST BALL"
var score_banner_timer := 2.0
var home_team_name := "JAGUAR HOUSE"
var away_team_name := "QUETZAL RUNNERS"
var home_team_id := USER_TEAM_ID
var away_team_id := "quetzal_runners"
var fixture_home_id := USER_TEAM_ID
var fixture_away_id := "quetzal_runners"
var court_name := "STONE COURT"
var result_text := ""
var status_text := ""
var status_timer := 0.0
var funds := 0
var match_number := 1
var home_fouls := 0
var away_fouls := 0
var home_ring_shots := 0
var away_ring_shots := 0
var manage_index := 0
var home_players: Array = []
var away_players: Array = []
var teams: Array = []
var rulesets: Array = []
var courts: Array = []
var role_profiles: Array = []
var fixture_rounds: Array = []
var league: Dictionary = {}
var league_table: Array = []
var roster_state: Array = []

func _ready() -> void:
	_configure_input()
	_load_content()
	_apply_match_identity()
	_prepare_match()
	queue_redraw()

func _process(delta: float) -> void:
	status_timer = maxf(0.0, status_timer - delta)
	match phase:
		GamePhase.TITLE:
			_update_management_input()
			if Input.is_action_just_pressed("confirm"): _start_match()
		GamePhase.PLAYING:
			_update_match(delta)
			if Input.is_action_just_pressed("cancel"): phase = GamePhase.TITLE
		GamePhase.RESULT:
			if Input.is_action_just_pressed("confirm"):
				_advance_between_matches()
				match_number += 1
				_apply_match_identity()
				_prepare_match()
				phase = GamePhase.TITLE
			elif Input.is_action_just_pressed("restart"):
				_start_match()
	queue_redraw()

func _load_content() -> void:
	var teams_data = ContentCatalog.load_json("res://data/teams.json")
	var rules_data = ContentCatalog.load_json("res://data/rules.json")
	var courts_data = ContentCatalog.load_json("res://data/courts.json")
	var league_data = ContentCatalog.load_json("res://data/league.json")
	var roles_data = ContentCatalog.load_json("res://data/player_roles.json")
	var rosters_data = ContentCatalog.load_json("res://data/rosters.json")
	var fixtures_data = ContentCatalog.load_json("res://data/fixtures.json")
	if typeof(teams_data) == TYPE_DICTIONARY: teams = teams_data.get("teams", [])
	if typeof(rules_data) == TYPE_DICTIONARY:
		rulesets = rules_data.get("rulesets", [])
		if not rulesets.is_empty():
			var active: Dictionary = rulesets[0]
			match_length = float(active.get("match_seconds", match_length))
			ring_points = int(active.get("ring_points", ring_points))
			wall_points = int(active.get("wall_points", wall_points))
	if typeof(courts_data) == TYPE_DICTIONARY: courts = courts_data.get("courts", [])
	if typeof(roles_data) == TYPE_DICTIONARY: role_profiles = roles_data.get("roles", [])
	if typeof(rosters_data) == TYPE_DICTIONARY: roster_state = rosters_data.get("rosters", []).duplicate(true)
	if typeof(fixtures_data) == TYPE_DICTIONARY: fixture_rounds = fixtures_data.get("rounds", [])
	if typeof(league_data) == TYPE_DICTIONARY:
		league = league_data
		funds = int(league.get("league", {}).get("starting_funds", 0))
	league_table = LeagueRules.make_table(teams)

func _team_for_id(id: String) -> Dictionary:
	for team in teams:
		if str(team.get("id", "")) == id: return team
	return {}

func _court_for_id(id: String) -> Dictionary:
	for court in courts:
		if str(court.get("id", "")) == id: return court
	return {}

func _role_profile(role: String) -> Dictionary:
	for profile in role_profiles:
		if str(profile.get("id", "")) == role: return profile
	return {"speed":1.0,"stamina":1.0,"tackle":1.0,"passing":1.0,"shooting":1.0,"toughness":5}

func _fixture_for_match() -> Dictionary:
	if fixture_rounds.is_empty(): return {"home":USER_TEAM_ID,"away":"quetzal_runners"}
	var round_data: Dictionary = fixture_rounds[(match_number - 1) % fixture_rounds.size()]
	for fixture in round_data.get("fixtures", []):
		if str(fixture.get("home", "")) == USER_TEAM_ID or str(fixture.get("away", "")) == USER_TEAM_ID:
			return fixture
	return {"home":USER_TEAM_ID,"away":"quetzal_runners"}

func _apply_match_identity() -> void:
	var fixture := _fixture_for_match()
	fixture_home_id = str(fixture.get("home", USER_TEAM_ID))
	fixture_away_id = str(fixture.get("away", "quetzal_runners"))
	home_team_id = USER_TEAM_ID
	away_team_id = fixture_away_id if fixture_home_id == USER_TEAM_ID else fixture_home_id
	var user_team := _team_for_id(home_team_id)
	var opponent := _team_for_id(away_team_id)
	home_team_name = str(user_team.get("name", "Jaguar House")).to_upper()
	away_team_name = str(opponent.get("name", "Opponent")).to_upper()
	var venue_team := _team_for_id(fixture_home_id)
	var court := _court_for_id(str(venue_team.get("home_court", "sunken_stone")))
	court_name = str(court.get("name", "Stone Court")).to_upper()
	wall_rebound = float(court.get("rebound", wall_rebound))
	ring_points = int(court.get("ring_points", ring_points))
	wall_points = int(court.get("wall_points", wall_points))

func _roster_for(team_id: String) -> Dictionary:
	return RosterRules.roster_for_team(roster_state, team_id)

func _prepare_match() -> void:
	home_score = 0; away_score = 0; match_time = match_length
	home_fouls = 0; away_fouls = 0; home_ring_shots = 0; away_ring_shots = 0
	last_score_text = "FIRST BALL"; score_banner_timer = 2.0; controlled_home_index = 0
	_spawn_rosters(); _reset_ball(false)

func _spawn_rosters() -> void:
	var home_specs := RosterRules.active_three(_roster_for(home_team_id))
	var away_specs := RosterRules.active_three(_roster_for(away_team_id))
	var home_spawns := [Vector2(205,135), Vector2(225,190), Vector2(205,245)]
	var away_spawns := [Vector2(435,135), Vector2(415,190), Vector2(435,245)]
	home_players.clear(); away_players.clear()
	for i in range(home_specs.size()): home_players.append(_make_player(home_spawns[i], home_specs[i], _team_for_id(home_team_id)))
	for i in range(away_specs.size()): away_players.append(_make_player(away_spawns[i], away_specs[i], _team_for_id(away_team_id)))

func _make_player(position: Vector2, spec: Dictionary, team: Dictionary) -> Dictionary:
	var role := str(spec.get("role", "runner"))
	var profile := _role_profile(role)
	var skill := float(spec.get("skill", 6))
	var skill_mult := 0.78 + skill * 0.04
	return {
		"id":str(spec.get("id", role)),"name":str(spec.get("name", role)).to_upper(),"position":position,"stamina":100.0,"role":role,"tackle_timer":0.0,"injured":0.0,
		"speed_mult":float(profile.get("speed",1.0)) * (float(team.get("speed",6))/7.0) * skill_mult,
		"stamina_mult":float(profile.get("stamina",1.0)),
		"tackle_mult":float(profile.get("tackle",1.0)) * (float(team.get("defence",7))/7.0) * skill_mult,
		"passing_mult":float(profile.get("passing",1.0)) * (float(team.get("attack",7))/7.0) * skill_mult,
		"shooting_mult":float(profile.get("shooting",1.0)) * (float(team.get("attack",7))/7.0) * skill_mult,
		"toughness":float(profile.get("toughness",5)) + float(spec.get("toughness_bonus",0)),
		"discipline":float(team.get("discipline",6)) + float(spec.get("discipline_bonus",0))
	}

func _update_management_input() -> void:
	var roster := _roster_for(USER_TEAM_ID)
	var players: Array = roster.get("players", [])
	if players.is_empty(): return
	if Input.is_action_just_pressed("manage_next"):
		manage_index = (manage_index + 1) % players.size(); status_text = "SELECTED %s" % str(players[manage_index].get("name","PLAYER")).to_upper(); status_timer = 1.2
	elif Input.is_action_just_pressed("substitute"):
		_manage_substitution(roster)
	elif Input.is_action_just_pressed("train"):
		_manage_training(roster)
	elif Input.is_action_just_pressed("medical"):
		_manage_medical(roster)

func _manage_substitution(roster: Dictionary) -> void:
	var players: Array = roster.get("players", [])
	if players.size() < 4: return
	var active := RosterRules.active_three(roster)
	var bench := RosterRules.bench(roster)
	var active_index := manage_index if manage_index < 3 else 2
	var bench_index := 0 if manage_index < 3 else manage_index - 3
	bench_index = clampi(bench_index, 0, bench.size() - 1)
	var result := RosterRules.substitute(active, bench, active_index, bench_index)
	if bool(result.get("changed", false)):
		roster["players"] = result["active"] + result["bench"]
		status_text = "LINEUP CHANGED"; status_timer = 1.5; manage_index = active_index

func _manage_training(roster: Dictionary) -> void:
	var players: Array = roster.get("players", [])
	if players.is_empty(): return
	manage_index = clampi(manage_index,0,players.size()-1)
	var career: Dictionary = league.get("career", {})
	var result := RosterRules.train_player(players[manage_index], funds, int(career.get("training_cost_base",220)))
	if bool(result.get("changed",false)):
		players[manage_index] = result["player"]; funds = int(result["funds"]); roster["players"] = players; status_text = "TRAINING COMPLETE"
	else: status_text = str(result.get("reason","NO CHANGE")).replace("_"," ")
	status_timer = 1.5

func _manage_medical(roster: Dictionary) -> void:
	var players: Array = roster.get("players", [])
	if players.is_empty(): return
	manage_index = clampi(manage_index,0,players.size()-1)
	var career: Dictionary = league.get("career", {})
	var result := RosterRules.treat_player(players[manage_index], funds, int(career.get("medical_cost_base",160)))
	if bool(result.get("changed",false)):
		players[manage_index] = result["player"]; funds = int(result["funds"]); roster["players"] = players; status_text = "TREATMENT COMPLETE"
	else: status_text = str(result.get("reason","NO CHANGE")).replace("_"," ")
	status_timer = 1.5

func _advance_between_matches() -> void:
	var roster := _roster_for(USER_TEAM_ID)
	var players: Array = roster.get("players", [])
	for i in range(players.size()): players[i] = RosterRules.recover_between_matches(players[i])
	roster["players"] = players

func _start_match() -> void:
	_prepare_match(); phase = GamePhase.PLAYING

func _finish_match() -> void:
	if phase == GamePhase.RESULT: return
	phase = GamePhase.RESULT; possession_team = 0; possession_index = -1; ball_velocity = Vector2.ZERO
	result_text = MatchRules.winner_text(home_team_name, away_team_name, home_score, away_score)
	var career: Dictionary = league.get("career", {})
	var prize := MatchRules.prize_for_result(home_score, away_score, int(career.get("win_purse",600)), int(career.get("draw_purse",250)), 0)
	funds += prize
	if prize > 0: result_text += "  +%d" % prize
	var cfg: Dictionary = league.get("league", {})
	if fixture_home_id == USER_TEAM_ID:
		LeagueRules.record_result(league_table, fixture_home_id, fixture_away_id, home_score, away_score, int(cfg.get("win_points",3)), int(cfg.get("draw_points",1)))
	else:
		LeagueRules.record_result(league_table, fixture_home_id, fixture_away_id, away_score, home_score, int(cfg.get("win_points",3)), int(cfg.get("draw_points",1)))
	_persist_match_injuries()

func _persist_match_injuries() -> void:
	var roster := _roster_for(USER_TEAM_ID)
	var specs: Array = roster.get("players", [])
	for runtime in home_players:
		var injury_seconds := float(runtime.get("injured",0.0))
		if injury_seconds <= 0.0: continue
		for i in range(specs.size()):
			if str(specs[i].get("id","")) == str(runtime.get("id","")):
				var spec: Dictionary = specs[i]
				spec["injury_matches"] = maxi(int(spec.get("injury_matches",0)), clampi(int(ceil(injury_seconds / 6.0)),1,3))
				specs[i] = spec; break
	roster["players"] = specs

func _update_match(delta: float) -> void:
	match_time = maxf(0.0, match_time - delta)
	if match_time <= 0.0: _finish_match(); return
	tackle_timer = maxf(0.0,tackle_timer-delta); score_banner_timer = maxf(0.0,score_banner_timer-delta)
	_tick_injuries(home_players,delta); _tick_injuries(away_players,delta)
	_update_controlled_player(delta); _update_team_ai(home_players,true,delta); _update_team_ai(away_players,false,delta)
	_update_ball(delta); _resolve_possession(); _resolve_tackles()
	if Input.is_action_just_pressed("switch_player"): _switch_controlled_player()

func _tick_injuries(players: Array, delta: float) -> void:
	for i in range(players.size()):
		var player: Dictionary = players[i]; player["injured"] = maxf(0.0,float(player.get("injured",0.0))-delta); players[i] = player

func _update_controlled_player(delta: float) -> void:
	if home_players.is_empty(): return
	var player: Dictionary = home_players[controlled_home_index]
	if float(player.get("injured",0.0)) > 0.0: return
	var movement := Input.get_vector("move_left","move_right","move_up","move_down")
	var position: Vector2 = player["position"]
	position += movement * PLAYER_SPEED * float(player.get("speed_mult",1.0)) * delta
	player["position"] = _clamp_to_court(position)
	player["stamina"] = MatchRules.recover_stamina(float(player["stamina"]), movement.length_squared()>0.01, delta*float(player.get("stamina_mult",1.0)))
	home_players[controlled_home_index] = player
	if possession_team == 1 and possession_index == controlled_home_index:
		ball_position = position + Vector2(16,3)
		if Input.is_action_just_pressed("pass_ball"): _pass_to_teammate()
		elif Input.is_action_just_pressed("strike_ball") and float(player["stamina"]) >= 10.0:
			player["stamina"] = MatchRules.clamp_stamina(float(player["stamina"])-10.0); home_players[controlled_home_index]=player
			_release_ball(position.direction_to(get_global_mouse_position()),420.0*float(player.get("shooting_mult",1.0)))

func _update_team_ai(players: Array, home: bool, delta: float) -> void:
	for i in range(players.size()):
		if home and i == controlled_home_index: continue
		var player: Dictionary = players[i]
		player["tackle_timer"] = maxf(0.0,float(player.get("tackle_timer",0.0))-delta)
		if float(player.get("injured",0.0)) > 0.0: players[i]=player; continue
		var position: Vector2 = player["position"]
		var target := TeamPlayRules.support_target(i,home,COURT)
		var owns := possession_team == (1 if home else 2) and possession_index == i
		if owns: target = Vector2(COURT.end.x-70,COURT.get_center().y) if home else Vector2(COURT.position.x+70,COURT.get_center().y)
		elif possession_team == 0 and TeamPlayRules.nearest_player_index(players,ball_position) == i: target = ball_position
		elif possession_team == (2 if home else 1) and position.distance_squared_to(_carrier_position()) < 16000: target = _carrier_position()
		var direction := position.direction_to(target)
		position += direction * AI_SPEED * float(player.get("speed_mult",1.0)) * delta
		player["position"] = _clamp_to_court(position)
		player["stamina"] = MatchRules.recover_stamina(float(player["stamina"]),direction.length_squared()>0.01,delta*float(player.get("stamina_mult",1.0)))
		players[i]=player
		if owns:
			ball_position = position + Vector2(16 if home else -16,3)
			if (home and position.x > COURT.get_center().x+90) or ((not home) and position.x < COURT.get_center().x-90):
				var aim := Vector2(COURT.end.x-18,COURT.get_center().y) if home else Vector2(COURT.position.x+18,COURT.get_center().y)
				_release_ball(position.direction_to(aim),365.0*float(player.get("shooting_mult",1.0)))

func _pass_to_teammate() -> void:
	var source: Dictionary = home_players[controlled_home_index]
	var source_position: Vector2 = source["position"]
	var target_index := TeamPlayRules.nearest_teammate_index(home_players,controlled_home_index,get_global_mouse_position())
	var speed := 285.0*float(source.get("passing_mult",1.0))
	if target_index == controlled_home_index: _release_ball(source_position.direction_to(get_global_mouse_position()),speed); return
	var target: Vector2 = home_players[target_index]["position"]
	_release_ball(source_position.direction_to(target),speed); controlled_home_index = target_index

func _switch_controlled_player() -> void:
	if home_players.is_empty(): return
	controlled_home_index = possession_index if possession_team == 1 and possession_index >= 0 else TeamPlayRules.nearest_player_index(home_players,ball_position)

func _update_ball(delta: float) -> void:
	if possession_team != 0: return
	ball_position += ball_velocity*delta; ball_velocity = ball_velocity.move_toward(Vector2.ZERO,92.0*delta)
	if _check_interception(): return
	if _check_ring_score() or _check_end_zone_score(): return
	_bounce_ball()

func _check_interception() -> bool:
	if ball_velocity.length() < 90.0: return false
	for player in home_players + away_players:
		var position: Vector2 = player["position"]
		if float(player.get("injured",0.0)) <= 0.0 and position.distance_to(ball_position) < 14.0:
			ball_velocity *= 0.35; return true
	return false

func _resolve_possession() -> void:
	if possession_team != 0 or ball_velocity.length() > 62.0: return
	for i in range(home_players.size()):
		var position: Vector2 = home_players[i]["position"]
		if float(home_players[i].get("injured",0.0)) <= 0.0 and position.distance_to(ball_position) < 21:
			possession_team=1; possession_index=i; controlled_home_index=i; return
	for i in range(away_players.size()):
		var position: Vector2 = away_players[i]["position"]
		if float(away_players[i].get("injured",0.0)) <= 0.0 and position.distance_to(ball_position) < 21:
			possession_team=2; possession_index=i; return

func _resolve_tackles() -> void:
	if home_players.is_empty() or away_players.is_empty(): return
	var player: Dictionary = home_players[controlled_home_index]
	if float(player.get("injured",0.0)) > 0.0: return
	var player_pos: Vector2 = player["position"]
	if Input.is_action_just_pressed("tackle") and MatchRules.can_tackle(float(player["stamina"]),tackle_timer):
		player["stamina"] = MatchRules.clamp_stamina(float(player["stamina"])-14.0); tackle_timer=0.55
		var ti := TeamPlayRules.nearest_player_index(away_players,player_pos); var opponent: Dictionary=away_players[ti]; var opponent_pos: Vector2=opponent["position"]
		if player_pos.distance_to(opponent_pos)<31:
			var force := PLAYER_SPEED*float(player.get("tackle_mult",1.0))
			if LeagueRules.foul_for_tackle(force,float(player.get("discipline",6.0))): home_fouls+=1; status_text="FOUL - TURNOVER"; status_timer=1.5; possession_team=2; possession_index=ti
			else:
				var push := player_pos.direction_to(opponent_pos)*24.0*float(player.get("tackle_mult",1.0)); opponent["position"]=_clamp_to_court(opponent_pos+push); opponent["injured"]=LeagueRules.injury_seconds_from_hit(force,float(opponent.get("toughness",5.0)))
				if possession_team==2 and possession_index==ti: _knock_ball_loose(opponent["position"],push.normalized())
			away_players[ti]=opponent
		home_players[controlled_home_index]=player
	if possession_team==1 and possession_index>=0:
		var carrier: Vector2=home_players[possession_index]["position"]; var ti:=TeamPlayRules.nearest_player_index(away_players,carrier); var tackler: Dictionary=away_players[ti]; var tp: Vector2=tackler["position"]
		if float(tackler.get("injured",0.0))<=0 and float(tackler.get("tackle_timer",0.0))<=0 and tp.distance_to(carrier)<28 and float(tackler["stamina"])>=10:
			var force:=AI_SPEED*float(tackler.get("tackle_mult",1.0)); tackler["stamina"]=MatchRules.clamp_stamina(float(tackler["stamina"])-10); tackler["tackle_timer"]=0.85
			if LeagueRules.foul_for_tackle(force,float(tackler.get("discipline",6.0))): away_fouls+=1; status_text="OPPOSITION FOUL"; status_timer=1.5
			else:
				var carrier_player: Dictionary=home_players[possession_index]; carrier_player["injured"]=LeagueRules.injury_seconds_from_hit(force,float(carrier_player.get("toughness",5.0))); home_players[possession_index]=carrier_player; _knock_ball_loose(carrier,tp.direction_to(carrier))
			away_players[ti]=tackler

func _knock_ball_loose(origin: Vector2,direction: Vector2)->void: ball_position=origin; ball_velocity=direction.normalized()*115; possession_team=0; possession_index=-1
func _carrier_position()->Vector2:
	if possession_team==1 and possession_index>=0: return home_players[possession_index]["position"]
	if possession_team==2 and possession_index>=0: return away_players[possession_index]["position"]
	return ball_position
func _release_ball(direction: Vector2,speed: float)->void:
	if direction.length_squared()<0.01: direction=Vector2.RIGHT if possession_team==1 else Vector2.LEFT
	ball_velocity=direction.normalized()*speed; possession_team=0; possession_index=-1

func _bounce_ball()->void:
	if ball_position.x<COURT.position.x+BALL_RADIUS: ball_position.x=COURT.position.x+BALL_RADIUS; ball_velocity.x=absf(ball_velocity.x)*wall_rebound
	elif ball_position.x>COURT.end.x-BALL_RADIUS: ball_position.x=COURT.end.x-BALL_RADIUS; ball_velocity.x=-absf(ball_velocity.x)*wall_rebound
	if ball_position.y<COURT.position.y+BALL_RADIUS: ball_position.y=COURT.position.y+BALL_RADIUS; ball_velocity.y=absf(ball_velocity.y)*wall_rebound
	elif ball_position.y>COURT.end.y-BALL_RADIUS: ball_position.y=COURT.end.y-BALL_RADIUS; ball_velocity.y=-absf(ball_velocity.y)*wall_rebound

func _check_ring_score()->bool:
	var left:=Vector2(COURT.position.x+18,COURT.get_center().y); var right:=Vector2(COURT.end.x-18,COURT.get_center().y)
	if ball_position.distance_to(left)<13 and ball_velocity.x<-120: away_ring_shots+=1; _award_score(2,ring_points,"RING SHOT"); return true
	if ball_position.distance_to(right)<13 and ball_velocity.x>120: home_ring_shots+=1; _award_score(1,ring_points,"RING SHOT"); return true
	return false
func _check_end_zone_score()->bool:
	if absf(ball_position.y-COURT.get_center().y)>48: return false
	if ball_position.x<=COURT.position.x+BALL_RADIUS and ball_velocity.x<0: _award_score(2,wall_points,"WALL SCORE"); return true
	if ball_position.x>=COURT.end.x-BALL_RADIUS and ball_velocity.x>0: _award_score(1,wall_points,"WALL SCORE"); return true
	return false
func _award_score(team:int,points:int,label:String)->void:
	if team==1: home_score+=points
	else: away_score+=points
	last_score_text="%s +%d"%[label,points]; score_banner_timer=1.5; _reset_ball(true)
func _reset_ball(preserve_stamina:=true)->void:
	ball_position=COURT.get_center(); ball_velocity=Vector2.ZERO; possession_team=0; possession_index=-1
	if preserve_stamina: _reset_positions()
	else: _spawn_rosters()
func _reset_positions()->void:
	var hs:=[Vector2(205,135),Vector2(225,190),Vector2(205,245)]; var as_:=[Vector2(435,135),Vector2(415,190),Vector2(435,245)]
	for i in range(home_players.size()): var p:Dictionary=home_players[i]; p["position"]=hs[i]; home_players[i]=p
	for i in range(away_players.size()): var p:Dictionary=away_players[i]; p["position"]=as_[i]; away_players[i]=p
func _clamp_to_court(point:Vector2)->Vector2: return Vector2(clampf(point.x,COURT.position.x+12,COURT.end.x-12),clampf(point.y,COURT.position.y+12,COURT.end.y-12))

func _configure_input()->void:
	_add_key_action("move_left",KEY_A); _add_key_action("move_left",KEY_LEFT); _add_key_action("move_right",KEY_D); _add_key_action("move_right",KEY_RIGHT); _add_key_action("move_up",KEY_W); _add_key_action("move_up",KEY_UP); _add_key_action("move_down",KEY_S); _add_key_action("move_down",KEY_DOWN)
	_add_key_action("pass_ball",KEY_SPACE); _add_key_action("strike_ball",KEY_X); _add_key_action("tackle",KEY_Z); _add_key_action("switch_player",KEY_C); _add_key_action("manage_next",KEY_C); _add_key_action("substitute",KEY_S); _add_key_action("train",KEY_T); _add_key_action("medical",KEY_M); _add_key_action("confirm",KEY_ENTER); _add_key_action("cancel",KEY_ESCAPE); _add_key_action("restart",KEY_R)
func _add_key_action(action:StringName,keycode:Key)->void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event:=InputEventKey.new(); event.physical_keycode=keycode
	if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)

func _selected_roster_player()->Dictionary:
	var players:Array=_roster_for(USER_TEAM_ID).get("players",[])
	if players.is_empty(): return {}
	return players[clampi(manage_index,0,players.size()-1)]

func _draw()->void:
	draw_rect(Rect2(0,0,640,360),Color("120f0b"))
	if phase==GamePhase.TITLE: _draw_title(); return
	if phase==GamePhase.RESULT: _draw_result(); return
	_draw_match()

func _draw_title()->void:
	var selected:=_selected_roster_player()
	draw_string(ThemeDB.fallback_font,Vector2(0,58),"OBSIDIAN RING",HORIZONTAL_ALIGNMENT_CENTER,640,29,Color("eadcae"))
	draw_string(ThemeDB.fallback_font,Vector2(0,101),"ROUND %02d   %s"%[match_number,court_name],HORIZONTAL_ALIGNMENT_CENTER,640,14,Color("bca777"))
	draw_string(ThemeDB.fallback_font,Vector2(0,132),"%s  VS  %s"%[home_team_name,away_team_name],HORIZONTAL_ALIGNMENT_CENTER,640,16,Color("f2d47d"))
	draw_string(ThemeDB.fallback_font,Vector2(0,174),"ENTER MATCH   C PLAYER   S SUB   T TRAIN   M MEDICAL",HORIZONTAL_ALIGNMENT_CENTER,640,10,Color("eadcae"))
	if not selected.is_empty(): draw_string(ThemeDB.fallback_font,Vector2(0,204),"%s  %s  SKILL %d  INJ %d"%[str(selected.get("name","PLAYER")).to_upper(),str(selected.get("role","runner")).to_upper(),int(selected.get("skill",1)),int(selected.get("injury_matches",0))],HORIZONTAL_ALIGNMENT_CENTER,640,12,Color("bca777"))
	draw_string(ThemeDB.fallback_font,Vector2(0,234),"FUNDS %05d   RING %d   WALL %d"%[funds,ring_points,wall_points],HORIZONTAL_ALIGNMENT_CENTER,640,11,Color("bca777"))
	if not league_table.is_empty(): draw_string(ThemeDB.fallback_font,Vector2(0,263),"LEADER %s  %d PTS"%[str(league_table[0].get("name","")),int(league_table[0].get("points",0))],HORIZONTAL_ALIGNMENT_CENTER,640,11,Color("9c8d68"))
	if status_timer>0: draw_string(ThemeDB.fallback_font,Vector2(0,302),status_text,HORIZONTAL_ALIGNMENT_CENTER,640,11,Color("f2d47d"))

func _draw_result()->void:
	draw_string(ThemeDB.fallback_font,Vector2(0,86),result_text,HORIZONTAL_ALIGNMENT_CENTER,640,19,Color("f2d47d"))
	draw_string(ThemeDB.fallback_font,Vector2(0,122),"%s %02d   %02d %s"%[home_team_name,home_score,away_score,away_team_name],HORIZONTAL_ALIGNMENT_CENTER,640,14,Color("eadcae"))
	draw_string(ThemeDB.fallback_font,Vector2(0,151),"RINGS %d-%d   FOULS %d-%d   FUNDS %05d"%[home_ring_shots,away_ring_shots,home_fouls,away_fouls,funds],HORIZONTAL_ALIGNMENT_CENTER,640,11,Color("bca777"))
	for i in range(mini(3,league_table.size())):
		var row:Dictionary=league_table[i]; draw_string(ThemeDB.fallback_font,Vector2(132,190+i*20),"%d. %-18s %2d PTS"%[i+1,str(row.get("name","")),int(row.get("points",0))],HORIZONTAL_ALIGNMENT_LEFT,380,11,Color("9c8d68"))
	draw_string(ThemeDB.fallback_font,Vector2(0,274),"ENTER NEXT ROUND    R REMATCH",HORIZONTAL_ALIGNMENT_CENTER,640,11,Color("bca777"))

func _draw_match()->void:
	draw_rect(COURT,Color("463522")); draw_rect(COURT,Color("b99b65"),false,3); draw_line(Vector2(COURT.get_center().x,COURT.position.y),Vector2(COURT.get_center().x,COURT.end.y),Color("7d6743"),2)
	var left:=Vector2(COURT.position.x+18,COURT.get_center().y); var right:=Vector2(COURT.end.x-18,COURT.get_center().y); draw_arc(left,13,0,TAU,24,Color("d2b87c"),4); draw_arc(right,13,0,TAU,24,Color("d2b87c"),4); draw_circle(ball_position,BALL_RADIUS,Color("1d1710"))
	for i in range(home_players.size()):
		var p:Vector2=home_players[i]["position"]; var injured:=float(home_players[i].get("injured",0))>0; draw_circle(p,11,Color("725f52") if injured else Color("d5c39a")); if i==controlled_home_index: draw_arc(p,15,0,TAU,18,Color("f2d47d"),2); draw_string(ThemeDB.fallback_font,p+Vector2(-18,-15),str(home_players[i].get("name","")),HORIZONTAL_ALIGNMENT_CENTER,36,7,Color("eadcae"))
	for player in away_players:
		var p:Vector2=player["position"]; draw_circle(p,11,Color("693e35") if float(player.get("injured",0))>0 else Color("9b563d"))
	draw_rect(Rect2(8,8,624,43),Color("090806")); var stamina:=int(home_players[controlled_home_index]["stamina"]) if not home_players.is_empty() else 0
	draw_string(ThemeDB.fallback_font,Vector2(16,27),"%s %02d   %03d   %02d %s"%[home_team_name,home_score,int(ceil(match_time)),away_score,away_team_name],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("eadcae")); draw_string(ThemeDB.fallback_font,Vector2(16,45),"%s  %s  STA %03d"%[court_name,str(home_players[controlled_home_index].get("name","P")) if not home_players.is_empty() else "P",stamina],HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("bca777"))
	if score_banner_timer>0: draw_string(ThemeDB.fallback_font,Vector2(250,62),last_score_text,HORIZONTAL_ALIGNMENT_CENTER,140,15,Color("f2d47d"))
	if status_timer>0: draw_string(ThemeDB.fallback_font,Vector2(0,342),status_text,HORIZONTAL_ALIGNMENT_CENTER,640,10,Color("f2d47d"))
