extends SceneTree

const FoulLedgerRules = preload("res://scripts/foul_ledger_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var home_players := [
		{"id":"h0","name":"HOME ZERO","position":Vector2(100, 100)},
		{"id":"h1","name":"HOME ONE","position":Vector2(200, 100)}
	]
	var away_players := [
		{"id":"a0","name":"AWAY ZERO","position":Vector2(210, 100)},
		{"id":"a1","name":"AWAY ONE","position":Vector2(420, 100)}
	]
	var controlled := FoulLedgerRules.controlled_actor(home_players, 1)
	_expect(str(controlled.get("id", "")) == "h1", "home foul attribution should use the controlled tackler")
	var ai := FoulLedgerRules.ai_tackler_actor(away_players, home_players, 1, 1, 0)
	_expect(str(ai.get("id", "")) == "a0", "away foul attribution should match the nearest AI tackler to the live carrier")
	var fallback := FoulLedgerRules.ai_tackler_actor(away_players, home_players, 0, -1, 0)
	_expect(str(fallback.get("id", "")) == "a0", "away foul attribution should fall back to nearest tackler to controlled home player")
	var event := FoulLedgerRules.make_event("away", ai, 4, 9)
	_expect(str(event.get("actor_id", "")) == "a0" and int(event.get("round", 0)) == 4 and int(event.get("serial", 0)) == 9, "foul ledger event should preserve actor round and serial")
	if failures.is_empty():
		print("Obsidian Ring foul ledger self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
