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
	var roster_state = scene.get("roster_state")
	var rows := StandingsSummaryRules.sorted_rows(table)
	var lines: Array[String] = ["LEAGUE TABLE"]
	for i in range(mini(4, rows.size())):
		var row: Dictionary = rows[i]
		lines.append(StandingsSummaryRules.row_line(row, i + 1, "jaguar_house", _roster_for_team(roster_state, str(row.get("id", "")))))
	var league_data = scene.get("league")
	var playoff_teams := 4
	if typeof(league_data) == TYPE_DICTIONARY:
		playoff_teams = int(league_data.get("league", {}).get("playoff_teams", playoff_teams))
	lines.append(StandingsSummaryRules.playoff_cutoff_line(playoff_teams, rows.size()))
	_label.text = "\n".join(lines)
	_panel.visible = true

func _roster_for_team(rosters, team_id: String) -> Dictionary:
	if typeof(rosters) != TYPE_ARRAY: return {}
	for roster in rosters:
		if typeof(roster) == TYPE_DICTIONARY and str(roster.get("team_id", "")) == team_id:
			return roster
	return {}

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(402, 82)
	_panel.size = Vector2(226, 168)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override("font_size", 8)
	_label.custom_minimum_size = Vector2(214, 156)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	return names.has("phase") and names.has("league_table") and names.has("league") and names.has("roster_state")
