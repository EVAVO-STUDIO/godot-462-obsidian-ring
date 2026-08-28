class_name ConditionRules
extends RefCounted

const MAX_FATIGUE_CARRY := 40
const BENCH_RECOVERY := 18
const STARTING_STAMINA_FLOOR := 58.0

static func carry_from_end_stamina(stamina: float) -> int:
	var safe := clampf(stamina, 0.0, 100.0)
	if safe >= 35.0:
		return 0
	return clampi(int(round((35.0 - safe) * 0.9)), 0, MAX_FATIGUE_CARRY)

static func recover_bench_carry(current: int) -> int:
	return maxi(0, current - BENCH_RECOVERY)

static func starting_stamina(fatigue_carry: int) -> float:
	return clampf(100.0 - float(clampi(fatigue_carry, 0, MAX_FATIGUE_CARRY)), STARTING_STAMINA_FLOOR, 100.0)

static func capture_stamina(previous: Dictionary, players) -> Dictionary:
	var result := previous.duplicate(true)
	if typeof(players) != TYPE_ARRAY:
		return result
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var id := str(player.get("id", ""))
		if id != "":
			result[id] = clampf(float(player.get("stamina", 100.0)), 0.0, 100.0)
	return result
