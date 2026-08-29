extends SceneTree

const RosterSaveRules = preload("res://scripts/roster_save_rules.gd")
const ConditionRules = preload("res://scripts/condition_rules.gd")
const SaveRecoveryRules = preload("res://scripts/save_recovery_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_canonical_roster_merge()
	_test_participant_accumulation()
	_test_substituted_injury_persistence()
	_test_match_long_injury_ledger()
	_test_condition_fatigue_order()
	_test_save_recovery()
	if failures.is_empty():
		print("Obsidian Ring persistence self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_canonical_roster_merge() -> void:
	var canonical := [{
		"team_id":"jaguar_house",
		"players":[
			{"id":"p1","name":"ONE","role":"runner","skill":5,"injury_matches":0,"fatigue_carry":0},
			{"id":"p2","name":"TWO","role":"guard","skill":4,"injury_matches":0,"fatigue_carry":0},
			{"id":"p3","name":"THREE","role":"striker","skill":6,"injury_matches":0,"fatigue_carry":0}
		]
	}]
	var saved := [{
		"team_id":"jaguar_house",
		"players":[
			{"id":"p1","name":"CORRUPTED NAME","role":"striker","skill":9,"injury_matches":2,"fatigue_carry":14},
			{"id":"p3","skill":99,"fatigue_carry":99},
			{"id":"unknown","skill":10}
		]
	}]
	var merged := RosterSaveRules.merge_rosters(canonical, saved)
	var players: Array = merged[0].get("players", [])
	_expect(players.size() == 3, "incomplete save must not delete canonical bench players")
	_expect(str(players[0].get("name", "")) == "ONE" and str(players[0].get("role", "")) == "runner", "saved state must not replace canonical player identity or role")
	_expect(int(players[0].get("skill", 0)) == 9 and int(players[0].get("injury_matches", 0)) == 2 and int(players[0].get("fatigue_carry", 0)) == 14, "mutable saved player state should merge by ID")
	_expect(str(players[1].get("id", "")) == "p2" and int(players[1].get("skill", 0)) == 4, "missing saved player must remain canonical and unchanged")
	_expect(int(players[2].get("skill", 0)) == 10 and int(players[2].get("fatigue_carry", 0)) == 40, "restored mutable fields should clamp to safe ranges")

func _test_participant_accumulation() -> void:
	var captured: Dictionary = {}
	captured = ConditionRules.capture_stamina(captured, [{"id":"starter","stamina":31.0},{"id":"other","stamina":80.0}])
	captured = ConditionRules.capture_stamina(captured, [{"id":"substitute","stamina":72.0},{"id":"other","stamina":64.0}])
	_expect(captured.has("starter"), "substituted-out participant must remain in match stamina accumulator")
	_expect(absf(float(captured["starter"]) - 31.0) < 0.001, "substituted-out participant should retain last observed stamina")
	_expect(absf(float(captured["other"]) - 64.0) < 0.001, "active participant stamina should update to latest observation")
	_expect(ConditionRules.carry_from_end_stamina(float(captured["starter"])) > 0, "tired substituted-out participant should receive fatigue carry rather than bench recovery")

func _test_substituted_injury_persistence() -> void:
	var substitution_file := FileAccess.open("res://scripts/match_substitution_director.gd", FileAccess.READ)
	_expect(substitution_file != null, "match substitution director should be readable")
	if substitution_file == null:
		return
	var source := substitution_file.get_as_text()
	_expect(source.contains("_persist_outgoing_injury(scene, outgoing)"), "live substitution must persist the outgoing player's injury before replacement")
	_expect(source.contains('var injury_seconds := float(outgoing.get("injured", 0.0))'), "outgoing injury persistence should use the live injury timer")
	_expect(source.contains("clampi(int(ceil(injury_seconds / 6.0)), 1, 3)"), "substitution injury conversion should match the result-path 1-3 match rule")
	_expect(source.contains('maxi(int(spec.get("injury_matches", 0)), injury_matches)'), "substitution persistence must never shorten an existing injury")

func _test_match_long_injury_ledger() -> void:
	var condition_file := FileAccess.open("res://scripts/condition_director.gd", FileAccess.READ)
	_expect(condition_file != null, "condition director should be readable for injury ledger checks")
	if condition_file == null:
		return
	var source := condition_file.get_as_text()
	_expect(source.contains("var _injury_seconds_by_id: Dictionary = {}"), "condition director should retain a match-long injury severity ledger")
	_expect(source.contains("_capture_user_injuries(scene.get(\"home_players\"))"), "user injuries should be sampled continuously while players are active")
	_expect(source.contains('if injury_seconds > float(_injury_seconds_by_id.get(id, 0.0))'), "injury ledger should retain the maximum observed severity rather than the countdown remainder")
	_expect(source.contains('var injury_matches := clampi(int(ceil(injury_seconds / 6.0)), 1, 3)'), "ledger should convert maximum injury severity to the canonical 1-3 match scale")
	_expect(source.contains('spec["injury_matches"] = maxi(int(spec.get("injury_matches", 0)), injury_matches)'), "ledger persistence must never shorten an existing career injury")
	var main_file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	_expect(main_file != null, "main.gd should remain readable for final-active injury fallback")
	if main_file != null:
		_expect(main_file.get_as_text().contains("_persist_match_injuries()"), "final on-court injury persistence should remain as a compatible fallback")

func _test_condition_fatigue_order() -> void:
	var condition_file := FileAccess.open("res://scripts/condition_director.gd", FileAccess.READ)
	var fatigue_file := FileAccess.open("res://scripts/fatigue_director.gd", FileAccess.READ)
	_expect(condition_file != null and fatigue_file != null, "condition and fatigue directors should be readable for process-order checks")
	if condition_file == null or fatigue_file == null:
		return
	var condition_source := condition_file.get_as_text()
	var fatigue_source := fatigue_file.get_as_text()
	_expect(condition_source.contains("process_priority = 150"), "condition should apply carried starting stamina before fatigue performance")
	_expect(fatigue_source.contains("process_priority = 170"), "fatigue should derive performance after condition state is applied")
	_expect(fatigue_source.contains("ConditionDirector runs at 150"), "fatigue ordering should remain intentional and documented in source")

func _test_save_recovery() -> void:
	var primary := JSON.stringify({"version":3,"funds":4200})
	var backup := JSON.stringify({"version":3,"funds":3100})
	var chosen := SaveRecoveryRules.choose_primary_or_backup(primary, backup, 2, 3)
	_expect(str(chosen.get("source", "")) == "primary" and int(chosen.get("data", {}).get("funds", 0)) == 4200, "valid primary season save should take precedence")
	chosen = SaveRecoveryRules.choose_primary_or_backup("{truncated", backup, 2, 3)
	_expect(str(chosen.get("source", "")) == "backup" and int(chosen.get("data", {}).get("funds", 0)) == 3100, "corrupt primary season save should recover from valid backup")
	chosen = SaveRecoveryRules.choose_primary_or_backup(JSON.stringify({"version":1}), JSON.stringify({"version":4}), 2, 3)
	_expect(str(chosen.get("source", "")) == "none" and chosen.get("data", {}).is_empty(), "unsupported season save versions must not restore")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
