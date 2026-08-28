extends CanvasLayer

const StandingsSummaryRules = preload("res://scripts/standings_summary_rules.gd")

var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	layer = 17
	_build_panel()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene) or int(scene.get("phase")) != 0:
		_panel.visible = false
		return
	var table = scene.get("league_table")
	if typeof(table) != TYPE_ARRAY or table.is_empty():
		_panel.visible = false
		return
	var rows := StandingsSummaryRules.sorted_rows(table)
	var lines: Array[String] = ["LEAGUE TABLE"]
	for i in range(mini(4, rows.size())):
		lines.append(StandingsSummaryRules.row_line(rows[i], i + 1))
	var league_data = scene.get("league")
	var playoff_teams := 4
	if typeof(league_data) == TYPE_DICTIONARY:
		playoff_teams = int(league_data.get("league", {}).get("playoff_teams", playoff_teams))
	lines.append(StandingsSummaryRules.playoff_cutoff_line(playoff_teams, rows.size()))
	_label.text = "\n".join(lines)
	_panel.visible = true

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(426, 82)
	_panel.size = Vector2(202, 168)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override("font_size", 8)
	_label.custom_minimum_size = Vector2(190, 156)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	return names.has("phase") and names.has("league_table") and names.has("league")
