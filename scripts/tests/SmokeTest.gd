extends SceneTree

const ProgressService = preload("res://scripts/shared/ProgressService.gd")
const ChapterScoreCalculator = preload("res://scripts/shared/ChapterScoreCalculator.gd")
const WorldState = preload("res://scripts/shared/WorldState.gd")
const LeWMReactionSystem = preload("res://scripts/shared/LeWMReactionSystem.gd")

const SCENE_PATHS := [
	"res://scenes/GameRoot.tscn",
	"res://scenes/Chapter1Forest.tscn",
	"res://scenes/Chapter2Boss.tscn",
	"res://scenes/Chapter3Climb.tscn",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0

	failures += _test_score_calculator()
	failures += _test_progress_service()
	failures += _test_progress_service_old_save_memory()
	failures += _test_lewm_reaction_contracts()
	failures += _test_chapter_1_exit_completion()

	for scene_path in SCENE_PATHS:
		var packed := load(scene_path)
		if packed == null:
			push_error("Failed to load scene: %s" % scene_path)
			failures += 1
			continue

		var node: Node = packed.instantiate()
		if node == null:
			push_error("Failed to instantiate scene: %s" % scene_path)
			failures += 1
			continue

		root.add_child(node)
		if scene_path != "res://scenes/GameRoot.tscn":
			if not node.has_method("get_objective_text"):
				push_error("Missing get_objective_text: %s" % scene_path)
				failures += 1
			if not node.has_method("get_completion_payload"):
				push_error("Missing get_completion_payload: %s" % scene_path)
				failures += 1
			else:
				var payload: Dictionary = node.get_completion_payload()
				if not payload.has("lewm_impact") or not payload.has("global_memory_delta"):
					push_error("Missing LeWM completion payload fields: %s" % scene_path)
					failures += 1
		node.queue_free()

	if failures > 0:
		quit(1)
	else:
		quit(0)

func _test_score_calculator() -> int:
	var calculator := ChapterScoreCalculator.new()
	var chapter_1 := calculator.calculate("chapter_1", {
		"time_seconds": 80.0,
		"clues_found": 2,
		"dream_stability": 60.0,
	})
	if int(chapter_1.get("stars", 0)) != 3:
		push_error("Chapter 1 scoring expected 3 stars.")
		return 1

	var chapter_2 := calculator.calculate("chapter_2", {
		"time_seconds": 151.0,
		"hp_remaining": 40.0,
		"danger_spikes": 1,
	})
	if int(chapter_2.get("stars", 0)) != 2:
		push_error("Chapter 2 scoring expected 2 stars.")
		return 1

	var chapter_3 := calculator.calculate("chapter_3", {
		"time_seconds": 240.0,
		"fall_count": 3,
	})
	if int(chapter_3.get("stars", 0)) != 3:
		push_error("Chapter 3 scoring expected 3 stars.")
		return 1

	return 0

func _test_chapter_1_exit_completion() -> int:
	var packed := load("res://scenes/Chapter1Forest.tscn")
	if packed == null:
		push_error("Failed to load Chapter 1 scene for exit completion test.")
		return 1

	var node: Node = packed.instantiate()
	root.add_child(node)

	var completed := [false]
	node.chapter_completed.connect(func(chapter_id: String, _payload: Dictionary) -> void:
		completed[0] = chapter_id == "chapter_1"
	)

	node.ly_thong_visible = true
	node.ly_thong_dialogue_done = true
	node.ly_thong_following = true
	node.player_pos = Vector2(900, 320)
	node.ly_thong_pos = Vector2(815, 335)
	node._update_ly_thong(0.016)
	node.queue_free()

	if not bool(completed[0]):
		push_error("Chapter 1 should complete when player reaches EXIT with Ly Thong following nearby.")
		return 1

	return 0

func _test_progress_service() -> int:
	var progress := ProgressService.new()
	if not progress.is_unlocked("chapter_1"):
		push_error("Chapter 1 should be unlocked by default.")
		return 1
	if progress.is_unlocked("chapter_2"):
		push_error("Chapter 2 should be locked by default.")
		return 1

	progress.record_result("chapter_1", {"stars": 2}, {"time_seconds": 100.0})
	if not progress.is_unlocked("chapter_2"):
		push_error("Chapter 2 should unlock after Chapter 1 completion.")
		return 1

	progress.record_result("chapter_1", {"stars": 1}, {"time_seconds": 120.0})
	if int(progress.get_chapter_progress("chapter_1").get("best_stars", 0)) != 2:
		push_error("Best stars should not be downgraded on replay.")
		return 1

	return 0

func _test_progress_service_old_save_memory() -> int:
	var legacy_save := {
		"schema_version": 1,
		"chapters": {
			"chapter_1": {"unlocked": true, "completed": false, "best_stars": 0, "best_time": 0.0, "last_payload": {}},
			"chapter_2": {"unlocked": false, "completed": false, "best_stars": 0, "best_time": 0.0, "last_payload": {}},
			"chapter_3": {"unlocked": false, "completed": false, "best_stars": 0, "best_time": 0.0, "last_payload": {}},
		},
	}
	var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write legacy progress save for compatibility test.")
		return 1
	file.store_string(JSON.stringify(legacy_save))
	file = null

	var progress := ProgressService.new()
	progress.load_progress()
	var memory := progress.get_global_memory()
	if not memory.has("danger_bias") or not memory.has("climb_anxiety"):
		push_error("Legacy save should be upgraded with default global memory keys.")
		return 1

	progress.record_result("chapter_2", {"stars": 1}, {
		"time_seconds": 30.0,
		"global_memory_delta": {"danger_bias": 5.0, "combat_spam_bias": 3.0},
	})
	memory = progress.get_global_memory()
	if float(memory.get("danger_bias", 0.0)) < 5.0:
		push_error("Global memory delta should persist through ProgressService.")
		return 1

	return 0

func _test_lewm_reaction_contracts() -> int:
	var lewm := LeWMReactionSystem.new()
	var world_state := WorldState.new()
	world_state.apply_global_memory({"danger_bias": 20.0, "climb_anxiety": 20.0})

	var forest := lewm.evaluate_forest({
		"explored_objects": 1,
		"time_in_forest": 60.0,
		"wandering": true,
		"distance_to_ly_thong": 80.0,
		"direct_exit_route": false,
	}, world_state)
	if String(forest.get("intent", "")) == "" or not forest.has("ui") or not forest.has("effects"):
		push_error("Forest LeWM reaction must expose standardized fields.")
		return 1
	if not bool(forest.get("path_shift", false)):
		push_error("Forest wandering should trigger PathShift effect.")
		return 1

	var boss := lewm.evaluate_boss({
		"attack_frequency": 5.0,
		"bow_ratio": 0.0,
		"aim_accuracy": 0.0,
		"distance_to_boss": 70.0,
		"weapon_switch_frequency": 0.0,
		"dash_frequency": 0.0,
		"clue_read": false,
		"trap_cleared": false,
	}, world_state)
	if String(boss.get("intent", "")) != "PunishSpam" or float(boss.get("severity", 0.0)) < 70.0:
		push_error("Boss spam behavior should trigger strong PunishSpam reaction.")
		return 1

	var climb := lewm.evaluate_climb({
		"fall_count": 3,
		"height_ratio": 0.60,
		"idle_time": 0.0,
		"repeated_miss_count": 2,
	}, world_state)
	if float(climb.get("wind", 0.0)) == 0.0 or not climb.has("trajectory_echo"):
		push_error("Climb falls/repeated misses should trigger wind and trajectory echo contract.")
		return 1

	return 0
