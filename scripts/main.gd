extends Node2D

const PLAYER_SPEED := 185.0
const COURT := Rect2(70, 62, 500, 250)
const BALL_RADIUS := 7.0

var player_position := Vector2(240, 190)
var ball_position := Vector2(320, 180)
var ball_velocity := Vector2.ZERO
var home_score := 0
var away_score := 0
var match_time := 180.0
var possession := false

func _ready() -> void:
	_configure_input()
	queue_redraw()

func _process(delta: float) -> void:
	match_time = maxf(0.0, match_time - delta)

	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player_position += movement * PLAYER_SPEED * delta
	player_position.x = clampf(player_position.x, COURT.position.x + 12.0, COURT.end.x - 12.0)
	player_position.y = clampf(player_position.y, COURT.position.y + 12.0, COURT.end.y - 12.0)

	if player_position.distance_to(ball_position) < 22.0 and ball_velocity.length() < 45.0:
		possession = true

	if possession:
		ball_position = player_position + Vector2(16, 4)
		if Input.is_action_just_pressed("pass_ball"):
			possession = false
			ball_velocity = Vector2(260, 0).rotated((get_global_mouse_position() - player_position).angle())
		elif Input.is_action_just_pressed("strike_ball"):
			possession = false
			ball_velocity = Vector2(390, 0).rotated((get_global_mouse_position() - player_position).angle())
	else:
		ball_position += ball_velocity * delta
		ball_velocity = ball_velocity.move_toward(Vector2.ZERO, 85.0 * delta)
		_bounce_ball()
		_check_ring_score()

	queue_redraw()

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
	var left_ring := Vector2(COURT.position.x + 18, COURT.get_center().y)
	var right_ring := Vector2(COURT.end.x - 18, COURT.get_center().y)
	if ball_position.distance_to(left_ring) < 13.0 and ball_velocity.x < 0.0:
		away_score += 5
		_reset_ball()
	elif ball_position.distance_to(right_ring) < 13.0 and ball_velocity.x > 0.0:
		home_score += 5
		_reset_ball()

func _reset_ball() -> void:
	ball_position = COURT.get_center()
	ball_velocity = Vector2.ZERO
	possession = false

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("120f0b"))
	draw_rect(COURT, Color("463522"))
	draw_rect(COURT, Color("b99b65"), false, 3.0)
	draw_line(Vector2(COURT.get_center().x, COURT.position.y), Vector2(COURT.get_center().x, COURT.end.y), Color("7d6743"), 2.0)

	var left_ring := Vector2(COURT.position.x + 18, COURT.get_center().y)
	var right_ring := Vector2(COURT.end.x - 18, COURT.get_center().y)
	draw_arc(left_ring, 13, 0, TAU, 24, Color("d2b87c"), 4.0)
	draw_arc(right_ring, 13, 0, TAU, 24, Color("d2b87c"), 4.0)

	draw_circle(ball_position, BALL_RADIUS, Color("1d1710"))
	draw_circle(player_position, 11, Color("d5c39a"))
	draw_line(player_position, player_position + Vector2(18, 0), Color("8b2c22"), 4.0)

	draw_rect(Rect2(8, 8, 624, 38), Color("090806"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 31), "OBSIDIAN RING   HOME %02d   %03d   AWAY %02d" % [home_score, int(ceil(match_time)), away_score], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("eadcae"))
