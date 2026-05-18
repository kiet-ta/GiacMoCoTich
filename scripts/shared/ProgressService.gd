extends RefCounted

const SAVE_PATH := "user://progress.json"
const SCHEMA_VERSION := 1
const CHAPTER_IDS := ["chapter_1", "chapter_2", "chapter_3"]
const DEFAULT_GLOBAL_MEMORY := {
	"trust_ly_thong": 0.0,
	"suspicion": 0.0,
	"danger_bias": 0.0,
	"combat_spam_bias": 0.0,
	"combat_kite_bias": 0.0,
	"climb_anxiety": 0.0,
	"dream_instability": 0.0,
}

var progress := _default_progress()

func load_progress() -> void:
	progress = _default_progress()
	if not FileAccess.file_exists(SAVE_PATH):
		save_progress()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		save_progress()
		return

	if int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		save_progress()
		return

	var chapters = parsed.get("chapters", {})
	if typeof(chapters) != TYPE_DICTIONARY:
		save_progress()
		return

	for chapter_id in CHAPTER_IDS:
		if typeof(chapters.get(chapter_id, {})) == TYPE_DICTIONARY:
			progress["chapters"][chapter_id].merge(chapters[chapter_id], true)

	var parsed_memory = parsed.get("global_memory", {})
	if typeof(parsed_memory) == TYPE_DICTIONARY:
		for key in DEFAULT_GLOBAL_MEMORY.keys():
			if parsed_memory.has(key):
				progress["global_memory"][key] = clampf(float(parsed_memory[key]), 0.0, 100.0)
	_apply_unlock_rules()
	save_progress()

func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(progress, "\t"))

func is_unlocked(chapter_id: String) -> bool:
	return bool(progress["chapters"].get(chapter_id, {}).get("unlocked", false))

func get_chapter_progress(chapter_id: String) -> Dictionary:
	return progress["chapters"].get(chapter_id, {}).duplicate(true)

func get_global_memory() -> Dictionary:
	return progress.get("global_memory", DEFAULT_GLOBAL_MEMORY).duplicate(true)

func record_result(chapter_id: String, score: Dictionary, payload: Dictionary) -> Dictionary:
	var chapter: Dictionary = progress["chapters"].get(chapter_id, _default_chapter(false))
	chapter["completed"] = true
	chapter["best_stars"] = max(int(chapter.get("best_stars", 0)), int(score.get("stars", 1)))

	var time_seconds := float(payload.get("time_seconds", 0.0))
	var best_time := float(chapter.get("best_time", 0.0))
	if time_seconds > 0.0 and (best_time <= 0.0 or time_seconds < best_time):
		chapter["best_time"] = time_seconds

	chapter["last_payload"] = payload.duplicate(true)
	progress["chapters"][chapter_id] = chapter

	_apply_global_memory_delta(payload.get("global_memory_delta", {}))
	var next_unlocked := _unlock_next_after(chapter_id)
	save_progress()
	return {"next_unlocked": next_unlocked}

func _apply_global_memory_delta(delta: Variant) -> void:
	if typeof(delta) != TYPE_DICTIONARY:
		return
	if not progress.has("global_memory") or typeof(progress["global_memory"]) != TYPE_DICTIONARY:
		progress["global_memory"] = DEFAULT_GLOBAL_MEMORY.duplicate(true)
	for key in DEFAULT_GLOBAL_MEMORY.keys():
		if delta.has(key):
			var current := float(progress["global_memory"].get(key, DEFAULT_GLOBAL_MEMORY[key]))
			progress["global_memory"][key] = clampf(current + float(delta[key]), 0.0, 100.0)

func _unlock_next_after(chapter_id: String) -> String:
	var index := CHAPTER_IDS.find(chapter_id)
	if index < 0 or index >= CHAPTER_IDS.size() - 1:
		return ""

	var next_id: String = CHAPTER_IDS[index + 1]
	var next_chapter: Dictionary = progress["chapters"][next_id]
	if bool(next_chapter.get("unlocked", false)):
		return ""

	next_chapter["unlocked"] = true
	progress["chapters"][next_id] = next_chapter
	return next_id

func _apply_unlock_rules() -> void:
	progress["chapters"]["chapter_1"]["unlocked"] = true
	for i in range(CHAPTER_IDS.size() - 1):
		var current_id: String = CHAPTER_IDS[i]
		var next_id: String = CHAPTER_IDS[i + 1]
		if bool(progress["chapters"][current_id].get("completed", false)):
			progress["chapters"][next_id]["unlocked"] = true

func _default_progress() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"global_memory": DEFAULT_GLOBAL_MEMORY.duplicate(true),
		"chapters": {
			"chapter_1": _default_chapter(true),
			"chapter_2": _default_chapter(false),
			"chapter_3": _default_chapter(false),
		},
	}

func _default_chapter(unlocked: bool) -> Dictionary:
	return {
		"unlocked": unlocked,
		"completed": false,
		"best_stars": 0,
		"best_time": 0.0,
		"last_payload": {},
	}
