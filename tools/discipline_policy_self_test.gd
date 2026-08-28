extends SceneTree

const DisciplineRules = preload("res://scripts/discipline_rules.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_test_default_policy()
	_test_custom_policy()
	if failures.is_empty():
		print("Obsidian Ring discipline policy self-test passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_default_policy() -> void:
	DisciplineRules.configure(3, 1)
	var booked := DisciplineRules.apply_booking({"booking_points":2,"suspension_matches":0,"suspensions_served":0}, 1)
	_expect(int(booked.get("suspension_matches", 0)) == 1, "three booking points should trigger one-match default suspension")
	_expect(int(booked.get("booking_points", 0)) == 0, "exact threshold should reset booking points to zero")

func _test_custom_policy() -> void:
	DisciplineRules.configure(4, 2)
	_expect(DisciplineRules.booking_threshold() == 4, "configured booking threshold should be retained")
	_expect(DisciplineRules.suspension_length() == 2, "configured suspension length should be retained")
	var booked := DisciplineRules.apply_booking({"booking_points":3,"suspension_matches":0,"suspensions_served":0}, 2)
	_expect(int(booked.get("suspension_matches", 0)) == 2, "custom policy should apply authored two-match suspension")
	_expect(int(booked.get("booking_points", 0)) == 1, "booking points above threshold should carry forward instead of disappearing")
	_expect(int(booked.get("suspensions_served", 0)) == 1, "triggered suspension should increment suspension history")
	var served := DisciplineRules.serve_round(booked)
	_expect(int(served.get("suspension_matches", 0)) == 1, "serving one round should decrement multi-match suspension by one")
	DisciplineRules.configure(3, 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
