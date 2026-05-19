extends RefCounted

func evaluate_forest(observation: Dictionary, world_state) -> Dictionary:
	var effects: Array[String] = []
	var intent := "ForestCalm"
	var severity := 12.0
	var whisper := ""
	var warning := ""
	var fog := 0.0
	var path_shift := false
	var reverse_leaves := 0.0
	var exit_guidance := 0.0

	var explored := int(observation.get("explored_objects", 0))
	var time_in_forest := float(observation.get("time_in_forest", 0.0))
	var wandering := bool(observation.get("wandering", false))
	var ly_distance := float(observation.get("distance_to_ly_thong", 9999.0))
	var direct_exit := bool(observation.get("direct_exit_route", false))
	var instability: float = world_state.get_global_value("dream_instability")

	if explored >= 2:
		intent = "ObjectMemory"
		severity = maxf(severity, 34.0)
		effects.append("object_whisper")
		whisper = "Rung Mong ghi nho nhung manh moi da cham vao."
		world_state.add_value("knowledge", 0.25)

	if time_in_forest > 45.0 or instability > 12.0:
		intent = "TemporalFog"
		severity = maxf(severity, 44.0 + instability * 0.35)
		effects.append("dream_fog")
		world_state.add_value("dream_stability", -0.12)
		fog = clampf((65.0 - world_state.get_value("dream_stability") + instability * 0.25) / 65.0, 0.0, 0.62)
		warning = "Giac mo dang duc lai."
		if whisper == "":
			whisper = "Thoi gian trong rung bat dau keo dai."

	if wandering:
		intent = "PathShift"
		severity = maxf(severity, 58.0)
		effects.append("path_shift")
		effects.append("reverse_leaves")
		path_shift = true
		reverse_leaves = 1.0
		world_state.add_value("suspicion", 0.18)
		warning = "Loi mon dang lech khoi ky uc."
		whisper = "Rung doi huong khi Thach Sanh luong lu."

	if direct_exit and ly_distance < 96.0:
		intent = "TrustGuide"
		severity = maxf(severity, 28.0)
		effects.append("exit_guidance")
		exit_guidance = 1.0
		world_state.add_value("trust_ly_thong", 0.18)
		if whisper == "":
			whisper = "Loi ra sang hon khi hai nguoi di cung nhau."

	return _with_extra(_reaction(intent, severity, effects, whisper, warning), {
		"fog": fog,
		"path_shift": path_shift,
		"reverse_leaves": reverse_leaves,
		"exit_guidance": exit_guidance,
	})

func evaluate_boss(observation: Dictionary, world_state) -> Dictionary:
	var tactic := "BalancedPressure"
	var pressure: float = 3.0 + world_state.get_global_value("danger_bias") * 0.04
	var severity: float = 24.0 + world_state.get_global_value("danger_bias") * 0.20
	var effects: Array[String] = ["baseline_pressure"]
	var whisper := ""
	var warning := ""

	var attack_frequency := float(observation.get("attack_frequency", 0.0))
	var bow_ratio := float(observation.get("bow_ratio", 0.0))
	var aim_accuracy := float(observation.get("aim_accuracy", 0.0))
	var distance := float(observation.get("distance_to_boss", 0.0))
	var weapon_switch_frequency := float(observation.get("weapon_switch_frequency", 0.0))
	var dash_frequency := float(observation.get("dash_frequency", 0.0))
	var early_dash_frequency := float(observation.get("early_dash_frequency", 0.0))
	var corner_time := float(observation.get("corner_time", 0.0))
	var damage_taken_rate := float(observation.get("damage_taken_rate", 0.0))
	var player_hp_ratio := float(observation.get("player_hp_ratio", 1.0))
	var previous_tactic := String(observation.get("previous_tactic", ""))
	var repeated_tactic_windows := int(observation.get("repeated_tactic_windows", 0))
	var clue_read := bool(observation.get("clue_read", false))
	var trap_cleared := bool(observation.get("trap_cleared", false))
	var behavior_read := "balanced"

	if attack_frequency >= 4.0 and bow_ratio < 0.4:
		tactic = "PunishSpam"
		pressure = 18.0
		severity = 84.0
		effects = ["counter_ring", "melee_pressure"]
		whisper = "Boss da doc duoc nhip chem lien tuc."
		warning = "Vong phan don sap no."
		behavior_read = "spam_melee"
		world_state.add_value("combat_style_spam", 8.0)
	elif corner_time >= 1.5:
		tactic = "AreaDeny"
		pressure = 15.0
		severity = 76.0
		effects = ["arena_hazard", "corner_read"]
		whisper = "Goc an toan dang bi hang da nuot lai."
		warning = "Boss dang khoa goc dung."
		behavior_read = "corner_hold"
		world_state.add_value("danger", 1.4)
	elif bow_ratio > 0.65 and distance > 180.0:
		tactic = "CloseGap"
		pressure = 14.0
		severity = 72.0
		effects = ["close_gap", "dash_line"]
		whisper = "Khoang cach an toan dang bi rut ngan."
		warning = "Boss sap ap sat."
		behavior_read = "kite_bow"
		world_state.add_value("combat_style_kite", 8.0)
	elif aim_accuracy > 0.62 and bow_ratio > 0.45:
		tactic = "AntiAim"
		pressure = 12.0
		severity = 66.0
		effects = ["zigzag", "arrow_read"]
		whisper = "Mui ten qua chuan xac lam boss doi buoc di."
		warning = "Boss dang ne duong ban."
		behavior_read = "accurate_bow"
	elif early_dash_frequency >= 2.0 or (dash_frequency > 3.0 and distance < 160.0):
		tactic = "DelayedStrike"
		pressure = 11.0
		severity = 62.0
		effects = ["feint", "delayed_hit"]
		whisper = "Boss da bat dau giu don sau nhip dash."
		warning = "Don tiep theo se cham hon."
		behavior_read = "early_dash"
	elif weapon_switch_frequency > 4.0:
		tactic = "WeaponRead"
		pressure = 10.0
		severity = 58.0
		effects = ["bait_switch", "timing_read"]
		whisper = "Doi vu khi qua gap de lo y do."
		warning = "Boss dang canh nhip doi vu khi."
		behavior_read = "weapon_switch"

	if dash_frequency > 3.0:
		pressure += 2.0
		severity = maxf(severity, 50.0)
		effects.append("dash_read")

	if previous_tactic == tactic and tactic != "BalancedPressure" and repeated_tactic_windows >= 2:
		pressure *= 0.84
		severity *= 0.90
		effects.append("reaction_cooldown")

	if player_hp_ratio < 0.35 and damage_taken_rate > 10.0:
		pressure *= 0.72
		severity *= 0.82
		effects.append("fair_pressure_drop")

	if clue_read:
		severity *= 0.82
		pressure *= 0.88
		effects.append("prepared_read")
	if trap_cleared:
		severity *= 0.92
		effects.append("trap_awareness")

	world_state.add_value("danger", pressure * 0.14)
	var reaction := _reaction(tactic, severity, effects, whisper, warning)
	return _with_extra(reaction, {
		"tactic": tactic,
		"arena_pressure": pressure,
		"behavior_read": behavior_read,
	})

func evaluate_climb(observation: Dictionary, world_state) -> Dictionary:
	var fall_count := int(observation.get("fall_count", 0))
	var height_ratio := float(observation.get("height_ratio", 0.0))
	var idle_time := float(observation.get("idle_time", 0.0))
	var repeated_miss_count := int(observation.get("repeated_miss_count", 0))
	var anxiety: float = world_state.get_global_value("climb_anxiety")

	var wind := 0.0
	var ghost_platform := false
	var trajectory_echo := false
	var intent := "MountainStillness"
	var severity: float = 15.0 + anxiety * 0.25
	var effects: Array[String] = []
	var whisper := ""
	var warning := ""

	if fall_count >= 3 or anxiety > 18.0:
		intent = "WindMemory"
		severity = maxf(severity, 72.0)
		effects.append("memory_wind")
		wind = -28.0 - anxiety * 0.12
		world_state.add_value("climb_confidence", -0.35)
		whisper = "Gio vuc nhac lai nhung lan roi."
		warning = "Gio ky uc sap day nguoc huong."

	if height_ratio > 0.55:
		intent = "HighAltitudeWind" if intent == "MountainStillness" else intent
		severity = maxf(severity, 54.0 + height_ratio * 20.0)
		effects.append("altitude_wind")
		wind += 26.0
		if warning == "":
			warning = "Len cao, gio doi huong manh hon."

	if idle_time > 8.0:
		intent = "MountainBreath"
		severity = maxf(severity, 48.0)
		effects.append("ghost_platform")
		ghost_platform = true
		whisper = "Dung yen qua lau, nui bat dau tho."

	if repeated_miss_count >= 2:
		intent = "LandingEcho" if intent == "MountainStillness" else intent
		severity = maxf(severity, 42.0)
		effects.append("trajectory_echo")
		trajectory_echo = true
		if whisper == "":
			whisper = "Vach nui luu lai bong cua cu nhay sai."

	return _with_extra(_reaction(intent, severity, effects, whisper, warning), {
		"wind": wind,
		"ghost_platform": ghost_platform,
		"trajectory_echo": trajectory_echo,
	})

func _reaction(intent: String, severity: float, effects: Array[String], whisper: String, warning: String) -> Dictionary:
	return {
		"intent": intent,
		"severity": clampf(severity, 0.0, 100.0),
		"effects": effects,
		"ui": {
			"whisper": whisper,
			"meter_label": intent,
			"warning": warning,
		},
	}

func _with_extra(reaction: Dictionary, extra: Dictionary) -> Dictionary:
	for key in extra.keys():
		reaction[key] = extra[key]
	return reaction
