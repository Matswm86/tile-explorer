extends Node2D
class_name Tile

signal tapped(tile)

const TILE_SIZE: float = 130.0
const CORNER_RADIUS: float = 14.0
const ICON_RADIUS: float = 38.0

var icon_id: int = 0
var board_position: Vector2 = Vector2.ZERO
var layer: int = 0
var blocked: bool = true
var in_tray: bool = false
var animating: bool = false

func _ready() -> void:
	z_index = layer
	queue_redraw()

func _draw() -> void:
	var half: float = TILE_SIZE * 0.5
	var rect := Rect2(-half, -half, TILE_SIZE, TILE_SIZE)
	# Tile body — soft white with a subtle bevel.
	draw_rect(rect, Color(0.99, 0.99, 0.99))
	# Top highlight strip.
	draw_rect(Rect2(-half, -half, TILE_SIZE, TILE_SIZE * 0.18), Color(1, 1, 1))
	# Bottom shade strip.
	draw_rect(Rect2(-half, half - TILE_SIZE * 0.16, TILE_SIZE, TILE_SIZE * 0.16), Color(0.86, 0.86, 0.88))
	# Border.
	draw_rect(rect, Color(0.18, 0.18, 0.20), false, 3.0)
	# Icon.
	Icons.draw_icon(self, icon_id, ICON_RADIUS)
	# Dim overlay if blocked by a tile above.
	if blocked and not in_tray:
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.42))

func bounds() -> Rect2:
	var half: float = TILE_SIZE * 0.5
	return Rect2(position - Vector2(half, half), Vector2(TILE_SIZE, TILE_SIZE))

func contains_point(p: Vector2) -> bool:
	return bounds().has_point(p)

func set_blocked(b: bool) -> void:
	if blocked != b:
		blocked = b
		queue_redraw()
