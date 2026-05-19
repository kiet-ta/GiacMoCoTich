extends Node2D

signal chapter_completed(chapter_id: String, payload: Dictionary)

const WorldState = preload("res://scripts/shared/WorldState.gd")
const LeWMOrchestrator = preload("res://scripts/shared/LeWMOrchestrator.gd")
const ThachSanhSprite = preload("res://scripts/shared/ThachSanhSprite.gd")
const LyThongSprite = preload("res://scripts/shared/LyThongSprite.gd")
const RawLeWMRecorder = preload("res://scripts/shared/RawLeWMRecorder.gd")

const TILE := 32
const MAP_W := 30
const MAP_H := 20
const PLAYER_RADIUS := 11.0

var world_state := WorldState.new()
var lewm := LeWMOrchestrator.new()
var raw_recorder := RawLeWMRecorder.new()
var player_pos := Vector2(120, 320)
var player_start := player_pos
var player_speed := 135.0
var player_facing := Vector2.DOWN
var player_anim_time := 0.0
var player_moving := false
var ly_thong_pos := Vector2(-80, 310)
var ly_thong_facing := Vector2.DOWN
var ly_thong_anim_time := 0.0
var ly_thong_moving := false
var ly_thong_visible := false
var ly_thong_dialogue_done := false
var ly_thong_following := false
var elapsed := 0.0
var moved_distance := 0.0
var explored_objects := {}
var whisper := ""
var fog_alpha := 0.0
var lewm_timer := 0.0
var completion_emitted := false
var path_shift_alpha := 0.0
var reverse_leaf_intensity := 0.0
var exit_guidance := 0.0
var lewm_intent := "ForestCalm"
var lewm_severity := 0.0
var lewm_source := "fallback"
var lewm_model_version := "rule-fallback"
var lewm_confidence := 0.0
var lewm_latency_ms := 0.0
var lewm_impact_log: Array[String] = []
var solids: Array[Rect2] = []
var interactables: Array[Dictionary] = []
var exit_rect := Rect2(880, 280, 48, 96)
var exit_completion_rect := exit_rect.grow(64.0)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lewm.configure("chapter_1", OS.get_cmdline_user_args())
	raw_recorder.configure("chapter_1", OS.get_cmdline_user_args())
	_build_map_collision()
	_build_interactables()
	queue_redraw()

func _physics_process(delta: float) -> void:
	elapsed += delta
	path_shift_alpha = maxf(0.0, path_shift_alpha - delta * 0.10)
	reverse_leaf_intensity = maxf(0.0, reverse_leaf_intensity - delta * 0.25)
	exit_guidance = maxf(0.0, exit_guidance - delta * 0.18)
	_update_player(delta)
	_update_ly_thong(delta)
	_update_lewm(delta)
	_record_raw_lewm_transition(delta)
	queue_redraw()

func apply_global_memory(memory: Dictionary) -> void:
	world_state.apply_global_memory(memory)
	if world_state.get_global_value("dream_instability") > 10.0:
		fog_alpha = maxf(fog_alpha, 0.08)
	if world_state.get_global_value("suspicion") > 12.0:
		whisper = "Rung Mong van giu lai nghi ngo tu lan truoc."

func get_objective_text() -> String:
	if not ly_thong_visible:
		return "Di chuyen trong rung va tim manh moi."
	if ly_thong_following:
		return "Dua Ly Thong ra loi ra phia dong."
	if ly_thong_visible and not ly_thong_dialogue_done:
		return "Lai gan Ly Thong va bam E de tro chuyen."
	return "Tiep tuc kham pha Rung Mong."

func get_hud_data() -> Dictionary:
	var prompt := whisper
	if prompt == "":
		prompt = "Tim manh moi trong rung. Khi Ly Thong xuat hien, lai gan va bam E."
	for item in interactables:
		if player_pos.distance_to(item["pos"]) < 42.0 and not explored_objects.has(item["id"]):
			prompt = "Bam E de tuong tac: %s" % String(item["id"]).replace("_", " ")
	if ly_thong_visible and player_pos.distance_to(ly_thong_pos) < 58.0 and not ly_thong_dialogue_done:
		prompt = "Bam E de noi chuyen voi Ly Thong."
	if ly_thong_following and exit_completion_rect.has_point(player_pos):
		prompt = "Dung trong vung EXIT de ket thuc man."
	return {
		"extra": "Manh moi: %d/3" % explored_objects.size(),
		"message": prompt,
		"chips": ["LeWM: %s" % lewm_intent, "WASD di chuyen", "E tuong tac"],
		"bars": [
			{"label": "Manh moi", "value": explored_objects.size(), "max": 3.0, "color": Color(0.48, 0.74, 0.95)},
			{"label": "On dinh giac mo", "value": world_state.get_value("dream_stability"), "max": 100.0, "color": Color(0.48, 0.90, 0.64)},
			{"label": "LeWM", "value": lewm_severity, "max": 100.0, "color": Color(0.56, 0.78, 1.0)},
		],
	}

func get_completion_payload() -> Dictionary:
	return {
		"time_seconds": elapsed,
		"clues_found": explored_objects.size(),
		"dream_stability": world_state.get_value("dream_stability"),
		"lewm_impact": lewm_impact_log.duplicate(true),
		"lewm_source": lewm_source,
		"lewm_model_version": lewm_model_version,
		"global_memory_delta": _global_memory_delta(),
	}

func get_debug_text() -> String:
	return "%s | %s" % [world_state.debug_summary(), lewm.debug_summary()]

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

	var moved := false
	if input != Vector2.ZERO:
		player_facing = ThachSanhSprite.facing_from_input(player_facing, input)
		var next_pos := player_pos + input * player_speed * delta
		if not _is_blocked(next_pos):
			player_pos = next_pos
			moved_distance = player_start.distance_to(player_pos)
			moved = true
	player_moving = moved
	player_anim_time = ThachSanhSprite.next_walk_time(player_anim_time, player_moving, delta)

	player_pos.x = clampf(player_pos.x, 32.0, MAP_W * TILE - 32.0)
	player_pos.y = clampf(player_pos.y, 32.0, MAP_H * TILE - 32.0)

	if not ly_thong_visible and (moved_distance > 130.0 or elapsed > 7.0):
		ly_thong_visible = true
		whisper = "Co nguoi dang di vao Rung Mong."

	if Input.is_key_pressed(KEY_E):
		_try_interact()

func _try_interact() -> void:
	for item in interactables:
		if player_pos.distance_to(item["pos"]) < 42.0 and not explored_objects.has(item["id"]):
			explored_objects[item["id"]] = true
			world_state.add_value(item["state"], item["delta"])
			whisper = item["text"]
			return

	if ly_thong_visible and player_pos.distance_to(ly_thong_pos) < 58.0 and not ly_thong_dialogue_done:
		ly_thong_dialogue_done = true
		ly_thong_following = true
		world_state.add_value("trust_ly_thong", 10.0)
		whisper = "Ly Thong: Di voi huynh, rung nay khong nen o lai lau."

func _update_ly_thong(delta: float) -> void:
	if not ly_thong_visible:
		ly_thong_moving = false
		return

	var target := player_pos
	if not ly_thong_dialogue_done:
		target = player_pos + Vector2(-42, 8)
	elif ly_thong_following:
		target = player_pos + Vector2(-38, 18)

	var direction := ly_thong_pos.direction_to(target)
	if ly_thong_pos.distance_to(target) > 8.0:
		ly_thong_pos += direction * 95.0 * delta
		ly_thong_facing = LyThongSprite.facing_from_input(ly_thong_facing, direction)
		ly_thong_moving = true
	else:
		ly_thong_moving = false
	ly_thong_anim_time = LyThongSprite.next_walk_time(ly_thong_anim_time, ly_thong_moving, delta)

	if ly_thong_following and exit_completion_rect.has_point(player_pos) and ly_thong_pos.distance_to(player_pos) < 140.0:
		_complete_chapter()

func _complete_chapter() -> void:
	if completion_emitted:
		return
	completion_emitted = true
	chapter_completed.emit("chapter_1", get_completion_payload())

func _update_lewm(delta: float) -> void:
	lewm_timer += delta
	if lewm_timer < 1.0:
		return
	lewm_timer = 0.0

	var observation := {
		"explored_objects": explored_objects.size(),
		"time_in_forest": elapsed,
		"wandering": moved_distance > 260.0 and not ly_thong_dialogue_done,
		"distance_to_ly_thong": player_pos.distance_to(ly_thong_pos) if ly_thong_visible else 9999.0,
		"direct_exit_route": ly_thong_following and player_pos.x > 700.0,
	}
	var reaction := lewm.evaluate_forest(observation, world_state, get_viewport(), _current_lewm_action_vector())
	_apply_lewm_reaction(reaction)
	fog_alpha = maxf(fog_alpha * 0.98, float(reaction.get("fog", 0.0)))
	var ui: Dictionary = reaction.get("ui", {})
	if String(ui.get("whisper", "")) != "":
		whisper = ui["whisper"]

func _apply_lewm_reaction(reaction: Dictionary) -> void:
	lewm_intent = String(reaction.get("intent", "ForestCalm"))
	lewm_severity = float(reaction.get("severity", 0.0))
	lewm_source = String(reaction.get("source", "fallback"))
	lewm_model_version = String(reaction.get("model_version", "rule-fallback"))
	lewm_confidence = float(reaction.get("confidence", 0.0))
	lewm_latency_ms = float(reaction.get("latency_ms", 0.0))
	if bool(reaction.get("path_shift", false)):
		path_shift_alpha = 1.0
	reverse_leaf_intensity = maxf(reverse_leaf_intensity, float(reaction.get("reverse_leaves", 0.0)))
	exit_guidance = maxf(exit_guidance, float(reaction.get("exit_guidance", 0.0)))
	_remember_impact(reaction)

func _remember_impact(reaction: Dictionary) -> void:
	var intent := String(reaction.get("intent", ""))
	if intent == "" or intent == "ForestCalm":
		return
	var ui: Dictionary = reaction.get("ui", {})
	var text := "%s: %s" % [intent, String(ui.get("warning", ui.get("whisper", "")))]
	if not lewm_impact_log.has(text):
		lewm_impact_log.append(text)
	if lewm_impact_log.size() > 6:
		lewm_impact_log.remove_at(0)

func _global_memory_delta() -> Dictionary:
	var dream_loss := maxf(0.0, 70.0 - world_state.get_value("dream_stability")) * 0.08
	return {
		"trust_ly_thong": maxf(0.0, world_state.get_value("trust_ly_thong")) * 0.12,
		"suspicion": maxf(0.0, world_state.get_value("suspicion")) * 0.12,
		"dream_instability": dream_loss,
	}

func _current_lewm_action_vector() -> Array:
	var move_x := 0.0
	var move_y := 0.0
	if Input.is_key_pressed(KEY_A):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_x += 1.0
	if Input.is_key_pressed(KEY_W):
		move_y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_y += 1.0
	return [
		move_x,
		move_y,
		1.0 if Input.is_key_pressed(KEY_E) else 0.0,
		float(explored_objects.size()) / 3.0,
		1.0 if ly_thong_following else 0.0,
		clampf(player_pos.x / float(MAP_W * TILE), 0.0, 1.0),
	]

func _record_raw_lewm_transition(delta: float) -> void:
	raw_recorder.record(get_viewport(), delta, {
		"move_x": _current_lewm_action_vector()[0],
		"move_y": _current_lewm_action_vector()[1],
		"interact": 1 if Input.is_key_pressed(KEY_E) else 0,
		"clues_found": explored_objects.size(),
		"ly_thong_following": 1 if ly_thong_following else 0,
		"lewm_intent_id": _forest_intent_id(lewm_intent),
	}, _current_raw_lewm_metadata())

func _current_raw_lewm_metadata() -> Dictionary:
	return {
		"elapsed": elapsed,
		"player_x": player_pos.x,
		"player_y": player_pos.y,
		"clues_found": explored_objects.size(),
		"ly_thong_visible": ly_thong_visible,
		"ly_thong_following": ly_thong_following,
		"dream_stability": world_state.get_value("dream_stability"),
		"lewm_intent": lewm_intent,
		"lewm_source": lewm_source,
		"lewm_model_version": lewm_model_version,
		"lewm_confidence": lewm_confidence,
	}

func _forest_intent_id(intent: String) -> int:
	match intent:
		"ObjectMemory":
			return 1
		"TemporalFog":
			return 2
		"PathShift":
			return 3
		"TrustGuide":
			return 4
		_:
			return 0

func _build_map_collision() -> void:
	solids.clear()
	for x in range(MAP_W):
		solids.append(Rect2(x * TILE, 0, TILE, TILE))
		solids.append(Rect2(x * TILE, (MAP_H - 1) * TILE, TILE, TILE))
	for y in range(MAP_H):
		solids.append(Rect2(0, y * TILE, TILE, TILE))
		solids.append(Rect2((MAP_W - 1) * TILE, y * TILE, TILE, TILE))

	for tree_pos in [
		Vector2(6, 4), Vector2(7, 4), Vector2(10, 3), Vector2(12, 5),
		Vector2(5, 12), Vector2(8, 14), Vector2(16, 4), Vector2(19, 5),
		Vector2(21, 12), Vector2(24, 10), Vector2(23, 15),
	]:
		solids.append(Rect2(tree_pos.x * TILE, tree_pos.y * TILE, TILE, TILE))

	for rock_pos in [Vector2(13, 11), Vector2(14, 11), Vector2(18, 14)]:
		solids.append(Rect2(rock_pos.x * TILE, rock_pos.y * TILE, TILE, TILE))

func _build_interactables() -> void:
	interactables = [
		{
			"id": "old_tree",
			"pos": Vector2(332, 164),
			"state": "knowledge",
			"delta": 7.0,
			"text": "Vet chem cu tren cay giong nhu da cho doi Thach Sanh.",
		},
		{
			"id": "strange_tracks",
			"pos": Vector2(515, 390),
			"state": "suspicion",
			"delta": 8.0,
			"text": "Dau chan la re sang phia khong co loi mon.",
		},
		{
			"id": "whisper_stone",
			"pos": Vector2(224, 470),
			"state": "dream_stability",
			"delta": -6.0,
			"text": "Da lanh nhu nuoc. Rung thi tham ten Ly Thong.",
		},
	]

func _is_blocked(pos: Vector2) -> bool:
	var probe := Rect2(pos - Vector2(PLAYER_RADIUS, PLAYER_RADIUS), Vector2(PLAYER_RADIUS * 2.0, PLAYER_RADIUS * 2.0))
	for solid in solids:
		if solid.intersects(probe):
			return true
	return false

func _draw() -> void:
	_draw_tiles()
	_draw_exit()
	_draw_interactables()
	_draw_lewm_phenomena()
	_draw_player()
	if ly_thong_visible:
		_draw_ly_thong()
	_draw_fog()

func _draw_player() -> void:
	ThachSanhSprite.draw(self, player_pos, player_facing, player_anim_time, player_moving)

func _draw_ly_thong() -> void:
	if not ly_thong_dialogue_done:
		draw_circle(ly_thong_pos, 24.0 + sin(elapsed * 5.0) * 3.0, Color(1.0, 0.78, 0.35, 0.26))
	LyThongSprite.draw(self, ly_thong_pos, ly_thong_facing, ly_thong_anim_time, ly_thong_moving)
	if not ly_thong_dialogue_done:
		_draw_world_label(ly_thong_pos + Vector2(-42, -42), "E noi chuyen", Color(1.0, 0.86, 0.44))

func _draw_tiles() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			var base := Color(0.18, 0.38, 0.19)
			if y in [8, 9, 10] or x in [3, 4, 25, 26]:
				base = Color(0.35, 0.28, 0.16)
			if x == 28 and y >= 8 and y <= 11:
				base = Color(0.52, 0.42, 0.22)
			draw_rect(rect, base)
			draw_rect(rect, Color(0.05, 0.08, 0.05, 0.25), false, 1.0)

	for solid in solids:
		if solid.position.x == 0 or solid.position.y == 0 or solid.position.x >= (MAP_W - 1) * TILE or solid.position.y >= (MAP_H - 1) * TILE:
			draw_rect(solid, Color(0.05, 0.16, 0.08))
		else:
			draw_rect(solid, Color(0.08, 0.25, 0.10))
			draw_circle(solid.get_center() + Vector2(0, -7), 18, Color(0.02, 0.32, 0.12))

func _draw_exit() -> void:
	var pulse := 0.18 + sin(elapsed * 5.0) * 0.06 + exit_guidance * 0.18
	draw_rect(exit_completion_rect, Color(0.95, 0.78, 0.30, pulse))
	draw_rect(exit_rect, Color(0.95, 0.78, 0.30, 0.42))
	draw_rect(exit_rect, Color(0.95, 0.78, 0.30), false, 2.0)
	_draw_world_label(exit_rect.position + Vector2(-24, -22), "EXIT - dan Ly Thong den day", Color(1.0, 0.88, 0.38))
	if ly_thong_following or exit_guidance > 0.01:
		draw_line(player_pos, exit_rect.get_center(), Color(1.0, 0.90, 0.45, 0.25 + exit_guidance * 0.35), 3.0)

func _draw_interactables() -> void:
	for item in interactables:
		var pos: Vector2 = item["pos"]
		var seen := explored_objects.has(item["id"])
		draw_circle(pos, 10.0, Color(0.55, 0.72, 0.95) if not seen else Color(0.25, 0.30, 0.36))
		draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), Color(0.10, 0.10, 0.12))
		if not seen and player_pos.distance_to(pos) < 42.0:
			draw_circle(pos, 18.0 + sin(elapsed * 6.0) * 3.0, Color(0.92, 0.98, 1.0, 0.28))
			_draw_world_label(pos + Vector2(-28, -34), "E", Color(0.70, 0.90, 1.0))
		elif not seen:
			draw_circle(pos, 15.0 + sin(elapsed * 4.0) * 2.0, Color(0.55, 0.72, 0.95, 0.18))

func _draw_fog() -> void:
	if fog_alpha > 0.01:
		draw_rect(Rect2(0, 0, MAP_W * TILE, MAP_H * TILE), Color(0.60, 0.72, 0.86, fog_alpha))

func _draw_lewm_phenomena() -> void:
	if path_shift_alpha > 0.01:
		for i in range(4):
			var y := 248.0 + i * 24.0 + sin(elapsed * 2.0 + i) * 8.0
			draw_line(Vector2(96, y), Vector2(850, y + 36.0), Color(0.92, 0.82, 0.48, 0.12 * path_shift_alpha), 8.0)
	if reverse_leaf_intensity > 0.01:
		for i in range(14):
			var x := 880.0 - fmod(elapsed * 38.0 + i * 67.0, 860.0)
			var y := 70.0 + fmod(i * 43.0 + sin(elapsed + i) * 18.0, 490.0)
			draw_line(Vector2(x, y), Vector2(x - 18.0, y - 6.0), Color(0.74, 0.92, 0.58, 0.28 * reverse_leaf_intensity), 2.0)

func _draw_world_label(pos: Vector2, text: String, color: Color) -> void:
	var width := maxf(30.0, text.length() * 8.0)
	var rect := Rect2(pos + Vector2(-6, -18), Vector2(width + 12.0, 24.0))
	draw_rect(rect, Color(0.02, 0.03, 0.04, 0.78))
	draw_rect(rect, color.darkened(0.25), false, 1.0)
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, 14, color)
