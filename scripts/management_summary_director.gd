extends CanvasLayer

const ManagementSummaryRules = preload("res://scripts/management_summary_rules.gd")

var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	layer = 18
	_build_panel()

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene) or int(scene.get("phase")) != 0:
		_panel.visible = false
		return
	var player := _selected_player(scene)
	var latest_foul := _latest_foul()
	var postseason := _postseason_state()
	_label.text = "%s\n%s\n%s" % [
		ManagementSummaryRules.player_line(player),
		ManagementSummaryRules.foul_line(latest_foul),
		ManagementSummaryRules.postseason_line(postseason.get("semifinal_winners", []), str(postseason.get("champion_id", "")))
	]
	_panel.visible = true

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(118, 314)
	_panel.size = Vector2(404, 42)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.custom_minimum_size = Vector2(392, 36)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false

func _selected_player(scene: Object) -> Dictionary:
	var rosters = scene.get("roster_state")
	if typeof(rosters) != TYPE_ARRAY:
		return {}
	var user_players: Array = []
	for roster in rosters:
		if typeof(roster) == TYPE_DICTIONARY and str(roster.get("team_id", "")) == "jaguar_house":
			user_players = roster.get("players", [])
			break
	if user_players.is_empty():
		return {}
	var index := clampi(int(scene.get("manage_index")), 0, user_players.size() - 1)
	var player = user_players[index]
	return player if typeof(player) == TYPE_DICTIONARY else {}

func _latest_foul() -> Dictionary:
	var ledger := get_node_or_null("/root/FoulLedgerDirector")
	if ledger == null or not ledger.has_method("latest_event"):
		return {}
	var event = ledger.call("latest_event")
	return event if typeof(event) == TYPE_DICTIONARY else {}

func _postseason_state() -> Dictionary:
	var director := get_node_or_null("/root/SeasonDirector")
	if director == null:
		return {}
	return {
		"semifinal_winners": director.get("_semifinal_winners"),
		"champion_id": director.get("_champion_id")
	}

func _supports(scene: Object) -> bool:
	var names: Dictionary = {}
	for property in scene.get_property_list():
		names[str(property.get("name", ""))] = true
	return names.has("phase") and names.has("manage_index") and names.has("roster_state")
