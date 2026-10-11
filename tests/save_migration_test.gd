extends SceneTree

# Headless check of the save rename (Tile Explorer -> MWM Brikkejakt).
# Run: godot --headless --audio-driver Dummy -s res://tests/save_migration_test.gd
# Existing save files in user:// are moved aside and restored afterwards.

const GM := preload("res://scripts/GameManager3D.gd")

var _fails: int = 0


func _init() -> void:
	var new_path: String = GM.SAVE_PATH
	var old_path: String = GM.LEGACY_SAVE_PATH
	_stash(new_path)
	_stash(old_path)

	# 1. Only the old file: progress kept and copied to the new file.
	_write(old_path, '{"version": 1, "current_level": 7, "highest_level": 9}')
	var gm: Node = _fresh_load()
	_check("old file -> level kept", gm.current_level == 7 and gm.highest_level == 9)
	_check("old file -> new file written", FileAccess.file_exists(new_path))
	_check("old file -> old file left in place", FileAccess.file_exists(old_path))
	var copied: Variant = JSON.parse_string(FileAccess.get_file_as_string(new_path))
	_check("new file holds level 7", copied is Dictionary and int(copied["current_level"]) == 7)
	gm.free()

	# 2. New file wins over the old one.
	_write(old_path, '{"version": 1, "current_level": 3, "highest_level": 3}')
	gm = _fresh_load()
	_check("new file preferred over old", gm.current_level == 7)
	gm.free()
	_clear(new_path)
	_clear(old_path)

	# 3. Corrupt old file: fresh start, nothing written.
	_write(old_path, "{not json")
	gm = _fresh_load()
	_check("corrupt old -> fresh start", gm.current_level == 1)
	_check("corrupt old -> no new file", not FileAccess.file_exists(new_path))
	gm.free()
	_clear(old_path)

	# 4. No files at all: fresh start.
	gm = _fresh_load()
	_check("no files -> fresh start", gm.current_level == 1)
	_check("no files -> no new file", not FileAccess.file_exists(new_path))
	gm.free()

	_restore(new_path)
	_restore(old_path)
	print("SAVE MIGRATION %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _fresh_load() -> Node:
	var gm: Node = GM.new()
	gm.current_level = 1
	gm.highest_level = 1
	gm._load_progress()
	return gm


func _check(label: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clear(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _stash(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(path, path + ".testbak")


func _restore(path: String) -> void:
	_clear(path)
	if FileAccess.file_exists(path + ".testbak"):
		DirAccess.rename_absolute(path + ".testbak", path)
