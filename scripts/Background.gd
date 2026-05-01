extends Node2D

const VIEW_W: float = 1080.0
const VIEW_H: float = 1920.0

const SKY_TOP: Color = Color(0.42, 0.78, 0.98)
const SKY_HORIZON: Color = Color(0.86, 0.95, 1.0)
const GROUND_NEAR: Color = Color(0.96, 0.86, 0.66)
const GROUND_FAR: Color = Color(0.85, 0.74, 0.55)
const RUG: Color = Color(0.99, 0.84, 0.84)
const RUG_TRIM: Color = Color(0.96, 0.66, 0.70)
const CASTLE: Color = Color(0.92, 0.84, 0.74)
const CASTLE_SHADE: Color = Color(0.78, 0.68, 0.56)

const HORIZON_Y: float = 1340.0
const RUG_RECT: Rect2 = Rect2(60, 410, 960, 1280)
const RUG_INNER: Rect2 = Rect2(78, 428, 924, 1244)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Sky gradient (top to horizon).
	Drawing.draw_vertical_gradient(
		self,
		Rect2(0, 0, VIEW_W, HORIZON_Y),
		SKY_TOP,
		SKY_HORIZON,
		28,
	)
	# Distant clouds — flat soft puffs.
	_draw_cloud(Vector2(180, 240), 110, 32)
	_draw_cloud(Vector2(820, 320), 140, 38)
	_draw_cloud(Vector2(540, 1180), 90, 26)
	# Castle silhouette on the horizon.
	_draw_castle()
	# Ground gradient.
	Drawing.draw_vertical_gradient(
		self,
		Rect2(0, HORIZON_Y, VIEW_W, VIEW_H - HORIZON_Y),
		GROUND_NEAR,
		GROUND_FAR,
		16,
	)
	# Soft pink "rug" framing the tile area.
	Drawing.draw_rounded_rect(self, RUG_RECT.grow(8), 64, Color(0, 0, 0, 0.10))
	Drawing.draw_rounded_rect(self, RUG_RECT, 60, RUG)
	Drawing.stroke_rounded_rect(self, RUG_RECT, 60, 5, RUG_TRIM)
	# Inner highlight band on top of rug.
	Drawing.draw_rounded_rect(self, Rect2(RUG_INNER.position, Vector2(RUG_INNER.size.x, 60)), 30, Color(1, 1, 1, 0.25))

func _draw_cloud(c: Vector2, w: float, h: float) -> void:
	var col := Color(1, 1, 1, 0.85)
	var col_shade := Color(0.84, 0.92, 1.0, 0.85)
	# A few overlapping ellipses approximated as scaled circles.
	draw_circle(c + Vector2(-w * 0.4, h * 0.2), h * 0.95, col_shade)
	draw_circle(c + Vector2(0, -h * 0.1), h * 1.1, col)
	draw_circle(c + Vector2(w * 0.4, h * 0.15), h * 0.95, col)
	draw_circle(c + Vector2(w * 0.15, -h * 0.4), h * 0.85, col)

func _draw_castle() -> void:
	# Centred just above the horizon; cartoonish fortress silhouette.
	var base_y: float = HORIZON_Y - 10.0
	var base_x: float = VIEW_W * 0.5
	# Main wall block.
	var wall := Rect2(base_x - 220, base_y - 220, 440, 220)
	draw_rect(wall, CASTLE)
	# Battlements: 5 crenellations along the top.
	for i in 5:
		var x: float = wall.position.x + 10.0 + float(i) * 86.0
		draw_rect(Rect2(x, wall.position.y - 28, 60, 30), CASTLE)
	# Side towers.
	draw_rect(Rect2(base_x - 280, base_y - 290, 70, 290), CASTLE_SHADE)
	draw_rect(Rect2(base_x + 210, base_y - 290, 70, 290), CASTLE_SHADE)
	# Tower flag poles.
	draw_line(Vector2(base_x - 245, base_y - 290), Vector2(base_x - 245, base_y - 360), Color(0.30, 0.24, 0.22), 4.0)
	draw_line(Vector2(base_x + 245, base_y - 290), Vector2(base_x + 245, base_y - 360), Color(0.30, 0.24, 0.22), 4.0)
	# Flags.
	var flag_a := PackedVector2Array([
		Vector2(base_x - 245, base_y - 360), Vector2(base_x - 200, base_y - 348), Vector2(base_x - 245, base_y - 336),
	])
	draw_colored_polygon(flag_a, Color(0.92, 0.42, 0.42))
	var flag_b := PackedVector2Array([
		Vector2(base_x + 245, base_y - 360), Vector2(base_x + 290, base_y - 348), Vector2(base_x + 245, base_y - 336),
	])
	draw_colored_polygon(flag_b, Color(0.42, 0.62, 0.92))
	# Central gate arch (darker).
	var gate := Rect2(base_x - 50, base_y - 110, 100, 110)
	draw_rect(gate, CASTLE_SHADE)
	draw_circle(Vector2(base_x, base_y - 110), 50, CASTLE_SHADE)
	# Window slits.
	for col in 3:
		var wx: float = wall.position.x + 80.0 + float(col) * 130.0
		draw_rect(Rect2(wx, wall.position.y + 60, 12, 30), CASTLE_SHADE)
