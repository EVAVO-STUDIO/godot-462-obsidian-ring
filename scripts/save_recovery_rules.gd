class_name SaveRecoveryRules
extends RefCounted

static func parse_supported_json(text: String, min_version: int, max_version: int) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var version := int(parsed.get("version", -1))
	if version < min_version or version > max_version:
		return {}
	return parsed

static func choose_primary_or_backup(primary_text: String, backup_text: String, min_version: int, max_version: int) -> Dictionary:
	var primary := parse_supported_json(primary_text, min_version, max_version)
	if not primary.is_empty():
		return {"data": primary, "source": "primary"}
	var backup := parse_supported_json(backup_text, min_version, max_version)
	if not backup.is_empty():
		return {"data": backup, "source": "backup"}
	return {"data": {}, "source": "none"}
