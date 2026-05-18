extends Node2D

signal chapter_completed(chapter_id: String, payload: Dictionary)

const WorldState = preload("res://scripts/shared/WorldState.gd")
const LeWMReactionSystem = preload("res://scripts/shared/LeWMReactionSystem.gd")

const ARENA := Rect2(420, 64, 520, 520)
const PREP_AREA := Rect2(48, 64, 320, 520)
const PLAYER_MAX_HP := 100.0
const BOSS_MAX_HP := 360.0

var world_state := WorldState.new()
var lewm := LeWMReactionSystem.new()
var player_pos := Vector2(150, 330)
var player_hp := PLAYER_MAX_HP
var player_speed := 165.0
var dash_cd := 0.0
var invuln := 0.0
var current_weapon := "axe"
var boss_pos := Vector2(700, 320)
var boss_hp := BOSS_MAX_HP
var boss_tactic := "BalancedPressure"
var boss_attack_cd := 0.0
var arena_started := false
var attack_cd := 0.0
var projectiles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var telegraphs: Array[Dictionary] = []
var whisper := ""
var window_time := 0.0
var attacks_in_window := 0
var bow_shots_in_window := 0
var bow_hits_in_window := 0
var weapon_switches_in_window := 0
var dash_count_in_window := 0
var arena_pressure := 0.0
var lewm_intent := "BalancedPressure"
var lewm_severity := 0.0
var lewm_impact_log: Array[String] = []
var elapsed := 0.0
var danger_spikes := 0
var clue_read := false
var trap_cleared := false
var completion_emitted := false

func _ready() -> void:
	_reset_chapter()

func _reset_chapter() -> void:
	player_pos = Vector2(150, 330)
	player_hp = PLAYER_MAX_HP
	player_speed = 165.0
	current_weapon = "axe"
	boss_pos = Vector2(700, 320)
	boss_hp = BOSS_MAX_HP
	boss_tactic = "BalancedPressure"
	boss_attack_cd = 0.0
	arena_started = false
	attack_cd = 0.0
	dash_cd = 0.0
	invuln = 0.0
	projectiles.clear()
	hazards.clear()
	telegraphs.clear()
	whisper = "Doc dau vet, ne bay, roi tien vao dau truong."
	window_time = 0.0
	attacks_in_window = 0
	bow_shots_in_window = 0
	bow_hits_in_window = 0
	weapon_switches_in_window = 0
	dash_count_in_window = 0
	arena_pressure = 0.0
	lewm_intent = "BalancedPressure"
	lewm_severity = 0.0
	lewm_impact_log.clear()
	elapsed = 0.0
	danger_spikes = 0
	clue_read = false
	trap_cleared = false
	completion_emitted = false
	world_state.reset()
	queue_redraw()

func apply_global_memory(memory: Dictionary) -> void:
	world_state.apply_global_memory(memory)
	arena_pressure = world_state.get_value("danger") * 0.15
	if world_state.get_global_value("danger_bias") > 10.0:
		whisper = "Dau truong da nho lai mui nguy hiem cu."

func _physics_process(delta: float) -> void:
	elapsed += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	boss_attack_cd = maxf(0.0, boss_attack_cd - delta)

	_update_weapon_switch()
	_update_player(delta)
	_update_projectiles(delta)
	_update_telegraphs(delta)
	_update_hazards(delta)
	_update_arena_start()

	if arena_started:
		_update_lewm_window(delta)
		_update_boss(delta)
		_check_boss_contact(delta)

	if player_hp <= 0.0:
		_reset_chapter()
	if boss_hp <= 0.0:
		_complete_chapter()

	queue_redraw()

func get_objective_text() -> String:
	if not arena_started:
		return "Doc dau vet, ne bay, roi tien vao dau truong."
	return "Danh bai Chan Tinh."

func get_hud_data() -> Dictionary:
	var boss_text := "Boss: --"
	if arena_started:
		boss_text = "Boss HP: %d/%d" % [int(maxf(boss_hp, 0.0)), int(BOSS_MAX_HP)]
	var tactic_text := _boss_tactic_text()
	var prep_done := (1 if clue_read else 0) + (1 if trap_cleared else 0)
	return {
		"extra": "Chuan bi: %d/2 | %s | Danger spikes: %d" % [prep_done, boss_text, danger_spikes],
		"message": "%s %s" % [whisper, tactic_text],
		"chips": [
			"LeWM: %s" % lewm_intent,
			"1 Riu" if current_weapon == "axe" else "1 riu",
			"2 Cung" if current_weapon == "bow" else "2 cung",
			"LMB tan cong",
			"Space dash",
		],
		"bars": _hud_bars(prep_done),
	}

func get_completion_payload() -> Dictionary:
	return {
		"time_seconds": elapsed,
		"hp_remaining": maxf(player_hp, 0.0),
		"danger_spikes": danger_spikes,
		"lewm_impact": lewm_impact_log.duplicate(true),
		"global_memory_delta": _global_memory_delta(),
	}

func get_debug_text() -> String:
	return "%s | tactic:%s pressure:%d" % [world_state.debug_summary(), boss_tactic, int(arena_pressure)]

func _update_weapon_switch() -> void:
	var previous := current_weapon
	if Input.is_key_pressed(KEY_1):
		current_weapon = "axe"
	elif Input.is_key_pressed(KEY_2):
		current_weapon = "bow"
	if previous != current_weapon:
		weapon_switches_in_window += 1

func _update_player(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	input = input.normalized()

	var speed := player_speed
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and dash_cd <= 0.0 and input != Vector2.ZERO:
		speed = 520.0
		dash_cd = 0.55
		invuln = 0.18
		dash_count_in_window += 1

	player_pos += input * speed * delta
	if arena_started:
		player_pos.x = clampf(player_pos.x, ARENA.position.x + 18.0, ARENA.end.x - 18.0)
		player_pos.y = clampf(player_pos.y, ARENA.position.y + 18.0, ARENA.end.y - 18.0)
	else:
		var allowed := PREP_AREA.merge(Rect2(360, 240, 90, 160))
		player_pos.x = clampf(player_pos.x, allowed.position.x + 18.0, allowed.end.x - 18.0)
		player_pos.y = clampf(player_pos.y, allowed.position.y + 18.0, allowed.end.y - 18.0)

	if not arena_started:
		if player_pos.distance_to(Vector2(190, 210)) < 38.0:
			clue_read = true
			whisper = "Dau vet keo dai vao noi boss an nap."
		if player_pos.distance_to(Vector2(280, 436)) < 46.0:
			trap_cleared = true
			whisper = "Bay da duoc ne qua an toan."

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and attack_cd <= 0.0:
		_attack()

func _attack() -> void:
	attacks_in_window += 1
	if current_weapon == "axe":
		attack_cd = 0.38
		if arena_started and player_pos.distance_to(boss_pos) < 76.0:
			boss_hp -= 18.0
	else:
		attack_cd = 0.24
		bow_shots_in_window += 1
		var direction := player_pos.direction_to(get_global_mouse_position())
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		projectiles.append({
			"pos": player_pos + direction * 18.0,
			"vel": direction * 430.0,
			"owner": "player",
			"damage": 12.0,
			"ttl": 1.8,
		})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		p["pos"] += p["vel"] * delta
		p["ttl"] = float(p["ttl"]) - delta
		projectiles[i] = p

		if String(p["owner"]) == "player" and arena_started and Vector2(p["pos"]).distance_to(boss_pos) < 24.0:
			boss_hp -= float(p["damage"])
			bow_hits_in_window += 1
			projectiles.remove_at(i)
			continue
		if String(p["owner"]) == "boss" and Vector2(p["pos"]).distance_to(player_pos) < 18.0:
			_damage_player(float(p["damage"]))
			projectiles.remove_at(i)
			continue
		if float(p["ttl"]) <= 0.0 or not Rect2(0, 0, 1000, 640).has_point(p["pos"]):
			projectiles.remove_at(i)

func _update_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h := hazards[i]
		h["ttl"] = float(h["ttl"]) - delta
		hazards[i] = h
		if Vector2(h["pos"]).distance_to(player_pos) < float(h["radius"]):
			_damage_player(18.0 * delta)
		if float(h["ttl"]) <= 0.0:
			hazards.remove_at(i)

func _update_telegraphs(delta: float) -> void:
	for i in range(telegraphs.size() - 1, -1, -1):
		var t := telegraphs[i]
		t["ttl"] = float(t["ttl"]) - delta
		telegraphs[i] = t
		if float(t["ttl"]) > 0.0:
			continue
		if String(t.get("kind", "hazard")) == "melee_counter":
			if Vector2(t["pos"]).distance_to(player_pos) < float(t["radius"]):
				_damage_player(float(t.get("damage", 18.0)))
		else:
			_spawn_hazard(Vector2(t["pos"]), float(t["radius"]))
		telegraphs.remove_at(i)

func _update_arena_start() -> void:
	if not arena_started and player_pos.x > 408.0:
		arena_started = true
		player_pos = Vector2(470, 320)
		whisper = "Dau truong dong lai. Boss dang doc tung thao tac."

func _update_lewm_window(delta: float) -> void:
	window_time += delta
	if window_time < 3.0:
		return

	var bow_ratio := 0.0
	if attacks_in_window > 0:
		bow_ratio = float(bow_shots_in_window) / float(attacks_in_window)
	var aim_accuracy := 0.0
	if bow_shots_in_window > 0:
		aim_accuracy = float(bow_hits_in_window) / float(bow_shots_in_window)

	var observation := {
		"attack_frequency": attacks_in_window,
		"bow_ratio": bow_ratio,
		"aim_accuracy": aim_accuracy,
		"distance_to_boss": player_pos.distance_to(boss_pos),
		"weapon_switch_frequency": weapon_switches_in_window,
		"dash_frequency": dash_count_in_window,
		"clue_read": clue_read,
		"trap_cleared": trap_cleared,
	}
	var reaction := lewm.evaluate_boss(observation, world_state)
	_apply_lewm_reaction(reaction)
	if lewm_severity >= 70.0:
		danger_spikes += 1
	var ui: Dictionary = reaction.get("ui", {})
	if String(ui.get("whisper", "")) != "":
		whisper = ui["whisper"]
	if boss_tactic == "AreaDeny" or arena_pressure > 12.0:
		_spawn_hazard_telegraph(player_pos + Vector2(randf_range(-60, 60), randf_range(-60, 60)), 46.0, 0.75, "hazard")

	window_time = 0.0
	attacks_in_window = 0
	bow_shots_in_window = 0
	bow_hits_in_window = 0
	weapon_switches_in_window = 0
	dash_count_in_window = 0

func _apply_lewm_reaction(reaction: Dictionary) -> void:
	boss_tactic = String(reaction.get("tactic", "BalancedPressure"))
	arena_pressure = float(reaction.get("arena_pressure", 3.0))
	lewm_intent = String(reaction.get("intent", boss_tactic))
	lewm_severity = float(reaction.get("severity", 0.0))
	_remember_impact(reaction)

func _remember_impact(reaction: Dictionary) -> void:
	var intent := String(reaction.get("intent", ""))
	if intent == "" or intent == "BalancedPressure":
		return
	var ui: Dictionary = reaction.get("ui", {})
	var text := "%s: %s" % [intent, String(ui.get("warning", ui.get("whisper", "")))]
	if not lewm_impact_log.has(text):
		lewm_impact_log.append(text)
	if lewm_impact_log.size() > 6:
		lewm_impact_log.remove_at(0)

func _global_memory_delta() -> Dictionary:
	return {
		"danger_bias": clampf(world_state.get_value("danger") * 0.16 + danger_spikes * 1.2, 0.0, 8.0),
		"combat_spam_bias": clampf(world_state.get_value("combat_style_spam") * 0.18, 0.0, 8.0),
		"combat_kite_bias": clampf(world_state.get_value("combat_style_kite") * 0.18, 0.0, 8.0),
	}

func _update_boss(delta: float) -> void:
	var direction := boss_pos.direction_to(player_pos)
	var speed := 92.0 + arena_pressure

	if boss_tactic == "CloseGap":
		speed = 170.0
	elif boss_tactic == "PunishSpam":
		speed = 130.0
	elif boss_tactic == "AntiAim":
		var side := Vector2(-direction.y, direction.x) * sin(Time.get_ticks_msec() * 0.012)
		direction = (direction + side * 0.8).normalized()
		speed = 135.0
	elif boss_tactic == "WeaponRead":
		speed = 150.0

	boss_pos += direction * speed * delta
	boss_pos.x = clampf(boss_pos.x, ARENA.position.x + 32.0, ARENA.end.x - 32.0)
	boss_pos.y = clampf(boss_pos.y, ARENA.position.y + 32.0, ARENA.end.y - 32.0)

	if boss_attack_cd <= 0.0:
		_boss_attack()

func _boss_attack() -> void:
	boss_attack_cd = 1.0
	var direction := boss_pos.direction_to(player_pos)
	if boss_tactic == "PunishSpam" and boss_pos.distance_to(player_pos) < 110.0:
		_spawn_hazard_telegraph(player_pos, 58.0, 0.42, "melee_counter")
		boss_attack_cd = 0.75
		return
	if boss_tactic == "AreaDeny":
		_spawn_hazard_telegraph(player_pos, 48.0, 0.70, "hazard")
		boss_attack_cd = 1.25
		return
	projectiles.append({
		"pos": boss_pos + direction * 28.0,
		"vel": direction * (230.0 + arena_pressure * 2.0),
		"owner": "boss",
		"damage": 14.0,
		"ttl": 2.6,
	})

func _check_boss_contact(_delta: float) -> void:
	if boss_pos.distance_to(player_pos) < 34.0:
		_damage_player(16.0)

func _damage_player(amount: float) -> void:
	if invuln > 0.0:
		return
	player_hp -= amount
	invuln = 0.35

func _spawn_hazard_telegraph(pos: Vector2, radius: float, ttl: float, kind: String) -> void:
	telegraphs.append({
		"pos": pos,
		"radius": radius,
		"ttl": ttl,
		"kind": kind,
		"damage": 22.0 if kind == "melee_counter" else 0.0,
	})

func _spawn_hazard(pos: Vector2, radius := 46.0) -> void:
	hazards.append({
		"pos": pos,
		"radius": radius,
		"ttl": 2.2,
	})

func _complete_chapter() -> void:
	if completion_emitted:
		return
	completion_emitted = true
	chapter_completed.emit("chapter_2", get_completion_payload())

func _boss_tactic_text() -> String:
	match boss_tactic:
		"PunishSpam":
			return "Boss dang phan don spam."
		"CloseGap":
			return "Boss dang ap sat."
		"AntiAim":
			return "Boss dang ne mui ten."
		"WeaponRead":
			return "Boss dang doc doi vu khi."
		_:
			return "Boss dang giu ap luc can bang."

func _hud_bars(prep_done: int) -> Array:
	var bars := [
		{"label": "HP Thach Sanh", "value": maxf(player_hp, 0.0), "max": PLAYER_MAX_HP, "color": Color(0.38, 0.84, 0.42)},
		{"label": "Dash", "value": clampf((0.55 - dash_cd) / 0.55 * 100.0, 0.0, 100.0), "max": 100.0, "color": Color(0.45, 0.72, 1.0)},
		{"label": "LeWM danger", "value": lewm_severity, "max": 100.0, "color": Color(1.0, 0.62, 0.22)},
	]
	if arena_started:
		bars.append({"label": "HP Chan Tinh", "value": maxf(boss_hp, 0.0), "max": BOSS_MAX_HP, "color": Color(0.92, 0.18, 0.12)})
		bars.append({"label": "Ap luc LeWM", "value": clampf(arena_pressure * 5.0, 0.0, 100.0), "max": 100.0, "color": Color(1.0, 0.62, 0.22)})
	else:
		bars.append({"label": "Chuan bi", "value": prep_done, "max": 2.0, "color": Color(0.84, 0.72, 0.42)})
	return bars

func _draw() -> void:
	_draw_map()
	_draw_pickups_and_clues()
	_draw_telegraphs()
	_draw_hazards()
	_draw_projectiles()
	_draw_player()
	if arena_started:
		_draw_boss()

func _draw_map() -> void:
	draw_rect(Rect2(0, 0, 1000, 640), Color(0.08, 0.08, 0.10))
	draw_rect(PREP_AREA, Color(0.15, 0.13, 0.10))
	draw_rect(ARENA, Color(0.12, 0.08, 0.09))
	draw_rect(PREP_AREA, Color(0.42, 0.32, 0.18), false, 3.0)
	draw_rect(ARENA, Color(0.62, 0.16, 0.12), false, 4.0)
	for i in range(10):
		var x := PREP_AREA.position.x + i * 32.0
		draw_line(Vector2(x, PREP_AREA.position.y), Vector2(x, PREP_AREA.end.y), Color(0.22, 0.18, 0.12), 1.0)
	for i in range(7):
		var pos := Vector2(510 + i * 62, 120 + (i % 3) * 125)
		draw_rect(Rect2(pos, Vector2(32, 32)), Color(0.21, 0.17, 0.17))
	if not arena_started:
		draw_rect(Rect2(372, 245, 48, 150), Color(0.95, 0.62, 0.20, 0.18))
		draw_line(Vector2(350, 320), Vector2(414, 320), Color(0.95, 0.72, 0.30), 4.0)
		_draw_world_label(Vector2(316, 232), "Vao dau truong", Color(1.0, 0.78, 0.35))

func _draw_pickups_and_clues() -> void:
	draw_circle(Vector2(190, 210), 12, Color(0.40, 0.78, 0.55) if clue_read else Color(0.78, 0.76, 0.68))
	_draw_world_label(Vector2(208, 216), "dau vet", Color(0.9, 0.85, 0.7))
	draw_rect(Rect2(260, 430, 40, 12), Color(0.25, 0.62, 0.28) if trap_cleared else Color(0.55, 0.22, 0.12))
	_draw_world_label(Vector2(240, 462), "cam bay", Color(0.95, 0.55, 0.45))
	if not clue_read:
		draw_circle(Vector2(190, 210), 21.0 + sin(elapsed * 5.0) * 2.0, Color(0.90, 0.82, 0.50, 0.18))
	if not trap_cleared:
		draw_rect(Rect2(246, 418, 68, 38), Color(0.95, 0.18, 0.08, 0.12))

func _draw_hazards() -> void:
	for h in hazards:
		draw_circle(h["pos"], h["radius"], Color(0.85, 0.10, 0.04, 0.22))
		draw_circle(h["pos"], h["radius"] * 0.55, Color(0.95, 0.30, 0.08, 0.25))
		draw_circle(h["pos"], h["radius"], Color(1.0, 0.55, 0.22, 0.60), false, 2.0)

func _draw_telegraphs() -> void:
	for t in telegraphs:
		var ttl := float(t.get("ttl", 0.0))
		var radius := float(t.get("radius", 46.0))
		var alpha := clampf(0.22 + sin(elapsed * 16.0) * 0.10, 0.12, 0.40)
		var color := Color(1.0, 0.28, 0.08, alpha)
		if String(t.get("kind", "hazard")) == "melee_counter":
			color = Color(1.0, 0.72, 0.18, alpha)
		draw_circle(t["pos"], radius, color)
		draw_circle(t["pos"], radius, color.lightened(0.35), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(t["pos"]) + Vector2(-18, -radius - 8), "%.1f" % maxf(ttl, 0.0), HORIZONTAL_ALIGNMENT_LEFT, 48, 14, Color.WHITE)

func _draw_projectiles() -> void:
	for p in projectiles:
		var color := Color(0.95, 0.85, 0.35) if String(p["owner"]) == "player" else Color(0.90, 0.12, 0.20)
		draw_circle(p["pos"], 5.0, color)

func _draw_player() -> void:
	var body := Color(0.25, 0.72, 0.95) if invuln <= 0.0 else Color(0.70, 0.90, 1.0)
	draw_circle(player_pos, 16.0, body)
	var aim := player_pos.direction_to(get_global_mouse_position())
	draw_line(player_pos, player_pos + aim * 32.0, Color(0.95, 0.95, 0.95), 3.0)
	if current_weapon == "axe":
		draw_rect(Rect2(player_pos + aim * 22.0 - Vector2(5, 14), Vector2(10, 28)), Color(0.72, 0.70, 0.62))
	else:
		draw_line(player_pos + aim * 16.0, player_pos + aim * 36.0, Color(0.62, 0.36, 0.18), 4.0)

func _draw_boss() -> void:
	_draw_boss_world_hp()
	draw_circle(boss_pos, 31.0, Color(0.28, 0.03, 0.06))
	draw_circle(boss_pos + Vector2(-11, -6), 5.0, Color(0.95, 0.10, 0.06))
	draw_circle(boss_pos + Vector2(11, -6), 5.0, Color(0.95, 0.10, 0.06))
	draw_colored_polygon([
		boss_pos + Vector2(-22, -24),
		boss_pos + Vector2(-40, -52),
		boss_pos + Vector2(-5, -31),
	], Color(0.48, 0.06, 0.05))
	draw_colored_polygon([
		boss_pos + Vector2(22, -24),
		boss_pos + Vector2(40, -52),
		boss_pos + Vector2(5, -31),
	], Color(0.48, 0.06, 0.05))
	if boss_tactic == "PunishSpam":
		draw_circle(boss_pos, 42.0, Color(1.0, 0.18, 0.08, 0.25))
	elif boss_tactic == "CloseGap":
		draw_circle(boss_pos, 40.0, Color(1.0, 0.60, 0.18, 0.20))
	elif boss_tactic == "AntiAim":
		draw_circle(boss_pos, 40.0, Color(0.40, 0.70, 1.0, 0.18))

func _draw_boss_world_hp() -> void:
	var bar := Rect2(boss_pos + Vector2(-54, -70), Vector2(108, 9))
	draw_rect(bar, Color(0.08, 0.02, 0.03, 0.92))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * maxf(boss_hp, 0.0) / BOSS_MAX_HP, bar.size.y)), Color(0.92, 0.12, 0.08))
	draw_rect(bar, Color(0.98, 0.44, 0.36), false, 1.0)

func _draw_world_label(pos: Vector2, text: String, color: Color) -> void:
	var width := maxf(42.0, text.length() * 8.0)
	var rect := Rect2(pos + Vector2(-6, -18), Vector2(width + 12.0, 24.0))
	draw_rect(rect, Color(0.02, 0.02, 0.025, 0.78))
	draw_rect(rect, color.darkened(0.35), false, 1.0)
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, 14, color)

func _draw_ui() -> void:
	draw_rect(Rect2(24, 600, 300, 18), Color(0.18, 0.02, 0.04))
	draw_rect(Rect2(24, 600, 300.0 * maxf(player_hp, 0.0) / PLAYER_MAX_HP, 18), Color(0.30, 0.78, 0.35))
	draw_string(ThemeDB.fallback_font, Vector2(26, 594), "HP", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, Color.WHITE)

	if arena_started:
		draw_rect(Rect2(420, 24, 520, 20), Color(0.12, 0.02, 0.03))
		draw_rect(Rect2(420, 24, 520.0 * maxf(boss_hp, 0.0) / BOSS_MAX_HP, 20), Color(0.86, 0.10, 0.08))
		draw_string(ThemeDB.fallback_font, Vector2(420, 20), "Chan Tinh", HORIZONTAL_ALIGNMENT_LEFT, 120, 16, Color.WHITE)
