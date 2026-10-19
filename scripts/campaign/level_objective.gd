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
	
