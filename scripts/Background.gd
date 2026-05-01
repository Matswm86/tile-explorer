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
	# Sun in upper-right.
	_draw_sun(Vector2(880, 230), 75)
	# Distant clouds — multi-blob organic shapes.
	_draw_cloud(Vector2(220, 260), 120, 36)
	_draw_cloud(Vector2(540, 1120), 95, 28)
	# Rolling hills behind the castle.
	_draw_hills()
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
	# Tiny grass tufts scattered on the ground.
	_draw_grass_tufts()
	# Soft pink "rug" framing the tile area.
	Drawing.draw_rounded_rect(self, RUG_RECT.grow(8), 64, Color(0, 0, 0, 0.10))
	Drawing.draw_rounded_rect(self, RUG_RECT, 60, RUG)
	Drawing.stroke_rounded_rect(self, RUG_RECT, 60, 5, RUG_TRIM)
	# Inner highlight band on top of rug.
	Drawing.draw_rounded_rect(self, Rect2(RUG_INNER.position, Vector2(RUG_INNER.size.x, 60)), 30, Color(1, 1, 1, 0.25))

func _draw_cloud(c: Vector2, w: float, h: float) -> void:
	var col := Color(1, 1, 1, 0.95)
	var col_shade := Color(0.78, 0.88, 1.0, 0.75)
	# Bottom bumps (in shadow).
	draw_circle(c + Vector2(-w * 0.55, h * 0.35), h * 0.90, col_shade)
	draw_circle(c + Vector2(w * 0.55, h * 0.35), h * 0.90, col_shade)
	# Body bumps (upper, in light).
	draw_circle(c + Vector2(-w * 0.35, -h * 0.10), h * 1.05, col)
	draw_circle(c + Vector2(0, -h * 0.30), h * 1.20, col)
	draw_circle(c + Vector2(w * 0.35, -h * 0.10), h * 1.05, col)
	# Top highlight blob.
	draw_circle(c + Vector2(-w * 0.20, -h * 0.45), h * 0.40, Color(1, 1, 1, 0.7))

func _draw_sun(c: Vector2, r: float) -> void:
	# Glow halo (two soft rings).
	draw_circle(c, r * 1.85, Color(1, 0.96, 0.55, 0.18))
	draw_circle(c, r * 1.45, Color(1, 0.94, 0.50, 0.30))
	# Rays — 12 lines around the disc.
	for i in 12:
		var a: float = TAU * float(i) / 12.0 + 0.13
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * r * 1.25, c + dir * r * 1.70, Color(1, 0.84, 0.30, 0.85), 8.0)
	# Disc body.
	draw_circle(c, r * 1.05, Color(1, 0.78, 0.18))
	draw_circle(c, r, Color(1, 0.93, 0.45))
	# Highlight crescent.
	draw_circle(c + Vector2(-r * 0.25, -r * 0.30), r * 0.35, Color(1, 1, 0.8, 0.55))

func _draw_hills() -> void:
	var col := Color(0.66, 0.74, 0.88, 0.7)
	var pts := PackedVector2Array()
	pts.append(Vector2(0, HORIZON_Y))
	var step: int = 60
	for x in range(0, int(VIEW_W) + step, step):
		var nx: float = float(x)
		var dy: float = sin(nx * 0.013 + 0.7) * 36.0 + sin(nx * 0.006) * 28.0
		var y: float = HORIZON_Y - 110.0 - dy
		pts.append(Vector2(nx, y))
	pts.append(Vector2(VIEW_W, HORIZON_Y))
	draw_colored_polygon(pts, col)
	# A second nearer set of hills, deeper colour.
	var col2 := Color(0.56, 0.66, 0.82, 0.85)
	var pts2 := PackedVector2Array()
	pts2.append(Vector2(0, HORIZON_Y))
	for x in range(0, int(VIEW_W) + step, step):
		var nx: float = float(x)
		var dy: float = sin(nx * 0.018 + 1.7) * 22.0 + sin(nx * 0.009 + 0.4) * 18.0
		var y: float = HORIZON_Y - 60.0 - dy
		pts2.append(Vector2(nx, y))
	pts2.append(Vector2(VIEW_W, HORIZON_Y))
	draw_colored_polygon(pts2, col2)

func _draw_grass_tufts() -> void:
	# Scattered small grass strokes near the rug edges, between rug and powerup bar.
	var col := Color(0.36, 0.66, 0.30, 0.85)
	var seeds: Array = [
		Vector2(40, 1380),  Vector2(95, 1395),  Vector2(160, 1370),
		Vector2(40, 1500),  Vector2(115, 1520), Vector2(46, 1620),
		Vector2(965, 1380), Vector2(1010, 1400), Vector2(945, 1500),
		Vector2(1020, 1530), Vector2(975, 1620), Vector2(995, 1660),
	]
	for s in seeds:
		draw_line(s, s + Vector2(0, -16), col, 3.0)
		draw_line(s + Vector2(-5, -8), s + Vector2(-5, -22), col, 3.0)
		draw_line(s + Vector2(5, -8), s + Vector2(5, -22), col, 3.0)

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
