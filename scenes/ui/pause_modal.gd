class_name PauseModal
extends CanvasLayer

signal resume_requested
signal quit_requested

var _bg_overlay: ColorRect
var panel: PanelContainer
var resume_button: Button
var quit_button: Button

func _ready() -> void:
	# Гарантируем обработку ввода во время get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100 # Отображаем поверх всех остальных UI элементов
	_build_ui()
	_connect_signals()
	hide()

func _build_ui() -> void:
	# 1. Полупрозрачный затемняющий фон на весь экран
	_bg_overlay = ColorRect.new()
	_bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_overlay.color = Color(0, 0, 0, 0.75)
	# Перехватываем клики, чтобы они не пролетали сквозь паузу на игровое поле
	_bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_overlay)

	# 2. Контейнер центрирования панели
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 3. Основное окно паузы
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 220)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	resume_button = Button.new()
	resume_button.text = "ПРОДОЛЖИТЬ"
	resume_button.custom_minimum_size = Vector2(0, 48)
	resume_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	vbox.add_child(resume_button)

	quit_button = Button.new()
	quit_button.text = "ВЫЙТИ В МЕНЮ"
	quit_button.custom_minimum_size = Vector2(0, 48)
	quit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	vbox.add_child(quit_button)

func _connect_signals() -> void:
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func open() -> void:
	show()

func close() -> void:
	hide()

func _on_resume_pressed() -> void:
	close()
	resume_requested.emit()

func _on_quit_pressed() -> void:
	close()
	quit_requested.emit()

func apply_theme(theme_data: Dictionary) -> void:
	var text_col: Color = theme_data.get("text_color", Color.WHITE)
	var btn_bg: Color = theme_data.get("cell_bg", Color("#2C303E"))
	var btn_hover: Color = theme_data.get("panel_bg", Color("#3A3F52"))
	var btn_pressed: Color = theme_data.get("panel_border", Color("#1F222C"))

	if resume_button:
		_style_button(resume_button, Color("#1E88E5"), Color("#2196F3"), Color("#1565C0"), Color.WHITE)
	if quit_button:
		_style_button(quit_button, btn_bg, btn_hover, btn_pressed, text_col)

func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color, font_color: Color) -> void:
	if not btn:
		return
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", font_color)

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
