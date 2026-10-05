extends Node

## Dev-only screenshot and touch bot. Boots the real game scene, sends real
## mouse events (they arrive as touches through emulate_touch_from_mouse),
## checks that tiles and buttons act on release, prints every touch area in px
## and mm, checks the top-left shell corner and the wrist strip are free,
## plays level 1 to a win through real touches and saves screenshots to
## CAPTURE_DIR. Run under Xvfb with --audio-driver Dummy. CAPTURE_SHELL=1 runs
## it as if inside MWM Play.

const CORNER: float = 232.0
const WRIST: float = 256.0

var out_dir: String = OS.get_environment("CAPTURE_DIR")
var game: Node


func _ready() -> void:
	if OS.get_environment("CAPTURE_SHELL") == "1":
		Engine.set_meta(&"mwm_play_shell", true)
	game = load("res://scenes/Game3D.tscn").instantiate()
	add_child(game)
	while game.state != game.GameState.IDLE:
		await _frames(1)
	await _frames(20)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	print("VIEWPORT %.0fx%.0f" % [vs.x, vs.y])
	await _level(1)
	await _shot("00_start_level1")
	_measure("level 1")
	await _check_tile_release()
	await _check_button_release()
	await _level(1)
	await _play_to_win()
	await _level(5)
	await _shot("04_level5")
	_measure("level 5")
	await _check_lose()
	await _level(5)
	game.fake_safe_top = 120.0
	game._layout_ui()
	await _frames(10)
	await _shot("06_inset120_level5")
	_measure("level 5, fake 120 px top cutout")
	game.fake_safe_top = -1.0
	game._layout_ui()
	await _level(30)
	await _shot("07_level30")
	_measure("level 30")
	var f := FileAccess.open(game.SAVE_PATH, FileAccess.READ)
	print("SAVE ", game.SAVE_PATH, " -> ", f.get_as_text() if f else "missing")
	get_tree().quit()


func _level(n: int) -> void:
	game.current_level = n
	game.load_level(n)
	await _frames(15)


func _check_tile_release() -> void:
	var t: Node3D = _free_tile()
	var p: Vector2 = _screen(t)
	await _press(p, true)
	var after_down: int = game.tray.size()
	await _press(p, false)
	await _wait_idle()
	print("TILE fires on down: ", after_down > 0, ", after release: ", game.tray.size() == 1)
	t = _free_tile()
	p = _screen(t)
	await _press(p, true)
	await _press(Vector2(p.x, 300), false)
	await _wait_idle()
	print("TILE slide-off release fires: ", game.tray.size() != 1)
	# Touch 90 px beside a lone free tile, off its drawing: snaps to it.
	t = _lonely_free_tile()
	var c: Vector2 = _screen(t)
	p = c
	for k in 8:
		var q: Vector2 = c + Vector2.from_angle(TAU * k / 8.0) * 90.0
		if game.board.pick_tile(q) == null:
			p = q
			break
	var direct: Variant = game.board.pick_tile(p)
	await _press(p, true)
	await _press(p, false)
	await _wait_idle()
	print(
		(
			"TILE snap %.0f px off centre: ray hit=%s picked=%s"
			% [p.distance_to(c), direct != null, t.in_tray]
		)
	)


func _check_button_release() -> void:
	var b: Control = game.undo_button
	var before: int = game.undo_left
	var r: Rect2 = b.get_global_rect()
	await _press(r.get_center(), true)
	await _shot("01_undo_held")
	var after_down: int = game.undo_left
	await _press(r.get_center(), false)
	await _wait_idle()
	print(
		(
			"UNDO fires on down: %s, after release: %s"
			% [after_down != before, game.undo_left == before - 1]
		)
	)
	# Press near the edge of the touch area, outside the drawn disc.
	r = game.reset_button.get_global_rect()
	var edge := Vector2(r.end.x - 4, r.position.y + 4)
	await _press(edge, true)
	await _press(edge, false)
	await _wait_idle()
	print("RESET at corner edge resets: ", game.undo_left == 3 and game.tray.size() == 0)


func _play_to_win() -> void:
	var taps: int = 0
	while game.state == game.GameState.IDLE and taps < 60:
		var t: Node3D = _pick_target()
		if t == null:
			break
		var p: Vector2 = _screen(t)
		await _press(p, true)
		await _press(p, false)
		await _wait_idle()
		taps += 1
		if taps == 4:
			await _shot("02_level1_playing")
	print("PLAY level 1: taps=%d state=%s" % [taps, game.state])
	await _frames(40)
	await _shot("03_win")
	# A palm in the wrist strip and a tap in the home corner do not continue.
	var vs: Vector2 = get_viewport().get_visible_rect().size
	for p in [Vector2(540, vs.y - 40), Vector2(100, 100)]:
		await _press(p, true)
		await _press(p, false)
	await _frames(5)
	print("WIN ignores strip and corner taps: ", game.state == game.GameState.WON)
	await _press(vs * 0.5, true)
	var held: bool = game.state == game.GameState.WON
	await _press(vs * 0.5, false)
	await _frames(10)
	print("WIN waits for release: %s, next level: %d" % [held, game.current_level])


func _check_lose() -> void:
	while game.state == game.GameState.IDLE:
		var t: Node3D = game._devshot_pick_no_triple()
		if t == null:
			break
		var p: Vector2 = _screen(t)
		await _press(p, true)
		await _press(p, false)
		await _wait_idle()
	await _frames(30)
	print("LOSE reached: ", game.state == game.GameState.LOST)
	await _shot("05_lose")


func _measure(label: String) -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var corner := Rect2(0, 0, CORNER, CORNER)
	var strip_y: float = vs.y - WRIST
	print("== touch areas, ", label)
	var bad: int = 0
	for b in [game.reset_button, game.undo_button, game.remove3_button, game.shuffle_button]:
		var r: Rect2 = b.get_global_rect()
		var flags: String = ""
		if b.visible and r.intersects(corner):
			flags += " IN-CORNER"
		if b.visible and r.end.y > strip_y:
			flags += " IN-STRIP"
		bad += 1 if flags != "" else 0
		print("HIT %s visible=%s %s%s" % [b.kind, b.visible, _mm(r), flags])
	for c in game.ui.get_children():
		if c is Control and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var r: Rect2 = c.get_global_rect()
			if r.intersects(corner) or r.end.y > strip_y:
				print("CONTROL %s takes mouse in a free zone %s" % [c.name, _mm(r)])
				bad += 1
	# Tiles: drawn width on screen and the snap circle around each free tile.
	var cam: Camera3D = game.board.camera
	var min_w: float = INF
	var max_w: float = 0.0
	var top: float = INF
	var low: float = 0.0
	var left: float = INF
	for t in game.board.tiles:
		if t.in_tray:
			continue
		var a: Vector2 = cam.unproject_position(t.global_position - Vector3(0.47, 0, 0))
		var b2: Vector2 = cam.unproject_position(t.global_position + Vector3(0.47, 0, 0))
		var w: float = a.distance_to(b2)
		min_w = minf(min_w, w)
		max_w = maxf(max_w, w)
		var s: Vector2 = _screen(t)
		var reach: float = game.board.SNAP_RADIUS_PX if not t.blocked else w * 0.5
		top = minf(top, s.y - reach)
		low = maxf(low, s.y + reach)
		left = minf(left, s.x - reach)
	print(
		(
			"TILES drawn %.0f-%.0f px wide (%.1f-%.1f mm@400); touch reach y %.0f-%.0f, x from %.0f"
			% [min_w, max_w, min_w * 25.4 / 400.0, max_w * 25.4 / 400.0, top, low, left]
		)
	)
	if low > strip_y or (top < CORNER and left < CORNER):
		bad += 1
	var tray_y: float = cam.unproject_position(Vector3(0, 0.3, 4.02)).y
	print("TRAY rack front edge y %.0f (strip starts y %.0f)" % [tray_y, strip_y])
	print("ZONES %s (%d problems)" % ["PASS" if bad == 0 else "FAIL", bad])


func _mm(r: Rect2) -> String:
	return (
		"(%.0f,%.0f) %.0fx%.0f px = %.1fx%.1f mm@400, %.1fx%.1f mm@430, bottom y %.0f"
		% [
			r.position.x,
			r.position.y,
			r.size.x,
			r.size.y,
			r.size.x * 25.4 / 400.0,
			r.size.y * 25.4 / 400.0,
			r.size.x * 25.4 / 430.0,
			r.size.y * 25.4 / 430.0,
			r.end.y
		]
	)


func _screen(t: Node3D) -> Vector2:
	return game.board.camera.unproject_position(t.global_position)


func _free_tile() -> Node3D:
	for t in game.board.tiles:
		if not t.in_tray and not t.blocked:
			return t
	return null


## Prefer the icon already in the tray, then an icon with 3 free tiles.
func _pick_target() -> Node3D:
	return game._devshot_pick_target()


## The free tile with the most room around it on screen.
func _lonely_free_tile() -> Node3D:
	var best: Node3D = null
	var best_gap: float = -1.0
	for t in game.board.tiles:
		if t.in_tray or t.blocked:
			continue
		var p: Vector2 = _screen(t)
		var gap: float = INF
		for o in game.board.tiles:
			if o != t and not o.in_tray:
				gap = minf(gap, _screen(o).distance_to(p))
		if gap > best_gap:
			best_gap = gap
			best = t
	return best


func _wait_idle() -> void:
	await _frames(3)
	while game.state == game.GameState.BUSY:
		await _frames(1)
	await _frames(3)


func _press(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)
	await _frames(3)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("SHOT ", name)
