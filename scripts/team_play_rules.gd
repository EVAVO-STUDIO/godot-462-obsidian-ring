class_name TeamPlayRules
extends RefCounted

static func nearest_teammate_index(players: Array, from_index: int, target: Vector2) -> int:
	var best_index := from_index
	var best_score := INF
	for i in range(players.size()):
		if i == from_index:
			continue
		var position: Vector2 = players[i]["position"]
		var score := position.distance_squared_to(target)
		if score < best_score:
			best_score = score
			best_index = i
	return best_index

static func nearest_player_index(players: Array, point: Vector2) -> int:
	var best_index := 0
	var best_distance := INF
	for i in range(players.size()):
		var position: Vector2 = players[i]["position"]
		var distance := position.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

static func support_target(index: int, home: bool, court: Rect2) -> Vector2:
	var x_ratio := 0.30 if home else 0.70
	var y_ratios := [0.28, 0.50, 0.72]
	return Vector2(
		lerpf(court.position.x, court.end.x, x_ratio),
		lerpf(court.position.y, court.end.y, y_ratios[index % y_ratios.size()])
	)
