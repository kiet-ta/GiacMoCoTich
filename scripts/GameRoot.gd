extends Node2D

const ProgressService = preload("res://scripts/shared/ProgressService.gd")
const ChapterScoreCalculator = preload("res://scripts/shared/ChapterScoreCalculator.gd")

const CHAPTERS := [
	{
		"id": "chapter_1",
		"title": "Chapter 1 - Rung Mong",
		"summary": "Kham pha rung, gap Ly Thong, tim loi ra phia dong.",
		"controls": "WASD move | E interact",
		"scene": preload("res://scenes/Chapter1Forest.tscn"),
	},
	{
		"id": "chapter_2",
		"title": "Chapter 2 - Chan Tinh",
		"summary": "Chuan bi ngan, vao dau truong, solo boss topdown.",
		"controls": "WASD move | Mouse aim | LMB attack | 1/2 weapon | Space dash",
		"scene": preload("res://scenes/Chapter2Boss.tscn"),
	},
	{
		"id": "chapter_3",
		"title": "Chapter 3 - Vuc Dai Bang",
		"summary": "Strict Jump King: giu Space de tich luc, tha de nhay.",
		"controls": "A/D move | Hold Space charge | Release Space jump",
		"scene": preload("res://scenes/Chapter3Climb.tscn"),
	},
]

var progress_service := ProgressService.new()
var score_calculator := ChapterScoreCalculator.new()

var current_chapter: Node = null
var current_index := -1
var debug_visible := false

var ui_layer: CanvasLayer
var menu: Control
var hud: Control
var completion_overlay: Control
var objective_label: Label
var timer_label: Label
var message_label: Label
var chapter_label: Label
var extra_label: Label
var debug_label: Label
var status_bars_box: VBoxContainer
var status_chips_box: HBoxContainer
var message_panel: PanelContainer
var notice_label: Label
var notice_ttl := 0.0
var hud_bars_signature := ""
var hud_chips_signature := ""

func _ready() -> void:
	DisplayServer.window_set_ime_active(false)
	progress_service.load_progress()
	_create_ui_layer()
	_show_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_show_menu()
		elif event.physical_keycode == KEY_F1:
			_try_start_chapter(0)
		elif event.physical_keycode == KEY_F2:
			_try_start_chapter(1)
		elif event.physical_keycode == KEY_F3:
			_try_start_chapter(2)
		elif event.physical_keycode == KEY_R and current_index >= 0:
			_try_start_chapter(current_index)
		elif event.physical_keycode == KEY_F9:
			debug_visible = not debug_visible
			debug_label.visible = debug_visible

func _process(delta: float) -> void:
	if notice_ttl > 0.0:
		notice_ttl = maxf(0.0, notice_ttl - delta)
		if notice_label != null:
			notice_label.visible = notice_ttl > 0.0
	_update_hud()

func _create_ui_layer() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	_create_hud()

func _create_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.visible = false
	ui_layer.add_child(hud)

	var top_left := PanelContainer.new()
	top_left.position = Vector2(16, 16)
	top_left.custom_minimum_size = Vector2(390, 58)
	top_left.add_theme_stylebox_override("panel", _compact_panel_style(Color(0.02, 0.03, 0.04, 0.56), Color(0.20, 0.30, 0.38, 0.55)))
	hud.add_child(top_left)

	var top_left_box := VBoxContainer.new()
	top_left_box.add_theme_constant_override("separation", 2)
	top_left.add_child(top_left_box)

	chapter_label = Label.new()
	chapter_label.add_theme_font_size_override("font_size", 12)
	chapter_label.add_theme_color_override("font_color", Color(0.72, 0.86, 1.0))
	top_left_box.add_child(chapter_label)

	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 16)
	objective_label.add_theme_color_override("font_color", Color.WHITE)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_left_box.add_child(objective_label)

	status_chips_box = HBoxContainer.new()
	status_chips_box.add_theme_constant_override("separation", 6)
	status_chips_box.visible = false
	hud.add_child(status_chips_box)

	var top_right := PanelContainer.new()
	top_right.position = Vector2(850, 16)
	top_right.custom_minimum_size = Vector2(134, 38)
	top_right.add_theme_stylebox_override("panel", _compact_panel_style(Color(0.02, 0.03, 0.04, 0.54), Color(0.20, 0.30, 0.38, 0.50)))
	hud.add_child(top_right)

	var top_right_box := VBoxContainer.new()
	top_right.add_child(top_right_box)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 16)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	top_right_box.add_child(timer_label)

	extra_label = Label.new()
	extra_label.visible = false
	extra_label.add_theme_font_size_override("font_size", 15)
	extra_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
	extra_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(extra_label)

	status_bars_box = VBoxContainer.new()
	status_bars_box.add_theme_constant_override("separation", 5)
	status_bars_box.visible = false
	hud.add_child(status_bars_box)

	message_panel = PanelContainer.new()
	message_panel.position = Vector2(220, 584)
	message_panel.custom_minimum_size = Vector2(560, 42)
	message_panel.add_theme_stylebox_override("panel", _compact_panel_style(Color(0.0, 0.0, 0.0, 0.58), Color(0.28, 0.36, 0.44, 0.55)))
	hud.add_child(message_panel)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_panel.add_child(message_label)

	debug_label = Label.new()
	debug_label.position = Vector2(16, 120)
	debug_label.custom_minimum_size = Vector2(560, 30)
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color(0.70, 1.0, 0.70))
	debug_label.visible = false
	hud.add_child(debug_label)

	notice_label = Label.new()
	notice_label.position = Vector2(44, 500)
	notice_label.custom_minimum_size = Vector2(912, 28)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 18)
	notice_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.46))
	notice_label.visible = false
	hud.add_child(notice_label)

func _show_menu() -> void:
	_clear_current_chapter()
	current_index = -1
	hud.visible = false
	_clear_completion_overlay()

	if menu != null:
		menu.queue_free()

	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(menu)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.035, 0.045, 0.065)
	menu.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(44, 34)
	panel.custom_minimum_size = Vector2(912, 570)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.09, 0.12, 0.96), Color(0.20, 0.32, 0.42, 0.9)))
	menu.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Giac Mo Co Tich"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Chon man choi. Hoan thanh man truoc de mo man tiep theo."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94))
	box.add_child(subtitle)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	box.add_child(cards)

	for i in range(CHAPTERS.size()):
		cards.add_child(_create_chapter_card(i))

	var help := Label.new()
	help.text = "Phim nhanh: F1/F2/F3 chon man, ESC ve menu, R choi lai man hien tai, F9 debug."
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	box.add_child(help)

func _create_chapter_card(index: int) -> Control:
	var data: Dictionary = CHAPTERS[index]
	var chapter_id := String(data["id"])
	var chapter_progress := progress_service.get_chapter_progress(chapter_id)
	var unlocked := progress_service.is_unlocked(chapter_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(282, 360)
	var base_color := Color(0.10, 0.13, 0.17, 0.98) if unlocked else Color(0.07, 0.075, 0.085, 0.96)
	card.add_theme_stylebox_override("panel", _panel_style(base_color, Color(0.28, 0.36, 0.46, 0.85)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	card.add_child(box)

	var title := Label.new()
	title.text = String(data["title"])
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.48, 0.52, 0.56))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)

	var stars := Label.new()
	stars.text = _star_text(int(chapter_progress.get("best_stars", 0)))
	stars.add_theme_font_size_override("font_size", 24)
	stars.add_theme_color_override("font_color", Color(1.0, 0.83, 0.28) if unlocked else Color(0.38, 0.38, 0.38))
	box.add_child(stars)

	var summary := Label.new()
	summary.text = String(data["summary"])
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", Color(0.78, 0.86, 0.94) if unlocked else Color(0.48, 0.52, 0.56))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)

	var controls := Label.new()
	controls.text = String(data["controls"])
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.68, 0.78, 0.88) if unlocked else Color(0.45, 0.48, 0.52))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(controls)

	var status := Label.new()
	if unlocked:
		status.text = "Da mo khoa" if not bool(chapter_progress.get("completed", false)) else "Da hoan thanh"
	else:
		status.text = "Hoan thanh man truoc de mo"
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65) if unlocked else Color(0.90, 0.52, 0.42))
	box.add_child(status)

	var start := Button.new()
	start.text = "Vao man" if unlocked else "Dang khoa"
	start.disabled = not unlocked
	start.custom_minimum_size = Vector2(0, 42)
	start.pressed.connect(func() -> void: _try_start_chapter(index))
	box.add_child(start)

	return card

func _try_start_chapter(index: int) -> void:
	var chapter_id := String(CHAPTERS[index]["id"])
	if not progress_service.is_unlocked(chapter_id):
		_show_menu_notice("Man nay dang khoa. Hay hoan thanh man truoc.")
		return
	_start_chapter(index)

func _start_chapter(index: int) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	_clear_completion_overlay()
	_clear_current_chapter()

	current_index = index
	current_chapter = CHAPTERS[index]["scene"].instantiate()
	add_child(current_chapter)
	if current_chapter.has_method("apply_global_memory"):
		current_chapter.apply_global_memory(progress_service.get_global_memory())
	hud.visible = true

	if current_chapter.has_signal("chapter_completed"):
		current_chapter.chapter_completed.connect(_on_chapter_completed)

func _clear_current_chapter() -> void:
	if current_chapter != null:
		current_chapter.queue_free()
		current_chapter = null

func _update_hud() -> void:
	if current_chapter == null or not hud.visible:
		return

	var data: Dictionary = CHAPTERS[current_index]
	chapter_label.text = String(data["title"])

	if current_chapter.has_method("get_objective_text"):
		objective_label.text = String(current_chapter.get_objective_text())
	else:
		objective_label.text = "Hoan thanh muc tieu man."

	var payload := _current_payload()
	var time_seconds := float(payload.get("time_seconds", 0.0))
	timer_label.text = "Time: %s" % _format_time(time_seconds)

	if current_chapter.has_method("get_hud_data"):
		var hud_data: Dictionary = current_chapter.get_hud_data()
		message_label.text = String(hud_data.get("message", ""))
		message_panel.visible = message_label.text.strip_edges() != ""
		_refresh_chips([])
		_refresh_status_bars([])
	else:
		extra_label.text = ""
		message_label.text = ""
		message_panel.visible = false
		_refresh_chips([])
		_refresh_status_bars([])

	if current_chapter.has_method("get_debug_text"):
		debug_label.text = String(current_chapter.get_debug_text())
	else:
		debug_label.text = ""

func _current_payload() -> Dictionary:
	if current_chapter != null and current_chapter.has_method("get_completion_payload"):
		return current_chapter.get_completion_payload()
	return {"time_seconds": 0.0}

func _on_chapter_completed(chapter_id: String, payload: Dictionary) -> void:
	if current_chapter != null:
		current_chapter.process_mode = Node.PROCESS_MODE_DISABLED
	var score := score_calculator.calculate(chapter_id, payload)
	var progress_result := progress_service.record_result(chapter_id, score, payload)
	_show_completion_overlay(chapter_id, payload, score, String(progress_result.get("next_unlocked", "")))

func _show_completion_overlay(chapter_id: String, payload: Dictionary, score: Dictionary, next_unlocked: String) -> void:
	hud.visible = false
	_clear_completion_overlay()

	completion_overlay = Control.new()
	completion_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(completion_overlay)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.68)
	completion_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.position = Vector2(245, 54)
	panel.custom_minimum_size = Vector2(510, 540)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.14, 0.98), Color(0.42, 0.56, 0.70, 0.95)))
	completion_overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Hoan thanh man"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var stars := Label.new()
	stars.text = _star_text(int(score.get("stars", 1)))
	stars.add_theme_font_size_override("font_size", 38)
	stars.add_theme_color_override("font_color", Color(1.0, 0.83, 0.28))
	box.add_child(stars)

	var time := Label.new()
	time.text = "Thoi gian: %s" % _format_time(float(payload.get("time_seconds", 0.0)))
	time.add_theme_font_size_override("font_size", 18)
	time.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	box.add_child(time)

	var impact := Label.new()
	impact.text = _format_lewm_impact(payload)
	impact.add_theme_font_size_override("font_size", 16)
	impact.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	impact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(impact)

	var criteria := Label.new()
	criteria.text = "\n".join(PackedStringArray(score.get("criteria", [])))
	criteria.add_theme_font_size_override("font_size", 16)
	criteria.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96))
	criteria.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(criteria)

	var unlock := Label.new()
	unlock.text = _unlock_message(next_unlocked)
	unlock.add_theme_font_size_override("font_size", 17)
	unlock.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	unlock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(unlock)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)

	var next := Button.new()
	next.text = "Man tiep theo"
	next.disabled = _next_index_for(chapter_id) < 0
	next.custom_minimum_size = Vector2(140, 42)
	next.pressed.connect(func() -> void:
		var next_index := _next_index_for(chapter_id)
		if next_index >= 0:
			_try_start_chapter(next_index)
	)
	buttons.add_child(next)

	var replay := Button.new()
	replay.text = "Choi lai"
	replay.custom_minimum_size = Vector2(120, 42)
	replay.pressed.connect(func() -> void: _try_start_chapter(current_index))
	buttons.add_child(replay)

	var back := Button.new()
	back.text = "Ve chon man"
	back.custom_minimum_size = Vector2(140, 42)
	back.pressed.connect(_show_menu)
	buttons.add_child(back)

func _clear_completion_overlay() -> void:
	if completion_overlay != null:
		completion_overlay.queue_free()
		completion_overlay = null

func _next_index_for(chapter_id: String) -> int:
	for i in range(CHAPTERS.size() - 1):
		if String(CHAPTERS[i]["id"]) == chapter_id:
			var next_id := String(CHAPTERS[i + 1]["id"])
			return i + 1 if progress_service.is_unlocked(next_id) else -1
	return -1

func _unlock_message(next_unlocked: String) -> String:
	if next_unlocked == "":
		return "Ket qua da duoc luu."
	for data in CHAPTERS:
		if String(data["id"]) == next_unlocked:
			return "Mo khoa: %s" % String(data["title"])
	return "Mo khoa man tiep theo."

func _format_lewm_impact(payload_or_impact: Variant) -> String:
	var payload: Dictionary = payload_or_impact if payload_or_impact is Dictionary else {}
	var impact_value: Variant = payload.get("lewm_impact", payload_or_impact)
	var impact: Array = impact_value if impact_value is Array else []
	var boss_read := _boss_read_label(String(payload.get("lewm_primary_read", "")))
	if impact.is_empty() and boss_read == "":
		return "LeWorldModel Impact: chua co phan ung dang ke."
	var lines := PackedStringArray(["LeWorldModel Impact:"])
	for item in impact.slice(maxi(impact.size() - 3, 0), impact.size()):
		lines.append("- %s" % String(item))
	if boss_read != "":
		lines.append("- Boss doc loi choi: %s" % boss_read)
	return "\n".join(lines)

func _boss_read_label(read_key: String) -> String:
	match read_key:
		"spam_melee":
			return "chem riu lien tuc"
		"kite_bow":
			return "giu khoang cach bang cung"
		"accurate_bow":
			return "ban cung qua chuan"
		"early_dash":
			return "dash som theo nhip boss"
		"corner_hold":
			return "giu goc an toan qua lau"
		"weapon_switch":
			return "doi vu khi qua gap"
		_:
			return ""

func _show_menu_notice(text: String) -> void:
	if menu != null:
		var notice := Label.new()
		notice.text = text
		notice.position = Vector2(64, 594)
		notice.add_theme_font_size_override("font_size", 17)
		notice.add_theme_color_override("font_color", Color(1.0, 0.62, 0.48))
		menu.add_child(notice)
	elif notice_label != null:
		notice_label.text = text
		notice_label.visible = true
		notice_ttl = 2.0

func _star_text(stars: int) -> String:
	var filled := ""
	for i in range(3):
		filled += "[*]" if i < stars else "[-]"
	return filled

func _format_time(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	return "%02d:%02d" % [total / 60, total % 60]

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	return style

func _compact_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	return style

func _refresh_chips(chips_value: Variant) -> void:
	var chips: Array = chips_value if chips_value is Array else []
	var signature := "|".join(PackedStringArray(chips))
	if signature == hud_chips_signature:
		return
	hud_chips_signature = signature
	_clear_children(status_chips_box)
	for chip in chips:
		var label := Label.new()
		label.text = String(chip)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
		label.add_theme_stylebox_override("normal", _chip_style(Color(0.12, 0.18, 0.24, 0.90), Color(0.36, 0.48, 0.60, 0.85)))
		status_chips_box.add_child(label)

func _refresh_status_bars(bars_value: Variant) -> void:
	var bars: Array = bars_value if bars_value is Array else []
	var signature := JSON.stringify(bars)
	if signature == hud_bars_signature:
		return
	hud_bars_signature = signature
	_clear_children(status_bars_box)
	for bar in bars:
		if not (bar is Dictionary):
			continue
		status_bars_box.add_child(_create_status_bar(bar))

func _create_status_bar(data: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.text = "%s  %d/%d" % [
		String(data.get("label", "Value")),
		int(float(data.get("value", 0.0))),
		int(float(data.get("max", 100.0))),
	]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	box.add_child(label)

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = maxf(1.0, float(data.get("max", 100.0)))
	progress.value = clampf(float(data.get("value", 0.0)), 0.0, progress.max_value)
	progress.custom_minimum_size = Vector2(0, 10)
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _bar_style(Color(0.08, 0.10, 0.13, 0.95), Color(0.20, 0.26, 0.34, 0.9)))
	progress.add_theme_stylebox_override("fill", _bar_style(data.get("color", Color(0.55, 0.84, 1.0)), data.get("color", Color(0.55, 0.84, 1.0))))
	box.add_child(progress)
	return box

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _chip_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

func _bar_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
