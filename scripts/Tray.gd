extends Node2D
class_name Tray

const SLOTS: int = 7
const SLOT_SIZE: float = Tile.TILE_SIZE
const SLOT_GAP: float = 6.0
const SLIDE_TIME: float = 0.18
const FLY_TIME: float = 0.26
const CLEAR_TIME: float = 0.22

var tiles: Array[Tile] = []  # Tiles currently in the tray, in tray order.
var origin: Vector2 = Vector2.ZERO  # Top-left of slot 0.

func slot_position(i: int) -> Vector2:
	var x: float = origin.x + (SLOT_SIZE + SLOT_GAP) * (float(i) + 0.5)
	var y: float = origin.y + SLOT_SIZE * 0.5
	return Vector2(x, y)

func tray_width() -> float:
	return (SLOT_SIZE + SLOT_GAP) * float(SLOTS) - SLOT_GAP

# Send a tile into the next available tray slot. Sorts the tray by icon_id
# so groups of three end up adjacent. Returns the parallel Tween animating
# the fly-in and slot reflow so the caller can await it.
func add_tile(t: Tile) -> Tween:
	t.in_tray = true
	var insert_at: int = tiles.size()
	for i in tiles.size():
		if tiles[i].icon_id > t.icon_id:
			insert_at = i
			break
	tiles.insert(insert_at, t)
	var tw: Tween = create_tween().set_parallel(true)
	for i in tiles.size():
		var target: Vector2 = slot_position(i)
		if tiles[i] == t:
			tw.tween_property(t, "position", target, FLY_TIME)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(tiles[i], "position", target, SLIDE_TIME)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw

# If the tray contains a triple, returns {tiles: Array[Tile], tween: Tween}
# describing the 3 tiles that should be cleared and the animation tween. The
# tiles are already removed from the tray's list, but the caller owns
# queue_free responsibility (so parent collections can also drop the refs).
# Returns null when no triple exists.
func resolve_matches() -> Dictionary:
	var counts: Dictionary = {}
	for t in tiles:
		counts[t.icon_id] = int(counts.get(t.icon_id, 0)) + 1
	var match_icon: int = -1
	for k in counts.keys():
		if int(counts[k]) >= 3:
			match_icon = int(k)
			break
	if match_icon < 0:
		return {}
	var to_remove: Array[Tile] = []
	for t in tiles:
		if t.icon_id == match_icon and to_remove.size() < 3:
			to_remove.append(t)
	for t in to_remove:
		tiles.erase(t)
	var tw: Tween = create_tween().set_parallel(true)
	for t in to_remove:
		tw.tween_property(t, "scale", Vector2(0.2, 0.2), CLEAR_TIME)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "modulate:a", 0.0, CLEAR_TIME)
	for i in tiles.size():
		tw.tween_property(tiles[i], "position", slot_position(i), SLIDE_TIME)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return {"tiles": to_remove, "tween": tw}

# Remove a specific tile from the tray (without queue_freeing it) and reflow
# the remaining slots. Used by Undo and Remove-3. Returns the slide tween.
func remove_tile(t: Tile) -> Tween:
	tiles.erase(t)
	var tw: Tween = create_tween().set_parallel(true)
	for i in tiles.size():
		tw.tween_property(tiles[i], "position", slot_position(i), SLIDE_TIME)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw

func is_full() -> bool:
	return tiles.size() >= SLOTS

func is_empty() -> bool:
	return tiles.is_empty()

func size() -> int:
	return tiles.size()
