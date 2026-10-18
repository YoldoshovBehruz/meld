class_name SettingsModal
extends Control

signal closed

@onready var panel_container: PanelContainer = %PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var category_label: Label = %CategoryLabel
@onready var theme_option: OptionButton = %ThemeOptionButton
@onready var back_button: Button = %BackButton

var theme_manager: ThemeManager

func setup(tm: ThemeManager) -> void:
	theme_manager = tm
	_populate_themes()

func _ready() -> void:
	_apply_ui_styles()
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if theme_option:
		theme_option.item_selected.connect(_on_theme_selected)
	close()

func open() -> void:
	visible = true
	_sync_theme_selection()

func close() -> void:
	visible = false

func _populate_themes() -> void:
	if not theme_option or not theme_manager:
		return

	theme_option.clear()

	for theme_key in ThemeManager.THEMES.keys():
		var data: Dictionary = ThemeManager.THEMES[theme_key]
		theme_option.add_item(data["name"], theme_key)

	# После заполнения сразу выделяем текущую тему.
	_sync_theme_selection()

# Выделяет в списке пункт с id, равным current_theme.
# ВАЖНО: OptionButton.selected — это ИНДЕКС, а не id,
# поэтому напрямую присваивать туда enum нельзя.
func _sync_theme_selection() -> void:
	if not theme_option or not theme_manager:
		return

	for i in theme_option.item_count:
		if theme_option.get_item_id(i) == theme_manager.current_theme:
			theme_option.selected = i
			return

	# Текущая тема не найдена в списке — сбрасываем на первый пункт.
	theme_option.selected = 0

func _on_theme_selected(index: int) -> void:
	# ИСПРАВЛЕНО:
	# enum в GDScript 2.0 нельзя вызывать как функцию.
	# Присваиваем int напрямую — тип enum совместим с int.
	var selected_theme: Enums.ThemeStyle = theme_option.get_item_id(index)

	if theme_manager:
		theme_manager.set_theme(selected_theme)

func _on_back_pressed() -> void:
	close()
	closed.emit()

func _apply_ui_styles() -> void:
	if panel_container:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("#1A1C23")
		panel_style.border_color = Color("#333846")
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(16)
		panel_style.set_content_margin_all(24)
		panel_container.add_theme_stylebox_override("panel", panel_style)

	if title_label:
		title_label.text = "НАСТРОЙКИ"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 24)

	if category_label:
		category_label.text = "ТЕМА ОФОРМЛЕНИЯ"
		category_label.add_theme_font_size_override("font_size", 14)
		category_label.add_theme_color_override("font_color", Color("#A0A5B5"))

	if theme_option:
		theme_option.custom_minimum_size = Vector2(0, 44)
		theme_option.add_theme_font_size_override("font_size", 16)

	_style_button(back_button, Color("#2C303E"), Color("#3A3F52"), Color("#1F222C"), "Назад")

func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color, text: String) -> void:
	if not btn: return
	btn.text = text
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(0, 44)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.set_corner_radius_all(8)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = hover_color

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = pressed_color

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
