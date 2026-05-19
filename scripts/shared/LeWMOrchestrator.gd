extends RefCounted

const WorldState = preload("res://scripts/shared/WorldState.gd")
const LeWMClient = preload("res://scripts/shared/LeWMClient.gd")
const LeWMReactionSystem = preload("res://scripts/shared/LeWMReactionSystem.gd")

var chapter_id := ""
var client := LeWMClient.new()
var fallback := LeWMReactionSystem.new()
var last_source := "fallback"
var last_model_version := "rule-fallback"
var last_confidence := 0.0
var last_latency_ms := 0.0
var last_error := ""
var ml_mode := "auto"
var min_ml_confidence := 0.55
var max_ml_latency_ms := 95.0

func configure(chapter: String, user_args: PackedStringArray) -> void:
	chapter_id = chapter
	for arg in user_args:
		if arg.begins_with("--lewm-mode="):
			ml_mode = arg.get_slice("=", 1)
		elif arg.begins_with("--lewm-min-confidence="):
			min_ml_confidence = clampf(float(arg.get_slice("=", 1)), 0.0, 1.0)
		elif arg.begins_with("--lewm-max-latency-ms="):
			max_ml_latency_ms = maxf(1.0, float(arg.get_slice("=", 1)))
	client.configure(user_args)
	client.start_session(chapter_id)

func evaluate_forest(observation: Dictionary, world_state: WorldState, viewport: Viewport, action_vector := []) -> Dictionary:
	return _evaluate("chapter_1", observation, world_state, viewport, action_vector, _forest_candidates(), Callable(fallback, "evaluate_forest"))

func evaluate_boss(observation: Dictionary, world_state: WorldState, viewport: Viewport, action_vector := []) -> Dictionary:
	return _evaluate("chapter_2", observation, world_state, viewport, action_vector, _boss_candidates(), Callable(fallback, "evaluate_boss"))

func evaluate_climb(observation: Dictionary, world_state: WorldState, viewport: Viewport, action_vector := []) -> Dictionary:
	return _evaluate("chapter_3", observation, world_state, viewport, action_vector, _climb_candidates(), Callable(fallback, "evaluate_climb"))

func debug_summary() -> String:
	return "lewm_source:%s model:%s conf:%d latency:%dms err:%s" % [
		last_source,
		last_model_version,
		int(last_confidence * 100.0),
		int(last_latency_ms),
		last_error,
	]

func _evaluate(api_chapter_id: String, observation: Dictionary, world_state: WorldState, viewport: Viewport, action_vector: Array, candidates: Array, fallback_callable: Callable) -> Dictionary:
	var reaction := client.predict_reaction(api_chapter_id, viewport, action_vector, observation, candidates)
	var sanitized := _sanitize_reaction(api_chapter_id, reaction, candidates)
	if not sanitized.is_empty():
		if _accept_ml_reaction(sanitized):
			_set_debug_from_reaction(sanitized)
			_apply_ml_memory_effect(api_chapter_id, sanitized, world_state)
			return sanitized
		last_error = "ml_gate:conf_%d_latency_%dms" % [
			int(float(sanitized.get("confidence", 0.0)) * 100.0),
			int(float(sanitized.get("latency_ms", client.last_latency_ms))),
		]

	var fallback_reaction: Dictionary = fallback_callable.call(observation, world_state)
	fallback_reaction["source"] = "fallback"
	fallback_reaction["confidence"] = 0.0
	fallback_reaction["model_version"] = "rule-fallback"
	fallback_reaction["latency_ms"] = client.last_latency_ms
	var fallback_error := client.last_error
	if fallback_error == "" and last_error != "":
		fallback_error = last_error
	last_source = "fallback"
	last_model_version = "rule-fallback"
	last_confidence = 0.0
	last_latency_ms = client.last_latency_ms
	last_error = fallback_error
	return fallback_reaction

func _accept_ml_reaction(reaction: Dictionary) -> bool:
	if ml_mode == "fallback":
		return false
	if ml_mode == "ml":
		return true
	var confidence := float(reaction.get("confidence", 0.0))
	var latency := float(reaction.get("latency_ms", client.last_latency_ms))
	return confidence >= min_ml_confidence and latency <= max_ml_latency_ms

func _sanitize_reaction(api_chapter_id: String, reaction: Dictionary, candidates: Array) -> Dictionary:
	if reaction.is_empty():
		return {}
	var intent := String(reaction.get("intent", ""))
	var base := _candidate_for_intent(candidates, intent)
	if base.is_empty():
		last_error = "unsafe_intent:%s" % intent
		return {}

	var sanitized := base.duplicate(true)
	var severity := clampf(float(reaction.get("severity", base.get("severity", 0.0))), 0.0, 100.0)
	sanitized["severity"] = severity
	sanitized["source"] = "ml"
	sanitized["confidence"] = clampf(float(reaction.get("confidence", 0.0)), 0.0, 1.0)
	sanitized["model_version"] = String(reaction.get("model_version", "lewm-local"))
	sanitized["latency_ms"] = float(reaction.get("latency_ms", client.last_latency_ms))
	sanitized["effects"] = _safe_effects(reaction.get("effects", sanitized.get("effects", [])), sanitized.get("effects", []))
	sanitized["ui"] = _safe_ui(reaction.get("ui", sanitized.get("ui", {})), sanitized.get("ui", {}), intent)

	if api_chapter_id == "chapter_1":
		_sanitize_forest_extras(sanitized)
	elif api_chapter_id == "chapter_2":
		_sanitize_boss_extras(sanitized)
	elif api_chapter_id == "chapter_3":
		_sanitize_climb_extras(sanitized)

	return sanitized

func _set_debug_from_reaction(reaction: Dictionary) -> void:
	last_source = String(reaction.get("source", "ml"))
	last_model_version = String(reaction.get("model_version", "lewm-local"))
	last_confidence = float(reaction.get("confidence", 0.0))
	last_latency_ms = float(reaction.get("latency_ms", 0.0))
	last_error = ""

func _apply_ml_memory_effect(api_chapter_id: String, reaction: Dictionary, world_state: WorldState) -> void:
	var intent := String(reaction.get("intent", ""))
	if api_chapter_id == "chapter_1":
		match intent:
			"ObjectMemory":
				world_state.add_value("knowledge", 0.25)
			"TemporalFog":
				world_state.add_value("dream_stability", -0.12)
			"PathShift":
				world_state.add_value("suspicion", 0.18)
			"TrustGuide":
				world_state.add_value("trust_ly_thong", 0.18)
	elif api_chapter_id == "chapter_2":
		match intent:
			"PunishSpam":
				world_state.add_value("combat_style_spam", 8.0)
			"CloseGap":
				world_state.add_value("combat_style_kite", 8.0)
			"AreaDeny":
				world_state.add_value("danger", 1.4)
		world_state.add_value("danger", float(reaction.get("arena_pressure", 3.0)) * 0.14)
	elif api_chapter_id == "chapter_3":
		if intent == "WindMemory":
			world_state.add_value("climb_confidence", -0.35)

func _candidate_for_intent(candidates: Array, intent: String) -> Dictionary:
	for candidate in candidates:
		if candidate is Dictionary and String(candidate.get("intent", "")) == intent:
			return candidate
	return {}

func _safe_effects(value: Variant, fallback_effects: Variant) -> Array:
	var allowed: Array = fallback_effects if fallback_effects is Array else []
	var requested: Array = value if value is Array else []
	var result := []
	for effect in requested:
		if allowed.has(String(effect)):
			result.append(String(effect))
	return result if not result.is_empty() else allowed.duplicate(true)

func _safe_ui(value: Variant, fallback_ui: Variant, intent: String) -> Dictionary:
	var fallback_ui_dict: Dictionary = fallback_ui if fallback_ui is Dictionary else {}
	var ui: Dictionary = value if value is Dictionary else {}
	return {
		"whisper": String(ui.get("whisper", fallback_ui_dict.get("whisper", ""))).left(140),
		"meter_label": intent,
		"warning": String(ui.get("warning", fallback_ui_dict.get("warning", ""))).left(120),
	}

func _sanitize_forest_extras(reaction: Dictionary) -> void:
	var intent := String(reaction.get("intent", "ForestCalm"))
	reaction["fog"] = 0.0
	reaction["path_shift"] = false
	reaction["reverse_leaves"] = 0.0
	reaction["exit_guidance"] = 0.0
	if intent == "TemporalFog":
		reaction["fog"] = clampf(float(reaction.get("severity", 0.0)) / 160.0, 0.08, 0.62)
	elif intent == "PathShift":
		reaction["path_shift"] = true
		reaction["reverse_leaves"] = 1.0
	elif intent == "TrustGuide":
		reaction["exit_guidance"] = 1.0

func _sanitize_boss_extras(reaction: Dictionary) -> void:
	var intent := String(reaction.get("intent", "BalancedPressure"))
	reaction["tactic"] = intent
	reaction["arena_pressure"] = clampf(float(reaction.get("arena_pressure", reaction.get("severity", 30.0) * 0.18)), 2.0, 18.0)
	reaction["behavior_read"] = String(reaction.get("behavior_read", _behavior_read_for_tactic(intent)))

func _sanitize_climb_extras(reaction: Dictionary) -> void:
	var intent := String(reaction.get("intent", "MountainStillness"))
	reaction["wind"] = 0.0
	reaction["ghost_platform"] = false
	reaction["trajectory_echo"] = false
	if intent == "WindMemory":
		reaction["wind"] = -32.0
	elif intent == "HighAltitudeWind":
		reaction["wind"] = 26.0
	elif intent == "MountainBreath":
		reaction["ghost_platform"] = true
	elif intent == "LandingEcho":
		reaction["trajectory_echo"] = true

func _behavior_read_for_tactic(tactic: String) -> String:
	match tactic:
		"PunishSpam":
			return "spam_melee"
		"CloseGap":
			return "kite_bow"
		"AntiAim":
			return "accurate_bow"
		"WeaponRead":
			return "weapon_switch"
		"AreaDeny":
			return "corner_hold"
		_:
			return "balanced"

func _forest_candidates() -> Array:
	return [
		_reaction("ForestCalm", 12.0, [], "", "", {"fog": 0.0, "path_shift": false, "reverse_leaves": 0.0, "exit_guidance": 0.0}),
		_reaction("ObjectMemory", 34.0, ["object_whisper"], "Rung Mong ghi nho nhung manh moi da cham vao.", "", {"fog": 0.0, "path_shift": false, "reverse_leaves": 0.0, "exit_guidance": 0.0}),
		_reaction("TemporalFog", 50.0, ["dream_fog"], "Thoi gian trong rung bat dau keo dai.", "Giac mo dang duc lai.", {"fog": 0.32, "path_shift": false, "reverse_leaves": 0.0, "exit_guidance": 0.0}),
		_reaction("PathShift", 58.0, ["path_shift", "reverse_leaves"], "Rung doi huong khi Thach Sanh luong lu.", "Loi mon dang lech khoi ky uc.", {"fog": 0.0, "path_shift": true, "reverse_leaves": 1.0, "exit_guidance": 0.0}),
		_reaction("TrustGuide", 28.0, ["exit_guidance"], "Loi ra sang hon khi hai nguoi di cung nhau.", "", {"fog": 0.0, "path_shift": false, "reverse_leaves": 0.0, "exit_guidance": 1.0}),
	]

func _boss_candidates() -> Array:
	return [
		_reaction("BalancedPressure", 24.0, ["baseline_pressure"], "", "", {"tactic": "BalancedPressure", "arena_pressure": 3.0, "behavior_read": "balanced"}),
		_reaction("PunishSpam", 84.0, ["counter_ring", "melee_pressure"], "Boss da doc duoc nhip chem lien tuc.", "Vong phan don sap no.", {"tactic": "PunishSpam", "arena_pressure": 18.0, "behavior_read": "spam_melee"}),
		_reaction("CloseGap", 72.0, ["close_gap", "dash_line"], "Khoang cach an toan dang bi rut ngan.", "Boss sap ap sat.", {"tactic": "CloseGap", "arena_pressure": 14.0, "behavior_read": "kite_bow"}),
		_reaction("AntiAim", 66.0, ["zigzag", "arrow_read"], "Mui ten qua chuan xac lam boss doi buoc di.", "Boss dang ne duong ban.", {"tactic": "AntiAim", "arena_pressure": 12.0, "behavior_read": "accurate_bow"}),
		_reaction("WeaponRead", 58.0, ["bait_switch", "timing_read"], "Doi vu khi qua gap de lo y do.", "Boss dang canh nhip doi vu khi.", {"tactic": "WeaponRead", "arena_pressure": 10.0, "behavior_read": "weapon_switch"}),
		_reaction("AreaDeny", 76.0, ["arena_hazard", "corner_read"], "Goc an toan dang bi hang da nuot lai.", "Boss dang khoa goc dung.", {"tactic": "AreaDeny", "arena_pressure": 15.0, "behavior_read": "corner_hold"}),
	]

func _climb_candidates() -> Array:
	return [
		_reaction("MountainStillness", 15.0, [], "", "", {"wind": 0.0, "ghost_platform": false, "trajectory_echo": false}),
		_reaction("WindMemory", 72.0, ["memory_wind"], "Gio vuc nhac lai nhung lan roi.", "Gio ky uc sap day nguoc huong.", {"wind": -32.0, "ghost_platform": false, "trajectory_echo": false}),
		_reaction("HighAltitudeWind", 64.0, ["altitude_wind"], "", "Len cao, gio doi huong manh hon.", {"wind": 26.0, "ghost_platform": false, "trajectory_echo": false}),
		_reaction("MountainBreath", 48.0, ["ghost_platform"], "Dung yen qua lau, nui bat dau tho.", "", {"wind": 0.0, "ghost_platform": true, "trajectory_echo": false}),
		_reaction("LandingEcho", 42.0, ["trajectory_echo"], "Vach nui luu lai bong cua cu nhay sai.", "", {"wind": 0.0, "ghost_platform": false, "trajectory_echo": true}),
	]

func _reaction(intent: String, severity: float, effects: Array, whisper: String, warning: String, extra: Dictionary) -> Dictionary:
	var reaction := {
		"intent": intent,
		"severity": severity,
		"effects": effects,
		"ui": {
			"whisper": whisper,
			"meter_label": intent,
			"warning": warning,
		},
	}
	for key in extra.keys():
		reaction[key] = extra[key]
	return reaction
