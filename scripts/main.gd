extends Node2D

const ContentCatalog = preload("res://scripts/content_catalog.gd")
const MatchRules = preload("res://scripts/match_rules.gd")
const TeamPlayRules = preload("res://scripts/team_play_rules.gd")
const PLAYER_SPEED := 185.0
const AI_SPEED := 132.0
const COURT := Rect2(70.0, 62.0, 500.0, 250.0)
const BALL_RADIUS := 7.0

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
var court_name := "STONE COURT"
var result_text := ""
var funds := 0
var match_number := 1
var home_players: Array = []
var away_players: Array = []
var teams: Array = []
var rulesets: Array = []
var courts: Array = []
var league: Dictionary = {}

func _ready() -> void:
	_configure_input()
	_load_content()
	_prepare_match()
	queue_redraw()

func _process(delta: float) -> void:
	if phase == GamePhase.TITLE:
		if Input.is_action_just_pressed("confirm"):
			_start_match()
	elif phase == GamePhase.PLAYING:
		_update_match(delta)
		if Input.is_action_just_pressed("cancel"):
			phase = GamePhase.TITLE
	elif phase == GamePhase.RESULT:
		if Input.is_action_just_pressed("confirm"):
			match_number += 1
			_rotate_opponent()
			_prepare_match()
			phase = GamePhase.TITLE
		elif Input.is_action_just_pressed("restart"):
			_start_match()
	queue_redraw()

func _update_match(delta: float) -> void:
	match_time = maxf(0.0, match_time - delta)
	if match_time <= 0.0:
		_finish_match()
		return
	tackle_timer = maxf(0.0, tackle_timer - delta)
	score_banner_timer = maxf(0.0, score_banner_timer - delta)
	_update_controlled_player(delta)
	_update_team_ai(home_players, true, delta)
	_update_team_ai(away_players, false, delta)
	_update_ball(delta)
	_resolve_possession()
	_resolve_tackles()
	if Input.is_action_just_pressed("switch_player"):
		_switch_controlled_player()

func _load_content() -> void:
	var teams_data = ContentCatalog.load_json("res://data/teams.json")
	var rules_data = ContentCatalog.load_json("res://data/rules.json")
	var courts_data = ContentCatalog.load_json("res://data/courts.json")
	var league_data = ContentCatalog.load_json("res://data/league.json")
	if typeof(teams_data) == TYPE_DICTIONARY:
		teams = teams_data.get("teams", [])
	if typeof(rules_data) == TYPE_DICTIONARY:
		rulesets = rules_data.get("rulesets", [])
		if not rulesets.is_empty():
			var active: Dictionary = rulesets[0]
			match_length = float(active.get("match_seconds", match_length))
			ring_points = int(active.get("ring_points", ring_points))
			wall_points = int(active.get("wall_points", wall_points))
	if typeof(courts_data) == TYPE_DICTIONARY:
		courts = courts_data.get("courts", [])
	if typeof(league_data) == TYPE_DICTIONARY:
		league = league_data
		funds = int(league.get("league", {}).get("starting_funds", 0))
	_apply_match_identity()

func _apply_match_identity() -> void:
	if not teams.is_empty():
		home_team_name = str(teams[0].get("name", home_team_name)).to_upper()
	if teams.size() > 1:
		var away_index := 1 + ((match_number - 1) % (teams.size() - 1))
		away_team_name = str(teams[away_index].get("name", away_team_name)).to_upper()
	if not courts.is_empty():
		var active_court: Dictionary = courts[(match_number - 1) % courts.size()]
		court_name = str(active_court.get("name", court_name)).to_upper()
		wall_rebound = float(active_court.get("rebound", wall_rebound))

func _rotate_opponent() -> void:
	_apply_match_identity()

func _prepare_match() -> void:
	home_score = 0
	away_score = 0
	match_time = match_length
	last_score_text = "FIRST BALL"
	score_banner_timer = 2.0
	controlled_home_index = 0
	_spawn_rosters()
	_reset_ball()

func _spawn_rosters() -> void:
	home_players = [
		_make_player(Vector2(205.0, 135.0), "runner"),
		_make_player(Vector2(225.0, 190.0), "striker"),
		_make_player(Vector2(205.0, 245.0), "guard")
	]
	away_players = [
		_make_player(Vector2(435.0, 135.0), "runner"),
		_make_player(Vector2(415.0, 190.0), "striker"),
		_make_player(Vector2(435.0, 245.0), "guard")
	]

func _make_player(position: Vector2, role: String) -> Dictionary:
	return {"position":position,"stamina":100.0,"role":role,"tackle_timer":0.0}

func _start_match() -> void:
	_prepare_match()
	phase = GamePhase.PLAYING

func _finish_match() -> void:
	phase = GamePhase.RESULT
	possession_team = 0
	possession_index = -1
	ball_velocity = Vector2.ZERO
	result_text = MatchRules.winner_text(home_team_name, away_team_name, home_score, away_score)
	var career: Dictionary = league.get("career", {})
	var prize := MatchRules.prize_for_result(home_score, away_score, int(career.get("win_purse", 600)), int(career.get("draw_purse", 250)), 0)
	funds += prize
	if prize > 0:
		result_text += "  +%d" % prize

func _update_controlled_player(delta: float) -> void:
	if home_players.is_empty():
		return
	var player: Dictionary = home_players[controlled_home_index]
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := movement.length_squared() > 0.01
	var position: Vector2 = player["position"]
	position += movement * PLAYER_SPEED * delta
	player["position"] = _clamp_to_court(position)
	player["stamina"] = MatchRules.recover_stamina(float(player["stamina"]), moving, delta)
	home_players[controlled_home_index] = player
	if possession_team == 1 and possession_index == controlled_home_index:
		ball_position = Vector2(player["position"]) + Vector2(16.0, 3.0)
		if Input.is_action_just_pressed("pass_ball"):
			_pass_to_teammate()
		elif Input.is_action_just_pressed("strike_ball") and float(player["stamina"]) >= 10.0:
			player["stamina"] = MatchRules.clamp_stamina(float(player["stamina"]) - 10.0)
			home_players[controlled_home_index] = player
			_release_ball(Vector2(player["position"]).direction_to(get_global_mouse_position()), 420.0)

func _update_team_ai(players: Array, home: bool, delta: float) -> void:
	for i in range(players.size()):
		if home and i == controlled_home_index:
			continue
		var player: Dictionary = players[i]
		player["tackle_timer"] = maxf(0.0, float(player["tackle_timer"]) - delta)
		var position: Vector2 = player["position"]
		var target := TeamPlayRules.support_target(i, home, COURT)
		var owns_ball := possession_team == (1 if home else 2) and possession_index == i
		if owns_ball:
			target = Vector2(COURT.end.x - 70.0, COURT.get_center().y) if home else Vector2(COURT.position.x + 70.0, COURT.get_center().y)
		elif possession_team == 0:
			var nearest := TeamPlayRules.nearest_player_index(players, ball_position)
			if nearest == i:
				target = ball_position
		elif possession_team == (2 if home else 1):
			var carrier_pos := _carrier_position()
			if position.distance_squared_to(carrier_pos) < 16000.0:
				target = carrier_pos
		var direction := position.direction_to(target)
		position += direction * AI_SPEED * delta
		player["position"] = _clamp_to_court(position)
		player["stamina"] = MatchRules.recover_stamina(float(player["stamina"]), direction.length_squared() > 0.01, delta)
		players[i] = player
		if owns_ball:
			ball_position = Vector2(player["position"]) + Vector2(16.0 if home else -16.0, 3.0)
			if (home and position.x > COURT.get_center().x + 90.0) or ((not home) and position.x < COURT.get_center().x - 90.0):
				var aim := Vector2(COURT.end.x - 18.0, COURT.get_center().y) if home else Vector2(COURT.position.x + 18.0, COURT.get_center().y)
				_release_ball(position.direction_to(aim), 365.0)

func _pass_to_teammate() -> void:
	var source: Dictionary = home_players[controlled_home_index]
	var target_index := TeamPlayRules.nearest_teammate_index(home_players, controlled_home_index, get_global_mouse_position())
	if target_index == controlled_home_index:
		_release_ball(Vector2(source["position"]).direction_to(get_global_mouse_position()), 270.0)
		return
	var target_position: Vector2 = home_players[target_index]["position"]
	_release_ball(Vector2(source["position"]).direction_to(target_position), 285.0)
	controlled_home_index = target_index

func _switch_controlled_player() -> void:
	if home_players.is_empty():
		return
	if possession_team == 1 and possession_index >= 0:
		controlled_home_index = possession_index
	else:
		controlled_home_index = TeamPlayRules.nearest_player_index(home_players, ball_position)

func _update_ball(delta: float) -> void:
	if possession_team != 0:
		return
	ball_position += ball_velocity * delta
	ball_velocity = ball_velocity.move_toward(Vector2.ZERO, 92.0 * delta)
	if _check_ring_score() or _check_end_zone_score():
		return
	_bounce_ball()

func _resolve_possession() -> void:
	if possession_team != 0 or ball_velocity.length() > 62.0:
		return
	for i in range(home_players.size()):
		if Vector2(home_players[i]["position"]).distance_to(ball_position) < 21.0:
			possession_team = 1
			possession_index = i
			controlled_home_index = i
			return
	for i in range(away_players.size()):
		if Vector2(away_players[i]["position"]).distance_to(ball_position) < 21.0:
			possession_team = 2
			possession_index = i
			return

func _resolve_tackles() -> void:
	if home_players.is_empty() or away_players.is_empty():
		return
	var player: Dictionary = home_players[controlled_home_index]
	if Input.is_action_just_pressed("tackle") and MatchRules.can_tackle(float(player["stamina"]), tackle_timer):
		player["stamina"] = MatchRules.clamp_stamina(float(player["stamina"]) - 14.0)
		tackle_timer = 0.55
		var target_index := TeamPlayRules.nearest_player_index(away_players, Vector2(player["position"]))
		var opponent: Dictionary = away_players[target_index]
		if Vector2(player["position"]).distance_to(Vector2(opponent["position"])) < 31.0:
			var push := Vector2(player["position"]).direction_to(Vector2(opponent["position"])) * 24.0
			opponent["position"] = _clamp_to_court(Vector2(opponent["position"]) + push)
			if possession_team == 2 and possession_index == target_index:
				_knock_ball_loose(Vector2(opponent["position"]), push.normalized())
			away_players[target_index] = opponent
		home_players[controlled_home_index] = player
	if possession_team == 1 and possession_index >= 0:
		var carrier_position: Vector2 = home_players[possession_index]["position"]
		var tackler_index := TeamPlayRules.nearest_player_index(away_players, carrier_position)
		var tackler: Dictionary = away_players[tackler_index]
		if float(tackler["tackle_timer"]) <= 0.0 and Vector2(tackler["position"]).distance_to(carrier_position) < 28.0 and float(tackler["stamina"]) >= 10.0:
			tackler["stamina"] = MatchRules.clamp_stamina(float(tackler["stamina"]) - 10.0)
			tackler["tackle_timer"] = 0.85
			_knock_ball_loose(carrier_position, Vector2(tackler["position"]).direction_to(carrier_position))
			away_players[tackler_index] = tackler

func _knock_ball_loose(origin: Vector2, direction: Vector2) -> void:
	ball_position = origin
	ball_velocity = direction.normalized() * 115.0
	possession_team = 0
	possession_index = -1

func _carrier_position() -> Vector2:
	if possession_team == 1 and possession_index >= 0:
		return home_players[possession_index]["position"]
	if possession_team == 2 and possession_index >= 0:
		return away_players[possession_index]["position"]
	return ball_position

func _release_ball(direction: Vector2, speed: float) -> void:
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if possession_team == 1 else Vector2.LEFT
	ball_velocity = direction.normalized() * speed
	possession_team = 0
	possession_index = -1

func _bounce_ball() -> void:
	if ball_position.x < COURT.position.x + BALL_RADIUS:
		ball_position.x = COURT.position.x + BALL_RADIUS
		ball_velocity.x = absf(ball_velocity.x) * wall_rebound
	elif ball_position.x > COURT.end.x - BALL_RADIUS:
		ball_position.x = COURT.end.x - BALL_RADIUS
		ball_velocity.x = -absf(ball_velocity.x) * wall_rebound
	if ball_position.y < COURT.position.y + BALL_RADIUS:
		ball_position.y = COURT.position.y + BALL_RADIUS
		ball_velocity.y = absf(ball_velocity.y) * wall_rebound
	elif ball_position.y > COURT.end.y - BALL_RADIUS:
		ball_position.y = COURT.end.y - BALL_RADIUS
		ball_velocity.y = -absf(ball_velocity.y) * wall_rebound

func _check_ring_score() -> bool:
	var left_ring := Vector2(COURT.position.x + 18.0, COURT.get_center().y)
	var right_ring := Vector2(COURT.end.x - 18.0, COURT.get_center().y)
	if ball_position.distance_to(left_ring) < 13.0 and ball_velocity.x < -120.0:
		_award_score(2, ring_points, "RING SHOT"); return true
	if ball_position.distance_to(right_ring) < 13.0 and ball_velocity.x > 120.0:
		_award_score(1, ring_points, "RING SHOT"); return true
	return false

func _check_end_zone_score() -> bool:
	var lane_top := COURT.get_center().y - 48.0
	var lane_bottom := COURT.get_center().y + 48.0
	if ball_position.y < lane_top or ball_position.y > lane_bottom:
		return false
	if ball_position.x <= COURT.position.x + BALL_RADIUS and ball_velocity.x < 0.0:
		_award_score(2, wall_points, "WALL SCORE"); return true
	if ball_position.x >= COURT.end.x - BALL_RADIUS and ball_velocity.x > 0.0:
		_award_score(1, wall_points, "WALL SCORE"); return true
	return false

func _award_score(team: int, points: int, label: String) -> void:
	if team == 1: home_score += points
	else: away_score += points
	last_score_text = "%s +%d" % [label, points]
	score_banner_timer = 1.5
	_reset_ball()

func _reset_ball() -> void:
	ball_position = COURT.get_center()
	ball_velocity = Vector2.ZERO
	possession_team = 0
	possession_index = -1
	_spawn_rosters()

func _clamp_to_court(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, COURT.position.x + 12.0, COURT.end.x - 12.0), clampf(point.y, COURT.position.y + 12.0, COURT.end.y - 12.0))

func _configure_input() -> void:
	_add_key_action("move_left", KEY_A); _add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D); _add_key_action("move_right", KEY_RIGHT)
	_add_key_action("move_up", KEY_W); _add_key_action("move_up", KEY_UP)
	_add_key_action("move_down", KEY_S); _add_key_action("move_down", KEY_DOWN)
	_add_key_action("pass_ball", KEY_SPACE)
	_add_key_action("strike_ball", KEY_X)
	_add_key_action("tackle", KEY_Z)
	_add_key_action("switch_player", KEY_C)
	_add_key_action("confirm", KEY_ENTER)
	_add_key_action("cancel", KEY_ESCAPE)
	_add_key_action("restart", KEY_R)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event := InputEventKey.new(); event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("120f0b"))
	if phase == GamePhase.TITLE:
		_draw_title(); return
	if phase == GamePhase.RESULT:
		_draw_result(); return
	_draw_match()

func _draw_title() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0, 82), "OBSIDIAN RING", HORIZONTAL_ALIGNMENT_CENTER, 640, 30, Color("eadcae"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 132), "MATCH %02d   %s" % [match_number, court_name], HORIZONTAL_ALIGNMENT_CENTER, 640, 15, Color("bca777"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 170), "%s  VS  %s" % [home_team_name, away_team_name], HORIZONTAL_ALIGNMENT_CENTER, 640, 17, Color("f2d47d"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 230), "ENTER  BEGIN MATCH", HORIZONTAL_ALIGNMENT_CENTER, 640, 15, Color("eadcae"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 272), "3 ON 3   SPACE PASS   X STRIKE   Z TACKLE   C SWITCH", HORIZONTAL_ALIGNMENT_CENTER, 640, 11, Color("bca777"))

func _draw_result() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(0, 120), result_text, HORIZONTAL_ALIGNMENT_CENTER, 640, 21, Color("f2d47d"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 162), "%s %02d   %02d %s" % [home_team_name, home_score, away_score, away_team_name], HORIZONTAL_ALIGNMENT_CENTER, 640, 15, Color("eadcae"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 205), "FUNDS %05d" % funds, HORIZONTAL_ALIGNMENT_CENTER, 640, 13, Color("bca777"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 250), "ENTER  NEXT MATCH    R  REMATCH", HORIZONTAL_ALIGNMENT_CENTER, 640, 12, Color("bca777"))

func _draw_match() -> void:
	draw_rect(COURT, Color("463522"))
	draw_rect(COURT, Color("b99b65"), false, 3.0)
	draw_line(Vector2(COURT.get_center().x, COURT.position.y), Vector2(COURT.get_center().x, COURT.end.y), Color("7d6743"), 2.0)
	var left_ring := Vector2(COURT.position.x + 18.0, COURT.get_center().y)
	var right_ring := Vector2(COURT.end.x - 18.0, COURT.get_center().y)
	draw_arc(left_ring, 13.0, 0.0, TAU, 24, Color("d2b87c"), 4.0)
	draw_arc(right_ring, 13.0, 0.0, TAU, 24, Color("d2b87c"), 4.0)
	draw_circle(ball_position, BALL_RADIUS, Color("1d1710"))
	for i in range(home_players.size()):
		var p: Vector2 = home_players[i]["position"]
		draw_circle(p, 11.0, Color("d5c39a"))
		if i == controlled_home_index:
			draw_arc(p, 15.0, 0.0, TAU, 18, Color("f2d47d"), 2.0)
	for player in away_players:
		draw_circle(Vector2(player["position"]), 11.0, Color("9b563d"))
	draw_rect(Rect2(8, 8, 624, 43), Color("090806"))
	var stamina := int(home_players[controlled_home_index]["stamina"]) if not home_players.is_empty() else 0
	draw_string(ThemeDB.fallback_font, Vector2(16, 27), "%s %02d   %03d   %02d %s" % [home_team_name, home_score, int(ceil(match_time)), away_score, away_team_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("eadcae"))
	draw_string(ThemeDB.fallback_font, Vector2(16, 45), "%s  P%d  STA %03d" % [court_name, controlled_home_index + 1, stamina], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("bca777"))
	if score_banner_timer > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(250, 62), last_score_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color("f2d47d"))
