class_name MediumBot
extends RefCounted

const PATTERN_SCORES := {
	Enums.PatternType.SQUARE_2X2: 1,
	Enums.PatternType.PATTERN_X: 3,
	Enums.PatternType.REVERSE_X: 5,
	Enums.PatternType.FULL_LINE_H: 5,
	Enums.PatternType.FULL_LINE_V: 5
}

func make_move(board_data: BoardData, pattern_detector: PatternDetector, bot_player: Enums.Player) -> Vector2i:
	var human_player: Enums.Player = Enums.Player.PLAYER_2 if bot_player == Enums.Player.PLAYER_1 else Enums.Player.PLAYER_1
	var empty_cells: Array[Vector2i] = []

	for x in range(BoardData.GRID_SIZE):
		for y in range(BoardData.GRID_SIZE):
			var coord := Vector2i(x, y)
			if board_data.is_empty(coord):
				empty_cells.append(coord)

	if empty_cells.is_empty():
		return Vector2i(-1, -1)

	var best_offense_coord := Vector2i(-1, -1)
	var max_offense_score := 0

	var best_defense_coord := Vector2i(-1, -1)
	var max_defense_score := 0

	# Симулируем каждый ход
	for coord in empty_cells:
		# 1. Проверяем атаку (сколько очков получит Бот)
		board_data.set_cell(coord, bot_player)
		var bot_patterns := pattern_detector.check_patterns(board_data, coord)
		board_data.set_cell(coord, Enums.Player.NONE)

		var bot_score := _get_max_pattern_score(bot_patterns)
		if bot_score > max_offense_score:
			max_offense_score = bot_score
			best_offense_coord = coord

		# 2. Проверяем защиту (сколько очков получил бы Игрок)
		board_data.set_cell(coord, human_player)
		var human_patterns := pattern_detector.check_patterns(board_data, coord)
		board_data.set_cell(coord, Enums.Player.NONE)

		var human_score := _get_max_pattern_score(human_patterns)
		if human_score > max_defense_score:
			max_defense_score = human_score
			best_defense_coord = coord

	# Приоритет 1: Забрать очки себе
	if max_offense_score > 0:
		return best_offense_coord

	# Приоритет 2: Заблокировать зачисление очков сопернику
	if max_defense_score > 0:
		return best_defense_coord

	# Приоритет 3: Случайный ход
	return empty_cells.pick_random()

func _get_max_pattern_score(patterns: Array[PatternInstance]) -> int:
	var max_pts := 0
	for pattern in patterns:
		var pts: int = PATTERN_SCORES.get(pattern.type, 0)
		if pts > max_pts:
			max_pts = pts
	return max_pts
