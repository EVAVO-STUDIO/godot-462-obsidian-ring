class_name CourtHazardRules
extends RefCounted

static func has_hazard(court: Dictionary, hazard: String) -> bool:
	for item in court.get("hazards", []):
		if str(item) == hazard:
			return true
	return false

static func effective_rebound(court: Dictionary, fallback: float) -> float:
	var rebound := clampf(float(court.get("rebound", fallback)), 0.1, 1.25)
	if has_hazard(court, "fast_walls"):
		return maxf(rebound, 0.96)
	return rebound

static func low_friction_drag_compensation(court: Dictionary) -> float:
	return 42.0 if has_hazard(court, "low_friction") else 0.0

static func vertical_margin(court: Dictionary) -> float:
	return 34.0 if has_hazard(court, "narrow_sidelines") else 12.0
