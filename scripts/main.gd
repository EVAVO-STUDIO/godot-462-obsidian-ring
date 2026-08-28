extends Node2D

const PLAYER_SPEED := 185.0
const AI_SPEED := 138.0
const COURT := Rect2(70.0, 62.0, 500.0, 250.0)
const BALL_RADIUS := 7.0
const MATCH_LENGTH := 180.0

var player_position := Vector2(240.0, 190.0)
var opponent_position := Vector2(430.0, 190.0)
var ball_position := Vector2(320.0, 180.0)
var ball_velocity := Vector2.ZERO
var home_score := 0
var away_score := 0
var match_time := MATCH_LENGTH
var possession_owner := 0
var stamina := 100.0
var opponent_stamina := 100.0
var tackle_timer := 0.0
var opponent_tackle_timer := 0.0
var last_score_text := "FIRST BALL"
var score_banner_timer := 2.0

func _ready() -> void:
	_configure_input()
	queue_redraw()

func _process(delta: float) -> void:
	if match_time > 0.0:
		match_time = maxf(0.0, match_time - delta)
		tackle_timer = maxf(0.0, tackle_timer - delta)
		opponent_tackle_timer = maxf(0.0, opponent_tackle_timer - delta)
		score_banner_timer = maxf(0.0, score_banner_timer - delta)
		_update_player(delta)
		_update_opponent(delta)
		_update_ball(delta)
		_resolve_possession()
		_resolve_tackles()
	else:
		possession_owner = 0
		ball_velocity = Vector2.ZERO

	queue_redraw()

func _update_player(delta: float) -> void:
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moving := movement.length_squared() > 0.01
	player_position += movement * PLAYER_SPEED * delta
	player_position = _clamp_to_court(player_position)
	stamina = clampf(stamina + (16.0 if not moving else -3.0) * delta, 0.0, 100.0)

	if possession_owner == 1:
		ball_position = player_position + Vector2(16.0, 3.0)
		if Input.is_action_just_pressed("pass_ball"):
			_release_ball(player_position.direction_to(get_global_mouse_position()), 270.0)
		elif Input.is_action_just_pressed("strike_ball") and stamina >= 10.0:
			stamina -= 10.0
			_release_ball(player_position.direction_to(get_global_mouse_position()), 420.0)

func _update_opponent(delta: float) -> void:
	var target := ball_position
	if possession_owner == 2:
		target = Vector2(COURT.position.x + 90.0, COURT.get_center().y)
	elif possession_owner == 1:
		target = player_position

	var direction := opponent_position.direction_to(target)
	var speed := AI_SPEED + (18.0 if possession_owner == 1 else 0.0)
	opponent_position += direction * speed * delta
	opponent_position = _clamp_to_court(opponent_position)
	opponent_stamina = clampf(opponent_stamina + (12.0 if direction.length_squared() < 0.01 else -2.0) * delta, 0.0, 100.0)

	if possession_owner == 2:
		ball_position = opponent_position + Vector2(-16.0, 3.0)
		if opponent_position.x < COURT.get_center().x + 30.0:
			var aim := Vector2(COURT.position.x + 18.0, COURT.get_center().y)
			_release_ball(opponent_position.direction_to(aim), 375.0)

func _update_ball(delta: float) -> void:
	if possession_owner != 0:
		return
	ball_position += ball_velocity * delta
	ball_velocity = ball_velocity.move_toward(Vector2.ZERO, 92.0 * delta)
	_check_ring_score()
	_check_end_zone_score()
	_bounce_ball()

func _resolve_possession() -> void:
	if possession_owner != 0 or ball_velocity.length() > 62.0:
		return
	if player_position.distance_to(ball_position) < 22.0:
		possession_owner = 1
	elif opponent_position.distance_to(ball_position) < 22.0:
		possession_owner = 2

func _resolve_tackles() -> void:
	if Input.is_action_just_pressed("tackle") and tackle_timer <= 0.0 and stamina >= 14.0:
		stamina -= 14.0
		tackle_timer = 0.55
		if player_position.distance_to(opponent_position) < 31.0:
			opponent_position += player_position.direction_to(opponent_position) * 24.0
			opponent_position = _clamp_to_court(opponent_position)
			if possession_owner == 2:
				possession_owner = 0
				ball_position = opponent_position.lerp(player_position, 0.45)
				ball_velocity = player_position.direction_to(opponent_position) * 110.0

	if possession_owner == 1 and opponent_tackle_timer <= 0.0 and opponent_position.distance_to(player_position) < 29.0:
		opponent_tackle_timer = 0.8
		if opponent_stamina >= 10.0:
			opponent_stamina -= 10.0
			possession_owner = 0
			ball_position = player_position.lerp(opponent_position, 0.45)
			ball_velocity = opponent_position.direction_to(player_position) * 105.0
			player_position += opponent_position.direction_to(player_position) * 20.0
			player_position = _clamp_to_court(player_position)

func _release_ball(direction: Vector2, speed: float) -> void:
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if possession_owner == 1 else Vector2.LEFT
	ball_velocity = direction.normalized() * speed
	possession_owner = 0

func _bounce_ball() -> void:
	if ball_position.x < COURT.position.x + BALL_RADIUS:
		ball_position.x = COURT.position.x + BALL_RADIUS
		ball_velocity.x = absf(ball_velocity.x) * 0.82
	elif ball_position.x > COURT.end.x - BALL_RADIUS:
		ball_position.x = COURT.end.x - BALL_RADIUS
		ball_velocity.x = -absf(ball_velocity.x) * 0.82

	if ball_position.y < COURT.position.y + BALL_RADIUS:
		ball_position.y = COURT.position.y + BALL_RADIUS
		ball_velocity.y = absf(ball_velocity.y) * 0.82
	elif ball_position.y > COURT.end.y - BALL_RADIUS:
		ball_position.y = COURT.end.y - BALL_RADIUS
		ball_velocity.y = -absf(ball_velocity.y) * 0.82

func _check_ring_score() -> void:
	var left_ring := Vector2(COURT.position.x + 18.0, COURT.get_center().y)
	var right_ring := Vector2(COURT.end.x - 18.0, COURT.get_center().y)
	if ball_position.distance_to(left_ring) < 13.0 and ball_velocity.x < -120.0:
		_award_score(2, 5, "RING SHOT")
	elif ball_position.distance_to(right_ring) < 13.0 and ball_velocity.x > 120.0:
		_award_score(1, 5, "RING SHOT")

func _check_end_zone_score() -> void:
	var lane_top := COURT.get_center().y - 48.0
	var lane_bottom := COURT.get_center().y + 48.0
	if ball_position.y < lane_top or ball_position.y > lane_bottom:
		return
	if ball_position.x <= COURT.position.x + 9.0 and ball_velocity.x < 0.0:
		_award_score(2, 1, "WALL SCORE")
	elif ball_position.x >= COURT.end.x - 9.0 and ball_velocity.x > 0.0:
		_award_score(1, 1, "WALL SCORE")

func _award_score(team: int, points: int, label: String) -> void:
	if team == 1:
		home_score += points
	else:
		away_score += points
	last_score_text = "%s +%d" % [label, points]
	score_banner_timer = 1.5
	_reset_ball()

func _reset_ball() -> void:
	ball_position = COURT.get_center()
	ball_velocity = Vector2.ZERO
	possession_owner = 0
	player_position = Vector2(240.0, 190.0)
	opponent_position = Vector2(400.0, 190.0)

func _clamp_to_court(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, COURT.position.x + 12.0, COURT.end.x - 12.0),
		clampf(point.y, COURT.position.y + 12.0, COURT.end.y - 12.0)
	)

func _configure_input() -> void:
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("move_up", KEY_W)
	_add_key_action("move_up", KEY_UP)
	_add_key_action("move_down", KEY_S)
	_add_key_action("move_down", KEY_DOWN)
	_add_key_action("pass_ball", KEY_SPACE)
	_add_key_action("strike_ball", KEY_X)
	_add_key_action("tackle", KEY_Z)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("120f0b"))
	draw_rect(COURT, Color("463522"))
	draw_rect(COURT, Color("b99b65"), false, 3.0)
	draw_line(Vector2(COURT.get_center().x, COURT.position.y), Vector2(COURT.get_center().x, COURT.end.y), Color("7d6743"), 2.0)

	var left_ring := Vector2(COURT.position.x + 18.0, COURT.get_center().y)
	var right_ring := Vector2(COURT.end.x - 18.0, COURT.get_center().y)
	draw_arc(left_ring, 13.0, 0.0, TAU, 24, Color("d2b87c"), 4.0)
	draw_arc(right_ring, 13.0, 0.0, TAU, 24, Color("d2b87c"), 4.0)

	draw_circle(ball_position, BALL_RADIUS, Color("1d1710"))
	draw_circle(player_position, 11.0, Color("d5c39a"))
	draw_line(player_position, player_position + Vector2(18.0, 0.0), Color("8b2c22"), 4.0)
	draw_circle(opponent_position, 11.0, Color("9b563d"))
	draw_line(opponent_position, opponent_position + Vector2(-18.0, 0.0), Color("1f2c32"), 4.0)

	draw_rect(Rect2(8, 8, 624, 38), Color("090806"))
	draw_string(ThemeDB.fallback_font, Vector2(16, 31), "OBSIDIAN RING  HOME %02d  %03d  AWAY %02d  STA %03d" % [home_score, int(ceil(match_time)), away_score, int(stamina)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("eadcae"))
	if score_banner_timer > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(250, 55), last_score_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color("f2d47d"))
