class_name BotSettingsModal
extends Control

signal start_game_requested(difficulty: Enums.BotDifficulty, first_turn: Enums.FirstTurn, player_color: Enums.PlayerColor)
signal cancelled

@export var difficulty_label: Label
@export var turn_label: Label
@export var color_label: Label

var diff_option: OptionButton
var turn_option: OptionButton
var color_option: OptionButton
var start_button: Button
var back_button: Button

var _panel_container: PanelContainer
var _main_box: VBoxContainer
var _bg_overlay: ColorRect

func _ready() -> void:
	_build_ui_layout()
	_setup_options()
	_connect_signals()
	visible = false

func _build_ui_layout() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	
	_bg_overlay = ColorRect.new()
	_bg_overlay.set_anchors_preset(PRESET_FULL_RECT)
	add_child(_bg_overlay)

	_panel_container = PanelContainer.new()
	_panel_container.custom_minimum_size = Vector2(360, 420)
	_panel_container.set_anchors_preset(PRESET_CENTER)
	_panel_container.grow_horizontal = GROW_DIRECTION_BOTH
	_panel_container.grow_vertical = GROW_DIRECTION_BOTH
	add_child(_panel_container)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
	_panel_container.add_child(margin_container)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 16)
	margin_container.add_child(_main_box)

	diff_option = OptionButton.new()
	turn_option = OptionButton.new()
	color_option = OptionButton.new()

	_add_field_section(difficulty_label, diff_option)
	_add_field_section(turn_label, turn_option)
	_add_field_section(color_label, color_option)

	var btn_box := HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	_main_box.add_child(btn_box)

	back_button = Button.new()
	back_button.text = "Назад"
	back_button.size_flags_horizontal = SIZE_EXPAND_FILL
	back_button.custom_minimum_size = Vector2(0, 42)

	start_button = Button.new()
	start_button.text = "ИГРАТЬ"
	start_button.size_flags_horizontal = SIZE_EXPAND_FILL
	start_button.custom_minimum_size = Vector2(0, 42)

	btn_box.add_child(back_button)
	btn_box.add_child(start_button)

func apply_theme(theme_data: Dictionary) -> void:
	_bg_overlay.color = theme_data.get("overlay_color", Color(0.05, 0.07, 0.1, 0.65))

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = theme_data["panel_bg"]
	panel_style.border_color = theme_data["panel_border"]
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 12
	_panel_container.add_theme_stylebox_override("panel", panel_style)

	var text_col: Color = theme_data["text_color"]
	if difficulty_label: difficulty_label.add_theme_color_override("font_color", text_col)
	if turn_label: turn_label.add_theme_color_override("font_color", text_col)
	if color_label: color_label.add_theme_color_override("font_color", text_col)

	var opt_style := StyleBoxFlat.new()
	opt_style.bg_color = theme_data["cell_bg"]
	opt_style.border_color = theme_data["cell_border"]
	opt_style.set_border_width_all(1)
	opt_style.set_corner_radius_all(6)
	opt_style.content_margin_left = 12
	opt_style.content_margin_right = 12

	for opt in [diff_option, turn_option, color_option]:
		opt.add_theme_color_override("font_color", text_col)
		opt.add_theme_stylebox_override("normal", opt_style)
		opt.add_theme_stylebox_override("hover", opt_style)
		opt.add_theme_stylebox_override("pressed", opt_style)

	var back_style := StyleBoxFlat.new()
	back_style.bg_color = theme_data["cell_bg"]
	back_style.set_corner_radius_all(8)
	back_button.add_theme_color_override("font_color", text_col)
	back_button.add_theme_stylebox_override("normal", back_style)
	back_button.add_theme_stylebox_override("hover", back_style)

	var start_style := StyleBoxFlat.new()
	start_style.bg_color = Color(0.2, 0.6, 0.9, 1.0) # Оставляем акцентным
	start_style.set_corner_radius_all(8)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", start_style)
	start_button.add_theme_stylebox_override("hover", start_style)

func _add_field_section(lbl: Label, option: OptionButton) -> void:
	var field_box := VBoxContainer.new()
	field_box.add_theme_constant_override("separation", 6)
	if lbl != null:
		if lbl.get_parent():
			lbl.get_parent().remove_child(lbl)
		field_box.add_child(lbl)
	option.custom_minimum_size = Vector2(0, 38)
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	field_box.add_child(option)
	_main_box.add_child(field_box)

func _setup_options() -> void:
	diff_option.clear()
	diff_option.add_item("Легко", Enums.BotDifficulty.EASY)
	diff_option.add_item("Средне", Enums.BotDifficulty.MEDIUM)
	diff_option.add_item("Сложно", Enums.BotDifficulty.HARD)
	diff_option.select(0)
	
	turn_option.clear()
	turn_option.add_item("Игрок", Enums.FirstTurn.PLAYER)
	turn_option.add_item("Бот", Enums.FirstTurn.BOT)
	turn_option.add_item("Случайно", Enums.FirstTurn.RANDOM)
	turn_option.select(0)

	color_option.clear()
	color_option.add_item("Синий", Enums.PlayerColor.BLUE)
	color_option.add_item("Красный", Enums.PlayerColor.RED)
	color_option.select(0)

func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

func open() -> void:
	visible = true

func close() -> void:
	visible = false

func _on_start_pressed() -> void:
	var diff := diff_option.selected as Enums.BotDifficulty
	var turn := turn_option.selected as Enums.FirstTurn
	var col := color_option.selected as Enums.PlayerColor
	close()
	start_game_requested.emit(diff, turn, col)

func _on_back_pressed() -> void:
	close()
	cancelled.emit()
