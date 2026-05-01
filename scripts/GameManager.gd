extends Node2D

const POWERUP_CHARGES_PER_LEVEL: int = 3
const MATCH_FLASH := preload("res://scripts/MatchFlash.gd")

@export var levels_path: String = "res://data/levels/"
@export var start_level: int = 1
@export var max_level: int = 30

@onready var board: Board = $Board
@onready var tray: Tray = $Tray
@onready var tray_frame: Node2D = $TrayFrame
@onready var ui: CanvasLayer = $UI
@onready var level_label: Label = $UI/HeaderCard/LevelLabel
@onready var progress_label: Label = $UI/HeaderCard/ProgressLabel
@onready var win_panel: Panel = $UI/WinPanel
@onready var win_label: Label = $UI/WinPanel/WinLabel
@onready var lose_panel: Panel = $UI/LosePanel
@onready var lose_label: Label = $UI/LosePanel/LoseLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var reset_button: Button = $UI/ResetButton
@onready var undo_button: Button = $UI/PowerupBar/UndoButton
@onready var remove3_button: Button = $UI/PowerupBar/Remove3Button
@onready var shuffle_button: Button = $UI/PowerupBar/ShuffleButton

enum GameState { IDLE, BUSY, WON, LOST }

var current_level: int = 1
var state: int = GameState.IDLE
var move_stack: Array[Tile] = []  # Tiles in tray, in arrival order (most recent last).
var undo_left: int = 0
var remove3_left: int = 0
var shuffle_left: int = 0

func _ready() -> void:
	current_level = start_level
	board.tile_tapped.connect(_on_tile_tapped)
	reset_button.pressed.connect(_on_reset_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	remove3_button.pressed.connect(_on_remove3_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	# Place tray and board so they don't overlap.
	tray.origin = Vector2((1080.0 - tray.tray_width()) * 0.5, 250.0)
	tray_frame.setup(tray.origin, Tray.SLOTS, Tray.SLOT_SIZE, Tray.SLOT_GAP)
	load_level(current_level)

func load_level(n: int) -> void:
	state = GameState.BUSY
	move_stack.clear()
	undo_left = POWERUP_CHARGES_PER_LEVEL
	remove3_left = POWERUP_CHARGES_PER_LEVEL
	shuffle_left = POWERUP_CHARGES_PER_LEVEL
	# Clear any leftover tray tiles from prior level.
	for t in tray.tiles:
		t.queue_free()
	tray.tiles.clear()
	win_panel.visible = false
	lose_panel.visible = false
	hint_label.visible = false
	reset_button.visible = true
	var path: String = "%slevel_%02d.json" % [levels_path, n]
	if not FileAccess.file_exists(path):
		level_label.text = "All levels complete"
		hint_label.text = "Tap to restart from level 1"
		hint_label.visible = true
		state = GameState.WON
		board.input_locked = true
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if data == null or not (data is Dictionary):
		level_label.text = "Bad level JSON"
		state = GameState.LOST
		return
	level_label.text = "Level %d" % n
	board.load_tiles(data["tiles"])
	_update_progress()
	_update_powerup_labels()
	board.input_locked = false
	state = GameState.IDLE

func _update_progress() -> void:
	progress_label.text = "Tiles left: %d" % board.remaining_count()

func _update_powerup_labels() -> void:
	undo_button.text = "Undo (%d)" % undo_left
	remove3_button.text = "Clear 3 (%d)" % remove3_left
	shuffle_button.text = "Shuffle (%d)" % shuffle_left
	undo_button.disabled = undo_left <= 0 or move_stack.is_empty()
	remove3_button.disabled = remove3_left <= 0 or tray.size() < 3
	shuffle_button.disabled = shuffle_left <= 0 or board.remaining_count() == 0

func _on_tile_tapped(t: Tile) -> void:
	if state != GameState.IDLE:
		return
	if tray.is_full():
		return
	state = GameState.BUSY
	board.input_locked = true
	move_stack.append(t)
	# Quick scale-punch on tap before the fly-to-tray.
	var punch: Tween = create_tween()
	punch.tween_property(t, "scale", Vector2(1.18, 1.18), 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch.tween_property(t, "scale", Vector2(1.0, 1.0), 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await punch.finished
	await tray.add_tile(t).finished
	# Resolve any triples (loops in the rare case clearing a triple exposes
	# another, though normally this only fires once per tap).
	while true:
		var match_info: Dictionary = tray.resolve_matches()
		if match_info.is_empty():
			break
		# Starburst at the centroid of the 3 cleared tiles.
		var sum := Vector2.ZERO
		for r in match_info["tiles"]:
			sum += r.position
		_spawn_flash(sum / float(match_info["tiles"].size()))
		await match_info["tween"].finished
		for r in match_info["tiles"]:
			move_stack.erase(r)
			board.tiles.erase(r)
			r.queue_free()
	board.recompute_blocking()
	_update_progress()
	_update_powerup_labels()
	if board.remaining_count() == 0 and tray.is_empty():
		_win()
		return
	if tray.is_full():
		_lose()
		return
	state = GameState.IDLE
	board.input_locked = false

func _spawn_flash(pos: Vector2) -> void:
	var flash: Node2D = MATCH_FLASH.new()
	flash.position = pos
	add_child(flash)

func _win() -> void:
	state = GameState.WON
	board.input_locked = true
	win_label.text = "Level %d complete\nTap to continue" % current_level
	win_panel.visible = true
	reset_button.visible = false

func _lose() -> void:
	state = GameState.LOST
	board.input_locked = true
	lose_label.text = "Tray full\nTap to retry"
	lose_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	if state == GameState.WON:
		current_level += 1
		if current_level > max_level:
			current_level = 1
		load_level(current_level)
		get_viewport().set_input_as_handled()
	elif state == GameState.LOST:
		load_level(current_level)
		get_viewport().set_input_as_handled()

func _on_reset_pressed() -> void:
	load_level(current_level)

func _on_undo_pressed() -> void:
	if state != GameState.IDLE or undo_left <= 0 or move_stack.is_empty():
		return
	state = GameState.BUSY
	board.input_locked = true
	undo_left -= 1
	var t: Tile = move_stack.pop_back()
	t.in_tray = false
	var slide: Tween = tray.remove_tile(t)
	var fly: Tween = create_tween()
	fly.tween_property(t, "position", t.board_position, 0.26)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await fly.finished
	if slide.is_valid():
		await slide.finished
	board.recompute_blocking()
	_update_progress()
	_update_powerup_labels()
	state = GameState.IDLE
	board.input_locked = false

func _on_remove3_pressed() -> void:
	if state != GameState.IDLE or remove3_left <= 0 or tray.size() < 3:
		return
	state = GameState.BUSY
	board.input_locked = true
	remove3_left -= 1
	# Step 1: pick the 3 leftmost tray tiles.
	var tray_kill: Array[Tile] = []
	for i in 3:
		tray_kill.append(tray.tiles[i])
	# Step 2: for each icon among those 3, kill enough additional tiles
	# (board first, then leftover tray) so the icon's total remaining count
	# stays a multiple of 3 — otherwise the level becomes unsolvable.
	var killed_by_icon: Dictionary = {}
	for t in tray_kill:
		killed_by_icon[t.icon_id] = int(killed_by_icon.get(t.icon_id, 0)) + 1
	var extra_kill: Array[Tile] = []
	for icon_id in killed_by_icon.keys():
		var remaining: int = 0
		for t in board.tiles:
			if t.icon_id == int(icon_id) and not (t in tray_kill):
				remaining += 1
		var need: int = remaining % 3
		if need == 0:
			continue
		# Prefer board (not in tray) so the visible board cleans up.
		var found: int = 0
		for t in board.tiles:
			if found >= need:
				break
			if t.icon_id == int(icon_id) and not t.in_tray and not (t in tray_kill) and not (t in extra_kill):
				extra_kill.append(t)
				found += 1
		# Fallback to tray tiles outside the leftmost-3 cut.
		if found < need:
			for t in tray.tiles:
				if found >= need:
					break
				if t.icon_id == int(icon_id) and not (t in tray_kill) and not (t in extra_kill):
					extra_kill.append(t)
					found += 1
	var all_kill: Array[Tile] = []
	for t in tray_kill:
		all_kill.append(t)
	for t in extra_kill:
		all_kill.append(t)
	# Step 3: drop refs from every collection.
	for t in all_kill:
		tray.tiles.erase(t)
		move_stack.erase(t)
		board.tiles.erase(t)
	# Step 4: animate everything fading + scaling out, slide tray.
	var tw: Tween = create_tween().set_parallel(true)
	for t in all_kill:
		tw.tween_property(t, "scale", Vector2(0.2, 0.2), 0.28)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "modulate:a", 0.0, 0.28)
	for i in tray.tiles.size():
		tw.tween_property(tray.tiles[i], "position", tray.slot_position(i), 0.20)
	await tw.finished
	for t in all_kill:
		t.queue_free()
	board.recompute_blocking()
	_update_progress()
	_update_powerup_labels()
	if board.remaining_count() == 0 and tray.is_empty():
		_win()
		return
	state = GameState.IDLE
	board.input_locked = false

func _on_shuffle_pressed() -> void:
	if state != GameState.IDLE or shuffle_left <= 0:
		return
	var board_tiles: Array[Tile] = []
	for t in board.tiles:
		if not t.in_tray:
			board_tiles.append(t)
	if board_tiles.is_empty():
		return
	state = GameState.BUSY
	board.input_locked = true
	shuffle_left -= 1
	var ids: Array[int] = []
	for t in board_tiles:
		ids.append(t.icon_id)
	ids.shuffle()
	for i in board_tiles.size():
		board_tiles[i].icon_id = ids[i]
		board_tiles[i].queue_redraw()
	# Brief flash so the player notices the change.
	var tw: Tween = create_tween()
	tw.tween_property(board, "modulate", Color(1.4, 1.4, 1.4), 0.10)
	tw.tween_property(board, "modulate", Color(1, 1, 1), 0.18)
	await tw.finished
	_update_powerup_labels()
	state = GameState.IDLE
	board.input_locked = false
