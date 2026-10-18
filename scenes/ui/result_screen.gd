class_name ResultScreen
extends Control

signal rematch_requested
signal menu_requested

@onready var title_label: Label = %TitleLabel
@onready var p1_score_label: Label = %P1ScoreLabel
@onready var p2_score_label: Label = %P2ScoreLabel
@onready var figures_label: Label = %FiguresLabel
@onready var combo_label: Label = %ComboLabel
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton
@onready var panel_container: PanelContainer = %PanelContainer

func _ready() -> void:
	if rematch_button:
		rematch_button.pressed.connect(func(): rematch_requested.emit())
	if menu_button:
		menu_button.pressed.connect(func(): menu_requested.emit())
	
	_apply_ui_styles()
	hide_results()

func _apply_ui_styles() -> void:
	# 1. Стилизация задней панели (PanelContainer)
	if panel_container:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("#1A1C23")              # Тёмный современный фон
		panel_style.border_color = Color("#333846")          # Тонкая рамка
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(16)                # Закругление углов
		panel_style.shadow_color = Color(0, 0, 0, 0.5)       # Глубокая тень
		panel_style.shadow_size = 16
		panel_style.shadow_offset = Vector2(0, 4)
		panel_style.set_content_margin_all(24)               # Внутренние отступы
		panel_container.add_theme_stylebox_override("panel", panel_style)

	# 2. Стилизация главного заголовка
	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 30)
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", 6)

	# 3. Стилизация текста статистики
	var stat_labels: Array[Label] = [p1_score_label, p2_score_label, figures_label, combo_label]
	for lbl in stat_labels:
		if lbl:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)

	if p1_score_label:
		p1_score_label.add_theme_color_override("font_color", Color("#4C8BF5")) # Акцент синего
	if p2_score_label:
		p2_score_label.add_theme_color_override("font_color", Color("#FF5252")) # Акцент красного
	if figures_label:
		figures_label.add_theme_color_override("font_color", Color("#A0A5B5"))  # Приглушённый серый
	if combo_label:
		combo_label.add_theme_color_override("font_color", Color("#A0A5B5"))

	# 4. Стилизация кнопок
	# Кнопка реванша (Зелёная)
	_style_button(rematch_button, Color("#2E7D32"), Color("#388E3C"), Color("#1B5E20"))
	# Кнопка меню (Тёмно-серая)
	_style_button(menu_button, Color("#2C303E"), Color("#3A3F52"), Color("#1F222C"))

func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color) -> void:
	if not btn:
		return

	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)

	# Обычное состояние
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.set_corner_radius_all(10)
	style_normal.set_content_margin_all(12)

	# Наведение мышью
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = hover_color

	# Нажатие
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = pressed_color

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)

func show_results(
	p1_score: int, 
	p2_score: int, 
	total_figures: int, 
	max_combo: int, 
	is_vs_bot: bool, 
	human_player: Enums.Player
) -> void:
	visible = true

	# Анимация всплытия модального окна
	if panel_container:
		panel_container.pivot_offset = panel_container.size / 2.0
		panel_container.scale = Vector2(0.7, 0.7)
		panel_container.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel_container, "modulate:a", 1.0, 0.2)

	# Определяем результат матча
	if p1_score == p2_score:
		title_label.text = "НИЧЬЯ!"
		title_label.modulate = Color(0.9, 0.9, 0.9)
	elif is_vs_bot:
		var human_score := p1_score if human_player == Enums.Player.PLAYER_1 else p2_score
		var bot_score := p2_score if human_player == Enums.Player.PLAYER_1 else p1_score

		if human_score > bot_score:
			title_label.text = "ВЫ ПОБЕДИЛИ!"
			title_label.modulate = Color(0.2, 0.9, 0.3)
		else:
			title_label.text = "ВЫ ПРОИГРАЛИ!"
			title_label.modulate = Color(0.9, 0.3, 0.3)
	else:
		if p1_score > p2_score:
			title_label.text = "ПОБЕДИЛ ИГРОК 1!"
			title_label.modulate = Color(0.2, 0.5, 0.9)
		else:
			title_label.text = "ПОБЕДИЛ ИГРОК 2!"
			title_label.modulate = Color(0.9, 0.3, 0.3)

	p1_score_label.text = "Игрок 1: %d" % p1_score
	p2_score_label.text = "Игрок 2: %d" % p2_score
	figures_label.text = "Всего фигур: %d" % total_figures
	combo_label.text = "Макс. очков за ход: %d" % max_combo

func hide_results() -> void:
	visible = false
