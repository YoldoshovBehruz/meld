# scenes/ui/result_screen.gd
class_name ResultScreen
extends Control

signal rematch_requested
signal menu_requested
signal next_level_requested(level: LevelDefinition)

const MARK_OK := "✔"
const MARK_FAIL := "✘"

@onready var title_label: Label = %TitleLabel
@onready var p1_score_label: Label = %P1ScoreLabel
@onready var p2_score_label: Label = %P2ScoreLabel
@onready var figures_label: Label = %FiguresLabel
@onready var combo_label: Label = %ComboLabel
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton
@onready var panel_container: PanelContainer = %PanelContainer

var _is_campaign: bool = false
var _next_level_to_open: LevelDefinition = null

var _campaign_box: VBoxContainer
var _campaign_stars_label: Label
var _campaign_goals_label: Label


func _ready() -> void:
	if rematch_button:
		rematch_button.pressed.connect(_on_rematch_pressed)
	if menu_button:
		menu_button.pressed.connect(func(): menu_requested.emit())

	_build_campaign_box()
	_apply_ui_styles()
	hide_results()


# =========================================================
# ДЕТАЛИ КАМПАНИИ (создаются кодом)
# =========================================================

func _build_campaign_box() -> void:
	_campaign_box = VBoxContainer.new()
	_campaign_box.name = "CampaignBox"
	_campaign_box.add_theme_constant_override("separation", 6)
	_campaign_box.visible = false

	var parent := rematch_button.get_parent()
	parent.add_child(_campaign_box)
	parent.move_child(_campaign_box, rematch_button.get_index())

	_campaign_stars_label = Label.new()
	_campaign_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_stars_label.add_theme_font_size_override("font_size", 32)
	_campaign_stars_label.add_theme_color_override("font_color", Color("#F4C542"))
	_campaign_box.add_child(_campaign_stars_label)

	_campaign_goals_label = Label.new()
	_campaign_goals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_campaign_goals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_campaign_goals_label.add_theme_font_size_override("font_size", 16)
	_campaign_goals_label.add_theme_color_override("font_color", Color("#E0E3EB"))
	_campaign_box.add_child(_campaign_goals_label)


func _build_goals_text(level: LevelDefinition, result: MatchResult) -> String:
	var lines: PackedStringArray = []
	lines.append("Обязательно:")
	for obj in level.required:
		lines.append(_goal_line(obj, result))

	if not level.bonus.is_empty():
		lines.append("")
		lines.append("Бонусы:")
		for obj in level.bonus:
			lines.append(_goal_line(obj, result))

	lines.append("")
	var moves_text := "Ходы: %d" % result.moves
	if level.max_moves > 0:
		moves_text += " / %d" % level.max_moves
	lines.append(moves_text)

	return "\n".join(lines)


func _goal_line(obj: LevelObjective, result: MatchResult) -> String:
	var mark := MARK_OK if obj.check(result) else MARK_FAIL
	var text := "%s  %s" % [mark, obj.describe()]
	if obj.metric != MatchResult.Metric.WIN:
		text += "   (сейчас: %d)" % obj.current_value(result)
	return text


# =========================================================
# СТИЛИ
# =========================================================

func _apply_ui_styles() -> void:
	if panel_container:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color("#1A1C23")
		panel_style.border_color = Color("#333846")
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(16)
		panel_style.shadow_color = Color(0, 0, 0, 0.5)
		panel_style.shadow_size = 16
		panel_style.shadow_offset = Vector2(0, 4)
		panel_style.set_content_margin_all(24)
		panel_container.add_theme_stylebox_override("panel", panel_style)

	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 30)
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", 6)

	var stat_labels: Array[Label] = [p1_score_label, p2_score_label, figures_label, combo_label]
	for lbl in stat_labels:
		if lbl:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)

	if p1_score_label:
		p1_score_label.add_theme_color_override("font_color", Color("#4C8BF5"))
	if p2_score_label:
		p2_score_label.add_theme_color_override("font_color", Color("#FF5252"))
	if figures_label:
		figures_label.add_theme_color_override("font_color", Color("#A0A5B5"))
	if combo_label:
		combo_label.add_theme_color_override("font_color", Color("#A0A5B5"))

	_style_button(rematch_button, Color("#2E7D32"), Color("#388E3C"), Color("#1B5E20"))
	_style_button(menu_button, Color("#2C303E"), Color("#3A3F52"), Color("#1F222C"))


func _style_button(btn: Button, base_color: Color, hover_color: Color, pressed_color: Color) -> void:
	if not btn:
		return

	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.set_corner_radius_all(10)
	style_normal.set_content_margin_all(12)

	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = hover_color

	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = pressed_color

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)


# =========================================================
# ПОКАЗ РЕЗУЛЬТАТА
# =========================================================

# Результат кампании: победа или поражение определяются целями уровня, а не счётом.
func show_campaign_result(
	level: LevelDefinition,
	result: MatchResult,
	next_level: LevelDefinition
) -> void:
	_is_campaign = true
	visible = true
	_set_score_rows_visible(false)
	_campaign_box.visible = true

	var stars := level.evaluate(result)
	var won := stars > 0
	_next_level_to_open = next_level if won else null

	title_label.text = "УРОВЕНЬ ПРОЙДЕН!" if won else "УРОВЕНЬ НЕ ПРОЙДЕН"
	title_label.modulate = Color(0.2, 0.9, 0.3) if won else Color(0.9, 0.3, 0.3)

	_campaign_stars_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	_campaign_goals_label.text = _build_goals_text(level, result)

	rematch_button.text = "СЛЕДУЮЩИЙ УРОВЕНЬ" if _next_level_to_open != null else "ПОВТОРИТЬ"

	_play_show_animation()


# Обычная партия (PvP и бот): победа по счёту, как раньше.
func show_results(
	p1_score: int,
	p2_score: int,
	total_figures: int,
	max_combo: int,
	is_vs_bot: bool,
	human_player: Enums.Player
) -> void:
	_is_campaign = false
	_next_level_to_open = null
	_campaign_box.visible = false
	_set_score_rows_visible(true)
	rematch_button.text = "РЕВАНШ (REMATCH)"
	visible = true

	_play_show_animation()

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


func _set_score_rows_visible(value: bool) -> void:
	for lbl in [p1_score_label, p2_score_label, figures_label, combo_label]:
		if lbl:
			lbl.visible = value


func _play_show_animation() -> void:
	if not panel_container:
		return
	panel_container.pivot_offset = panel_container.size / 2.0
	panel_container.scale = Vector2(0.7, 0.7)
	panel_container.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.2)


func _on_rematch_pressed() -> void:
	if _is_campaign and _next_level_to_open != null:
		next_level_requested.emit(_next_level_to_open)
	else:
		rematch_requested.emit()
