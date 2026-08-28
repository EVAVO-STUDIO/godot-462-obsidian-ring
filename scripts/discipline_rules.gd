class_name DisciplineRules
extends RefCounted

static var _booking_threshold := 3
static var _suspension_length := 1

static func configure(booking_threshold: int, suspension_length: int) -> void:
	_booking_threshold = maxi(1, booking_threshold)
	_suspension_length = maxi(1, suspension_length)

static func booking_threshold() -> int:
	return _booking_threshold

static func suspension_length() -> int:
	return _suspension_length

static func booking_points_for_foul(force: float, discipline: float) -> int:
	var severity := force - discipline * 8.0
	if severity >= 190.0:
		return 2
	if severity >= 145.0:
		return 1
	return 0

static func suspension_matches(total_booking_points: int, booking_threshold_override: int = -1, suspension_length_override: int = -1) -> int:
	var threshold := _booking_threshold if booking_threshold_override < 1 else booking_threshold_override
	var length := _suspension_length if suspension_length_override < 1 else suspension_length_override
	if total_booking_points < threshold:
		return 0
	return maxi(1, length)

static func apply_booking(player: Dictionary, booking_points: int, booking_threshold_override: int = -1, suspension_length_override: int = -1) -> Dictionary:
	var next := player.duplicate(true)
	var threshold := _booking_threshold if booking_threshold_override < 1 else booking_threshold_override
	var length := _suspension_length if suspension_length_override < 1 else suspension_length_override
	var current := maxi(0, int(next.get("booking_points", 0)))
	var total := maxi(0, current + maxi(0, booking_points))
	next["booking_points"] = total
	if total < threshold:
		return next
	var existing_suspension := maxi(0, int(next.get("suspension_matches", 0)))
	next["suspension_matches"] = maxi(existing_suspension, length)
	next["booking_points"] = maxi(0, total - threshold)
	next["suspensions_served"] = maxi(0, int(next.get("suspensions_served", 0))) + 1
	return next

static func serve_round(player: Dictionary) -> Dictionary:
	var next := player.duplicate(true)
	next["suspension_matches"] = maxi(0, int(next.get("suspension_matches", 0)) - 1)
	return next

static func available(player: Dictionary) -> bool:
	return int(player.get("injury_matches", 0)) <= 0 and int(player.get("suspension_matches", 0)) <= 0
