class_name EasyBot
extends RefCounted

func make_move(board_data: BoardData) -> Vector2i:
	var empty_cells: Array[Vector2i] = []
	
	# Собираем список всех свободных клеток на поле
	for x in range(BoardData.GRID_SIZE):
		for y in range(BoardData.GRID_SIZE):
			var coord := Vector2i(x, y)
			if board_data.is_empty(coord):
				empty_cells.append(coord)
	
	if empty_cells.is_empty():
		return Vector2i(-1, -1)
	
	# Выбираем случайную пустую клетку
	return empty_cells.pick_random()
