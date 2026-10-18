class_name CellView
extends Control

signal clicked(coord: Vector2i)

@onready var background: ColorRect = $Background

var coord: Vector2i = Vector2i.ZERO
var _outline_rect: ReferenceRect

# Состояние для обновления при смене темы на лету
var current_owner: Enums.Player = Enums.Player.NONE
var is_scored: bool = false

# Динамические цвета из темы
var color_empty := Color(0.18, 0.2, 0.25, 1.0)
var color_scored := Color(0.95, 0.8, 0.2, 1.0)
const COLOR_P1 := Color(0.2, 0.5, 0.9, 1.0)      # Синий (Оставляем базовым для P1)
const COLOR_P2 := Color(0.9, 0.3, 0.3, 1.0)      # Красный (Оставляем базовым для P2)

func _ready() -> void:
	if background:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_outline_rect = ReferenceRect.new()
	_outline_rect.set_anchors_preset(PRESET_FULL_RECT)
	_outline_rect.border_width = 4.0
	_outline_rect.editor_only = false
	_outline_rect.mouse_filter = MOUSE_FILTER_IGNORE
	_outline_rect.modulate.a = 0.0
	add_child(_outline_rect)

func setup(p_coord: Vector2i) -> void:
	coord = p_coord
	custom_minimum_size = Vector2(48, 48)

func apply_theme(theme_data: Dictionary) -> void:
	color_empty = theme_data["cell_bg"]
	color_scored = theme_data["pattern_highlight"]
	
	if _outline_rect:
		_outline_rect.border_color = theme_data["pattern_highlight"]
	
	# Принудительно обновляем внешний вид текущей клетки
	_refresh_visuals(false)

func update_state(owner_player: Enums.Player, is_highlighted: bool = false) -> void:
	if not is_node_ready():
		await ready

	var was_empty = (current_owner == Enums.Player.NONE)
	current_owner = owner_player
	is_scored = is_highlighted
	
	_refresh_visuals(was_empty and current_owner != Enums.Player.NONE)

func _refresh_visuals(play_anim: bool) -> void:
	var target_color := color_empty

	if is_scored:
		target_color = color_scored
	else:
		match current_owner:
			Enums.Player.PLAYER_1: target_color = COLOR_P1
			Enums.Player.PLAYER_2: target_color = COLOR_P2
			_: target_color = color_empty

	if play_anim:
		background.color = target_color
		pivot_offset = size / 2.0
		scale = Vector2(0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		background.color = target_color

func animate_pattern_outline(duration: float = 0.5) -> void:
	if _outline_rect == null:
		return

	_outline_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_outline_rect, "modulate:a", 1.0, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.15)
	tween.tween_property(_outline_rect, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(coord)
