extends SceneTree

const ContentCatalog = preload("res://scripts/content_catalog.gd")
const CourtHazardRules = preload("res://scripts/court_hazard_rules.gd")
const CourtGeometryRules = preload("res://scripts/court_geometry_rules.gd")
const BASE_COURT := Rect2(70.0, 62.0, 500.0, 250.0)

var failures: Array[String] = []

func _initialize() -> void:
	var data = ContentCatalog.load_json("res://data/courts.json")
	_expect(typeof(data) == TYPE_DICTIONARY, "courts catalogue should load")
	var courts: Array = data.get("courts", []) if typeof(data) == TYPE_DICTIONARY else []
	var rain := _court(courts, "rain_court")
	var temple := _court(courts, "high_temple")
	var gate := _court(courts, "obsidian_gate")
	var sunken := _court(courts, "sunken_stone")
	_expect(CourtHazardRules.has_hazard(rain, "low_friction"), "Rain Court should expose low_friction")
	_expect(CourtHazardRules.low_friction_drag_compensation(rain) > 0.0, "low_friction should compensate ball drag")
	_expect(CourtHazardRules.effective_rebound(temple, 0.82) >= 0.96, "fast_walls should raise live rebound")
	_expect(CourtHazardRules.vertical_margin(gate) > CourtHazardRules.vertical_margin(rain), "narrow_sidelines should tighten vertical playable margin")
	var sunken_rect := CourtGeometryRules.movement_rect(BASE_COURT, sunken)
	var temple_rect := CourtGeometryRules.movement_rect(BASE_COURT, temple)
	var gate_rect := CourtGeometryRules.movement_rect(BASE_COURT, gate)
	_expect(temple_rect.size.x > sunken_rect.size.x, "wider authored court should produce wider live court geometry")
	_expect(gate_rect.size.y < sunken_rect.size.y, "shorter authored court should produce tighter vertical geometry")
	var outside := Vector2(0, 0)
	var clamped := CourtGeometryRules.clamp_player(outside, gate_rect)
	_expect(gate_rect.has_point(clamped), "court geometry should clamp players into movement space")
	_test_source_owned_geometry()
	if failures.is_empty():
		print("Obsidian Ring court hazard/geometry self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_source_owned_geometry() -> void:
	var main_file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	_expect(main_file != null, "main.gd should be readable for court geometry ownership checks")
	if main_file != null:
		var source := main_file.get_as_text()
		_expect(source.contains("const CourtGeometryRules = preload"), "main should consume shared court geometry rules")
		_expect(source.contains("var court_rect := COURT"), "main should own one live court rectangle")
		_expect(source.contains("court_rect = CourtGeometryRules.movement_rect(COURT, court)"), "venue selection should derive live court geometry from authored dimensions")
		_expect(source.contains("TeamPlayRules.support_target(i,home,court_rect)"), "AI support lanes should use live court geometry")
		_expect(source.contains("CourtGeometryRules.clamp_player(point,court_rect,12.0)"), "player clamp should use live court geometry")
		_expect(source.contains("ball_position=court_rect.get_center()"), "ball reset should use live court center")
		_expect(source.contains("ball_position.x<court_rect.position.x+BALL_RADIUS"), "ball wall collisions should use live court bounds")
		_expect(source.contains("Vector2(court_rect.position.x+18,court_rect.get_center().y)"), "ring positions should use live court geometry")
		_expect(source.contains("court_rect.size.y*0.192"), "wall scoring aperture should scale with live court height")
		_expect(source.contains("draw_rect(court_rect"), "rendering should use the same live court rectangle")
		_expect(source.contains("_formation_positions(true)") and source.contains("_formation_positions(false)"), "formations should derive from live court geometry")
	var hazard_file := FileAccess.open("res://scripts/court_hazard_director.gd", FileAccess.READ)
	_expect(hazard_file != null, "court hazard director should be readable")
	if hazard_file != null:
		var hazard_source := hazard_file.get_as_text()
		_expect(hazard_source.contains('scene.get("court_rect")'), "narrow sideline hazard should consume live court geometry")
		_expect(hazard_source.contains("rect.position.y + margin") and hazard_source.contains("rect.end.y - margin"), "narrow sideline clamp should refine live court bounds")
		_expect(not hazard_source.contains("COURT_TOP") and not hazard_source.contains("COURT_BOTTOM"), "hazards must not reintroduce fixed court boundaries")
	var project := FileAccess.open("res://project.godot", FileAccess.READ)
	_expect(project != null, "project.godot should be readable for geometry autoload checks")
	if project != null:
		_expect(not project.get_as_text().contains("CourtGeometryDirector"), "court geometry reconciliation autoload should stay removed")
	_expect(not FileAccess.file_exists("res://scripts/court_geometry_director.gd"), "obsolete court geometry director should remain deleted")

func _court(courts: Array, id: String) -> Dictionary:
	for court in courts:
		if str(court.get("id", "")) == id:
			return court
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
