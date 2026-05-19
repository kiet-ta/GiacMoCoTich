extends RefCounted

static var _textures := {}

static func facing_from_input(current: Vector2, input: Vector2) -> Vector2:
	if input == Vector2.ZERO:
		return current
	if absf(input.x) > absf(input.y):
		return Vector2.RIGHT if input.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if input.y > 0.0 else Vector2.UP

static func next_walk_time(current: float, moving: bool, delta: float) -> float:
	if moving:
		return current + delta
	return 0.0

static func draw(canvas: CanvasItem, sheet_path: String, frame_size: Vector2, pos: Vector2, facing: Vector2, walk_time: float, moving: bool, tint: Color = Color.WHITE, walk_fps: float = 8.0) -> void:
	var sheet := _get_sheet(sheet_path)
	if sheet == null:
		return
	var row := _row_for_facing(facing)
	var col := 0
	if moving:
		col = int(floor(walk_time * walk_fps)) % 4
	var source := Rect2(Vector2(col, row) * frame_size, frame_size)
	var target := Rect2(pos - frame_size * 0.5, frame_size)
	canvas.draw_texture_rect_region(sheet, target, source, tint)

static func _get_sheet(sheet_path: String) -> Texture2D:
	if _textures.has(sheet_path):
		return _textures[sheet_path]
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(sheet_path))
	if err != OK or image.is_empty():
		push_error("Failed to load sprite sheet: %s" % sheet_path)
		return null
	var texture := ImageTexture.create_from_image(image)
	_textures[sheet_path] = texture
	return texture

static func _row_for_facing(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 2 if facing.x > 0.0 else 1
	return 3 if facing.y < 0.0 else 0
