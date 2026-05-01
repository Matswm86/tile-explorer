extends Node2D

# Brief starburst that plays when a triple matches. Self-frees after animation.

const RAYS: int = 10
const INNER: float = 0.30
const OUTER: float = 1.20

var radius: float = 80.0
var ray_color: Color = Color(1.0, 0.96, 0.50, 0.95)
var ring_color: Color = Color(1.0, 1.0, 0.80, 0.85)

func _ready() -> void:
	queue_redraw()
	z_index = 100
	scale = Vector2(0.4, 0.4)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.42)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(Callable(self, "queue_free"))

func _draw() -> void:
	# Soft yellow halo.
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1, 0.98, 0.55, 0.35))
	# 10 radial rays.
	for i in RAYS:
		var a: float = TAU * float(i) / float(RAYS)
		var dir := Vector2(cos(a), sin(a))
		draw_line(dir * radius * INNER, dir * radius * OUTER, ray_color, 7.0)
	# White core.
	draw_circle(Vector2.ZERO, radius * 0.20, Color(1, 1, 1, 0.95))
	# Ring outline.
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 32, ring_color, 5.0)
