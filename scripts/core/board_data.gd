class_name BoardData
extends RefCounted

const GRID_SIZE: int = 10

var _grid: Array = []
var _occupied_count: int = 0

func _init() -> void:
	reset()

func reset() -> void:
	_grid.clear()
	_occupied_count = 0
	for x in range(GRID_SIZE):
		var column: Array[Enums.Player] = []
		for y in range(GRID_SIZE):
			column.append(Enums.Player.NONE)
		_grid.append(column)

func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < GRID_SIZE and coord.y >= 0 and coord.y < GRID_SIZE

func get_cell(coord: Vector2i) -> Enums.Player:
	if not is_valid_coord(coord):
		return Enums.Player.NONE
	return _grid[coord.x][coord.y] as Enums.Player

func set_cell(coord: Vector2i, player: Enums.Player) -> bool:
	if not is_valid_coord(coord):
		return false
	var current := _grid[coord.x][coord.y] as Enums.Player
	if current == Enums.Player.NONE and player != Enums.Player.NONE:
		_occupied_count += 1
	elif current != Enums.Player.NONE and player == Enums.Player.NONE:
		_occupied_count -= 1
	_grid[coord.x][coord.y] = player
	return true

func is_occupied(coord: Vector2i) -> bool:
	return is_valid_coord(coord) and get_cell(coord) != Enums.Player.NONE

func is_empty(coord: Vector2i) -> bool:
	return is_valid_coord(coord) and get_cell(coord) == Enums.Player.NONE

func get_occupied_count() -> int:
	return _occupied_count
