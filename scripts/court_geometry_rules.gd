class_name CourtGeometryRules
extends RefCounted

const REFERENCE_WIDTH := 500.0
const REFERENCE_HEIGHT := 250.0
const MIN_WIDTH_SCALE := 0.92
const MAX_WIDTH_SCALE := 1.04
const MIN_HEIGHT_SCALE := 0.92
const MAX_HEIGHT_SCALE := 1.04

static func movement_rect(base_rect: Rect2, court: Dictionary) -> Rect2:
	var width := maxf(1.0, float(court.get("width", REFERENCE_WIDTH)))
	var height := maxf(1.0, float(court.get("height", REFERENCE_HEIGHT)))
	var sx := clampf(width / REFERENCE_WIDTH, MIN_WIDTH_SCALE, MAX_WIDTH_SCALE)
	var sy := clampf(height / REFERENCE_HEIGHT, MIN_HEIGHT_SCALE, MAX_HEIGHT_SCALE)
	var size := Vector2(base_rect.size.x * sx, base_rect.size.y * sy)
	return Rect2(base_rect.get_center() - size * 0.5, size)

static func clamp_player(point: Vector2, movement_rect: Rect2, padding: float = 12.0) -> Vector2:
	return Vector2(
		clampf(point.x, movement_rect.position.x + padding, movement_rect.end.x - padding),
		clampf(point.y, movement_rect.position.y + padding, movement_rect.end.y - padding)
	)
