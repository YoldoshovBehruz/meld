class_name BoardView
extends CenterContainer

signal cell_clicked(coord: Vector2i)

const CELL_VIEW_SCENE = preload("res://scenes/board/cell_view.tscn")
@onready var grid_container: GridContainer = %GridContainer

var _cells: Dictionary = {}
var _current_theme_data: Dictionary

func create_board() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_cells.clear()

	grid_container.columns = BoardData.GRID_SIZE

	for y in range(BoardData.GRID_SIZE):
		for x in range(BoardData.GRID_SIZE):
			var coord := Vector2i(x, y)
			var cell_instance: CellView = CELL_VIEW_SCENE.instantiate()
			grid_container.add_child(cell_instance)
			cell_instance.setup(coord)
			
			if not _current_theme_data.is_empty():
				cell_instance.apply_theme(_current_theme_data)
				
			cell_instance.clicked.connect(_on_cell_clicked)
			_cells[coord] = cell_instance

func apply_theme(theme_data: Dictionary) -> void:
	_current_theme_data = theme_data
	for cell in _cells.values():
		cell.apply_theme(theme_data)

func update_cell(coord: Vector2i, owner_player: Enums.Player, is_highlighted: bool = false) -> void:
	if _cells.has(coord):
		var cell: CellView = _cells[coord]
		cell.update_state(owner_player, is_highlighted)

func animate_pattern(cells: Array[Vector2i], duration: float = 0.5) -> void:
	for coord in cells:
		if _cells.has(coord):
			var cell: CellView = _cells[coord]
			cell.animate_pattern_outline(duration)

func _on_cell_clicked(coord: Vector2i) -> void:
	cell_clicked.emit(coord)
