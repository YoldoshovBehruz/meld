class_name PatternDetector
extends RefCounted

func check_patterns(board_data: BoardData, last_coord: Vector2i) -> Array[PatternInstance]:
	var new_patterns: Array[PatternInstance] = []
	
	_detect_2x2(board_data, last_coord, new_patterns)
	_detect_x(board_data, last_coord, new_patterns)
	_detect_reverse_x(board_data, last_coord, new_patterns)
	_detect_lines(board_data, last_coord, new_patterns)
	
	return new_patterns

func _detect_2x2(board_data: BoardData, last_coord: Vector2i, result: Array[PatternInstance]) -> void:
	for dx in range(-1, 1):
		for dy in range(-1, 1):
			var top_left := Vector2i(last_coord.x + dx, last_coord.y + dy)
			var c1 := top_left
			var c2 := top_left + Vector2i(1, 0)
			var c3 := top_left + Vector2i(0, 1)
			var c4 := top_left + Vector2i(1, 1)

			if board_data.is_occupied(c1) and board_data.is_occupied(c2) \
			   and board_data.is_occupied(c3) and board_data.is_occupied(c4):
				var cells: Array[Vector2i] = [c1, c2, c3, c4]
				result.append(PatternInstance.new(Enums.PatternType.SQUARE_2X2, cells))

func _detect_x(board_data: BoardData, last_coord: Vector2i, result: Array[PatternInstance]) -> void:
	var possible_center_offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1)
	]

	for offset in possible_center_offsets:
		var center := last_coord + offset
		
		# 4 диагонали (должны быть закрашены)
		var c_top_left := center + Vector2i(-1, -1)
		var c_top_right := center + Vector2i(1, -1)
		var c_bottom_left := center + Vector2i(-1, 1)
		var c_bottom_right := center + Vector2i(1, 1)

		# 4 промежуточные клетки между концами Х (должны быть ПУСТЫМИ)
		var top := center + Vector2i(0, -1)
		var bottom := center + Vector2i(0, 1)
		var left := center + Vector2i(-1, 0)
		var right := center + Vector2i(1, 0)

		# 1. Проверяем, что центр и все 4 диагонали закрашены
		if not (board_data.is_occupied(center) \
		   and board_data.is_occupied(c_top_left) \
		   and board_data.is_occupied(c_top_right) \
		   and board_data.is_occupied(c_bottom_left) \
		   and board_data.is_occupied(c_bottom_right)):
			continue

		# 2. Проверяем, что пространство вокруг Х строго пустое
		if board_data.is_empty(top) \
		   and board_data.is_empty(bottom) \
		   and board_data.is_empty(left) \
		   and board_data.is_empty(right):
			var cells: Array[Vector2i] = [center, c_top_left, c_top_right, c_bottom_left, c_bottom_right]
			result.append(PatternInstance.new(Enums.PatternType.PATTERN_X, cells))

func _detect_reverse_x(board_data: BoardData, last_coord: Vector2i, result: Array[PatternInstance]) -> void:
	var possible_centers: Array[Vector2i] = [
		last_coord + Vector2i(0, 1),
		last_coord + Vector2i(0, -1),
		last_coord + Vector2i(1, 0),
		last_coord + Vector2i(-1, 0)
	]

	for center in possible_centers:
		# Центр должен быть строго пустым
		if not board_data.is_empty(center):
			continue

		# 4 лепестка креста (должны быть закрашены)
		var top := center + Vector2i(0, -1)
		var bottom := center + Vector2i(0, 1)
		var left := center + Vector2i(-1, 0)
		var right := center + Vector2i(1, 0)

		# 4 угловые клетки вокруг креста (должны быть ПУСТЫМИ)
		var top_left := center + Vector2i(-1, -1)
		var top_right := center + Vector2i(1, -1)
		var bottom_left := center + Vector2i(-1, 1)
		var bottom_right := center + Vector2i(1, 1)

		# 1. Проверяем, что 4 лепестка закрашены
		if not (board_data.is_occupied(top) \
		   and board_data.is_occupied(bottom) \
		   and board_data.is_occupied(left) \
		   and board_data.is_occupied(right)):
			continue

		# 2. Проверяем, что углы вокруг креста строго пустые
		if board_data.is_empty(top_left) \
		   and board_data.is_empty(top_right) \
		   and board_data.is_empty(bottom_left) \
		   and board_data.is_empty(bottom_right):
			var cells: Array[Vector2i] = [top, bottom, left, right]
			result.append(PatternInstance.new(Enums.PatternType.REVERSE_X, cells))

func _detect_lines(board_data: BoardData, last_coord: Vector2i, result: Array[PatternInstance]) -> void:
	# 1. Горизонтальная линия
	var h_full := true
	var h_cells: Array[Vector2i] = []
	for x in range(BoardData.GRID_SIZE):
		var coord := Vector2i(x, last_coord.y)
		if not board_data.is_occupied(coord):
			h_full = false
			break
		h_cells.append(coord)

	if h_full:
		result.append(PatternInstance.new(Enums.PatternType.FULL_LINE_H, h_cells))

	# 2. Вертикальная линия
	var v_full := true
	var v_cells: Array[Vector2i] = []
	for y in range(BoardData.GRID_SIZE):
		var coord := Vector2i(last_coord.x, y)
		if not board_data.is_occupied(coord):
			v_full = false
			break
		v_cells.append(coord)

	if v_full:
		result.append(PatternInstance.new(Enums.PatternType.FULL_LINE_V, v_cells))
