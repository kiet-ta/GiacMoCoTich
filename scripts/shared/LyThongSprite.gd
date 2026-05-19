extends RefCounted

const TopDownSpriteSheet = preload("res://scripts/shared/TopDownSpriteSheet.gd")

const SHEET_PATH := "res://assets/characters/ly_thong_32x32_sheet.png"
const FRAME_SIZE := Vector2(32, 32)
const WALK_FPS := 8.0

static func facing_from_input(current: Vector2, input: Vector2) -> Vector2:
	return TopDownSpriteSheet.facing_from_input(current, input)

static func next_walk_time(current: float, moving: bool, delta: float) -> float:
	return TopDownSpriteSheet.next_walk_time(current, moving, delta)

static func draw(canvas: CanvasItem, pos: Vector2, facing: Vector2, walk_time: float, moving: bool, tint := Color.WHITE) -> void:
	TopDownSpriteSheet.draw(canvas, SHEET_PATH, FRAME_SIZE, pos, facing, walk_time, moving, tint, WALK_FPS)
