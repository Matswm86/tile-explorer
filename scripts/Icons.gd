extends RefCounted
class_name Icons

# Brighter, more saturated palette — closer to the chibi-icon reference.
const TABLE: Array = [
	{"name": "circle",   "color": Color(0.96, 0.27, 0.34)},   # cherry red
	{"name": "square",   "color": Color(0.18, 0.60, 0.96)},   # bright blue
	{"name": "triangle", "color": Color(0.22, 0.78, 0.36)},   # leaf green
	{"name": "diamond",  "color": Color(0.99, 0.82, 0.16)},   # sun yellow
	{"name": "star",     "color": Color(0.74, 0.32, 0.96)},   # grape purple
	{"name": "hexagon",  "color": Color(1.00, 0.55, 0.08)},   # tangerine
	{"name": "heart",    "color": Color(0.98, 0.42, 0.74)},   # bubblegum pink
	{"name": "plus",     "color": Color(0.16, 0.82, 0.88)},   # mint cyan
	{"name": "crescent", "color": Color(0.62, 0.40, 0.22)},   # cocoa
	{"name": "ring",     "color": Color(0.36, 0.40, 0.50)},   # slate
	{"name": "pentagon", "color": Color(0.90, 0.70, 0.18)},   # honey gold
	{"name": "bolt",     "color": Color(0.16, 0.26, 0.62)},   # navy
]

const OUTLINE_W: float = 3.0
const HIGHLIGHT_ALPHA: float = 0.55

static func count() -> int:
	return TABLE.size()

static func name_of(id: int) -> String:
	return String(TABLE[id]["name"])

static func color_of(id: int) -> Color:
	return TABLE[id]["color"]

static func _outline_of(col: Color) -> Color:
	return col.darkened(0.55)

static func _highlight_of(col: Color) -> Color:
	var h: Color = col.lightened(0.55)
	h.a = HIGHLIGHT_ALPHA
	return h

# Stroke a polygon outline by closing the loop and drawing a polyline.
static func _stroke_poly(node: CanvasItem, pts: PackedVector2Array, w: float, col: Color) -> void:
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	node.draw_polyline(loop, col, w, true)

# Draw a small white highlight in the upper-left of the icon's bounding box.
static func _draw_shine(node: CanvasItem, r: float) -> void:
	node.draw_circle(Vector2(-r * 0.30, -r * 0.32), r * 0.22, Color(1, 1, 1, 0.75))

# Draw icon shape `id` centered at (0,0) with a half-extent `r`. Each icon
# gets a dark outline, a saturated body, and a small white shine for the
# cartoon look.
static func draw_icon(node: CanvasItem, id: int, r: float) -> void:
	var col: Color = color_of(id)
	var dark: Color = _outline_of(col)
	var name: String = name_of(id)
	match name:
		"circle":
			node.draw_circle(Vector2.ZERO, r + 1.5, dark)
			node.draw_circle(Vector2.ZERO, r, col)
			_draw_shine(node, r)
		"square":
			var body := Rect2(-r, -r, r * 2.0, r * 2.0)
			Drawing.draw_rounded_rect(node, body.grow(2.0), 8, dark)
			Drawing.draw_rounded_rect(node, body, 8, col)
			Drawing.draw_rounded_rect(node, Rect2(-r * 0.78, -r * 0.78, r * 0.55, r * 0.20), 4, _highlight_of(col))
		"triangle":
			var tri := PackedVector2Array([
				Vector2(0, -r),
				Vector2(-r * 0.95, r * 0.78),
				Vector2(r * 0.95, r * 0.78),
			])
			node.draw_colored_polygon(tri, col)
			_stroke_poly(node, tri, OUTLINE_W, dark)
			_draw_shine(node, r)
		"diamond":
			var dm := PackedVector2Array([
				Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0),
			])
			node.draw_colored_polygon(dm, col)
			_stroke_poly(node, dm, OUTLINE_W, dark)
			_draw_shine(node, r * 0.85)
		"star":
			var st: PackedVector2Array = _star_points(r, 5, 0.46)
			node.draw_colored_polygon(st, col)
			_stroke_poly(node, st, OUTLINE_W, dark)
			_draw_shine(node, r * 0.7)
		"hexagon":
			var hx: PackedVector2Array = _regular_polygon(r, 6, -PI / 2.0)
			node.draw_colored_polygon(hx, col)
			_stroke_poly(node, hx, OUTLINE_W, dark)
			_draw_shine(node, r * 0.8)
		"heart":
			var ht: PackedVector2Array = _heart_points(r)
			node.draw_colored_polygon(ht, col)
			_stroke_poly(node, ht, OUTLINE_W, dark)
			# Heart shine sits on the right lobe.
			node.draw_circle(Vector2(-r * 0.32, -r * 0.12), r * 0.20, Color(1, 1, 1, 0.75))
		"plus":
			var t: float = r * 0.40
			# Outline: slightly larger plus drawn in dark colour.
			node.draw_rect(Rect2(-r - 2, -t - 2, (r + 2) * 2.0, (t + 2) * 2.0), dark)
			node.draw_rect(Rect2(-t - 2, -r - 2, (t + 2) * 2.0, (r + 2) * 2.0), dark)
			node.draw_rect(Rect2(-r, -t, r * 2.0, t * 2.0), col)
			node.draw_rect(Rect2(-t, -r, t * 2.0, r * 2.0), col)
			_draw_shine(node, r * 0.7)
		"crescent":
			# A crescent moon: full disc minus an offset disc cut.
			node.draw_circle(Vector2.ZERO, r + 1.5, dark)
			node.draw_circle(Vector2.ZERO, r, col)
			# "Cut" by drawing the tile body colour over the right side.
			node.draw_circle(Vector2(r * 0.32, -r * 0.12), r * 0.86, Color(1.0, 0.99, 0.94))
			_draw_shine(node, r * 0.6)
		"ring":
			node.draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, dark, r * 0.42)
			node.draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, col, r * 0.32)
			node.draw_arc(Vector2(-r * 0.30, -r * 0.32), r * 0.82, PI * 0.85, PI * 1.55, 16, Color(1, 1, 1, 0.6), r * 0.10)
		"pentagon":
			var pn: PackedVector2Array = _regular_polygon(r, 5, -PI / 2.0)
			node.draw_colored_polygon(pn, col)
			_stroke_poly(node, pn, OUTLINE_W, dark)
			_draw_shine(node, r * 0.7)
		"bolt":
			var bolt := PackedVector2Array([
				Vector2(-r * 0.15, -r),
				Vector2(r * 0.55, -r * 0.20),
				Vector2(r * 0.10, -r * 0.05),
				Vector2(r * 0.45, r),
				Vector2(-r * 0.45, r * 0.05),
				Vector2(0.0, 0.0),
				Vector2(-r * 0.55, r * 0.05),
			])
			node.draw_colored_polygon(bolt, col)
			_stroke_poly(node, bolt, OUTLINE_W, dark)
			node.draw_circle(Vector2(-r * 0.05, -r * 0.55), r * 0.16, Color(1, 1, 1, 0.7))

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
