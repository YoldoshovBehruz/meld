# autoload/campaign_manager.gd
extends Node

const SAVE_PATH := "user://campaign.json"
const LEVELS_DIR := "res://data/campaign/"

signal level_progress_changed(level_id: StringName, stars: int)

var _levels: Array[LevelDefinition] = []
var _progress: Dictionary = {}   # StringName -> {"stars": int, "best_score": int}


func _ready() -> void:
	_levels = _load_levels()
	_progress = _load_progress()
	GameEvents.match_finished.connect(_on_match_finished)


func get_levels() -> Array[LevelDefinition]:
	return _levels


func get_stars(level_id: StringName) -> int:
	return int(_progress.get(level_id, {}).get("stars", 0))


func is_unlocked(index: int) -> bool:
	return index == 0 or get_stars(_levels[index - 1].id) > 0


func find_level(level_id: StringName) -> LevelDefinition:
	for level in _levels:
		if level.id == level_id:
			return level
	return null


func _on_match_finished(result: MatchResult) -> void:
	if result.mode != &"campaign":
		return

	var level := find_level(result.level_id)
	if level == null:
		return

	var stars := level.evaluate(result)
	var entry: Dictionary = _progress.get(level.id, {"stars": 0, "best_score": 0})
	entry.stars = maxi(int(entry.stars), stars)
	entry.best_score = maxi(int(entry.best_score), result.local_score)
	_progress[level.id] = entry

	_save_progress()
	level_progress_changed.emit(level.id, stars)


func _load_levels() -> Array[LevelDefinition]:
	var out: Array[LevelDefinition] = []
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		return out
	for file in DirAccess.get_files_at(LEVELS_DIR):
		var path := LEVELS_DIR + file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var level := load(path) as LevelDefinition
		if level:
			out.append(level)
	out.sort_custom(func(a, b): return a.order < b.order)
	return out


func _load_progress() -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(SAVE_PATH):
		return out
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for key in data:
			out[StringName(key)] = {
				"stars": int(data[key].get("stars", 0)),
				"best_score": int(data[key].get("best_score", 0)),
			}
	return out


func _save_progress() -> void:
	var data := {}
	for key in _progress:
		data[String(key)] = _progress[key]
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
