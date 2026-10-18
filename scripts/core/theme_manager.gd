class_name ThemeManager
extends Node

signal theme_changed(new_theme: Enums.ThemeStyle)


# ============================================================
# SETTINGS
# ============================================================

const SETTINGS_FILE := "user://theme_settings.cfg"
const SETTINGS_SECTION := "theme"
const SETTINGS_KEY := "current_theme"

const DEFAULT_THEME: Enums.ThemeStyle = Enums.ThemeStyle.MIDNIGHT

var current_theme: Enums.ThemeStyle = DEFAULT_THEME


# ============================================================
# THEMES
# ============================================================

const THEMES = {
	Enums.ThemeStyle.MIDNIGHT: {
		"name": "Midnight — Ночь",
		"bg_color": Color("#0B1220"),
		"panel_bg": Color("#121C2F"),
		"panel_border": Color("#3B5275"),
		"cell_bg": Color("#18243A"),
		"cell_border": Color("#3B5275"),
		"pattern_highlight": Color("#B56CFF"),
		"text_color": Color("#FFFFFF"),
		"overlay_color": Color(0.0, 0.0, 0.0, 0.7)
	},

	Enums.ThemeStyle.FOREST: {
		"name": "Forest — Лес",
		"bg_color": Color("#173B28"),
		"panel_bg": Color("#1E4A33"),
		"panel_border": Color("#4F8560"),
		"cell_bg": Color("#26583A"),
		"cell_border": Color("#4F8560"),
		"pattern_highlight": Color("#F2C94C"),
		"text_color": Color("#FFFFFF"),
		"overlay_color": Color(0.0, 0.0, 0.0, 0.6)
	},

	Enums.ThemeStyle.SUNSET: {
		"name": "Sunset — Закат",
		"bg_color": Color("#8F351F"),
		"panel_bg": Color("#A33F26"),
		"panel_border": Color("#E07A54"),
		"cell_bg": Color("#B94E32"),
		"cell_border": Color("#E07A54"),
		"pattern_highlight": Color("#8C5BFF"),
		"text_color": Color("#FFFFFF"),
		"overlay_color": Color(0.0, 0.0, 0.0, 0.6)
	},

	Enums.ThemeStyle.ARCTIC: {
		"name": "Arctic — Арктика",
		"bg_color": Color("#0E4F63"),
		"panel_bg": Color("#125E75"),
		"panel_border": Color("#46A6BA"),
		"cell_bg": Color("#176B82"),
		"cell_border": Color("#46A6BA"),
		"pattern_highlight": Color("#FFB52E"),
		"text_color": Color("#FFFFFF"),
		"overlay_color": Color(0.0, 0.0, 0.0, 0.6)
	}
}


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	# Добавляем себя в группу, чтобы другие экраны могли
	# найти ThemeManager даже без знания имени автозагрузки.
	add_to_group("theme_manager")

	_load_theme()


# ============================================================
# THEME DATA
# ============================================================

func get_theme_data(theme: Enums.ThemeStyle = current_theme) -> Dictionary:
	return THEMES.get(
		theme,
		THEMES[DEFAULT_THEME]
	)


# ============================================================
# SET THEME
# ============================================================

func set_theme(theme: Enums.ThemeStyle) -> void:
	# Не делаем лишнюю запись, если тема уже выбрана.
	if current_theme == theme:
		return

	# Проверяем, существует ли такая тема.
	if not THEMES.has(theme):
		push_warning("ThemeManager: неизвестная тема: %s" % theme)
		return

	# Меняем текущую тему.
	current_theme = theme

	# СРАЗУ сохраняем её на диск.
	_save_theme()

	# Уведомляем остальные системы игры.
	theme_changed.emit(current_theme)


# ============================================================
# SAVE
# ============================================================

func _save_theme() -> void:
	var config := ConfigFile.new()

	# Сохраняем выбранную тему как integer enum.
	config.set_value(
		SETTINGS_SECTION,
		SETTINGS_KEY,
		int(current_theme)
	)

	var error := config.save(SETTINGS_FILE)

	if error != OK:
		push_warning(
			"ThemeManager: не удалось сохранить тему. Ошибка: %s"
			% error
		)


# ============================================================
# LOAD
# ============================================================

func _load_theme() -> void:
	var config := ConfigFile.new()

	var error := config.load(SETTINGS_FILE)

	# Файла ещё нет — используем Midnight.
	if error == ERR_FILE_NOT_FOUND:
		current_theme = DEFAULT_THEME
		return

	# Другая ошибка чтения.
	if error != OK:
		push_warning(
			"ThemeManager: не удалось загрузить настройки темы. Ошибка: %s"
			% error
		)

		current_theme = DEFAULT_THEME
		return

	# Получаем сохранённое значение.
	var saved_theme = config.get_value(
		SETTINGS_SECTION,
		SETTINGS_KEY,
		int(DEFAULT_THEME)
	)

	# Проверяем, что значение действительно является существующей темой.
	if THEMES.has(saved_theme):
		current_theme = saved_theme as Enums.ThemeStyle
	else:
		push_warning(
			"ThemeManager: сохранена неизвестная тема: %s. Используется Midnight."
			% saved_theme
		)

		current_theme = DEFAULT_THEME
