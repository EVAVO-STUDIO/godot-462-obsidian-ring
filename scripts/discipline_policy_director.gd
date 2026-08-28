extends Node

const DisciplineRules = preload("res://scripts/discipline_rules.gd")

func _ready() -> void:
	process_priority = -250

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or not _supports(scene):
		return
	var league_data = scene.get("league")
	if typeof(league_data) != TYPE_DICTIONARY:
		return
	var cfg = league_data.get("league", {})
	if typeof(cfg) != TYPE_DICTIONARY:
		return
	DisciplineRules.configure(
		maxi(1, int(cfg.get("booking_threshold", 3))),
		maxi(1, int(cfg.get("suspension_matches", 1)))
	)

func _supports(scene: Object) -> bool:
	for property in scene.get_property_list():
		if str(property.get("name", "")) == "league":
			return true
	return false
