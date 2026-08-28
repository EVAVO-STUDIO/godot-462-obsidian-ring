class_name DisciplineRules
extends RefCounted

static func booking_points_for_foul(force: float, discipline: float) -> int:
	var severity := force - discipline * 8.0
	if severity >= 190.0:
		return 2
	if severity >= 145.0:
		return 1
	return 0

static func suspension_matches(total_booking_points: int, previous_suspensions: int = 0) -> int:
	var threshold := 3 + previous_suspensions
	if total_booking_points < threshold:
		return 0
	return 1 + int((total_booking_points - threshold) / 3)

static func apply_booking(player: Dictionary, booking_points: int) -> Dictionary:
	var next := player.duplicate(true)
	var current := int(next.get("booking_points", 0))
	next["booking_points"] = maxi(0, current + booking_points)
	var prior := int(next.get("suspensions_served", 0))
	var suspension := suspension_matches(int(next["booking_points"]), prior)
	if suspension > int(next.get("suspension_matches", 0)):
		next["suspension_matches"] = suspension
		next["booking_points"] = 0
		next["suspensions_served"] = prior + 1
	return next

static func serve_round(player: Dictionary) -> Dictionary:
	var next := player.duplicate(true)
	next["suspension_matches"] = maxi(0, int(next.get("suspension_matches", 0)) - 1)
	return next

static func available(player: Dictionary) -> bool:
	return int(player.get("injury_matches", 0)) <= 0 and int(player.get("suspension_matches", 0)) <= 0
