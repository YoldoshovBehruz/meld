# scenes/campaign/campaign_menu.gd
class_name CampaignMenu
extends Control

signal level_selected(level: LevelDefinition)
signal back_requested

const DEFAULT_BACKGROUND := Color("#0B1220")
const DEFAULT_PANEL := Color("#121C2F")
const DEFAULT_BORDER := Color("#3B5275")
const DEFAULT_CELL := Color("#18243A")
const DEFAULT_ACCENT := Color("#B56CFF")
const DEFAULT_TEXT := Color("#F4F7FF")
const BOT_NAMES := ["Лёгкий", "Средний", "Сложный"]

var _background: ColorRect
var _ambient_glow: ColorRect
var _left_accent: ColorRect
var _header_panel: PanelContainer
var _content_panel: PanelContainer
var _back_button: Button
var _header_title: Label
var _header_subtitle: Label
var _status_label: Label
var _level_count_label: Label
var _scroll: ScrollContainer
var _map: LevelMap

var _overlay: ColorRect
var _modal_panel: PanelContainer
var _prep_title: Label
var _prep_goals: Label
var _prep_scroll: ScrollContainer
var _cancel_button: Button
var _play_button: Button
var _prep_level: LevelDefinition = null

var _bg_color: Color = DEFAULT_BACKGROUND
var _panel_color: Color = DEFAULT_PANEL
var _border_color: Color = DEFAULT_BORDER
var _cell_color: Color = DEFAULT_CELL
var _accent_color: Color = DEFAULT_ACCENT
var _text_color: Color = DEFAULT_TEXT


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_build_background()
	_build_layout()
	_build_prep_overlay()
	_apply_visual_theme()


func open() -> void:
	_map.rebuild()
	_style_control_tree(_map)
	_update_level_count()
	_overlay.visible = false
	visible = true
	_scroll.scroll_vertical = 0


# Открывает карту кампании и сразу показывает подготовку к заданному уровню.
# Используется при переходе на следующий уровень с экрана результатов.
func open_level_preparation(level: LevelDefinition) -> void:
	if level == null:
		return

	open()
	_show_level_preparation(level)


func close() -> void:
	_overlay.visible = false
	visible = false


# Получает палитру от ThemeManager, чтобы кампания соответствовала теме игры.
func apply_theme(data: Dictionary) -> void:
	_bg_color = _read_color(data, "bg_color", DEFAULT_BACKGROUND)
	_panel_color = _read_color(data, "panel_color", DEFAULT_PANEL)
	_border_color = _read_color(data, "border_color", DEFAULT_BORDER)
	_cell_color = _read_color(data, "cell_color", DEFAULT_CELL)
	_accent_color = _read_color(data, "highlight_color", DEFAULT_ACCENT)
	_text_color = _read_color(data, "text_color", DEFAULT_TEXT)
	_apply_visual_theme()


func _read_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value
	if value is String:
		return Color(value)
	return fallback


# ---------- Основной экран ----------

func _build_background() -> void:
	_background = ColorRect.new()
	_background.color = DEFAULT_BACKGROUND
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# Ненавязчивое цветовое пятно в верхней части экрана.
	_ambient_glow = ColorRect.new()
	_ambient_glow.anchor_left = 0.58
	_ambient_glow.anchor_right = 1.0
	_ambient_glow.anchor_top = 0.0
	_ambient_glow.anchor_bottom = 0.22
	_ambient_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ambient_glow)

	_left_accent = ColorRect.new()
	_left_accent.anchor_left = 0.0
	_left_accent.anchor_right = 0.0
	_left_accent.anchor_top = 0.0
	_left_accent.anchor_bottom = 1.0
	_left_accent.offset_left = 0.0
	_left_accent.offset_right = 3.0
	_left_accent.offset_top = 0.0
	_left_accent.offset_bottom = 0.0
	_left_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_accent)


func _build_layout() -> void:
	var viewport_width := get_viewport_rect().size.x
	var page_padding := 14 if viewport_width < 600.0 else 26

	var page_margin := MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", page_padding)
	page_margin.add_theme_constant_override("margin_right", page_padding)
	page_margin.add_theme_constant_override("margin_top", page_padding)
	page_margin.add_theme_constant_override("margin_bottom", page_padding)
	add_child(page_margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	page_margin.add_child(root)

	# Верхняя панель.
	_header_panel = PanelContainer.new()
	_header_panel.custom_minimum_size = Vector2(0.0, 78.0)
	root.add_child(_header_panel)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 12)
	header_margin.add_theme_constant_override("margin_right", 12)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	_header_panel.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_margin.add_child(header_row)

	_back_button = Button.new()
	_back_button.text = "←  Назад"
	_back_button.custom_minimum_size = Vector2(104.0, 46.0)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	header_row.add_child(_back_button)

	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	title_column.add_theme_constant_override("separation", 2)
	header_row.add_child(title_column)

	_header_title = Label.new()
	_header_title.text = "КАМПАНИЯ"
	_header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title.add_theme_font_size_override("font_size", 25 if viewport_width >= 600.0 else 20)
	_header_title.add_theme_color_override("font_color", DEFAULT_TEXT)
	title_column.add_child(_header_title)

	_header_subtitle = Label.new()
	_header_subtitle.text = "Пройди испытания. Открывай новые уровни."
	_header_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_subtitle.add_theme_font_size_override("font_size", 12)
	_header_subtitle.add_theme_color_override("font_color", Color("#AAB8D0"))
	title_column.add_child(_header_subtitle)

	# Карточка с картой уровней.
	_content_panel = PanelContainer.new()
	_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_panel.custom_minimum_size = Vector2(0.0, 220.0)
	root.add_child(_content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 8)
	content_margin.add_theme_constant_override("margin_right", 8)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	_content_panel.add_child(content_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(_scroll)

	_map = LevelMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.level_chosen.connect(_on_level_chosen)
	_scroll.add_child(_map)

	# Нижняя подсказка и количество уровней.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)

	_status_label = Label.new()
	_status_label.text = "ВЫБЕРИ УРОВЕНЬ, ЧТОБЫ УВИДЕТЬ ЦЕЛИ"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color("#AAB8D0"))
	footer.add_child(_status_label)

	_level_count_label = Label.new()
	_level_count_label.text = ""
	_level_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_level_count_label.add_theme_font_size_override("font_size", 11)
	_level_count_label.add_theme_color_override("font_color", DEFAULT_ACCENT)
	footer.add_child(_level_count_label)


# ---------- Окно подготовки к уровню ----------

func _build_prep_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.01, 0.02, 0.05, 0.78)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var viewport_size := get_viewport_rect().size
	var panel_width := maxf(260.0, minf(460.0, viewport_size.x - 32.0))
	_modal_panel = PanelContainer.new()
	_modal_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	_modal_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_modal_panel)

	var modal_margin := MarginContainer.new()
	var inner_padding := 16 if viewport_size.x < 600.0 else 24
	modal_margin.add_theme_constant_override("margin_left", inner_padding)
	modal_margin.add_theme_constant_override("margin_right", inner_padding)
	modal_margin.add_theme_constant_override("margin_top", inner_padding)
	modal_margin.add_theme_constant_override("margin_bottom", inner_padding)
	_modal_panel.add_child(modal_margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	modal_margin.add_child(box)

	var kicker := Label.new()
	kicker.text = "ПОДГОТОВКА К УРОВНЮ"
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", DEFAULT_ACCENT)
	box.add_child(kicker)

	_prep_title = Label.new()
	_prep_title.add_theme_font_size_override("font_size", 24 if viewport_size.x >= 600.0 else 20)
	_prep_title.add_theme_color_override("font_color", DEFAULT_TEXT)
	_prep_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_prep_title)

	var objective_heading := Label.new()
	objective_heading.text = "УСЛОВИЯ ПРОХОЖДЕНИЯ"
	objective_heading.add_theme_font_size_override("font_size", 11)
	objective_heading.add_theme_color_override("font_color", Color("#AAB8D0"))
	box.add_child(objective_heading)

	_prep_scroll = ScrollContainer.new()
	_prep_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_prep_scroll.custom_minimum_size = Vector2(0.0, clampf(viewport_size.y * 0.34, 120.0, 260.0))
	box.add_child(_prep_scroll)

	_prep_goals = Label.new()
	_prep_goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prep_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prep_goals.add_theme_font_size_override("font_size", 15)
	_prep_goals.add_theme_color_override("font_color", DEFAULT_TEXT)
	_prep_scroll.add_child(_prep_goals)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 10)
	box.add_child(button_row)

	_cancel_button = Button.new()
	_cancel_button.text = "Назад"
	_cancel_button.custom_minimum_size = Vector2(100.0, 46.0)
	_cancel_button.pressed.connect(func() -> void: _overlay.visible = false)
	button_row.add_child(_cancel_button)

	_play_button = Button.new()
	_play_button.text = "▶  Продолжить"
	_play_button.custom_minimum_size = Vector2(152.0, 46.0)
	_play_button.pressed.connect(_on_play_pressed)
	button_row.add_child(_play_button)


func _on_level_chosen(level: LevelDefinition) -> void:
	_show_level_preparation(level)


func _show_level_preparation(level: LevelDefinition) -> void:
	if level == null:
		return

	_prep_level = level
	_prep_title.text = level.title if level.title != "" else String(level.id)
	_prep_goals.text = _goals_text(level)
	_prep_scroll.scroll_vertical = 0
	_overlay.visible = true


func _on_play_pressed() -> void:
	_overlay.visible = false
	if _prep_level != null:
		level_selected.emit(_prep_level)


func _update_level_count() -> void:
	if _level_count_label == null:
		return
	var levels := CampaignManager.get_levels()
	_level_count_label.text = "%d УРОВНЕЙ" % levels.size()


# ---------- Визуальная тема ----------

func _apply_visual_theme() -> void:
	if _background:
		_background.color = _bg_color
	if _ambient_glow:
		_ambient_glow.color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.075)
	if _left_accent:
		_left_accent.color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.9)

	if _header_panel:
		_header_panel.add_theme_stylebox_override(
			"panel", _make_panel_style(_panel_color, _border_color, 1, 16, true)
		)
	if _content_panel:
		_content_panel.add_theme_stylebox_override(
			"panel", _make_panel_style(_panel_color, _border_color, 1, 16, true)
		)
	if _modal_panel:
		_modal_panel.add_theme_stylebox_override(
			"panel", _make_panel_style(_panel_color, _accent_color, 2, 18, true)
		)

	if _header_title:
		_header_title.add_theme_color_override("font_color", _text_color)
	if _header_subtitle:
		_header_subtitle.add_theme_color_override("font_color", _muted_text_color())
	if _status_label:
		_status_label.add_theme_color_override("font_color", _muted_text_color())
	if _level_count_label:
		_level_count_label.add_theme_color_override("font_color", _accent_color)
	if _prep_title:
		_prep_title.add_theme_color_override("font_color", _text_color)
	if _prep_goals:
		_prep_goals.add_theme_color_override("font_color", _text_color)

	if _map:
		_style_control_tree(_map)
	if _back_button:
		_style_button(_back_button)
	if _cancel_button:
		_style_button(_cancel_button)
	if _play_button:
		_style_primary_button(_play_button)


func _muted_text_color() -> Color:
	return _text_color.lerp(_bg_color, 0.36)


func _style_control_tree(node: Node) -> void:
	if node is Button:
		_style_button(node as Button)
	elif node is PanelContainer:
		(node as PanelContainer).add_theme_stylebox_override(
			"panel", _make_panel_style(_cell_color, _border_color, 1, 12, false)
		)
	elif node is Panel:
		(node as Panel).add_theme_stylebox_override(
			"panel", _make_panel_style(_cell_color, _border_color, 1, 12, false)
		)
	elif node is Label:
		(node as Label).add_theme_color_override("font_color", _text_color)

	for child in node.get_children():
		_style_control_tree(child)


func _style_button(button: Button) -> void:
	var normal := _make_flat_style(_cell_color, _border_color, 1, 10)
	var hover_color := _cell_color.lerp(_accent_color, 0.16)
	var hover := _make_flat_style(hover_color, _accent_color, 1, 10)
	var pressed := _make_flat_style(_cell_color.lerp(_accent_color, 0.30), _accent_color, 1, 10)
	var disabled := _make_flat_style(_cell_color.lerp(_bg_color, 0.45), _border_color, 1, 10)
	var focus := _make_flat_style(Color(0.0, 0.0, 0.0, 0.0), _accent_color, 2, 10)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", _text_color)
	button.add_theme_color_override("font_hover_color", _text_color)
	button.add_theme_color_override("font_pressed_color", _text_color)
	button.add_theme_color_override("font_focus_color", _text_color)
	button.add_theme_color_override("font_disabled_color", Color(_text_color.r, _text_color.g, _text_color.b, 0.42))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(
		button.custom_minimum_size.x,
		maxf(button.custom_minimum_size.y, 44.0)
	)


func _style_primary_button(button: Button) -> void:
	_style_button(button)
	button.add_theme_stylebox_override(
		"normal", _make_flat_style(_accent_color, _accent_color, 1, 10)
	)
	button.add_theme_stylebox_override(
		"hover", _make_flat_style(_accent_color.lightened(0.08), _accent_color.lightened(0.08), 1, 10)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_flat_style(_accent_color.darkened(0.16), _accent_color, 1, 10)
	)
	button.add_theme_color_override("font_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	button.add_theme_color_override("font_pressed_color", Color("#FFFFFF"))


func _make_flat_style(
	fill_color: Color,
	outline_color: Color,
	outline_width: int,
	corner_radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = outline_color
	style.set_border_width_all(outline_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_panel_style(
	fill_color: Color,
	outline_color: Color,
	outline_width: int,
	corner_radius: int,
	with_shadow: bool
) -> StyleBoxFlat:
	var style := _make_flat_style(fill_color, outline_color, outline_width, corner_radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	if with_shadow:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0.0, 4.0)
	return style


# ---------- Текст целей кампании ----------

func _goals_text(level: LevelDefinition) -> String:
	var lines: PackedStringArray = []
	if level.bot_difficulty >= 0:
		lines.append("Соперник: бот (%s)" % BOT_NAMES[level.bot_difficulty])
	lines.append("Обязательно:")
	for obj in level.required:
		lines.append("  • " + _describe(obj))
	if level.max_moves > 0:
		lines.append("Лимит ходов: %d" % level.max_moves)
	if not level.bonus.is_empty():
		lines.append("")
		lines.append("Бонусы (звёзды):")
		for obj in level.bonus:
			lines.append("  ★ " + _describe(obj))
	return "\n".join(lines)


func _describe(obj: LevelObjective) -> String:
	if obj.metric == MatchResult.Metric.WIN:
		return "Победа"
	var sign := "≥" if obj.op == LevelObjective.Op.AT_LEAST else "≤"
	return "%s %s %d" % [_metric_name(obj.metric), sign, obj.target]


func _metric_name(metric: MatchResult.Metric) -> String:
	match metric:
		MatchResult.Metric.SCORE: return "Очки"
		MatchResult.Metric.MOVES: return "Ходы"
		MatchResult.Metric.MATCHES: return "Партии"
		MatchResult.Metric.SQUARES: return "Квадраты 2×2"
		MatchResult.Metric.CROSSES: return "X"
		MatchResult.Metric.REVERSE_CROSSES: return "Обратные X"
		MatchResult.Metric.LINES: return "Линии"
	return "Победа"
