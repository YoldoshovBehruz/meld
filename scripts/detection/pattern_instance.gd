class_name PatternInstance
extends RefCounted

var type: Enums.PatternType
var occupied_cells: Array[Vector2i]
var unique_id: String

func _init(p_type: Enums.PatternType, p_cells: Array[Vector2i]) -> void:
	type = p_type
	occupied_cells = p_cells.duplicate()
	unique_id = _generate_unique_id()

func _generate_unique_id() -> String:
	var sorted_cells: Array[Vector2i] = occupied_cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)
	var id_str: String = "%d:" % [type]
	for cell in sorted_cells:
		id_str += "(%d,%d)" % [cell.x, cell.y]
	return id_str
