extends Node2D
class_name Board

signal tile_tapped(tile)

const TILE_SCENE: PackedScene = preload("res://scenes/Tile.tscn")
const OVERLAP_INSET: float = 6.0  # pixels — tiles must overlap by more than this to count as covering

var tiles: Array[Tile] = []
var input_locked: bool = false

func clear_board() -> void:
	for t in tiles:
		t.queue_free()
	tiles.clear()

# tile_data: Array of {icon: int, x: float, y: float, layer: int}
func load_tiles(tile_data: Array) -> void:
	clear_board()
	for d in tile_data:
		var t: Tile = TILE_SCENE.instantiate()
		t.icon_id = int(d["icon"])
		t.layer = int(d.get("layer", 0))
		t.position = Vector2(float(d["x"]), float(d["y"]))
		t.board_position = t.position
		add_child(t)
		tiles.append(t)
	recompute_blocking()

func remaining_count() -> int:
	var n: int = 0
	for t in tiles:
		if not t.in_tray:
			n += 1
	return n

func remove_tile(t: Tile) -> void:
	tiles.erase(t)
	t.queue_free()

# A tile is blocked if any other tile on a strictly higher layer overlaps its
# AABB (with a small inset to avoid spurious edge contacts).
func recompute_blocking() -> void:
	for t in tiles:
		if t.in_tray:
			continue
		t.set_blocked(_is_blocked(t))

func _is_blocked(t: Tile) -> bool:
	var b1: Rect2 = t.bounds().grow(-OVERLAP_INSET)
	for o in tiles:
		if o == t or o.in_tray:
			continue
		if o.layer <= t.layer:
			continue
		if b1.intersects(o.bounds()):
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	var pos: Vector2 = Vector2.INF
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		pos = event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = event.position
	else:
		return
	# Find topmost unblocked tile under the touch.
	var hit: Tile = null
	for t in tiles:
		if t.in_tray or t.blocked:
			continue
		if t.contains_point(pos):
			if hit == null or t.layer > hit.layer:
				hit = t
	if hit != null:
		emit_signal("tile_tapped", hit)
