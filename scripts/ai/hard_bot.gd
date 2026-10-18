class_name HardBot
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

	var best_score := -999999
	var best_moves: Array[Vector2i] = []

	for coord in empty_cells:
		var score := 0

		# 1. Атака: сколько очков бот получит прямым ходом
		board_data.set_cell(coord, bot_player)
		var bot_patterns := pattern_detector.check_patterns(board_data, coord)
		board_data.set_cell(coord, Enums.Player.NONE)

		var immediate_bot_score := _get_max_pattern_score(bot_patterns)
		if immediate_bot_score > 0:
			score += immediate_bot_score * 100 # Высочайший приоритет забрать очки

		# 2. Защита: насколько этот ход мешает человеку получить очки
		board_data.set_cell(coord, human_player)
		var human_patterns := pattern_detector.check_patterns(board_data, coord)
		board_data.set_cell(coord, Enums.Player.NONE)

		var immediate_human_score := _get_max_pattern_score(human_patterns)
		if immediate_human_score > 0:
			score += immediate_human_score * 80 # Высокий приоритет заблокировать человека

		# 3. Оценка будущего потенциала (заготовки для диагоналей и крестов)
		score += _evaluate_position_potential(board_data, coord, bot_player)

		# 4. Проверка безопасности: не открывает ли этот ход победную клетку сопернику рядом
		score -= _check_retaliation_risk(board_data, pattern_detector, coord, human_player)

		if score > best_score:
			best_score = score
			best_moves = [coord]
		elif score == best_score:
			best_moves.append(coord)

	return best_moves.pick_random()

func _get_max_pattern_score(patterns: Array[PatternInstance]) -> int:
	var max_pts := 0
	for pattern in patterns:
		var pts: int = PATTERN_SCORES.get(pattern.type, 0)
		if pts > max_pts:
			max_pts = pts
	return max_pts

func _evaluate_position_potential(board_data: BoardData, coord: Vector2i, bot_player: Enums.Player) -> int:
	var potential := 0
	# Бонус за близкие союзные клетки (создание связок)
	var neighbors := [
		coord + Vector2i(1, 1), coord + Vector2i(-1, -1),
		coord + Vector2i(1, -1), coord + Vector2i(-1, 1),
		coord + Vector2i(1, 0), coord + Vector2i(-1, 0),
		coord + Vector2i(0, 1), coord + Vector2i(0, -1)
	]
	for n in neighbors:
		if board_data.is_valid_coord(n) and board_data.get_cell(n) == bot_player:
			potential += 2
	return potential

func _check_retaliation_risk(board_data: BoardData, pattern_detector: PatternDetector, coord: Vector2i, human_player: Enums.Player) -> int:
	board_data.set_cell(coord, Enums.Player.PLAYER_1) # Симуляция
	var risk := 0
	var empty_neighbors: Array[Vector2i] = []
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var n := coord + Vector2i(dx, dy)
			if board_data.is_empty(n):
				empty_neighbors.append(n)

	for n in empty_neighbors:
		board_data.set_cell(n, human_player)
		var h_patterns := pattern_detector.check_patterns(board_data, n)
		board_data.set_cell(n, Enums.Player.NONE)
		if _get_max_pattern_score(h_patterns) > 0:
			risk += 30

	board_data.set_cell(coord, Enums.Player.NONE)
	return risk
