extends Node2D

const FRAME_FILL: Color = Color(0.30, 0.34, 0.44)
const FRAME_OUTLINE: Color = Color(0.18, 0.20, 0.26)
const SLOT_FILL: Color = Color(0.22, 0.24, 0.32)
const SLOT_RIM: Color = Color(0.42, 0.46, 0.56)

var origin: Vector2 = Vector2.ZERO
var slot_count: int = 7
var slot_size: float = 130.0
var slot_gap: float = 6.0

func setup(orig: Vector2, count: int, size: float, gap: float) -> void:
	origin = orig
	slot_count = count
	slot_size = size
	slot_gap = gap
	queue_redraw()

func _draw() -> void:
	if slot_count <= 0:
		return
	var w: float = (slot_size + slot_gap) * float(slot_count) - slot_gap
	var pad: float = 14.0
	var frame_rect := Rect2(origin.x - pad, origin.y - pad, w + pad * 2.0, slot_size + pad * 2.0)
	# Drop shadow.
	Drawing.draw_rounded_rect(self, Rect2(frame_rect.position + Vector2(0, 6), frame_rect.size), 30, Color(0, 0, 0, 0.25))
	# Frame body.
	Drawing.draw_rounded_rect(self, frame_rect, 30, FRAME_FILL)
	# Frame outline.
	Drawing.stroke_rounded_rect(self, frame_rect, 30, 4, FRAME_OUTLINE)
	# Inner slots.
	for i in slot_count:
		var cx: float = origin.x + (slot_size + slot_gap) * (float(i) + 0.5)
		var cy: float = origin.y + slot_size * 0.5
		var slot := Rect2(cx - slot_size * 0.5 + 4.0, cy - slot_size * 0.5 + 4.0, slot_size - 8.0, slot_size - 8.0)
		Drawing.draw_rounded_rect(self, slot, 18, SLOT_FILL)
		Drawing.stroke_rounded_rect(self, slot, 18, 2, SLOT_RIM)
