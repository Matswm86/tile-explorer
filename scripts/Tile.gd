extends Node2D
class_name Tile

signal tapped(tile)

const TILE_SIZE: float = 130.0
const CORNER_RADIUS: float = 22.0
const ICON_RADIUS: float = 48.0

const BODY_TOP: Color = Color(1.0, 0.99, 0.94)
const BODY_BOT: Color = Color(0.50, 0.40, 0.24, 0.18)
const HIGHLIGHT: Color = Color(1, 1, 1, 0.55)
const OUTLINE: Color = Color(0.18, 0.16, 0.20)
const SHADOW: Color = Color(0, 0, 0, 0.32)
const BLOCK_DIM: Color = Color(0.10, 0.12, 0.18, 0.48)

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
	# Drop shadow, offset down-right.
	Drawing.draw_rounded_rect(self, Rect2(rect.position + Vector2(4, 7), rect.size), CORNER_RADIUS, SHADOW)
	# Tile body.
	Drawing.draw_rounded_rect(self, rect, CORNER_RADIUS, BODY_TOP)
	# Bottom shade band (subtle, fakes a vertical cream gradient).
	var shade_rect := Rect2(-half + 5, half - TILE_SIZE * 0.18, TILE_SIZE - 10, TILE_SIZE * 0.13)
	Drawing.draw_rounded_rect(self, shade_rect, 12, BODY_BOT)
	# Top highlight strip.
	var hi_rect := Rect2(-half + 5, -half + 5, TILE_SIZE - 10, TILE_SIZE * 0.22)
	Drawing.draw_rounded_rect(self, hi_rect, CORNER_RADIUS - 6, HIGHLIGHT)
	# Outer outline.
	Drawing.stroke_rounded_rect(self, rect, CORNER_RADIUS, 3.5, OUTLINE)
	# Icon (saturated body + dark outline + small white shine).
	Icons.draw_icon(self, icon_id, ICON_RADIUS)
	# Dim overlay if blocked by a tile above.
	if blocked and not in_tray:
		Drawing.draw_rounded_rect(self, rect, CORNER_RADIUS, BLOCK_DIM)

func bounds() -> Rect2:
	var half: float = TILE_SIZE * 0.5
	return Rect2(position - Vector2(half, half), Vector2(TILE_SIZE, TILE_SIZE))

func contains_point(p: Vector2) -> bool:
	return bounds().has_point(p)

func set_blocked(b: bool) -> void:
	if blocked != b:
		blocked = b
		queue_redraw()
