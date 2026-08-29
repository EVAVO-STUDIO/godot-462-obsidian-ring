class_name DisciplineRules
extends RefCounted

const DEFAULT_BOOKING_THRESHOLD := 3
const DEFAULT_SUSPENSION_LENGTH := 1

static func booking_points_for_foul(force: float, discipline: float) -> int:
	var severity := force - discipline * 8.0
	if severity >= 190.0:
		return 2
	if severity >= 145.0:
		return 1
	return 0

static func suspension_matches(total_booking_points: int, booking_threshold_override: int = -1, suspension_length_override: int = -1) -> int:
	var threshold := DEFAULT_BOOKING_THRESHOLD if booking_threshold_override < 1 else booking_threshold_override
	var length := DEFAULT_SUSPENSION_LENGTH if suspension_length_override < 1 else suspension_length_override
	if total_booking_points < threshold:
		return 0
	return maxi(1, length)

static func apply_booking(player: Dictionary, booking_points: int, booking_threshold_override: int = -1, suspension_length_override: int = -1) -> Dictionary:
	var next := player.duplicate(true)
	var threshold := DEFAULT_BOOKING_THRESHOLD if booking_threshold_override < 1 else booking_threshold_override
	var length := DEFAULT_SUSPENSION_LENGTH if suspension_length_override < 1 else suspension_length_override
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
