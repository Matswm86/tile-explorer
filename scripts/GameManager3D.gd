extends Node3D

# Game flow for the 3D presentation. The rules, level format, power-up
# semantics and win/lose conditions are ported unchanged from the shipped
# 2D version — only the rendering and animation layer is new.

const POWERUP_CHARGES_PER_LEVEL: int = 3

@export var levels_path: String = "res://data/levels/"
@export var start_level: int = 1
@export var max_level: int = 30

@onready var board: Board3D = $Board
@onready var tray: Tray3D = $Tray
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
var state: int = GameState.BUSY
var move_stack: Array[Tile3D] = []  # tray tiles in arrival order (recent last)
var undo_left: int = 0
var remove3_left: int = 0
var shuffle_left: int = 0


func _ready() -> void:
	# Camera + sun orientation set here (matrices in .tscn are unreadable).
	var cam: Camera3D = $Camera
	# -68 pitch frames the widest level (world x +-3.7, 7-layer stacks) at
	# ndc x +-0.92 on the 1080x1920 portrait frustum; -50 clipped corners.
	cam.position = Vector3(0, 14.9, 5.5)
	cam.rotation_degrees = Vector3(-68, 0, 0)
	$Sun.rotation_degrees = Vector3(-50, -30, 0)
	current_level = start_level
	board.tile_tapped.connect(_on_tile_tapped)
	board.blocked_tapped.connect(func(t: Tile3D) -> void: t.shake())
	reset_button.pressed.connect(_on_reset_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	remove3_button.pressed.connect(_on_remove3_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	_build_table()
	_build_tray_base()
	# Bake the 12 procedural icons into textures, then install the shared
	# tile mesh + materials. Must complete before the first level loads.
	var icon_textures: Array = await IconBaker.bake_icons(self)
	Tile3D.install_shared(icon_textures)
	load_level(current_level)
	_maybe_devshot()


func load_level(n: int) -> void:
	state = GameState.BUSY
	move_stack.clear()
	undo_left = POWERUP_CHARGES_PER_LEVEL
	remove3_left = POWERUP_CHARGES_PER_LEVEL
	shuffle_left = POWERUP_CHARGES_PER_LEVEL
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


func _on_tile_tapped(t: Tile3D) -> void:
	if state != GameState.IDLE:
		return
	if tray.is_full():
		return
	state = GameState.BUSY
	board.input_locked = true
	move_stack.append(t)
	# Quick scale-punch on tap, in parallel with the flight start.
	var punch: Tween = create_tween()
	(
		punch
		. tween_property(t, "scale", Vector3(1.14, 1.14, 1.14), 0.06)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	punch.tween_property(t, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await tray.add_tile(t).finished
	# Resolve any triples (loops in the rare case a clear exposes another).
	while true:
		var match_info: Dictionary = tray.resolve_matches()
		if match_info.is_empty():
			break
		await match_info["tween"].finished
		Fx3D.match_burst(self, match_info["centroid"], Icons.color_of(int(match_info["icon"])))
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


func _win() -> void:
	state = GameState.WON
	board.input_locked = true
	win_label.text = "Level %d complete\nTap to continue" % current_level
	Fx3D.win_confetti(self, Vector3(0, 4.0, 0))
	_show_panel(win_panel)
	reset_button.visible = false


func _lose() -> void:
	state = GameState.LOST
	board.input_locked = true
	lose_label.text = "Tray full\nTap to retry"
	_show_panel(lose_panel)


func _show_panel(panel: Panel) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	panel.visible = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
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
	var t: Tile3D = move_stack.pop_back()
	t.in_tray = false
	var slide: Tween = tray.remove_tile(t)
	# Fly back to the board along a reverse arc.
	var target: Vector3 = Board3D.px_to_world(t.board_position, t.layer)
	var start: Vector3 = t.position
	var fly: Tween = create_tween()
	(
		fly
		. tween_method(
			func(s: float) -> void:
				var p: Vector3 = start.lerp(target, s)
				p.y += Tray3D.ARC_HEIGHT * 4.0 * s * (1.0 - s)
				t.position = p,
			0.0,
			1.0,
			0.30
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
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
	var tray_kill: Array[Tile3D] = []
	for i in 3:
		tray_kill.append(tray.tiles[i])
	# Step 2: for each icon among those 3, kill enough additional tiles
	# (board first, then leftover tray) so the icon's total remaining count
	# stays a multiple of 3 — otherwise the level becomes unsolvable.
	var killed_by_icon: Dictionary = {}
	for t in tray_kill:
		killed_by_icon[t.icon_id] = int(killed_by_icon.get(t.icon_id, 0)) + 1
	var extra_kill: Array[Tile3D] = []
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
			if (
				t.icon_id == int(icon_id)
				and not t.in_tray
				and not (t in tray_kill)
				and not (t in extra_kill)
			):
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
	var all_kill: Array[Tile3D] = []
	for t in tray_kill:
		all_kill.append(t)
	for t in extra_kill:
		all_kill.append(t)
	# Step 3: drop refs from every collection.
	for t in all_kill:
		tray.tiles.erase(t)
		move_stack.erase(t)
		board.tiles.erase(t)
	# Step 4: animate everything shrinking out, slide tray closed.
	var tw: Tween = create_tween().set_parallel(true)
	for t in all_kill:
		(
			tw
			. tween_property(t, "scale", Vector3(0.05, 0.05, 0.05), 0.28)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
		)
		tw.tween_property(t, "rotation:y", t.rotation.y + 2.5, 0.28)
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
	var board_tiles: Array[Tile3D] = []
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
	# Spin-flip every board tile while the icons swap at half-spin.
	var tw: Tween = create_tween().set_parallel(true)
	for i in board_tiles.size():
		var t: Tile3D = board_tiles[i]
		(
			tw
			. tween_property(t, "rotation:y", t.rotation.y + TAU, 0.40)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN_OUT)
		)
	var swap: Tween = create_tween()
	swap.tween_interval(0.20)
	swap.tween_callback(
		func() -> void:
			for i in board_tiles.size():
				board_tiles[i].icon_id = ids[i]
	)
	await tw.finished
	_update_powerup_labels()
	state = GameState.IDLE
	board.input_locked = false


# --- static scene dressing (table + tray base), built in code -------------


func _build_table() -> void:
	var table := MeshInstance3D.new()
	table.mesh = RoundedBox.build(Vector3(16.0, 0.5, 14.0), 0.18, 6)
	table.position = Vector3(0, -0.25, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.45, 0.42)
	mat.roughness = 0.95
	table.material_override = mat
	add_child(table)


func _build_tray_base() -> void:
	var base := MeshInstance3D.new()
	base.mesh = RoundedBox.build(Vector3(7.15, 0.28, 1.24), 0.13, 6)
	base.position = Vector3(0, 0.0, Tray3D.TRAY_Z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.40, 0.30)
	mat.roughness = 0.85
	base.material_override = mat
	add_child(base)
	# 7 slot markers on the shelf top.
	var slot_tex: ImageTexture = await IconBaker.bake_slot(self)
	var slot_mat := StandardMaterial3D.new()
	slot_mat.albedo_texture = slot_tex
	slot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in Tray3D.SLOTS:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.84, 0.84)
		q.mesh = quad
		q.material_override = slot_mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p: Vector3 = tray.slot_position(i)
		q.position = Vector3(p.x, 0.146, p.z)
		q.rotation_degrees = Vector3(-90, 0, 0)
		add_child(q)


# --- dev harness: TILE_DEVSHOT=/path.png [TILE_DEVTAPS=N] ------------------
# Runs only when the env var is set. Optionally simulates N taps through the
# real picking path, asserts the board shrank when a triple was tapped, saves
# a screenshot and exits. Used for local visual iteration; inert in release.


func _maybe_devshot() -> void:
	var shot_path: String = OS.get_environment("TILE_DEVSHOT")
	if shot_path == "":
		return
	var dev_level: int = int(OS.get_environment("TILE_DEVLEVEL"))
	if dev_level > 0:
		load_level(dev_level)
		current_level = dev_level
	var taps: int = int(OS.get_environment("TILE_DEVTAPS"))
	await get_tree().create_timer(0.8).timeout
	var mode: String = OS.get_environment("TILE_DEVMODE")
	if mode == "power":
		await _devshot_power()
	elif mode == "lose":
		await _devshot_lose()
	var before: int = board.remaining_count()
	var tapped: int = 0
	for i in taps:
		var target: Tile3D = _devshot_pick_target()
		if target == null:
			break
		var screen: Vector2 = board.camera.unproject_position(target.global_position)
		var hit: Tile3D = board.pick_tile(screen)
		if hit == null or hit.blocked:
			print("DEVSHOT: pick mismatch at tap %d" % i)
			break
		_on_tile_tapped(hit)
		tapped += 1
		while state == GameState.BUSY:
			await get_tree().process_frame
		if state != GameState.IDLE:
			break
	await get_tree().create_timer(0.5).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	if taps > 0:
		var after: int = board.remaining_count()
		var ok: bool = tapped >= 3 and after <= before - 3 and tray.size() <= 1
		print(
			(
				"DEVSHOT: taps=%d board %d->%d tray=%d => %s"
				% [tapped, before, after, tray.size(), "PASS" if ok else "FAIL"]
			)
		)
	else:
		print("DEVSHOT: screenshot saved")
	get_tree().quit(0)


func _devshot_wait_idle() -> void:
	while state == GameState.BUSY:
		await get_tree().process_frame


# Exercise Undo, Clear 3 and Shuffle through their real handlers.
func _devshot_power() -> void:
	_on_tile_tapped(_devshot_pick_no_triple())
	await _devshot_wait_idle()
	_on_undo_pressed()
	await _devshot_wait_idle()
	var ok_undo: bool = tray.is_empty() and undo_left == 2 and move_stack.is_empty()
	print("DEVSHOT undo => %s" % ("PASS" if ok_undo else "FAIL"))
	for i in 3:
		_on_tile_tapped(_devshot_pick_no_triple())
		await _devshot_wait_idle()
	var ok_fill: bool = tray.size() == 3
	_on_remove3_pressed()
	await _devshot_wait_idle()
	var ok_r3: bool = ok_fill and tray.is_empty() and remove3_left == 2
	print("DEVSHOT clear3 => %s" % ("PASS" if ok_r3 else "FAIL"))
	_on_shuffle_pressed()
	await _devshot_wait_idle()
	print("DEVSHOT shuffle => %s" % ("PASS" if shuffle_left == 2 else "FAIL"))


# Fill the tray with pairs only (never a third copy) until it overflows.
func _devshot_lose() -> void:
	while state == GameState.IDLE:
		var t: Tile3D = _devshot_pick_no_triple()
		if t == null:
			break
		_on_tile_tapped(t)
		await _devshot_wait_idle()
	print("DEVSHOT lose => %s" % ("PASS" if state == GameState.LOST else "FAIL"))


# An unblocked board tile whose icon has at most 1 copy in the tray.
func _devshot_pick_no_triple() -> Tile3D:
	for t in board.tiles:
		if t.in_tray or t.blocked:
			continue
		var in_tray_count: int = 0
		for o in tray.tiles:
			if o.icon_id == t.icon_id:
				in_tray_count += 1
		if in_tray_count < 2:
			return t
	return null


# Prefer completing a triple: pick an icon with >=3 unblocked tiles.
func _devshot_pick_target() -> Tile3D:
	var by_icon: Dictionary = {}
	for t in board.tiles:
		if t.in_tray or t.blocked:
			continue
		if not by_icon.has(t.icon_id):
			by_icon[t.icon_id] = []
		by_icon[t.icon_id].append(t)
	# Continue an icon already started in the tray.
	for t in tray.tiles:
		if by_icon.has(t.icon_id):
			return by_icon[t.icon_id][0]
	for k in by_icon.keys():
		if by_icon[k].size() >= 3:
			return by_icon[k][0]
	for k in by_icon.keys():
		return by_icon[k][0]
	return null
