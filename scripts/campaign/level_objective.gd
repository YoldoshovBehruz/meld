# scripts/campaign/level_objective.gd
class_name LevelObjective
extends Resource

enum Op { AT_LEAST, AT_MOST }

@export var metric: MatchResult.Metric = MatchResult.Metric.SCORE
@export var op: Op = Op.AT_LEAST
@export var target: int = 1


func check(result: MatchResult) -> bool:
	var value := result.get_metric(metric)
	return value >= target if op == Op.AT_LEAST else value <= target


func current_value(result: MatchResult) -> int:
	return result.get_metric(metric)


func describe() -> String:
	if metric == MatchResult.Metric.WIN:
		return "Победа"
	var sign := "≥" if op == Op.AT_LEAST else "≤"
	return "%s %s %d" % [metric_name(metric), sign, target]


static func metric_name(m: MatchResult.Metric) -> String:
	match m:
		MatchResult.Metric.SCORE: return "Очки"
		MatchResult.Metric.MOVES: return "Ходы"
		MatchResult.Metric.MATCHES: return "Партии"
		MatchResult.Metric.SQUARES: return "Квадраты 2×2"
		MatchResult.Metric.CROSSES: return "X"
		MatchResult.Metric.REVERSE_CROSSES: return "Обратные X"
		MatchResult.Metric.LINES: return "Линии"
	return "Победа"
