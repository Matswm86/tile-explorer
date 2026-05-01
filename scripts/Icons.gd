extends RefCounted
class_name Icons

const TABLE: Array = [
	{"name": "circle",   "color": Color(0.91, 0.26, 0.30)},
	{"name": "square",   "color": Color(0.20, 0.55, 0.92)},
	{"name": "triangle", "color": Color(0.27, 0.74, 0.32)},
	{"name": "diamond",  "color": Color(0.95, 0.78, 0.18)},
	{"name": "star",     "color": Color(0.62, 0.28, 0.92)},
	{"name": "hexagon",  "color": Color(0.98, 0.55, 0.10)},
	{"name": "heart",    "color": Color(0.96, 0.42, 0.78)},
	{"name": "plus",     "color": Color(0.18, 0.78, 0.85)},
	{"name": "crescent", "color": Color(0.55, 0.36, 0.20)},
	{"name": "ring",     "color": Color(0.30, 0.30, 0.34)},
	{"name": "pentagon", "color": Color(0.85, 0.66, 0.18)},
	{"name": "bolt",     "color": Color(0.14, 0.22, 0.55)},
]

static func count() -> int:
	return TABLE.size()

static func name_of(id: int) -> String:
	return String(TABLE[id]["name"])

static func color_of(id: int) -> Color:
	return TABLE[id]["color"]

# Draw icon shape `id` centered at (0,0) with a half-extent radius `r`.
static func draw_icon(node: CanvasItem, id: int, r: float) -> void:
	var col: Color = color_of(id)
	var name: String = name_of(id)
	match name:
		"circle":
			node.draw_circle(Vector2.ZERO, r, col)
		"square":
			node.draw_rect(Rect2(-r, -r, r * 2.0, r * 2.0), col)
		"triangle":
			var tri := PackedVector2Array([
				Vector2(0, -r),
				Vector2(-r * 0.95, r * 0.78),
				Vector2(r * 0.95, r * 0.78),
			])
			node.draw_colored_polygon(tri, col)
		"diamond":
			var dm := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0),
			])
			node.draw_colored_polygon(dm, col)
		"star":
			node.draw_colored_polygon(_star_points(r, 5, 0.46), col)
		"hexagon":
			node.draw_colored_polygon(_regular_polygon(r, 6, -PI / 2.0), col)
		"heart":
			node.draw_colored_polygon(_heart_points(r), col)
		"plus":
			var t: float = r * 0.42
			node.draw_rect(Rect2(-r, -t, r * 2.0, t * 2.0), col)
			node.draw_rect(Rect2(-t, -r, t * 2.0, r * 2.0), col)
		"crescent":
			node.draw_circle(Vector2.ZERO, r, col)
			node.draw_circle(Vector2(r * 0.32, -r * 0.12), r * 0.86, Color(1, 1, 1))
		"ring":
			node.draw_arc(Vector2.ZERO, r * 0.85, 0.0, TAU, 48, col, r * 0.32)
		"pentagon":
			node.draw_colored_polygon(_regular_polygon(r, 5, -PI / 2.0), col)
		"bolt":
			var bolt := PackedVector2Array([
				Vector2(-r * 0.15, -r),
				Vector2(r * 0.55, -r * 0.2),
				Vector2(r * 0.10, -r * 0.05),
				Vector2(r * 0.45, r),
				Vector2(-r * 0.45, r * 0.05),
				Vector2(0, r * 0.0),
				Vector2(-r * 0.55, r * 0.05),
			])
			node.draw_colored_polygon(bolt, col)

static func _regular_polygon(r: float, sides: int, start_angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a: float = start_angle + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

static func _star_points(r: float, points: int, inner_ratio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = points * 2
	for i in n:
		var a: float = -PI / 2.0 + TAU * float(i) / float(n)
		var rr: float = r if i % 2 == 0 else r * inner_ratio
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts

static func _heart_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps: int = 36
	for i in steps:
		var t: float = TAU * float(i) / float(steps)
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) * (r / 17.0))
	return pts
