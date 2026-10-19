# scripts/core/match_result.gd
class_name MatchResult
extends RefCounted

enum Metric { SCORE, MOVES, MATCHES, SQUARES, CROSSES, REVERSE_CROSSES, LINES, WIN }

var mode: StringName = &"free"
var level_id: StringName = &""
var bot_difficulty: int = -1
var local_score: int = 0
var local_player_won: bool = false
var moves: int = 0
var pattern_counts: Dictionary = {}   # &"square", &"cross", &"reverse_cross", &"line" -> int (только локальный игрок)

func get_metric(metric: Metric) -> int:
	match metric:
		Metric.SCORE: return local_score
		Metric.MOVES: return moves
		Metric.MATCHES: return 1
		Metric.SQUARES: return pattern_counts.get(&"square", 0)
		Metric.CROSSES: return pattern_counts.get(&"cross", 0)
		Metric.REVERSE_CROSSES: return pattern_counts.get(&"reverse_cross", 0)
		Metric.LINES: return pattern_counts.get(&"line", 0)
		Metric.WIN: return 1 if local_player_won else 0
	return 0
