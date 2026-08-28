extends SceneTree

const ContentCatalog = preload("res://scripts/content_catalog.gd")
const CourtHazardRules = preload("res://scripts/court_hazard_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var data = ContentCatalog.load_json("res://data/courts.json")
	_expect(typeof(data) == TYPE_DICTIONARY, "courts catalogue should load")
	var courts: Array = data.get("courts", []) if typeof(data) == TYPE_DICTIONARY else []
	var rain := _court(courts, "rain_court")
	var temple := _court(courts, "high_temple")
	var gate := _court(courts, "obsidian_gate")
	_expect(CourtHazardRules.has_hazard(rain, "low_friction"), "Rain Court should expose low_friction")
	_expect(CourtHazardRules.low_friction_drag_compensation(rain) > 0.0, "low_friction should compensate ball drag")
	_expect(CourtHazardRules.effective_rebound(temple, 0.82) >= 0.96, "fast_walls should raise live rebound")
	_expect(CourtHazardRules.vertical_margin(gate) > CourtHazardRules.vertical_margin(rain), "narrow_sidelines should tighten vertical playable margin")
	if failures.is_empty():
		print("Obsidian Ring court hazard self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _court(courts: Array, id: String) -> Dictionary:
	for court in courts:
		if str(court.get("id", "")) == id:
			return court
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
