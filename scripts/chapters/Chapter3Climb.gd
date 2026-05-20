extends Node2D

signal chapter_completed(chapter_id: String, payload: Dictionary)

const WorldState = preload("res://scripts/shared/WorldState.gd")
const LeWMOrchestrator = preload("res://scripts/shared/LeWMOrchestrator.gd")
const RawLeWMRecorder = preload("res://scripts/shared/RawLeWMRecorder.gd")

const LEVEL_TOP := -2600.0
const LEVEL_BOTTOM := 900.0
const VIEW_SIZE := Vector2(1000, 640)
const PLAYER_SIZE := Vector2(20, 28)
const GRAVITY := 760.0
const TERMINAL_FALL_VELOCITY := 900.0
const SUBSTEP_MAX_PIXELS := 8.0
const AIM_RAMP_RATE := 0.75
const WHISPER_DEFAULT_TTL := 5.5
const TUTORIAL_TTL := 6.0
const FALL_FLASH_TTL := 0.35
const CAMERA_SHAKE_TTL := 0.35
const CAMERA_SHAKE_AMP := 18.0

var world_state := WorldState.new()
var lewm := LeWMOrchestrator.new()
var raw_recorder := RawLeWMRecorder.new()
var player_pos := Vector2(130, 820)
var player_vel := Vector2.ZERO
var grounded := false
var charging := false
var charge := 0.0
var aim_dir := 0.0
var space_was_pressed := false
var camera_y := 260.0
var platforms: Array[Rect2] = []
var wind := 0.0
var wind_target := 0.0
var lewm_timer := 0.0
var fall_count := 0
var falling := false
var fall_start_y := 0.0
var idle_time := 0.0
var last_player_pos := player_pos
var whisper := ""
var whisper_ttl := 0.0
var ghost_platform_ttl := 0.0
var ghost_platform := Rect2(620, -920, 118, 14)
var trajectory_echo_ttl := 0.0
var wind_warning_ttl := 0.0
var repeated_miss_count := 0
var last_fall_zone := 999999
var lewm_intent := "MountainStillness"
var lewm_severity := 0.0
var lewm_source := "fallback"
var lewm_model_version := "rule-fallback"
var lewm_confidence := 0.0
var lewm_latency_ms := 0.0
var lewm_impact_log: Array[String] = []
var elapsed := 0.0
var completion_emitted := false
var best_height_ratio := 0.0
var best_height_pulse := 0.0
var fall_flash_ttl := 0.0
var camera_shake_ttl := 0.0
var camera_shake_offset := Vector2.ZERO
var tutorial_ttl := TUTORIAL_TTL
var has_jumped := false

func _ready() -> void:
	lewm.configure("chapter_3", OS.get_cmdline_user_args())
	raw_recorder.configure("chapter_3", OS.get_cmdline_user_args())
	_build_platforms()
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	trajectory_echo_ttl = maxf(0.0, trajectory_echo_ttl - delta)
	wind_warning_ttl = maxf(0.0, wind_warning_ttl - delta)
	whisper_ttl = maxf(0.0, whisper_ttl - delta)
	if whisper_ttl <= 0.0:
		whisper = ""
	fall_flash_ttl = maxf(0.0, fall_flash_ttl - delta)
	if not has_jumped:
		tutorial_ttl = maxf(0.0, tutorial_ttl - delta)
	best_height_pulse = maxf(0.0, best_height_pulse - delta)
	_update_camera_shake(delta)
	_update_idle(delta)
	_update_charge_and_jump(delta)
	_update_movement(delta)
	_update_lewm(delta)
	_update_camera()
	_update_best_height()
	_record_raw_lewm_transition(delta)
	queue_redraw()

func apply_global_memory(memory: Dictionary) -> void:
	world_state.apply_global_memory(memory)
	if world_state.get_global_value("climb_anxiety") > 12.0:
		_set_whisper("Vuc nui da nho nhung lan roi truoc.", 6.0)

func get_objective_text() -> String:
	return "Leo len dinh vuc bang charge jump."

func get_hud_data() -> Dictionary:
	return {
		"extra": "Charge: %d%% | Falls: %d | Height: %d%% | Wind: %d" % [
			int(charge * 100.0),
			fall_count,
			int(_height_ratio() * 100.0),
			int(wind),
		],
		"message": whisper if whisper != "" else "Giu Space de tich luc, tha Space de nhay.",
		"chips": ["LeWM: %s" % lewm_intent, "A/D can huong", "Space charge"],
		"bars": [
			{"label": "Charge", "value": charge * 100.0, "max": 100.0, "color": Color(0.98, 0.72, 0.22)},
			{"label": "Do cao", "value": _height_ratio() * 100.0, "max": 100.0, "color": Color(0.46, 0.76, 1.0)},
			{"label": "Kiem soat", "value": clampf(100.0 - fall_count * 12.0, 0.0, 100.0), "max": 100.0, "color": Color(0.50, 0.90, 0.62)},
			{"label": "LeWM wind", "value": lewm_severity, "max": 100.0, "color": Color(0.66, 0.82, 1.0)},
		],
	}

func get_completion_payload() -> Dictionary:
	return {
		"time_seconds": elapsed,
		"fall_count": fall_count,
		"height_ratio": _height_ratio(),
		"lewm_impact": lewm_impact_log.duplicate(true),
		"lewm_source": lewm_source,
		"lewm_model_version": lewm_model_version,
		"global_memory_delta": _global_memory_delta(),
	}

func get_debug_text() -> String:
	return "%s | wind:%d ghost:%.1f | %s" % [world_state.debug_summary(), int(wind), ghost_platform_ttl, lewm.debug_summary()]

func _update_idle(delta: float) -> void:
	if player_pos.distance_to(last_player_pos) < 1.0:
		idle_time += delta
	else:
		idle_time = 0.0
	last_player_pos = player_pos

func _update_charge_and_jump(delta: float) -> void:
	var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	var input_dir := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_dir += 1.0

	if grounded and space_pressed:
		charging = true
		charge = clampf(charge + delta * 0.9, 0.0, 1.0)
		aim_dir = move_toward(aim_dir, input_dir, AIM_RAMP_RATE * delta)

	if charging and not space_pressed and space_was_pressed:
		player_vel.x = aim_dir * (135.0 + charge * 190.0)
		player_vel.y = -(270.0 + charge * 470.0)
		grounded = false
		charging = false
		charge = 0.0
		aim_dir = 0.0
		has_jumped = true
		tutorial_ttl = 0.0

	if not charging:
		aim_dir = 0.0

	if not space_pressed and grounded and not charging:
		charge = 0.0

	space_was_pressed = space_pressed

func _update_movement(delta: float) -> void:
	if grounded and charging:
		player_vel.x = 0.0
	elif grounded:
		var dir := 0.0
		if Input.is_physical_key_pressed(KEY_A):
			dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			dir += 1.0
		player_vel.x = dir * 105.0
	else:
		var air_dir := 0.0
		if Input.is_physical_key_pressed(KEY_A):
			air_dir -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			air_dir += 1.0
		player_vel.x += air_dir * 56.0 * delta
		player_vel.x += wind * delta

	player_vel.y += GRAVITY * delta
	player_vel.y = minf(player_vel.y, TERMINAL_FALL_VELOCITY)

	if not grounded and player_vel.y > 0.0 and not falling:
		falling = true
		fall_start_y = player_pos.y

	var dx := player_vel.x * delta
	var dy := player_vel.y * delta
	var steps := int(ceil(maxf(absf(dx), absf(dy)) / SUBSTEP_MAX_PIXELS))
	steps = clampi(steps, 1, 12)
	var step_dx := dx / float(steps)
	var step_dy := dy / float(steps)

	grounded = false
	for i in range(steps):
		player_pos.x += step_dx
		player_pos.x = clampf(player_pos.x, 36.0, 920.0)
		if _resolve_axis_x():
			step_dx = 0.0
		player_pos.y += step_dy
		if _resolve_axis_y():
			step_dy = 0.0

	if player_pos.y > LEVEL_BOTTOM + 160.0:
		_trigger_fall_reset()

	if player_pos.y < LEVEL_TOP + 120.0:
		_complete_chapter()

func _trigger_fall_reset() -> void:
	player_pos = Vector2(130, 820)
	player_vel = Vector2.ZERO
	grounded = false
	falling = false
	fall_count += 1
	_track_fall_zone()
	_set_whisper("Roi ve chan nui. Khong co checkpoint trong giac mo nay.", 5.0)
	_trigger_fall_feedback()

func _complete_chapter() -> void:
	if completion_emitted:
		return
	completion_emitted = true
	chapter_completed.emit("chapter_3", get_completion_payload())

func _resolve_axis_x() -> bool:
	var rect := _player_rect(player_pos)
	var collided := false
	for platform in _active_platforms():
		if not rect.intersects(platform):
			continue
		if player_vel.x > 0.0:
			player_pos.x = platform.position.x - PLAYER_SIZE.x * 0.5
		elif player_vel.x < 0.0:
			player_pos.x = platform.end.x + PLAYER_SIZE.x * 0.5
		else:
			var push_left := rect.end.x - platform.position.x
			var push_right := platform.end.x - rect.position.x
			if push_left < push_right:
				player_pos.x = platform.position.x - PLAYER_SIZE.x * 0.5
			else:
				player_pos.x = platform.end.x + PLAYER_SIZE.x * 0.5
		player_vel.x = 0.0
		rect = _player_rect(player_pos)
		collided = true
	return collided

func _resolve_axis_y() -> bool:
	var rect := _player_rect(player_pos)
	var collided := false
	for platform in _active_platforms():
		if not rect.intersects(platform):
			continue
		if player_vel.y > 0.0:
			player_pos.y = platform.position.y - PLAYER_SIZE.y * 0.5
			_handle_landing()
			grounded = true
		elif player_vel.y < 0.0:
			player_pos.y = platform.end.y + PLAYER_SIZE.y * 0.5
		else:
			var push_up := rect.end.y - platform.position.y
			var push_down := platform.end.y - rect.position.y
			if push_up < push_down:
				player_pos.y = platform.position.y - PLAYER_SIZE.y * 0.5
				grounded = true
			else:
				player_pos.y = platform.end.y + PLAYER_SIZE.y * 0.5
		player_vel.y = 0.0
		rect = _player_rect(player_pos)
		collided = true
	return collided

func _active_platforms() -> Array[Rect2]:
	var arr: Array[Rect2] = platforms.duplicate()
	if ghost_platform_ttl > 0.0:
		arr.append(ghost_platform)
	return arr

func _handle_landing() -> void:
	if not falling:
		return
	var fall_distance := player_pos.y - fall_start_y
	if fall_distance > 180.0:
		fall_count += 1
		_track_fall_zone()
		world_state.add_value("climb_confidence", -5.0)
		_set_whisper("Nui khong tha thu cu nhay sai luc.", 4.0)
		_trigger_fall_feedback()
	falling = false

func _set_whisper(text: String, ttl: float = WHISPER_DEFAULT_TTL) -> void:
	whisper = text
	whisper_ttl = ttl

func _trigger_fall_feedback() -> void:
	camera_shake_ttl = CAMERA_SHAKE_TTL
	fall_flash_ttl = FALL_FLASH_TTL

func _update_camera_shake(delta: float) -> void:
	if camera_shake_ttl > 0.0:
		camera_shake_ttl = maxf(0.0, camera_shake_ttl - delta)
		var t := clampf(camera_shake_ttl / CAMERA_SHAKE_TTL, 0.0, 1.0)
		camera_shake_offset = Vector2(
			sin(elapsed * 92.0) * CAMERA_SHAKE_AMP * t,
			cos(elapsed * 73.0) * CAMERA_SHAKE_AMP * t * 0.6
		)
	else:
		camera_shake_offset = Vector2.ZERO

func _update_best_height() -> void:
	var ratio := _height_ratio()
	if ratio > best_height_ratio + 0.005:
		best_height_ratio = ratio
		best_height_pulse = 0.6

func _update_lewm(delta: float) -> void:
	lewm_timer += delta
	wind = lerpf(wind, wind_target, delta * 1.5)
	ghost_platform_ttl = maxf(0.0, ghost_platform_ttl - delta)
	if lewm_timer < 1.0:
		return
	lewm_timer = 0.0

	var height_ratio := _height_ratio()
	var reaction := lewm.evaluate_climb({
		"fall_count": fall_count,
		"height_ratio": height_ratio,
		"idle_time": idle_time,
		"repeated_miss_count": repeated_miss_count,
	}, world_state, get_viewport(), _current_lewm_action_vector())
	_apply_lewm_reaction(reaction)

func _apply_lewm_reaction(reaction: Dictionary) -> void:
	var previous_target := wind_target
	wind_target = float(reaction["wind"])
	lewm_intent = String(reaction.get("intent", "MountainStillness"))
	lewm_severity = float(reaction.get("severity", 0.0))
	lewm_source = String(reaction.get("source", "fallback"))
	lewm_model_version = String(reaction.get("model_version", "rule-fallback"))
	lewm_confidence = float(reaction.get("confidence", 0.0))
	lewm_latency_ms = float(reaction.get("latency_ms", 0.0))
	if absf(wind_target) > 2.0 and absf(previous_target - wind_target) > 4.0:
		wind_warning_ttl = 2.0
	if bool(reaction["ghost_platform"]):
		ghost_platform_ttl = 5.0
	if bool(reaction.get("trajectory_echo", false)):
		trajectory_echo_ttl = 4.0
	var ui: Dictionary = reaction.get("ui", {})
	if String(ui.get("whisper", "")) != "":
		_set_whisper(String(ui["whisper"]), 6.0)
	_remember_impact(reaction)

func _remember_impact(reaction: Dictionary) -> void:
	var intent := String(reaction.get("intent", ""))
	if intent == "" or intent == "MountainStillness":
		return
	var ui: Dictionary = reaction.get("ui", {})
	var text := "%s: %s" % [intent, String(ui.get("warning", ui.get("whisper", "")))]
	if not lewm_impact_log.has(text):
		lewm_impact_log.append(text)
	if lewm_impact_log.size() > 6:
		lewm_impact_log.remove_at(0)

func _global_memory_delta() -> Dictionary:
	return {
		"climb_anxiety": clampf(fall_count * 0.85 + repeated_miss_count * 1.4, 0.0, 12.0),
		"dream_instability": clampf(lewm_severity * 0.03, 0.0, 4.0),
	}

func _current_lewm_action_vector() -> Array:
	var move_x := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		move_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move_x += 1.0
	return [
		move_x,
		1.0 if grounded else 0.0,
		charge,
		player_vel.x / 600.0,
		player_vel.y / 900.0,
		_height_ratio(),
	]

func _record_raw_lewm_transition(delta: float) -> void:
	raw_recorder.record(get_viewport(), delta, {
		"move_x": _current_lewm_action_vector()[0],
		"grounded": 1 if grounded else 0,
		"charge": charge,
		"velocity_x": player_vel.x,
		"velocity_y": player_vel.y,
		"lewm_intent_id": _climb_intent_id(lewm_intent),
	}, _current_raw_lewm_metadata())

func _current_raw_lewm_metadata() -> Dictionary:
	return {
		"elapsed": elapsed,
		"player_x": player_pos.x,
		"player_y": player_pos.y,
		"height_ratio": _height_ratio(),
		"fall_count": fall_count,
		"repeated_miss_count": repeated_miss_count,
		"wind": wind,
		"lewm_intent": lewm_intent,
		"lewm_source": lewm_source,
		"lewm_model_version": lewm_model_version,
		"lewm_confidence": lewm_confidence,
	}

func _climb_intent_id(intent: String) -> int:
	match intent:
		"WindMemory":
			return 1
		"HighAltitudeWind":
			return 2
		"MountainBreath":
			return 3
		"LandingEcho":
			return 4
		_:
			return 0

func _track_fall_zone() -> void:
	var zone := int(fall_start_y / 220.0)
	if abs(zone - last_fall_zone) <= 1:
		repeated_miss_count += 1
	last_fall_zone = zone

func _update_camera() -> void:
	camera_y = clampf(player_pos.y - 420.0, LEVEL_TOP, LEVEL_BOTTOM - VIEW_SIZE.y)

func _height_ratio() -> float:
	return clampf((LEVEL_BOTTOM - player_pos.y) / (LEVEL_BOTTOM - LEVEL_TOP), 0.0, 1.0)

func _build_platforms() -> void:
	platforms = [
		Rect2(40, 870, 860, 28),
		Rect2(120, 690, 160, 18),
		Rect2(410, 560, 145, 18),
		Rect2(720, 430, 130, 18),
		Rect2(520, 250, 120, 16),
		Rect2(250, 95, 110, 16),
		Rect2(105, -110, 95, 16),
		Rect2(380, -280, 92, 16),
		Rect2(690, -455, 108, 16),
		Rect2(520, -640, 86, 16),
		Rect2(280, -815, 92, 16),
		Rect2(120, -1010, 84, 16),
		Rect2(395, -1200, 90, 16),
		Rect2(720, -1390, 82, 16),
		Rect2(520, -1585, 88, 16),
		Rect2(270, -1775, 86, 16),
		Rect2(110, -1970, 78, 16),
		Rect2(390, -2160, 78, 16),
		Rect2(675, -2360, 150, 18),
	]

func _player_rect(pos: Vector2) -> Rect2:
	return Rect2(pos - PLAYER_SIZE * 0.5, PLAYER_SIZE)

func _screen_pos(world_pos: Vector2) -> Vector2:
	return world_pos - Vector2(0, camera_y) + camera_shake_offset

func _screen_rect(rect: Rect2) -> Rect2:
	return Rect2(_screen_pos(rect.position), rect.size)

func _draw() -> void:
	_draw_background()
	_draw_platforms()
	_draw_charge_guide()
	_draw_player()
	_draw_wind_indicator()
	_draw_lewm_badge()
	_draw_tutorial_hint()
	_draw_fall_flash()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, VIEW_SIZE.x, VIEW_SIZE.y), Color(0.07, 0.08, 0.13))
	for i in range(18):
		var y := fmod(float(i * 180) - fmod(camera_y * 0.35, 180.0), 720.0) - 40.0
		draw_line(Vector2(0, y), Vector2(VIEW_SIZE.x, y - 90), Color(0.15, 0.16, 0.23), 2.0)
	if absf(wind) > 2.0 or wind_warning_ttl > 0.0:
		for i in range(8):
			var y2 := 80.0 + i * 65.0
			var dir := 1.0 if wind_target >= 0.0 else -1.0
			var alpha := 0.42 if wind_warning_ttl <= 0.0 else 0.64 + sin(elapsed * 12.0) * 0.14
			draw_line(Vector2(80, y2), Vector2(80 + dir * 80, y2 - 18), Color(0.68, 0.82, 1.0, alpha), 3.0)
	_draw_height_rail()

func _draw_platforms() -> void:
	for p in platforms:
		var rect := _screen_rect(p)
		draw_rect(rect, Color(0.34, 0.30, 0.24))
		draw_rect(rect, Color(0.70, 0.62, 0.42), false, 2.0)
	if ghost_platform_ttl > 0.0:
		var grect := _screen_rect(ghost_platform)
		var pulse := 0.5 + 0.5 * sin(elapsed * 6.0)
		draw_rect(grect, Color(0.48, 0.74, 0.95, 0.22 + pulse * 0.20))
		draw_rect(grect, Color(0.70, 0.94, 1.0, 0.55 + pulse * 0.40), false, 2.0)
		draw_string(ThemeDB.fallback_font, grect.position + Vector2(8, -8), "ghost %.0fs" % ghost_platform_ttl, HORIZONTAL_ALIGNMENT_LEFT, 90, 13, Color(0.82, 0.95, 1.0))

func _draw_player() -> void:
	var rect := _screen_rect(_player_rect(player_pos))
	draw_rect(rect, Color(0.22, 0.70, 0.95))
	draw_rect(Rect2(rect.position + Vector2(4, -8), Vector2(12, 8)), Color(0.42, 0.82, 1.0))
	if charging:
		draw_circle(rect.get_center(), 24.0 + charge * 16.0, Color(0.90, 0.78, 0.24, 0.22))
		_draw_player_charge_bar(rect)
		_draw_player_direction_arrow(rect)

func _draw_player_charge_bar(rect: Rect2) -> void:
	var bar_w := 38.0
	var bar_h := 5.0
	var c := rect.get_center()
	var bar_x := c.x - bar_w * 0.5
	var bar_y := rect.position.y - 14.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.06, 0.07, 0.10, 0.85))
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.34, 0.42, 0.54, 0.85), false, 1.0)
	var fill_color := Color(0.52, 0.94, 0.42).lerp(Color(0.96, 0.32, 0.20), charge)
	draw_rect(Rect2(bar_x + 1, bar_y + 1, (bar_w - 2) * charge, bar_h - 2), fill_color)

func _draw_player_direction_arrow(rect: Rect2) -> void:
	if absf(aim_dir) < 0.05:
		return
	var sign_dir := signf(aim_dir)
	var c := rect.get_center()
	var arrow_y := rect.end.y + 10.0
	var tip := Vector2(c.x + aim_dir * 22.0, arrow_y)
	var color := Color(1.0, 0.86, 0.30, 0.92)
	draw_line(Vector2(c.x, arrow_y), tip, color, 3.0)
	draw_line(tip, tip + Vector2(-sign_dir * 6, -5), color, 3.0)
	draw_line(tip, tip + Vector2(-sign_dir * 6, 5), color, 3.0)

func _draw_charge_guide() -> void:
	if not charging and trajectory_echo_ttl <= 0.0:
		return
	var sim_pos := player_pos
	var guide_charge := charge if charging else 0.58
	var sim_vel := Vector2(aim_dir * (135.0 + guide_charge * 190.0), -(270.0 + guide_charge * 470.0))
	var last := _screen_pos(sim_pos)
	var step := 0.09
	var base_alpha := 0.48 if charging else 0.20
	var line_color := Color(0.5, 0.94, 0.42).lerp(Color(0.98, 0.34, 0.20), guide_charge) if charging else Color(1.0, 0.82, 0.28)
	line_color.a = base_alpha
	for i in range(18):
		sim_vel.x += wind * step
		sim_vel.y += GRAVITY * step
		sim_pos += sim_vel * step
		var next := _screen_pos(sim_pos)
		draw_line(last, next, line_color, 2.0)
		last = next
	if charging:
		var dot_color := line_color
		dot_color.a = 0.92
		draw_circle(last, 4.5, dot_color)

func _draw_height_rail() -> void:
	var rail := Rect2(944, 190, 12, 380)
	draw_rect(rail, Color(0.02, 0.03, 0.05, 0.72))
	draw_rect(rail, Color(0.48, 0.62, 0.78, 0.72), false, 1.0)
	for q in range(1, 4):
		var ty := rail.end.y - rail.size.y * (q * 0.25)
		draw_line(Vector2(rail.position.x - 3, ty), Vector2(rail.end.x + 3, ty), Color(0.42, 0.54, 0.66, 0.62), 1.0)
	if best_height_ratio > 0.0:
		var best_y := rail.end.y - rail.size.y * best_height_ratio
		var alpha_extra := 0.30 if best_height_pulse > 0.0 else 0.0
		draw_rect(Rect2(Vector2(933, best_y - 2), Vector2(34, 4)), Color(0.96, 0.42, 0.92, 0.65 + alpha_extra))
	var marker_y := rail.end.y - rail.size.y * _height_ratio()
	draw_rect(Rect2(Vector2(939, marker_y - 4), Vector2(22, 8)), Color(0.98, 0.75, 0.24))
	draw_string(ThemeDB.fallback_font, Vector2(905, 184), "DINH", HORIZONTAL_ALIGNMENT_LEFT, 70, 14, Color(0.88, 0.94, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(900, 590), "CHAN", HORIZONTAL_ALIGNMENT_LEFT, 70, 14, Color(0.68, 0.76, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(866, 176), "%d%%" % int(_height_ratio() * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 80, 13, Color(0.98, 0.86, 0.36))
	if best_height_ratio > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(854, 612), "Best %d%%" % int(best_height_ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, 100, 12, Color(0.96, 0.62, 0.94))

func _draw_wind_indicator() -> void:
	var bg := Rect2(410, 16, 180, 44)
	draw_rect(bg, Color(0.04, 0.05, 0.08, 0.74))
	var border := Color(0.32, 0.44, 0.58, 0.72)
	if wind_warning_ttl > 0.0:
		var pulse := 0.5 + 0.5 * sin(elapsed * 14.0)
		border = Color(0.98, 0.72, 0.24, 0.72 + pulse * 0.28)
	elif absf(wind) > 45.0:
		border = Color(0.96, 0.46, 0.32, 0.86)
	draw_rect(bg, border, false, 1.0)
	draw_string(ThemeDB.fallback_font, bg.position + Vector2(8, 16), "GIO", HORIZONTAL_ALIGNMENT_LEFT, 40, 12, Color(0.78, 0.88, 1.0))
	var center_y := bg.position.y + 30.0
	var center_x := bg.position.x + 92.0
	var dir := 0.0
	if absf(wind) > 0.5:
		dir = signf(wind)
	var arrow_len := clampf(absf(wind) * 0.55, 6.0, 56.0)
	var arrow_color := Color(0.72, 0.86, 1.0)
	if absf(wind) > 45.0 or wind_warning_ttl > 0.0:
		arrow_color = Color(1.0, 0.74, 0.32)
	var tail := Vector2(center_x - dir * arrow_len * 0.5, center_y)
	var tip := Vector2(center_x + dir * arrow_len * 0.5, center_y)
	draw_line(tail, tip, arrow_color, 3.0)
	if dir != 0.0:
		draw_line(tip, tip + Vector2(-dir * 7, -6), arrow_color, 3.0)
		draw_line(tip, tip + Vector2(-dir * 7, 6), arrow_color, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(bg.end.x - 48, bg.position.y + 28), "%d" % int(wind), HORIZONTAL_ALIGNMENT_LEFT, 40, 14, arrow_color)

func _draw_lewm_badge() -> void:
	var bg := Rect2(16, 82, 240, 26)
	draw_rect(bg, Color(0.06, 0.08, 0.12, 0.84))
	var border := Color(0.36, 0.48, 0.60, 0.85)
	if lewm_severity > 65.0:
		border = Color(0.96, 0.40, 0.32, 0.95)
	elif lewm_severity > 30.0:
		border = Color(0.98, 0.72, 0.32, 0.90)
	draw_rect(bg, border, false, 1.0)
	draw_string(ThemeDB.fallback_font, bg.position + Vector2(10, 18), "LeWM: %s" % lewm_intent, HORIZONTAL_ALIGNMENT_LEFT, 220, 13, Color(0.92, 0.97, 1.0))

func _draw_tutorial_hint() -> void:
	if tutorial_ttl <= 0.0:
		return
	var alpha := clampf(tutorial_ttl / TUTORIAL_TTL, 0.0, 1.0)
	var bg := Rect2(290, 460, 420, 76)
	draw_rect(bg, Color(0.04, 0.06, 0.10, 0.76 * alpha))
	draw_rect(bg, Color(0.36, 0.52, 0.74, 0.82 * alpha), false, 1.0)
	draw_string(ThemeDB.fallback_font, bg.position + Vector2(20, 28), "Hold SPACE de charge  -  A/D de can huong", HORIZONTAL_ALIGNMENT_LEFT, 380, 16, Color(1, 1, 1, alpha))
	draw_string(ThemeDB.fallback_font, bg.position + Vector2(20, 54), "Tha SPACE de nhay", HORIZONTAL_ALIGNMENT_LEFT, 380, 14, Color(0.78, 0.88, 1.0, alpha))

func _draw_fall_flash() -> void:
	if fall_flash_ttl <= 0.0:
		return
	var alpha := clampf(fall_flash_ttl / FALL_FLASH_TTL, 0.0, 1.0) * 0.5
	draw_rect(Rect2(0, 0, VIEW_SIZE.x, VIEW_SIZE.y), Color(1.0, 0.22, 0.18, alpha))
