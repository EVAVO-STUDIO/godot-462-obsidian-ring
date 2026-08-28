class_name ContentCatalog
extends RefCounted

static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing content file: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open content file: %s" % path)
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Invalid JSON content: %s" % path)
	return parsed

static func by_id(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id := str(item.get("id", ""))
		if not id.is_empty():
			result[id] = item
	return result
