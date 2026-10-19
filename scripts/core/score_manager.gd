# scripts/core/score_manager.gd
class_name ScoreManager
extends RefCounted

signal score_changed(p1_score: int, p2_score: int)

var p1_score: int = 0
var p2_score: int = 0

var total_figures_created: int = 0
var max_combo: int = 0

# Счетчики для метрик кампании/дейли (аккумулируются только для локального игрока)
var pattern_counts: Dictionary = {
	&"square": 0,
	&"cross": 0,
	&"reverse_cross": 0,
	&"line": 0
}

var _scored_pattern_ids: Dictionary = {}
var _highlighted_cells: Dictionary = {}

const PATTERN_SCORES := {
	Enums.PatternType.SQUARE_2X2: 1,
	Enums.PatternType.PATTERN_X: 3,
	Enums.PatternType.REVERSE_X: 5,
	Enums.PatternType.FULL_LINE_H: 5,
	Enums.PatternType.FULL_LINE_V: 5
}

func reset() -> void:
	p1_score = 0
	p2_score = 0
	total_figures_created = 0
	max_combo = 0
	pattern_counts = {
		&"square": 0,
		&"cross": 0,
		&"reverse_cross": 0,
		&"line": 0
	}
	_scored_pattern_ids.clear()
	_highlighted_cells.clear()
	score_changed.emit(p1_score, p2_score)

func process_patterns(patterns: Array[PatternInstance], active_player: Enums.Player, is_local_player: bool = true) -> Dictionary:
	var best_pattern: PatternInstance = null
	var max_points := 0

	for pattern in patterns:
		if _scored_pattern_ids.has(pattern.unique_id):
			continue

		var pts: int = PATTERN_SCORES.get(pattern.type, 0)
		if pts > max_points:
			max_points = pts
			best_pattern = pattern

	if best_pattern == null or max_points == 0:
		return {"pattern": null, "points": 0, "new_cells": [] as Array[Vector2i]}

	_scored_pattern_ids[best_pattern.unique_id] = true
	total_figures_created += 1

	if max_points > max_combo:
		max_combo = max_points

	if active_player == Enums.Player.PLAYER_1:
		p1_score += max_points
	elif active_player == Enums.Player.PLAYER_2:
		p2_score += max_points

	score_changed.emit(p1_score, p2_score)

	# Засчитываем метрики для локального игрока
	if is_local_player:
		match best_pattern.type:
			Enums.PatternType.SQUARE_2X2:
				pattern_counts[&"square"] = pattern_counts.get(&"square", 0) + 1
			Enums.PatternType.PATTERN_X:
				pattern_counts[&"cross"] = pattern_counts.get(&"cross", 0) + 1
			Enums.PatternType.REVERSE_X:
				pattern_counts[&"reverse_cross"] = pattern_counts.get(&"reverse_cross", 0) + 1
			Enums.PatternType.FULL_LINE_H, Enums.PatternType.FULL_LINE_V:
				pattern_counts[&"line"] = pattern_counts.get(&"line", 0) + 1

	var new_highlighted_cells: Array[Vector2i] = []
	for cell in best_pattern.occupied_cells:
		if not _highlighted_cells.has(cell):
			_highlighted_cells[cell] = true
			new_highlighted_cells.append(cell)

	return {
		"pattern": best_pattern,
		"points": max_points,
		"new_cells": new_highlighted_cells
	}

func is_cell_highlighted(coord: Vector2i) -> bool:
	return _highlighted_cells.has(coord)
