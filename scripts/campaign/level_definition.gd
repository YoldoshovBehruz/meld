# scripts/campaign/level_definition.gd
class_name LevelDefinition
extends Resource

@export var id: StringName
@export var title: String = ""
@export var order: int = 0
@export var board_size: int = 10
@export var max_moves: int = 0
@export var bot_difficulty: int = -1
@export var required: Array[LevelObjective] = []   # все обязательны → 1 звезда
@export var bonus: Array[LevelObjective] = []      # до 2 штук → +1 звезда каждая

func to_config() -> MatchConfig:
	var c := MatchConfig.new()
	c.mode = &"campaign"
	c.level_id = id
	c.board_size = board_size
	c.max_moves = max_moves
	c.bot_difficulty = bot_difficulty
	return c

func evaluate(result: MatchResult) -> int:
	for obj in required:
		if not obj.check(result):
			return 0
	var stars := 1
	for obj in bonus:
		if obj.check(result):
			stars += 1
	return mini(stars, 3)
