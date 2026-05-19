extends RefCounted

const DEFAULT_BASE_DIR := "res://ml_data/lewm_raw"
const DEFAULT_IMAGE_SIZE := 128
const DEFAULT_CAPTURE_INTERVAL := 0.10

var enabled := false
var image_size := DEFAULT_IMAGE_SIZE
var capture_interval := DEFAULT_CAPTURE_INTERVAL
var chapter_id := ""
var episode_id := ""
var episode_dir_abs := ""
var frames_dir_abs := ""
var actions_path_abs := ""
var metadata_path_abs := ""
var frame_index := 0
var accumulator := 0.0
var previous_frame_rel := ""
var previous_action := {}
var previous_metadata := {}

func configure(chapter: String, user_args: PackedStringArray) -> void:
	chapter_id = chapter
	enabled = user_args.has("--lewm-record")
	if not enabled:
		return
	for arg in user_args:
		if arg.begins_with("--lewm-image-size="):
			image_size = maxi(32, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--lewm-capture-interval="):
			capture_interval = maxf(0.016, float(arg.get_slice("=", 1)))
	_start_episode()

func record(viewport: Viewport, delta: float, action: Dictionary, metadata: Dictionary) -> void:
	if not enabled:
		return
	accumulator += delta
	if accumulator < capture_interval:
		return
	accumulator = 0.0

	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(image_size, image_size, Image.INTERPOLATE_BILINEAR)

	var frame_rel := "frames/%06d.png" % frame_index
	var frame_abs := "%s/%s" % [episode_dir_abs, frame_rel]
	var err := image.save_png(frame_abs)
	if err != OK:
		push_error("Failed to save LeWM frame: %s" % frame_abs)
		return

	if previous_frame_rel != "":
		_append_jsonl(actions_path_abs, {
			"t": frame_index - 1,
			"frame": previous_frame_rel,
			"next_frame": frame_rel,
			"action": previous_action,
		})
		_append_jsonl(metadata_path_abs, {
			"t": frame_index - 1,
			"metadata": previous_metadata,
			"next_metadata": metadata,
		})

	previous_frame_rel = frame_rel
	previous_action = action.duplicate(true)
	previous_metadata = metadata.duplicate(true)
	frame_index += 1

func _start_episode() -> void:
	episode_id = "ep_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	episode_dir_abs = ProjectSettings.globalize_path("%s/%s/episodes/%s" % [DEFAULT_BASE_DIR, chapter_id, episode_id])
	frames_dir_abs = "%s/frames" % episode_dir_abs
	actions_path_abs = "%s/actions.jsonl" % episode_dir_abs
	metadata_path_abs = "%s/metadata.jsonl" % episode_dir_abs
	DirAccess.make_dir_recursive_absolute(frames_dir_abs)
	_write_text("%s/episode.json" % episode_dir_abs, JSON.stringify({
		"chapter_id": chapter_id,
		"episode_id": episode_id,
		"image_size": image_size,
		"capture_interval": capture_interval,
		"created_unix": Time.get_unix_time_from_system(),
	}, "\t"))

func _append_jsonl(path: String, row: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE_READ)
	if file == null:
		push_error("Failed to open LeWM log: %s" % path)
		return
	file.seek_end()
	file.store_string(JSON.stringify(row) + "\n")

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write LeWM file: %s" % path)
		return
	file.store_string(text)
